//
//  OLSettingController.h
//  QuickLocalization
//
//  Created by Zitao Xiong on 7/18/15.
//  Copyright (c) 2015 nanaimostudio. All rights reserved.
//

#import <Cocoa/Cocoa.h>
extern NSUInteger QL_CountOccurentOfStringWithSubString(NSString *str, NSString *subString);

@interface OLSettingController : NSWindowController
@property (nonatomic, weak) NSBundle *bundle;
+ (void)registerFormatStringDefaults;
@end
