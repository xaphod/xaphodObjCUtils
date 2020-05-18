//
//  RXTimer.h
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

#import <Foundation/Foundation.h>

@class RXTimer;
typedef void (^RXTimerHandler)(RXTimer* timer);
typedef void (^RXActionBlock)(int numTilEnd, id context);

@interface RXTimer : NSObject


/**
 Initializes a cancelable, one-shot timer in suspended state.
 
 @discussion Setting a tolerance for a timer allows the system to fire later than the
 scheduled fire date. This allows the system to optimize for increased power savings
 and maintaining responsiveness. The timer may fire at any time between its scheduled
 fire date and the scheduled fire date plus the tolerance. The timer will not fire before
 the scheduled fire date, though. The default value is zero, which means no additional
 tolerance is applied - however, the system may choose to set a minimal "leeway" value.
 
 As the user of the timer, you will have the best idea of what an acceptable tolerance
 for a timer will be. As a general rule of thumb, you should set the "tolerance" as large
 as possible. This might be for example the minimal perceivable duration or delay for a
 human user, say 50 ms. Your mileage may vary, but even a small amount of tolerance will
 have a significant positive impact on the power usage of your application.
 
 
 @param: delay The delay in seconds after the timer will fire
 
 @param queue  The queue on which to submit the block.
 
 @param block  The block to submit. This parameter cannot be NULL.
 
 @param tolearance A tolerance in seconds the fire data can deviate. Must be
 positive.
 
 @return An initialized \p RXTimer object.
 
 
 */

- (id)initWithTimeIntervalSinceNow:(NSTimeInterval)delay
                         tolorance:(double)tolerance
                             queue:(dispatch_queue_t)queue
                             block:(RXTimerHandler)block;


/**
 Starts the timer.
 
 The timer fires once after the specified delay plus the specified tolerance.
 */
- (void) start;

/**
 Cancels the timer.
 
 The timer becomes invalid and its block will not be executed.
 */
- (void)cancel;

/**
 Returns YES if the timer has not yet been fired and it is not cancelled.
 */
- (BOOL)isValid;

// calls actionBlock working back from endDate by increment steps. If endDate already passed, nothing happens. No need to use or retain the return value.
+ (NSMutableArray<RXTimer*>*)perform:(NSInteger)n actionsBeforeEndDate:(NSDate*)endDate withIncrement:(NSTimeInterval)increment queue:(dispatch_queue_t)queue actionBlock:(RXActionBlock)actionBlock context:(id)context;

@end