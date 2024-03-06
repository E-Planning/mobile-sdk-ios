/*   Copyright 2014 APPNEXUS INC
 
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

#import "EPLTrackerManager.h"
#import "EPLReachability.h"
#import "EPLTrackerInfo.h"
#import "EPLGlobal.h"
#import "EPLLogging.h"
#import "EPLGDPRSettings.h"
#import "EPLSDKSettings+PrivateMethods.h"

#import "NSTimer+EPLCategory.h"

@interface EPLTrackerManager ()

@property (nonatomic, readwrite, strong) NSMutableArray *trackerArray;
@property (nonatomic, readwrite, strong) EPLReachability *internetReachability;

@property (nonatomic, readonly, assign) BOOL internetIsReachable;

@property (nonatomic, readwrite, strong) NSTimer *trackerRetryTimer;

@end

@implementation EPLTrackerManager

#pragma mark - Lifecycle.

+ (instancetype)sharedManager {
    static EPLTrackerManager *manager;
    static dispatch_once_t managerToken;
    dispatch_once(&managerToken, ^{
        manager = [[EPLTrackerManager alloc] init];
    });
    return manager;
}

- (instancetype)init {
    if (self = [super init]) {
        _internetReachability = [EPLReachability sharedReachabilityForInternetConnection];
    }
    return self;
}



#pragma mark - Getters and Setters.

- (NSArray *)trackerArray
{
    if (!_trackerArray)  { _trackerArray = [[NSMutableArray alloc] init]; }
    return _trackerArray;
}



#pragma mark - Public methods.

+ (void)fireTrackerURLArray: (NSArray<NSString *> *)arrayWithURLs withBlock:(OnComplete)completionBlock
{
    [[self sharedManager] fireTrackerURLArray:arrayWithURLs withBlock:completionBlock];
}

+ (void)fireTrackerURL: (NSString *)URL
{
    [[self sharedManager] fireTrackerURL:URL];
}


#pragma mark - Private methods.

- (void)fireTrackerURLArray: (NSArray<NSString *> *)arrayWithURLs withBlock:(OnComplete)completionBlock
{
    if (!arrayWithURLs || ([arrayWithURLs count] <= 0)) {
        if(completionBlock)
        {
          completionBlock(NO);
        }
        return;
    }

    //
    if (!self.internetIsReachable)
    {
        EPLLogDebug(@"Internet IS UNREACHABLE - queing trackers for firing later: %@", arrayWithURLs);

        [arrayWithURLs enumerateObjectsUsingBlock:^(NSString *URL, NSUInteger idx, BOOL *stop) {
            [self queueTrackerURLForRetry:URL withBlock:completionBlock];
        }];

        return;
    }


    //
    EPLLogDebug(@"Internet is reachable - FIRING TRACKERS %@", arrayWithURLs);

    [arrayWithURLs enumerateObjectsUsingBlock:^(NSString *URL, NSUInteger idx, BOOL *stop)
    {
        
        NSMutableURLRequest  *request    = EPLBasicRequestWithURL([NSURL URLWithString:URL]);
        [EPLGlobal setANCookieToRequest:request];
        
        __weak EPLTrackerManager  *weakSelf  = self;
        
        [[[NSURLSession sharedSession] dataTaskWithRequest: request
                                         completionHandler: ^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error)
                                            {
                                                if (error) {
                                                    EPLLogDebug(@"Internet REACHABILITY ERROR - queing tracker for firing later: %@", URL);

                                                    EPLTrackerManager  *strongSelf  = weakSelf;
                                                    if (!strongSelf) {
                                                        EPLLogError(@"FAILED TO ACQUIRE strongSelf.");
                                                        return;
                                                    }

                                                    [strongSelf queueTrackerURLForRetry:URL withBlock:completionBlock];
                                                } else {
                                                    if (completionBlock) {
                                                        completionBlock(YES);
                                                    }
                                                }
                                            }
            ] resume];
    }];
}

- (void)fireTrackerURL: (NSString *)URL
{
    if ([URL length] > 0) {
        [self fireTrackerURLArray:@[URL] withBlock:nil];
    }
}

- (void)retryTrackerFiresWithBlock:(OnComplete)completionBlock
{
    NSArray *trackerArrayCopy;

    @synchronized(self) {
        if ((self.trackerArray.count > 0) && self.internetIsReachable)
        {
            EPLLogDebug(@"Internet back online - Firing trackers %@", self.trackerArray);

            trackerArrayCopy = [[NSArray alloc] initWithArray:self.trackerArray];
            [self.trackerArray removeAllObjects];
            [self.trackerRetryTimer invalidate];

        } else {
            if (completionBlock) {
              completionBlock(NO);
            }
            return;
        }
    }

    __weak EPLTrackerManager *weakSelf = self;

    [trackerArrayCopy enumerateObjectsUsingBlock:^(EPLTrackerInfo *info, NSUInteger idx, BOOL *stop) 
        {
            if (info.isExpired)  { return; }
            NSMutableURLRequest  *retryrequest    = EPLBasicRequestWithURL([NSURL URLWithString:info.URL]);
            [EPLGlobal setANCookieToRequest:retryrequest];
        
            [[[NSURLSession sharedSession] dataTaskWithRequest:retryrequest
                                             completionHandler: ^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error)
                                                {
                                                    if (error) 
                                                    {
                                                        EPLLogDebug(@"CONNECTION ERROR - queing tracker for firing later: %@", info.URL);
                                                        info.numberOfTimesFired += 1;

                                                        if ((info.numberOfTimesFired < kANTrackerManagerMaximumNumberOfRetries) && !info.isExpired) 
                                                        {
                                                            EPLTrackerManager *strongSelf = weakSelf;
                                                            if (!strongSelf)  {
                                                                EPLLogError(@"FAILED TO ACQUIRE strongSelf.");
                                                                return;
                                                            }

                                                            [strongSelf queueTrackerInfoForRetry:info withBlock:completionBlock];
                                                        }
                                                    } else {
                                                        EPLLogDebug(@"RETRY SUCCESSFUL for %@", info);
                                                        if (completionBlock) {
                                                          completionBlock(YES);
                                                        }
                                                    }
                                                }
                ] resume];
        }];
}


- (void)queueTrackerURLForRetry:(NSString *)URL withBlock:(OnComplete)completionBlock
{
    [self queueTrackerInfoForRetry:[[EPLTrackerInfo alloc] initWithURL:URL] withBlock:completionBlock];
}

- (void)queueTrackerInfoForRetry:(EPLTrackerInfo *)trackerInfo withBlock:(OnComplete)completionBlock
{
    @synchronized(self) {
        [self.trackerArray addObject:trackerInfo];
        [self scheduleRetryTimerIfNecessaryWithBlock:completionBlock];
    }
}

- (void)scheduleRetryTimerIfNecessaryWithBlock:(OnComplete)completionBlock {
    if (![self.trackerRetryTimer an_isScheduled]) {
        __weak EPLTrackerManager *weakSelf = self;
        self.trackerRetryTimer = [NSTimer an_scheduledTimerWithTimeInterval: kANTrackerManagerRetryInterval
                                                                      block: ^{
                                                                                  EPLTrackerManager  *strongSelf  = weakSelf;
                                                                                  if (!strongSelf)  {
                                                                                     EPLLogError(@"FAILED TO ACQUIRE strongSelf.");
                                                                                     return;
                                                                                  }
                                                                                  [strongSelf retryTrackerFiresWithBlock:completionBlock];
                                                                              }
                                                                    repeats: YES ];
    }
}

- (BOOL)internetIsReachable {
    EPLNetworkStatus networkStatus = [self.internetReachability currentReachabilityStatus];
    BOOL connectionRequired = [self.internetReachability connectionRequired];
    if (networkStatus != EPLNetworkStatusNotReachable && !connectionRequired) {
        return YES;
    }
    return NO;
}


@end
