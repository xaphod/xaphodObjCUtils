//
//  XaphodUtils.m
//
//  Created by Tim Carr on 7/11/16.
//  Copyright © 2016 Tim Carr. All rights reserved.
//

#import "XaphodUtils.h"
#include <ifaddrs.h>
#include <arpa/inet.h>
#include <net/if.h>
#include <sys/sysctl.h>

@implementation XaphodUtils

+ (uint16_t)getFreeTCPPort {
    uint16_t startingPort = (uint16_t)arc4random_uniform(20000) + 1024;
    BOOL isFree = NO;
    while (!isFree) {
        startingPort += 1;
        isFree = [self isTCPPortFree:(in_port_t)startingPort];
    }
    return startingPort;
}

+ (BOOL)isTCPPortFree:(in_port_t)port {
    int socketFileDescriptor = socket(AF_INET, SOCK_STREAM, 0);
    if (socketFileDescriptor == -1) {
        return NO;
    }
    
    struct sockaddr_in addr;
    addr.sin_len = (__uint8_t)sizeof(addr);
    addr.sin_family = (sa_family_t)AF_INET;
    addr.sin_port = OSHostByteOrder() == OSLittleEndian ? _OSSwapInt16(port) : port;
    struct in_addr inetaddr;
    inetaddr.s_addr = inet_addr("0.0.0.0");
    addr.sin_addr = inetaddr;
    for (int i=0 ; i<8 ; i+=1)
        addr.sin_zero[i] = 0;
    struct sockaddr bind_addr;
    memcpy(&bind_addr, &addr, (int)(sizeof(addr)));
    
    if (bind(socketFileDescriptor, &bind_addr, (socklen_t)sizeof(addr)) == -1) {
        shutdown(socketFileDescriptor, SHUT_RDWR);
        close(socketFileDescriptor);
        return NO;
    }
    if (listen(socketFileDescriptor, SOMAXCONN) == -1) {
        shutdown(socketFileDescriptor, SHUT_RDWR);
        close(socketFileDescriptor);
        return NO;
    }
    shutdown(socketFileDescriptor, SHUT_RDWR);
    close(socketFileDescriptor);
    return YES;
}

+ (void)registerDefaultsFromSettingsBundle {
    [[NSUserDefaults standardUserDefaults] registerDefaults:[self defaultsFromPlistNamed:@"Root"]];
}

+ (NSDictionary *)defaultsFromPlistNamed:(NSString *)plistName {
    NSString *settingsBundle = [[NSBundle mainBundle] pathForResource:@"Settings" ofType:@"bundle"];
    NSAssert(settingsBundle, @"Could not find Settings.bundle while loading defaults.");
    
    NSString *plistFullName = [NSString stringWithFormat:@"%@.plist", plistName];
    
    NSDictionary *settings = [NSDictionary dictionaryWithContentsOfFile:[settingsBundle stringByAppendingPathComponent:plistFullName]];
    NSAssert1(settings, @"Could not load plist '%@' while loading defaults.", plistFullName);
    
    NSArray *preferences = [settings objectForKey:@"PreferenceSpecifiers"];
    NSAssert1(preferences, @"Could not find preferences entry in plist '%@' while loading defaults.", plistFullName);
    
    NSMutableDictionary *defaults = [NSMutableDictionary dictionary];
    for(NSDictionary *prefSpecification in preferences) {
        NSString *key = [prefSpecification objectForKey:@"Key"];
        
        id value = [prefSpecification objectForKey:@"DefaultValue"];
        if(key && value) {
            [defaults setObject:value forKey:key];
        }
        
        NSString *type = [prefSpecification objectForKey:@"Type"];
        if ([type isEqualToString:@"PSChildPaneSpecifier"]) {
            NSString *file = [prefSpecification objectForKey:@"File"];
            NSAssert1(file, @"Unable to get child plist name from plist '%@'", plistFullName);
            [defaults addEntriesFromDictionary:[self defaultsFromPlistNamed:file]];
        }
    }
    
    return defaults;
}

@end
