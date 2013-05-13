//
//  QuickLocalization.m
//  QuickLocalization
//
//  Created by Zitao Xiong on 5/12/13.
//  Copyright (c) 2013 nanaimostudio. All rights reserved.
//

#import "QuickLocalization.h"
#import "RCXcode.h"
static NSString *localizeRegexs[] = {
    @"NSLocalizedString\\s*\\(\\s*@\"(.*)\"\\s*,\\s*(.*)\\s*\\)",
    @"localizedStringForKey:\\s*@\"(.*)\"\\s*value:\\s*(.*)\\s*table:\\s*(.*)",
    @"NSLocalizedStringFromTable\\s*\\(\\s*@\"(.*)\"\\s*,\\s*(.*)\\s*,\\s*(.*)\\s*\\)",
    @"NSLocalizedStringFromTableInBundle\\s*\\(\\s*@\"(.*)\"\\s*,\\s*(.*)\\s*,\\s*(.*)\\s*,\\s*(.*)\\s*\\)",
    @"NSLocalizedStringWithDefaultValue\\s*\\(\\s*@\"(.*)\"\\s*,\\s*(.*)\\s*,\\s*(.*)\\s*,\\s*(.*)\\s*,\\s*(.*)\\s*\\)"
};
static NSString *stringRegexs = @"@\"[^\"]*\"";
@implementation QuickLocalization


+ (void)pluginDidLoad:(NSBundle *)plugin {
    static id sharedPlugin = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedPlugin = [[self alloc] init];
    });
}

- (id)init {
    if (self = [super init]) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidFinishLaunching:)
                                                     name:NSApplicationDidFinishLaunchingNotification
                                                   object:nil];
    }
    return self;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    NSMenuItem *viewMenuItem = [[NSApp mainMenu] itemWithTitle:@"Edit"];
    if (viewMenuItem) {
        [[viewMenuItem submenu] addItem:[NSMenuItem separatorItem]];
        NSMenuItem *sample = [[NSMenuItem alloc] initWithTitle:@"Quick Localization" action:@selector(quickLocalization) keyEquivalent:@"c"];
        [sample setKeyEquivalentModifierMask:NSCommandKeyMask | NSShiftKeyMask];
        [sample setTarget:self];
        [[viewMenuItem submenu] addItem:sample];
        [sample release];
    }
}

// Sample Action, for menu item:
- (void)quickLocalization {
    IDESourceCodeDocument *document = [RCXcode currentSourceCodeDocument];
    NSTextView *textView = [RCXcode currentSourceCodeTextView];
    if (!document || !textView) {
        return;
    }
    
    //    NSLog(@"file: %@", [RCXcode currentWorkspaceDocument].workspace.representingFilePath.fileURL.absoluteString);
    NSArray *selectedRanges = [textView selectedRanges];
    if ([selectedRanges count] > 0) {
        NSRange range = [[selectedRanges objectAtIndex:0] rangeValue];
        NSRange lineRange = [textView.textStorage.string lineRangeForRange:range];
        NSString *line = [textView.textStorage.string substringWithRange:lineRange];
        
        NSRegularExpression *localizedRex = [[[NSRegularExpression alloc] initWithPattern:localizeRegexs[0] options:NSRegularExpressionCaseInsensitive error:nil] autorelease];
        NSArray *localizedMatches = [localizedRex matchesInString:line options:0 range:NSMakeRange(0, [line length])];
        
        NSRegularExpression *regex = [[[NSRegularExpression alloc] initWithPattern:stringRegexs options:NSRegularExpressionCaseInsensitive error:nil] autorelease];
        NSArray *matches = [regex matchesInString:line options:0 range:NSMakeRange(0, [line length])];
        NSUInteger addedLength = 0;
        for (int i = 0; i < [matches count]; i++) {
            NSTextCheckingResult *result = [matches objectAtIndex:i];
            NSRange matchedRangeInLine = result.range;
            NSRange matchedRangeInDocument = NSMakeRange(lineRange.location + matchedRangeInLine.location + addedLength, matchedRangeInLine.length);
            if ([self isRange:matchedRangeInLine inSkipedRanges:localizedMatches]) {
                continue;
            }
            NSString *string = [line substringWithRange:matchedRangeInLine];
            
            NSString *outputString = [NSString stringWithFormat:@"NSLocalizedString(%@, %@)", string, string];
            addedLength = outputString.length - string.length;
            if ([textView shouldChangeTextInRange:matchedRangeInDocument replacementString:outputString]) {
                [textView.textStorage replaceCharactersInRange:matchedRangeInDocument
                                          withAttributedString:[[[NSAttributedString alloc] initWithString:outputString] autorelease]];
                [textView didChangeText];
            }
            
            //            [textView replaceCharactersInRange:matchedRangeInDocument withString:outputString];
            //            NSAlert *alert = [NSAlert alertWithMessageText:outputString defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:@""];
            //            [alert runModal];
        }
    }
}

- (BOOL)isRange:(NSRange)range inSkipedRanges:(NSArray *)ranges {
    for (int i = 0; i < [ranges count]; i++) {
        NSTextCheckingResult *result = [ranges objectAtIndex:i];
        NSRange skippedRange = result.range;
        if (skippedRange.location <= range.location && skippedRange.location + skippedRange.length > range.location + range.length) {
            return YES;
        }
    }
    return NO;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

@end