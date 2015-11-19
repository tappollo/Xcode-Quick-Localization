//
//  QLIDEHelper.m
//  QLMethod2Implement
//
//  Created by Long on 14-4-15.
//  Copyright (c) 2014年 Tendencystudio. All rights reserved.
//

#import "QLIDEHelper.h"
#import "QLXcodeHelper.h"
#import <AppKit/AppKit.h>

@implementation QLIDEHelper


+ (BOOL)openFile:(NSString *)filePath
{
    NSWindowController *currentWindowController = [[NSApp mainWindow] windowController];
    NSLog(@"currentWindowController %@",[currentWindowController description]);
    if ([currentWindowController isKindOfClass:NSClassFromString(@"IDEWorkspaceWindowController")]) {
        NSLog(@"Open in current Xocde");
        id<NSApplicationDelegate> appDelegate = (id<NSApplicationDelegate>)[NSApp delegate];
        if ([appDelegate application:NSApp openFile:filePath]) {
            return YES;
        }
    }
    return NO;
}

+ (NSString *)getCurrentEditFilePath
{
    IDESourceCodeDocument *currentSourceCodeDocument = [QLXcodeHelper currentSourceCodeDocument];
    NSString *filePath = [[currentSourceCodeDocument fileURL] path];
    return filePath;
}

+ (BOOL)isHeaderFile
{
    NSString *filePath = [QLIDEHelper getCurrentEditFilePath];
    if ([filePath rangeOfString:@".h"].length > 0) {
        return YES;
    }
    return NO;
}

+ (NSString *)getHFilePathOfCurrentEditFile
{
    NSString *filePath = [QLIDEHelper getCurrentEditFilePath];
    filePath = [filePath stringByDeletingPathExtension];
    filePath = [filePath stringByAppendingPathExtension:@"h"];
    return filePath;
}

+ (NSString *)getMFilePathOfCurrentEditFile
{
    NSString *filePath = [QLIDEHelper getCurrentEditFilePath];
    if ([filePath rangeOfString:@".h"].length > 0) {
        NSString *mFilePath = [filePath stringByReplacingOccurrencesOfString:@".h" withString:@".m"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:mFilePath]) {
            return mFilePath;
        }
        
        mFilePath = [filePath stringByReplacingOccurrencesOfString:@".h" withString:@".mm"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:mFilePath]) {
            return mFilePath;
        }
        
    }
    return filePath;
}

+ (NSString *)getCurrentClassName
{
    NSString *fileName = [[QLIDEHelper getCurrentEditFilePath] lastPathComponent];
    return [fileName stringByDeletingPathExtension];
}

+ (void)selectText:(NSString *)text
{
    NSTextView *textView = [QLXcodeHelper currentSourceCodeTextView];
    NSRange textRange = [textView.textStorage.string rangeOfString:text options:NSCaseInsensitiveSearch];
    if (textRange.location != NSNotFound)
    {
        [textView setSelectedRange:textRange];
        [textView scrollRangeToVisible:textRange];
    }
}

+ (void)selectTextWithRegex:(NSString *)regex highlightText:(NSString *)text
{
    NSTextView *textView = [QLXcodeHelper currentSourceCodeTextView];
    NSRegularExpression *regularExpression = [NSRegularExpression
                                              regularExpressionWithPattern:regex
                                              options:NSRegularExpressionAnchorsMatchLines
                                              error:NULL];
    
    NSRange range = [regularExpression rangeOfFirstMatchInString:textView.textStorage.string
                                                         options:0
                                                           range:NSMakeRange(0, [textView.textStorage.string length])];
    if (range.location == NSNotFound) {
        return;
    }
    
    NSString *string = [textView.textStorage.string substringWithRange:range];
    NSLog(@"selectTextWithRegex: %@", string);
    NSRange textRange = [string rangeOfString:text options:NSCaseInsensitiveSearch];
    if (textRange.location != NSNotFound) {
        range = NSMakeRange(range.location+textRange.location, textRange.length);
    }
    [textView setSelectedRange:range];
    [textView scrollRangeToVisible:range];
}

+ (void)replaceText:(NSString *)text withNewText:(NSString *)newText
{
    NSTextView *textView = [QLXcodeHelper currentSourceCodeTextView];
    NSRange textRange = [textView.textStorage.string rangeOfString:text options:NSCaseInsensitiveSearch];
    [textView scrollRangeToVisible:textRange];
    [textView insertText:newText replacementRange:textRange];
}

+ (NSString *)getCurrentSelectMethod
{
    NSTextView *textView = [QLXcodeHelper currentSourceCodeTextView];
    NSArray* selectedRanges = [textView selectedRanges];
    if (selectedRanges.count >= 1) {
        NSRange selectedRange = [[selectedRanges objectAtIndex:0] rangeValue];
        NSString *text = textView.textStorage.string;
        NSRange lineRange = [text lineRangeForRange:selectedRange];
        NSString *line = [text substringWithRange:lineRange];
        return line;
    }
    return nil;
}

+ (NSArray *)getCurrentClassNameByCurrentSelectedRangeWithFileType:(QLIDEFileType)fileType
{
    NSTextView *textView = [QLXcodeHelper currentSourceCodeTextView];
    NSArray* selectedRanges = [textView selectedRanges];
    if (selectedRanges.count >= 1) {
        NSRange selectedRange = [[selectedRanges objectAtIndex:0] rangeValue];
        NSString *text = textView.textStorage.string;
        NSRange lineRange = [text lineRangeForRange:selectedRange];
        NSString *regexString = nil;
        if (fileType == QLIDEFileTypeHFile) {
            regexString = @"(?<=@interface)\\s+(\\w+)\\s*\\(?(\\w*)\\)?";
        }else if (fileType == QLIDEFileTypeMFile) {
            regexString = @"(?<=@implementation)\\s+(\\w+)\\s*\\(?(\\w*)\\)?";
        }
        NSRegularExpression *regex = [NSRegularExpression
                                      regularExpressionWithPattern:regexString
                                      options:0
                                      error:NULL];
        NSArray *results = [regex matchesInString:textView.textStorage.string options:0 range:NSMakeRange(0, lineRange.location)];
        if (results.count > 0) {
            NSTextCheckingResult *textCheckingResult = results[results.count - 1];
            NSRange classNameRange = textCheckingResult.range;
            if (classNameRange.location != NSNotFound) {
                NSMutableArray *array = [NSMutableArray array];
                for (int i = 0; i < textCheckingResult.numberOfRanges; i++) {
                    NSString *item = [text substringWithRange:[textCheckingResult rangeAtIndex:i]];
                    if (item.length > 0) {
                        [array addObject:item];
                        NSLog(@"%@", item);
                    }
                }
                return array;
            }
        }
    }
    return nil;
}

+ (NSRange)getClassImplementContentRangeWithClassNameItemList:(NSArray *)classNameItemList fileText:(NSString *)fileText fileType:(QLIDEFileType)fileType
{
    if (classNameItemList.count > 1) {
        NSString *normalImplementationFormatString = @"@implementation\\s+%@.+?(?=\\s{0,3000}@end)";
        if (fileType == QLIDEFileTypeHFile) {
            normalImplementationFormatString = @"@interface\\s+%@.+?(?=\\s{0,3000}@end)";
        }
        
        NSString *regexPattern = [NSString stringWithFormat:normalImplementationFormatString, classNameItemList[1]];
        if (classNameItemList.count == 3) {
            NSString *categoryImplementationFormatString = @"@implementation\\s+%@\\s+\\(%@\\).+?(?=\\s{0,3000}@end)";
            if (fileType == QLIDEFileTypeHFile) {
                categoryImplementationFormatString = @"@interface\\s+%@\\s+\\(%@\\).+?(?=\\s{0,3000}@end)";
            }
            regexPattern = [NSString stringWithFormat:categoryImplementationFormatString, classNameItemList[1], classNameItemList[2]];
        }
        NSLog(@"#%@",regexPattern);
        
        NSRegularExpression *regex = [NSRegularExpression
                                      regularExpressionWithPattern:regexPattern
                                      options:NSRegularExpressionDotMatchesLineSeparators
                                      error:NULL];
        
        NSTextCheckingResult *textCheckingResult = [regex firstMatchInString:fileText
                                                                     options:0
                                                                       range:NSMakeRange(0, fileText.length)];
        
        //        NSLog(@"#%@", [fileText substringWithRange:textCheckingResult.range]);
        if (textCheckingResult.range.location != NSNotFound) {
            return textCheckingResult.range;
        }
        
    }
    return NSMakeRange(NSNotFound, 0);
}

+ (NSRange)getInsertRangeWithClassImplementContentRange:(NSRange)range
{
    if (range.location != NSNotFound) {
        return NSMakeRange(range.location+range.length, 1);
    }
    
    return NSMakeRange(NSNotFound, 0);
}

@end

