//
//  OLSettingController.m
//  QuickLocalization
//
//  Created by Zitao Xiong on 7/18/15.
//  Copyright (c) 2015 nanaimostudio. All rights reserved.
//

#import "OLSettingController.h"

NSUInteger QL_CountOccurentOfStringWithSubString(NSString *str, NSString *subString) {
    NSUInteger count = 0, length = [str length];
    NSRange range = NSMakeRange(0, length);
    while(range.location != NSNotFound)
    {
        range = [str rangeOfString:subString options:0 range:range];
        if(range.location != NSNotFound)
        {
            range = NSMakeRange(range.location + range.length, length - (range.location + range.length));
            count++; 
        }
        
    }
    
    return count;
}
@interface OLSettingController ()
@property (weak) IBOutlet NSTextField *commentTextField;
@property (weak) IBOutlet NSTextField *tableNameTextField;
@property (weak) IBOutlet NSTextField *bunldeTextField;
@property (weak) IBOutlet NSButton *swiftCheckButton;
@property (weak) IBOutlet NSButton *commentSameAsKeyCheckButton;
@property (weak) IBOutlet NSComboBox *comboBox;
@property (weak) IBOutlet NSTextField *previewLabel;
@property (weak) IBOutlet NSButton *commentAsKeyButton;
@property (weak) IBOutlet NSTextField *valueTextField;
@property (weak) IBOutlet NSButton *swiftLocalizationPreviewButton;

@end

@implementation OLSettingController

- (void)windowDidLoad {
    [super windowDidLoad];
    [self.comboBox selectItemAtIndex:0];
    [self updatePreviewText];
}

- (IBAction)onSaveButton:(id)sender {
}

- (IBAction)commentDidChange:(id)sender {
    [self updatePreviewText];
}

- (IBAction)onTableNameChanged:(id)sender {
    [self updatePreviewText];
}

- (IBAction)onBunldeNameChanged:(id)sender {
    [self updatePreviewText];
}

- (IBAction)onCommentAsKayButton:(id)sender {
    if (self.commentAsKeyButton.state == NSOnState) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kQLFormatStringCommentSameKey];
    }
    else {
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kQLFormatStringCommentSameKey];
    }
    [self updatePreviewText];
}

- (IBAction)onValueTextField:(id)sender {
    [self updatePreviewText];
}

- (IBAction)onSwiftLocalizationPreviewChanged:(id)sender {
    if (self.swiftLocalizationPreviewButton.state == NSOnState) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kQLFormatStringSwiftSyntax];
    }
    else {
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kQLFormatStringSwiftSyntax];
    }
    [self updatePreviewText];
}

- (IBAction)onComboBoxChanged:(id)sender {
    [self updatePreviewText];
}

- (NSString *)updatePreviewText {
    NSString *formatString = [self.comboBox objectValueOfSelectedItem];
    NSUInteger placeholderCount = QL_CountOccurentOfStringWithSubString(formatString, @"%@");
    
    NSString *value = @"\"Hello World\"";
    if (self.swiftLocalizationPreviewButton.state == NSOffState) {
        value = [NSString stringWithFormat:@"@%@", value];
    }
    NSString *comment;
    NSString *savedComment;
    if ([self.commentAsKeyButton state] == NSOnState) {
        comment = [value copy];
        savedComment = @"%@";
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kQLFormatStringCommentSameKey];
    }
    else {
        comment = self.commentTextField.stringValue;
        savedComment = comment.copy;
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kQLFormatStringCommentSameKey];
    }
    
    NSString *savedFormatString;
    if (placeholderCount == 2) {
        //swift or object-c
        [self.previewLabel setStringValue:[NSString stringWithFormat:formatString, value, comment]];
        savedFormatString = [NSString stringWithFormat:formatString, @"%@", savedComment];
    }
    
    else if (placeholderCount == 4) {
        //object-c from bundle
        [self.previewLabel setStringValue:[NSString stringWithFormat:formatString, value, comment, self.tableNameTextField.stringValue, self.bunldeTextField.stringValue]];
        savedFormatString = [NSString stringWithFormat:formatString, @"%@", savedComment, self.tableNameTextField.stringValue, self.bunldeTextField.stringValue];
    }
    else if (placeholderCount == 5) {
        [self.previewLabel setStringValue:[NSString stringWithFormat:formatString, value, self.tableNameTextField.stringValue, self.bunldeTextField.stringValue, self.valueTextField.stringValue, comment]];
        savedFormatString = [NSString stringWithFormat:formatString, @"%@", self.tableNameTextField.stringValue, self.bunldeTextField.stringValue, self.valueTextField.stringValue, savedComment];
    }
    else {
        [self.previewLabel setStringValue:@"%@ must be 2, 4, or 5"];
        return @"";
    }
    
    [[NSUserDefaults standardUserDefaults] setObject:savedFormatString forKey:kQLFormatStringKey];
    
    return savedFormatString;
}
@end
