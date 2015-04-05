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
static NSString * const QLShouldUseNilForComment = @"QLShouldUseNilForComment";
static NSString * const QLShouldUseSnippetForComment = @"QLShouldUseSnippetForComment";

@interface QuickLocalization ()

@property (nonatomic, assign) BOOL shouldUseNilForComment;
@property (nonatomic, assign) BOOL shouldUseSnippetForComment;

@end

@implementation QuickLocalization

static id sharedPlugin = nil;


+ (void)pluginDidLoad:(NSBundle *)plugin {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedPlugin = [[self alloc] init];
    });
}

- (id)init {
    if (self = [super init]) {
        NSMenuItem *viewMenuItem = [[NSApp mainMenu] itemWithTitle:@"Edit"];
        if (viewMenuItem) {
            [[viewMenuItem submenu] addItem:[NSMenuItem separatorItem]];
            
            NSMenuItem *localization = [[NSMenuItem alloc] initWithTitle:@"Quick Localization" action:@selector(quickLocalization) keyEquivalent:@"d"];
            [localization setKeyEquivalentModifierMask:NSShiftKeyMask | NSAlternateKeyMask];
            [localization setTarget:self];
            
            NSMenuItem *nilToggle = [[NSMenuItem alloc] initWithTitle:@"Use nil for NSLocalizedString comment" action:@selector(toggleNilOption) keyEquivalent:@""];
            [nilToggle setTarget:self];
            
            NSMenuItem *snippetToggle = [[NSMenuItem alloc] initWithTitle:@"Use <# comments #> for NSLocalizedString comment" action:@selector(toggleSnippetOption) keyEquivalent:@""];
            [snippetToggle setTarget:self];
            
            NSMenu *groupMenu = [[NSMenu alloc] initWithTitle:@"Quick Localization"];
            [groupMenu addItem:localization];
            [groupMenu addItem:nilToggle];
            [groupMenu addItem:snippetToggle];
            
            NSMenuItem *groupMenuItem = [[NSMenuItem alloc] initWithTitle:@"Quick Localization" action:NULL keyEquivalent:@""];
            [[viewMenuItem submenu] addItem:groupMenuItem];
            [[viewMenuItem submenu] setSubmenu:groupMenu forItem:groupMenuItem];
        }
    }
    return self;
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
        
        NSRegularExpression *localizedRex = [[NSRegularExpression alloc] initWithPattern:localizeRegexs[0] options:NSRegularExpressionCaseInsensitive error:nil];
        NSArray *localizedMatches = [localizedRex matchesInString:line options:0 range:NSMakeRange(0, [line length])];
        
        NSRegularExpression *regex = [[NSRegularExpression alloc] initWithPattern:stringRegexs options:NSRegularExpressionCaseInsensitive error:nil];
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
//            NSLog(@"string index:%d, %@", i, string);
            NSString *outputString;

            if ([self shouldUseNilForComment]) {
                outputString = [NSString stringWithFormat:@"NSLocalizedString(%@, nil)", string];
            }
            else if ([self shouldUseSnippetForComment]) {
                outputString = [NSString stringWithFormat:@"NSLocalizedString(%@, <# comments #>)", string];
            }
            else {
                outputString = [NSString stringWithFormat:@"NSLocalizedString(%@, %@)", string, string];
            }

            addedLength = addedLength + outputString.length - string.length;
            if ([textView shouldChangeTextInRange:matchedRangeInDocument replacementString:outputString]) {
                [textView.textStorage replaceCharactersInRange:matchedRangeInDocument
                                          withAttributedString:[[NSAttributedString alloc] initWithString:outputString]];
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

- (void)toggleNilOption {
    [self setShouldUseNilForComment:![self shouldUseNilForComment]];
    if (self.shouldUseNilForComment) {
        self.shouldUseSnippetForComment = NO;
    }
}

- (void)toggleSnippetOption {
    self.shouldUseSnippetForComment = !self.shouldUseSnippetForComment;
    if (self.shouldUseSnippetForComment) {
        self.shouldUseNilForComment = NO;
    }
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    if ([menuItem action] == @selector(toggleNilOption)) {
        [menuItem setState:[self shouldUseNilForComment] ? NSOnState : NSOffState];
    }
    else if ([menuItem action] == @selector(toggleSnippetOption)) {
        [menuItem setState:[self shouldUseSnippetForComment] ? NSOnState : NSOffState];
    }
    return YES;
}

#pragma mark Preferences

- (BOOL)shouldUseNilForComment {
    return [[NSUserDefaults standardUserDefaults] boolForKey:QLShouldUseNilForComment];
}

- (void)setShouldUseNilForComment:(BOOL)shouldUseNilForComment {
    [[NSUserDefaults standardUserDefaults] setBool:shouldUseNilForComment forKey:QLShouldUseNilForComment];
}

- (BOOL)shouldUseSnippetForComment {
    return [[NSUserDefaults standardUserDefaults] boolForKey:QLShouldUseSnippetForComment];
}

- (void)setShouldUseSnippetForComment:(BOOL)shouldUseSnippetForComment {
    [[NSUserDefaults standardUserDefaults] setBool:shouldUseSnippetForComment forKey:QLShouldUseSnippetForComment];
}
@end
