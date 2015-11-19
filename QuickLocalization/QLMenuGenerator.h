//
//  AMMenuGenerator.h
//  AMMethod2Implement
//
//  Created by JohnnyLiu on 15/4/1.
//  Copyright (c) 2015年 Tendencystudio. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface QLMenuGenerator : NSObject

+ (void)generateMenuItems:(NSBundle *)bundle version:(NSString *)version target:(id)target;
+ (NSUInteger)getKeyEquivalentModifierMaskWithKey:(NSString *)key;

@end
