//
//  XaphodUtils.h
//
//  Created by Tim Carr on 7/11/16.
//  Copyright © 2016 Tim Carr. All rights reserved.
//

#import <Foundation/Foundation.h>

#define xdKBytesMB 1048576ULL // megabyte in bytes

@interface XaphodUtils : NSObject

+ (void)registerDefaultsFromSettingsBundle;

+ (NSString *)getIPAddress:(BOOL)preferIPv4 includeCellular:(BOOL)includeCellular;
+ (NSDictionary<NSString*,NSString*>*)getIPAddresses;
+ (BOOL)isValidIpAddress:(NSString *)ip;
+ (NSString*)interfaceNameOfLocalIpAddress:(NSString*)ip;
+ (NSString*)getWifiSSID; // returns nil or string
+ (NSTimeInterval)timeSinceLastWifiChange;
+ (NSDate*)dateOfLastWifiChange;
+ (uint64_t)deviceSpaceFree;
+ (uint16_t)getFreeTCPPort;
+ (BOOL)isTCPPortFree:(in_port_t)port;

@end
