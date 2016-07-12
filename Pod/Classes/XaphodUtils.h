//
//  XaphodUtils.h
//
//  Created by Tim Carr on 7/11/16.
//  Copyright © 2016 Tim Carr. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface XaphodUtils : NSObject

+ (uint16_t)getFreeTCPPort;
+ (void)registerDefaultsFromSettingsBundle;

@end
