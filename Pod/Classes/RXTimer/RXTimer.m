//
//  RXTimer.m
//
//  Copyright 2013 Andreas Grosam
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.

#import "RXTimer.h"
#import <dispatch/dispatch.h>

#ifndef DDLogWarn
#define DDLogWarn(frmt, ...) (void)0
#endif

@interface RXTimer ()
@end

@implementation RXTimer {
    dispatch_source_t   _timer;
    uint64_t            _interval;
    uint64_t            _leeway;
}


- (id) initWithTimeIntervalSinceNow:(NSTimeInterval)delay
                          tolorance:(double)tolerance
                              queue:(dispatch_queue_t)queue
                              block:(RXTimerHandler)block;
{
    self = [super init];
    if (self) {
        _interval = (uint64_t)(delay * NSEC_PER_SEC);
        _leeway = (uint64_t)(tolerance * NSEC_PER_SEC);
        _timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
        
        dispatch_source_set_event_handler(_timer, ^{
            dispatch_source_cancel(self->_timer); // one shot timer
            if (block) {
                block(self);
            }
        });
    }
    return self;
}

- (void) dealloc {
    dispatch_source_cancel(_timer);
    //dispatch_release(_timer);
}



// Invoking this method has no effect if the timer source has already been canceled.
- (void) start {
    assert(_timer);
    dispatch_source_set_timer(_timer, dispatch_time(DISPATCH_TIME_NOW, _interval),
                              DISPATCH_TIME_FOREVER /*one shot*/, _leeway);
    dispatch_resume(_timer);
}

- (void) cancel {
    dispatch_source_cancel(_timer);
}

- (BOOL) isValid {
    return _timer && 0 == dispatch_source_testcancel(_timer);
}

// calls actionBlock working back from endDate by increment steps. If endDate already passed, nothing happens. No need to use or retain the return value.
+ (NSMutableArray<RXTimer*>*)perform:(NSInteger)numberOfFiresBeforeEndDate actionsBeforeEndDate:(NSDate*)endDate withIncrement:(NSTimeInterval)increment queue:(dispatch_queue_t)queue actionBlock:(RXActionBlock)actionBlock context:(id)context {

    NSTimeInterval timeTilEnd = endDate.timeIntervalSinceNow;
    if (!actionBlock || !queue) {
        NSAssert(false, @"ERR");
        DDLogWarn(@"RXTimer: ERROR - params missing, no-op");
        return nil;
    }
    
    if (timeTilEnd < 0 || (numberOfFiresBeforeEndDate > 0 && increment == 0)) {
        DDLogWarn(@"RXTimer: immediately calling actionBlock because date is in the past or will never fire");
        dispatch_async(queue, ^{
            actionBlock(0, context);
        });
        return nil;
    }
    
    RXTimer *timer = nil;
    NSMutableArray<RXTimer*>* timers = [NSMutableArray arrayWithCapacity:numberOfFiresBeforeEndDate+1];

    for (int numFromEnd=0; numFromEnd <= numberOfFiresBeforeEndDate; numFromEnd += 1) {
        NSTimeInterval delay = timeTilEnd-(numFromEnd*increment);
        if (delay > 0) {
            timer = [[RXTimer alloc] initWithTimeIntervalSinceNow:delay tolorance:0 queue:queue block:^(RXTimer *timer) {
                actionBlock(numFromEnd, context);
            }];
            [timer start];
            [timers addObject:timer];
        } else {
            DDLogWarn(@"RXTimer: WARNING, this actionBlock firing right away, as delay is negative...");
            actionBlock(numFromEnd, context);
        }
    }
    return timers;
}


@end
