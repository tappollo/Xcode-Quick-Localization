//
//  QuickLocalization.m
//  QuickLocalization
//
//  Created by Zitao Xiong on 5/12/13.
//  Copyright (c) 2013 nanaimostudio. All rights reserved.
//

#import "QuickLocalization.h"
#import "RCXcode.h"
#import "OLSettingController.h"
#import "QLMenuGenerator.h"
#import "QLIDEHelper.h"

static NSString *localizeRegexs[] = {
    @"NSLocalizedString\\s*\\(\\s*@\"(.*)\"\\s*,\\s*(.*)\\s*\\)",
    @"localizedStringForKey:\\s*@\"(.*)\"\\s*value:\\s*(.*)\\s*table:\\s*(.*)",
    @"NSLocalizedStringFromTable\\s*\\(\\s*@\"(.*)\"\\s*,\\s*(.*)\\s*,\\s*(.*)\\s*\\)",
    @"NSLocalizedStringFromTableInBundle\\s*\\(\\s*@\"(.*)\"\\s*,\\s*(.*)\\s*,\\s*(.*)\\s*,\\s*(.*)\\s*\\)",
    @"NSLocalizedStringWithDefaultValue\\s*\\(\\s*@\"(.*)\"\\s*,\\s*(.*)\\s*,\\s*(.*)\\s*,\\s*(.*)\\s*,\\s*(.*)\\s*\\)"
};

static NSString *objcStringRegexs = @"@([\"'])(?:(?=(\\\\?))\\2.)*?\\1";
static NSString *swiftStringRegexs = @"([\"'])(?:(?=(\\\\?))\\2.)*?\\1";

static NSString * const QLShouldUseNilForComment = @"QLShouldUseNilForComment";
static NSString * const QLShouldUseSnippetForComment = @"QLShouldUseSnippetForComment";
static NSString * const QLShouldUseSwiftSyntax = @"QLShouldUseSwiftSyntax";
static NSString * const QLShouldUseNSLocalizedStringFromTableInBundle = @"QLShouldUseNSLocalizedStringFromTableInBundle";

@interface QuickLocalization ()

@property (nonatomic, assign) BOOL shouldUseNilForComment;
@property (nonatomic, assign) BOOL shouldUseSnippetForComment;
@property (nonatomic, assign) BOOL shouldUseSwiftSyntax;
@property (nonatomic, assign) BOOL shouldUseStringFromTableInBundle;
@property (nonatomic, strong) OLSettingController *settingControlelr;
@property (nonatomic, strong) NSBundle *bundle;
@end

@implementation QuickLocalization

static id sharedPlugin = nil;


+ (void)pluginDidLoad:(NSBundle *)plugin
{
    static id sharedPlugin = nil;
    static dispatch_once_t onceToken;
    NSString *currentApplicationName = [[NSBundle mainBundle] infoDictionary][@"CFBundleName"];
    if ([currentApplicationName isEqual:@"Xcode"]) {
        dispatch_once(&onceToken, ^{
            sharedPlugin = [[self alloc] initWithBundle:plugin];
        });
    }
}

- (id)initWithBundle:(NSBundle *)plugin
{
    if (self = [super init]) {
        // reference to plugin's bundle, for resource acccess
        self.bundle = plugin;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidFinishLaunching:)
                                                     name:NSApplicationDidFinishLaunchingNotification
                                                   object:nil];
        
        
    }
    return self;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [self createMenuItem];
    [OLSettingController registerFormatStringDefaults];
}

- (void)createMenuItem {
    [QLMenuGenerator generateMenuItems:self.bundle version:[self getBundleVersion] target:self];
}

// Sample Action, for menu item:
- (void)quickLocalization:(id)sender {
    IDESourceCodeDocument *document = [RCXcode currentSourceCodeDocument];
    NSTextView *textView = [RCXcode currentSourceCodeTextView];
    if (!document || !textView) {
        return;
    }
    
    NSArray *selectedRanges = [textView selectedRanges];
    if ([selectedRanges count] > 0) {
        NSRange range = [[selectedRanges objectAtIndex:0] rangeValue];
        BOOL replaced = [self replaceTextInRange:range textView:textView];
        //if user selected text is not being replaced, try using line replacing
        if (!replaced) {
            NSRange lineRange = [textView.textStorage.string lineRangeForRange:range];
            [self replaceTextInRange:lineRange textView:textView];
        }
    }
}

- (BOOL)replaceTextInRange:(NSRange)range textView:(NSTextView *)textView {
    NSString *line = [textView.textStorage.string substringWithRange:range];
    
    NSRegularExpression *localizedRex = [[NSRegularExpression alloc] initWithPattern:localizeRegexs[0] options:NSRegularExpressionCaseInsensitive error:nil];
    NSArray *localizedMatches = [localizedRex matchesInString:line options:0 range:NSMakeRange(0, [line length])];
    
    NSRegularExpression *regex = [[NSRegularExpression alloc] initWithPattern:[self currentStringRegexs] options:NSRegularExpressionCaseInsensitive error:nil];
    NSArray *matches = [regex matchesInString:line options:0 range:NSMakeRange(0, [line length])];
    NSUInteger addedLength = 0;
    for (int i = 0; i < [matches count]; i++) {
        NSTextCheckingResult *result = [matches objectAtIndex:i];
        NSRange matchedRangeInLine = result.range;
        NSRange matchedRangeInDocument = NSMakeRange(range.location + matchedRangeInLine.location + addedLength, matchedRangeInLine.length);
        if ([self isRange:matchedRangeInLine inSkipedRanges:localizedMatches]) {
            continue;
        }
        NSString *string = [line substringWithRange:matchedRangeInLine];
        //            NSLog(@"string index:%d, %@", i, string);
        NSString *outputString;
        
        NSString *savedFormatString = [[NSUserDefaults standardUserDefaults] objectForKey:kQLFormatStringKey];
        
        NSUInteger placeHolderCount = QL_CountOccurentOfStringWithSubString(savedFormatString, @"%@");
        if (placeHolderCount == 2) {
            outputString = [NSString stringWithFormat:savedFormatString, string, string];
        }
        else if (placeHolderCount == 1) {
            outputString = [NSString stringWithFormat:savedFormatString, string];
        }
        else {
            outputString = [NSString stringWithFormat:@"placeholder incorrect, format string is %@", savedFormatString];
        }
        
        addedLength = addedLength + outputString.length - string.length;
        if ([textView shouldChangeTextInRange:matchedRangeInDocument replacementString:outputString]) {
            [textView.textStorage replaceCharactersInRange:matchedRangeInDocument
                                      withAttributedString:[[NSAttributedString alloc] initWithString:outputString]];
            [textView didChangeText];
        }
        
    }
    
    if (matches.count) {
        return YES;
    }
    else {
        return NO;
    }
}

- (NSString *)currentStringRegexs {
    BOOL isSwiftSyntax = [[NSUserDefaults standardUserDefaults] boolForKey:kQLFormatStringSwiftSyntax];
    if (isSwiftSyntax) {
        return swiftStringRegexs;
    }
    else {
        return objcStringRegexs;
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
    self.shouldUseNilForComment = !self.shouldUseNilForComment;
    
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

- (void)toggleSwiftOption {
    self.shouldUseSwiftSyntax = !self.shouldUseSwiftSyntax;
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    if ([menuItem action] == @selector(toggleNilOption)) {
        [menuItem setState:[self shouldUseNilForComment] ? NSOnState : NSOffState];
    }
    else if ([menuItem action] == @selector(toggleSnippetOption)) {
        [menuItem setState:[self shouldUseSnippetForComment] ? NSOnState : NSOffState];
    }
    else if ([menuItem action] == @selector(toggleSwiftOption)) {
        [menuItem setState:[self shouldUseSwiftSyntax] ? NSOnState : NSOffState];
    }
    return YES;
}

- (void)toggleStringFromTableInBundle {
    self.shouldUseStringFromTableInBundle = !self.shouldUseStringFromTableInBundle;
}

#pragma mark Preferences
- (BOOL)shouldUseStringFromTableInBundle {
    return [[NSUserDefaults standardUserDefaults] boolForKey:QLShouldUseNSLocalizedStringFromTableInBundle];
}

- (void)setShouldUseStringFromTableInBundle:(BOOL)shouldUseStringFromTableInBundle {
    [[NSUserDefaults standardUserDefaults] setBool:shouldUseStringFromTableInBundle forKey:QLShouldUseNSLocalizedStringFromTableInBundle];
}

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

- (BOOL)shouldUseSwiftSyntax {
    return [[NSUserDefaults standardUserDefaults] boolForKey:QLShouldUseSwiftSyntax];
}

- (void)setShouldUseSwiftSyntax:(BOOL)shouldUseSwiftSyntax {
    [[NSUserDefaults standardUserDefaults] setBool:shouldUseSwiftSyntax forKey:QLShouldUseSwiftSyntax];
}

- (NSString *)getBundleVersion
{
    NSString *bundleVersion = [[self.bundle infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    return bundleVersion;
}

- (void)showSettingWindow
{
    if (self.settingControlelr == nil) {
        self.settingControlelr = [[OLSettingController alloc] initWithWindowNibName:@"OLSettingController"];
        self.settingControlelr.bundle = self.bundle;
        
    }
    
    [self.settingControlelr showWindow:self.settingControlelr];
}
@end
