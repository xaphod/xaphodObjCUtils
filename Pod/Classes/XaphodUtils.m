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
@import SystemConfiguration.CaptiveNetwork;

#define IOS_CELLULAR    @"pdp_ip0"
#define IOS_WIFI        @"en0"
#define IP_ADDR_IPv4    @"ipv4"
#define IP_ADDR_IPv6    @"ipv6"

@implementation XaphodUtils

static NSString* XaphodUtilsLastKnownSSID = nil;
static NSDate* XaphodUtilsLastSSIDChange = nil;

#pragma mark -

+ (void)load {
    NSLog(@"xaphodObjCUtils +load: init");
    XaphodUtilsLastSSIDChange = [NSDate distantPast];
}

+ (NSString *)getIPAddress:(BOOL)preferIPv4 includeCellular:(BOOL)includeCellular
{
    NSArray *searchArray = nil;
    if (includeCellular) {
        searchArray = preferIPv4 ?
        @[ IOS_WIFI @"/" IP_ADDR_IPv4, IOS_WIFI @"/" IP_ADDR_IPv6, IOS_CELLULAR @"/" IP_ADDR_IPv4, IOS_CELLULAR @"/" IP_ADDR_IPv6 ] :
        @[ IOS_WIFI @"/" IP_ADDR_IPv6, IOS_WIFI @"/" IP_ADDR_IPv4, IOS_CELLULAR @"/" IP_ADDR_IPv6, IOS_CELLULAR @"/" IP_ADDR_IPv4 ] ;
    } else {
        searchArray = preferIPv4 ?
        @[ IOS_WIFI @"/" IP_ADDR_IPv4, IOS_WIFI @"/" IP_ADDR_IPv6 ] :
        @[ IOS_WIFI @"/" IP_ADDR_IPv6, IOS_WIFI @"/" IP_ADDR_IPv4 ] ;
    }
    
    NSDictionary *addresses = [XaphodUtils getIPAddresses];
    //DDLogVerbose(@"addresses: %@", addresses);
    
    __block NSString *address;
    [searchArray enumerateObjectsUsingBlock:^(NSString *key, NSUInteger idx, BOOL *stop)
     {
         address = addresses[key];
         if(address) *stop = YES;
     } ];
    return address ? address : @"0.0.0.0";
}

/* iPhone 6S connected to mac fake wifi (169.)
 
 "awdl0/ipv6" = "fe80::342b:dbff:feaa:59ec";
 "en0/ipv4" = "169.254.54.235";
 "en0/ipv6" = "fe80::8f2:285f:b2dc:2083";
 "lo0/ipv4" = "127.0.0.1";
 "lo0/ipv6" = "fe80::1";
 "pdp_ip0/ipv4" = "25.123.163.102";
 "utun0/ipv6" = "fe80::dcd3:5a6d:cd7d:7378";
 */
+ (NSDictionary<NSString*,NSString*>*)getIPAddresses
{
    NSMutableDictionary<NSString*,NSString*> *addresses = [NSMutableDictionary dictionaryWithCapacity:8];
    
    // retrieve the current interfaces - returns 0 on success
    struct ifaddrs *interfaces;
    if(!getifaddrs(&interfaces)) {
        // Loop through linked list of interfaces
        struct ifaddrs *interface;
        for(interface=interfaces; interface; interface=interface->ifa_next) {
            if(!(interface->ifa_flags & IFF_UP) /* || (interface->ifa_flags & IFF_LOOPBACK) */ ) {
                continue; // deeply nested code harder to read
            }
            const struct sockaddr_in *addr = (const struct sockaddr_in*)interface->ifa_addr;
            char addrBuf[ MAX(INET_ADDRSTRLEN, INET6_ADDRSTRLEN) ];
            if(addr && (addr->sin_family==AF_INET || addr->sin_family==AF_INET6)) {
                NSString *name = [NSString stringWithUTF8String:interface->ifa_name];
                NSString *type;
                if(addr->sin_family == AF_INET) {
                    if(inet_ntop(AF_INET, &addr->sin_addr, addrBuf, INET_ADDRSTRLEN)) {
                        type = IP_ADDR_IPv4;
                    }
                } else {
                    const struct sockaddr_in6 *addr6 = (const struct sockaddr_in6*)interface->ifa_addr;
                    if(inet_ntop(AF_INET6, &addr6->sin6_addr, addrBuf, INET6_ADDRSTRLEN)) {
                        type = IP_ADDR_IPv6;
                    }
                }
                if(type) {
                    NSString *key = [NSString stringWithFormat:@"%@/%@", name, type];
                    addresses[key] = [NSString stringWithUTF8String:addrBuf];
                }
            }
        }
        // Free memory
        freeifaddrs(interfaces);
    }
    return [addresses count] ? addresses : nil;
}

/** Get interface name of a given IP address (or nil if none found)
 */

+ (NSString*)interfaceNameOfLocalIpAddress:(NSString*)ip {
    if (!ip || [ip isEqualToString:@""])
        return nil;
    NSDictionary<NSString*,NSString*> *addresses = [XaphodUtils getIPAddresses];
    for (NSString* interfaceNameWithIPV in addresses.allKeys) {
        if ([addresses[interfaceNameWithIPV] isEqualToString:ip]) {
            return [interfaceNameWithIPV componentsSeparatedByString:@"/"][0];
        }
    }
    return nil;
}

/** Check if an IP address is valid.
 
 Looks for both IPv4 and IPv6.
 Based on: http://stackoverflow.com/questions/1679152/how-to-validate-an-ip-address-with-regular-expression-in-objective-c/10971521#10971521
 
 @param ip IP address as string.
 @return Returns true if given IP address is valid, false otherwise.
 
 */
+ (BOOL)isValidIpAddress:(NSString *)ip {
    const char *utf8 = [ip UTF8String];
    
    // Check valid IPv4.
    struct in_addr dst;
    int success = inet_pton(AF_INET, utf8, &(dst.s_addr));
    if (success != 1) {
        // Check valid IPv6.
        struct in6_addr dst6;
        success = inet_pton(AF_INET6, utf8, &dst6);
    }
    return (success == 1);
}

+ (NSString*)getWifiSSID {
    /** Returns first non-empty SSID network info dictionary.
     *  @see CNCopyCurrentNetworkInfo */
    NSArray *interfaceNames = CFBridgingRelease(CNCopySupportedInterfaces());
    
    NSDictionary *SSIDInfo = nil;
    BOOL isNotEmpty = false;
    for (NSString *interfaceName in interfaceNames) {
        SSIDInfo = CFBridgingRelease(CNCopyCurrentNetworkInfo((__bridge CFStringRef)interfaceName));
        //DDLogVerbose(@"%s: %@ => %@", __func__, interfaceName, SSIDInfo);
        isNotEmpty = (SSIDInfo.count > 0);
        if (isNotEmpty) {
            break;
        }
    }
    
    if (isNotEmpty) {
        if (XaphodUtilsLastKnownSSID == nil || (![[SSIDInfo objectForKey:@"SSID"] isEqualToString:XaphodUtilsLastKnownSSID])) {
            static BOOL everSet = NO; // the first time we read the SSID, don't update the last change date, because we don't want to sleep in connectToCam for this case
            if (everSet)
                XaphodUtilsLastSSIDChange = [NSDate date];
            everSet = YES;
        }
        
        XaphodUtilsLastKnownSSID = [SSIDInfo objectForKey:@"SSID"];
        return [SSIDInfo objectForKey:@"SSID"];
    } else {
        if (XaphodUtilsLastKnownSSID != nil)
            XaphodUtilsLastSSIDChange = [NSDate date];
        XaphodUtilsLastKnownSSID = nil;

        return nil;
    }
}

+ (NSTimeInterval)timeSinceLastWifiChange {
    return ABS([XaphodUtilsLastSSIDChange timeIntervalSinceNow]);
}

+ (NSDate*)dateOfLastWifiChange {
    return XaphodUtilsLastSSIDChange;
}

// used for debugging purposes
// iphone 6S (no change when turning airplane mode on/off, turning wifi or BT on/off): lo0 pdp_ip0 pdp_ip1 pdp_ip2 pdp_ip3 pdp_ip4 ap1 en0 en1 awdl0 ipsec0 ipsec1 ipsec2
//- (void)logInterfaceNames {
//    int                 mib[6];
//    size_t              len;
//    char                *buf;
//    struct if_msghdr    *ifm;
//    struct sockaddr_dl  *sdl;
//    
//    mib[0] = CTL_NET;
//    mib[1] = AF_ROUTE;
//    mib[2] = 0;
//    mib[3] = AF_LINK;
//    mib[4] = NET_RT_IFLIST;
//    
//    char name[128];
//    memset(name, 0, sizeof(name));
//    NSLog(@"INTERFACES FOUND: ");
//    for (int i=1; i<20; i ++) {
//        if (if_indextoname(i, name)) {
//            printf("%s ",name);
//        }else{
//            continue;
//        }
//        
//        if ((mib[5] = if_nametoindex(name)) == 0) {
//            printf("Error: if_nametoindex error\n");
//            return;
//        }
//        
//        if (sysctl(mib, 6, NULL, &len, NULL, 0) < 0) {
//            printf("Error: sysctl, take 1\n");
//            return;
//        }
//        
//        if ((buf = malloc(len)) == NULL) {
//            printf("Could not allocate memory. error!\n");
//            return;
//        }
//        
//        if (sysctl(mib, 6, buf, &len, NULL, 0) < 0) {
//            printf("Error: sysctl, take 2");
//            free(buf);
//            return;
//        }
//        
//        ifm = (struct if_msghdr *)buf;
//        sdl = (struct sockaddr_dl *)(ifm + 1);
//        //        ptr = (unsigned char *)LLADDR(sdl);
//        //        NSString *macString = [NSString stringWithFormat:@"%02X:%02X:%02X:%02X:%02X:%02X", *ptr, *(ptr+1), *(ptr+2), *(ptr+3), *(ptr+4), *(ptr+5)];
//        //        printf(" %s\n",[macString cStringUsingEncoding:NSUTF8StringEncoding]);
//        free(buf);
//    }
//    
//    NSLog(@" (END)");
//}

+ (uint64_t)deviceSpaceFree {
    uint64_t totalSpace = 0;
    uint64_t totalFreeSpace = 0;
    
    __autoreleasing NSError *error = nil;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSDictionary *dictionary = [[NSFileManager defaultManager] attributesOfFileSystemForPath:[paths lastObject] error: &error];
    
    if (dictionary) {
        NSNumber *fileSystemSizeInBytes = [dictionary objectForKey: NSFileSystemSize];
        NSNumber *freeFileSystemSizeInBytes = [dictionary objectForKey:NSFileSystemFreeSize];
        totalSpace = [fileSystemSizeInBytes unsignedLongLongValue];
        totalFreeSpace = [freeFileSystemSizeInBytes unsignedLongLongValue];
        //        DDLogVerbose(@"Disk-space: Capacity of %llu MiB with %llu MiB available.", ((totalSpace/1024ll)/1024ll), ((totalFreeSpace/1024ll)/1024ll));
        
    } else {
        NSLog(@"Error Obtaining free space info: Domain = %@, Code = %ld", [error domain], (long)[error code]);
    }
    
    return totalFreeSpace;
}

+ (uint16_t)getFreeTCPPort {
    uint16_t startingPort = (uint16_t)arc4random_uniform(20000) + 1024;
    BOOL isFree = NO;
    while (!isFree) {
        startingPort += 1;
        isFree = [XaphodUtils isTCPPortFree:(in_port_t)startingPort];
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
