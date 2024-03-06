/*   Copyright 2021 APPNEXUS INC
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF EPLY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import "EPLRealTimer.h"
#import "NSTimer+EPLCategory.h"
#import "EPLGlobal.h"
#import "EPLLogging.h"
#import "NSPointerArray+EPLCategory.h"
#import "EPLSDKSettings.h"
@interface EPLRealTimer()

@property (nonatomic, readwrite, strong) NSTimer *viewabilityTimer;
@property (nonatomic, readwrite, strong)  NSPointerArray *timerDelegates;


@end

@implementation EPLRealTimer

+ (instancetype)sharedInstance {
    static EPLRealTimer *manager;
    static dispatch_once_t managerToken;
    dispatch_once(&managerToken, ^{
        manager = [[EPLRealTimer alloc] init];
        manager.timerDelegates = [NSPointerArray weakObjectsPointerArray];
    });
    return manager;
}

+ (void) scheduleTimer {
    [self sharedInstance];
}

+ (BOOL)addDelegate:(nonnull id<EPLRealTimerDelegate>)delegate {
    return [[self sharedInstance] addDelegate:delegate];
}

+ (BOOL)removeDelegate:(nonnull id<EPLRealTimerDelegate>)delegate {
    return [[self sharedInstance] removeDelegate:delegate];
}

- (void) scheduleTimer {
    if(_viewabilityTimer == nil){
        __weak EPLRealTimer *weakSelf = self;
        
        if ([[EPLSDKSettings sharedInstance] enableContinuousTracking]) {
            _viewabilityTimer = [NSTimer an_scheduledTimerWithTimeInterval:kAppNexusNativeAdIABShouldBeViewableForTrackingDuration
                                                                     block:^ {
                EPLRealTimer *strongSelf = weakSelf;
                
                [strongSelf notifyListenerObjects];
            } repeats:YES mode:NSRunLoopCommonModes];
            
        }else{
            _viewabilityTimer = [NSTimer an_scheduledTimerWithTimeInterval:kAppNexusNativeAdIABShouldBeViewableForTrackingDuration
                                                                     block:^ {
                EPLRealTimer *strongSelf = weakSelf;
                
                [strongSelf notifyListenerObjects];
            } repeats:YES];
            
        }
    }
}

- (BOOL)addDelegate:(nonnull id<EPLRealTimerDelegate>)delegate {
    
    if(![delegate conformsToProtocol:@protocol(EPLRealTimerDelegate)]){
        EPLLogError(@"FAILED to add delegate, delegate does not confront to protocol");
        return NO;
    }
    if([self.timerDelegates containsObject:delegate]){
        EPLLogWarn(@"Delegate already added");
        return YES;
    }
    if(self.viewabilityTimer == nil){
        [self scheduleTimer];
    }
    [self.timerDelegates addObject:delegate];
    return YES;
    
}

- (BOOL)removeDelegate:(nonnull id<EPLRealTimerDelegate>)delegate {
    if(![delegate conformsToProtocol:@protocol(EPLRealTimerDelegate)]){
        EPLLogError(@"FAILED to remove delegate, delegate does not confront to protocol");
        return NO;
    }
    
    [self.timerDelegates removeObject:delegate];
    
    //if no delegates found then the timer can be stopped & added again if a new delegate is added
    if(self.timerDelegates.count <= 0){
        [self.viewabilityTimer invalidate];
        self.viewabilityTimer = nil;
    }
    
    return YES;
}

-(void) notifyListenerObjects {
    if(self.timerDelegates.count > 0) {
        for (int i=0; i< self.timerDelegates.count; i++){
            
            id<EPLRealTimerDelegate> delegate = [self.timerDelegates objectAtIndex:i];
            if([delegate respondsToSelector:@selector(handle1SecTimerSentNotification)]){
                EPLLogInfo(@"Notifications pushed from time");
                [delegate handle1SecTimerSentNotification];
            }
        }
    }
    else {
        EPLLogError(@"no delegate subscription found");
    }
}

@end
