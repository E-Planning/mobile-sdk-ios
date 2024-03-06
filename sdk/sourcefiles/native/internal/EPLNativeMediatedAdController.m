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

#import "EPLNativeMediatedAdController.h"
#import "EPLNativeCustomAdapter.h"
#import "EPLNativeAdFetcher.h"
#import "EPLLogging.h"
#import "NSString+EPLCategory.h"
#import "NSObject+EPLCategory.h"
#import "EPLNativeMediatedAdResponse+PrivateMethods.h"
#import "EPLNativeAdResponse+PrivateMethods.h"

@interface EPLNativeMediatedAdController () <EPLNativeCustomAdapterRequestDelegate>

@property (nonatomic, readwrite, strong) EPLMediatedAd *mediatedAd;

@property (nonatomic, readwrite, strong) id<EPLNativeCustomAdapter> currentAdapter;

@end



@implementation EPLNativeMediatedAdController

+ (instancetype)initMediatedAd: (EPLMediatedAd *)mediatedAd
                   withFetcher: (EPLNativeAdFetcher *)adFetcher
             adRequestDelegate: (id<EPLNativeAdFetcherDelegate>)adRequestDelegate
{
    EPLNativeMediatedAdController *controller = [[EPLNativeMediatedAdController alloc] initMediatedAd: mediatedAd
                                                                                          withFetcher: adFetcher
                                                                                    adRequestDelegate: adRequestDelegate];
    if ([controller initializeRequest]) {
        return controller;
    } else {
        return nil;
    }

}

- (instancetype)initMediatedAd: (EPLMediatedAd *)mediatedAd
                   withFetcher: (EPLNativeAdFetcher *)adFetcher
             adRequestDelegate: (id<EPLNativeAdFetcherDelegate>)adRequestDelegate
{
    self = [super init];
    if (self) {
        _adFetcher = adFetcher;
        _adRequestDelegate = adRequestDelegate;
        _mediatedAd = mediatedAd;
    }
    return self;
}

- (BOOL)initializeRequest {
    NSString *className = nil;
    NSString *errorInfo = nil;
    EPLAdResponseCode *errorCode = EPLAdResponseCode.DEFAULT;

    do {
        // check that the ad is non-nil
        if (!self.mediatedAd) {
            errorInfo = @"null mediated ad object";
            errorCode = EPLAdResponseCode.UNABLE_TO_FILL;
            break;
        }
        
        className = self.mediatedAd.className;
        EPLLogDebug(@"instantiating_class %@", className);
        
        // notify that a mediated class name was received
        EPLPostNotifications(kANUniversalAdFetcherWillInstantiateMediatedClassNotification, self,
                            @{kANUniversalAdFetcherMediatedClassKey: className});

        // check to see if an instance of this class exists
        Class adClass = NSClassFromString(className);
        if (!adClass) {
            errorInfo = @"ClassNotFoundError";
            errorCode = EPLAdResponseCode.MEDIATED_SDK_UNAVAILABLE;
            break;
        }
        
        id adInstance = [[adClass alloc] init];
        if (![self validAdInstance:adInstance]) {
            errorInfo = @"InstantiationError";
            errorCode = EPLAdResponseCode.MEDIATED_SDK_UNAVAILABLE;
            break;
        }
        
        // instance valid - request a mediated ad
        id<EPLNativeCustomAdapter> adapter = (id<EPLNativeCustomAdapter>)adInstance;
        adapter.requestDelegate = self;
        self.currentAdapter = adapter;
        
        [self markLatencyStart];
        [self startTimeout];
        
        [self.currentAdapter requestNativeAdWithServerParameter:self.mediatedAd.param
                                                       adUnitId:self.mediatedAd.adId
                                            targetingParameters:[self targetingParameters]];
    } while (false);

    if (errorCode.code != EPLAdResponseCode.DEFAULT.code) {
        [self handleInstantiationFailure:className
                               errorCode:errorCode
                               errorInfo:errorInfo];
        return NO;
    }
    
    return YES;
}

- (BOOL)validAdInstance:(id)adInstance {
    if (!adInstance) {
        return NO;
    }
    if (![adInstance conformsToProtocol:@protocol(EPLNativeCustomAdapter)]) {
        return NO;
    }
    if (![adInstance respondsToSelector:@selector(setRequestDelegate:)]) {
        return NO;
    }
    if (![adInstance respondsToSelector:@selector(requestNativeAdWithServerParameter:adUnitId:targetingParameters:)]) {
        return NO;
    }
    return YES;
}

- (void)handleInstantiationFailure:(NSString *)className
                         errorCode:(EPLAdResponseCode *)errorCode
                         errorInfo:(NSString *)errorInfo
{
    if ([errorInfo length] > 0) {
        EPLLogError(@"mediation_instantiation_failure %@", errorInfo);
    }

    [self didFailToReceiveAd:errorCode];
}

- (void)setAdapter:(id<EPLNativeCustomAdapter>)adapter {
    self.currentAdapter = adapter;
}

- (void)clearAdapter {
    if (self.currentAdapter)
        self.currentAdapter.requestDelegate = nil;
    self.currentAdapter = nil;
    self.hasSucceeded = NO;
    self.hasFailed = YES;
    [self cancelTimeout];
    EPLLogInfo(@"mediation_finish");
}

- (EPLTargetingParameters *)targetingParameters
{
    EPLTargetingParameters *targetingParameters = [[EPLTargetingParameters alloc] init];
    
    NSMutableDictionary<NSString *, NSString *>  *customKeywordsAsStrings  = [EPLGlobal convertCustomKeywordsAsMapToStrings: self.adRequestDelegate.customKeywords
                                                                                                       withSeparatorString: @"," ];

    targetingParameters.customKeywords    = customKeywordsAsStrings;
    targetingParameters.age               = self.adRequestDelegate.age;
    targetingParameters.gender            = self.adRequestDelegate.gender;
    targetingParameters.location          = self.adRequestDelegate.location;
    NSString *idfa = EPLAdvertisingIdentifier();
    if(idfa){
        targetingParameters.idforadvertising  = idfa;
    }
    

    return targetingParameters;
}

#pragma mark - helper methods

- (BOOL)checkIfMediationHasResponded {
    // we received a callback from mediation adaptor, cancel timeout
    [self cancelTimeout];
    // don't succeed or fail more than once per mediated ad
    return (self.hasSucceeded || self.hasFailed);
}

- (void)didReceiveAd:(id)adObject {
    if ([self checkIfMediationHasResponded]) return;
    if (!adObject) {
        [self didFailToReceiveAd:EPLAdResponseCode.INTERNAL_ERROR];
        return;
    }
    self.hasSucceeded = YES;
    [self markLatencyStop];
    
    EPLLogDebug(@"received an ad from the adapter");
    
    [self finish:EPLAdResponseCode.SUCCESS withAdObject:adObject];
}

- (void)didFailToReceiveAd:(EPLAdResponseCode *)errorCode {
    if ([self checkIfMediationHasResponded]) return;
    [self markLatencyStop];
    self.hasFailed = YES;
    [self finish:errorCode withAdObject:nil];
}

- (void)finish:(EPLAdResponseCode *)errorCode withAdObject:(id)adObject
{
    // use queue to force return
    [self runInBlock:^(void) {
        NSString *responseURLString = [self createResponseURLRequest: self.mediatedAd.responseURL
                                                              reason: (int)errorCode ];

        // fireResulCB will clear the adapter if fetcher exists
        if (!self.adFetcher) {
            [self clearAdapter];
        }

        [self.adFetcher fireResponseURL:responseURLString reason:errorCode adObject:adObject];
    } ];
}

- (NSString *)createResponseURLRequest:(NSString *)baseString reason:(int)reasonCode
{
    if ([baseString length] < 1) {
        return @"";
    }
    
    // append reason code
    NSString *responseURLString = [baseString an_stringByAppendingUrlParameter: @"reason"
                                                                         value: [NSString stringWithFormat:@"%d",reasonCode]];
    
    // append latency measurements
    NSTimeInterval latency = [self getLatency] * 1000; // secs to ms

    if (latency > 0) {
        responseURLString = [responseURLString an_stringByAppendingUrlParameter: @"latency"
                                                                          value: [NSString stringWithFormat:@"%.0f", latency]];
    }

EPLLogDebug(@"responseURLString=%@", responseURLString);
    return responseURLString;
}

#pragma mark - Timeout handler

- (void)startTimeout {
    if (self.timeoutCanceled) return;
    __weak EPLNativeMediatedAdController *weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                  self.mediatedAd.networkTimeout * NSEC_PER_MSEC),
                   dispatch_get_main_queue(), ^{
                       EPLNativeMediatedAdController *strongSelf = weakSelf;
                       if (!strongSelf || strongSelf.timeoutCanceled) return;
                       EPLLogWarn(@"mediation_timeout");
                       [strongSelf didFailToReceiveAd:EPLAdResponseCode.INTERNAL_ERROR];
                   });
}

- (void)cancelTimeout {
    self.timeoutCanceled = YES;
}

# pragma mark - Latency Measurement

/**
 * Should be called immediately after mediated SDK returns
 * from `requestAd` call.
 */
- (void)markLatencyStart {
    self.latencyStart = [NSDate timeIntervalSinceReferenceDate];
}

/**
 * Should be called immediately after mediated SDK
 * calls either of `onAdLoaded` or `onAdFailed`.
 */
- (void)markLatencyStop {
    self.latencyStop = [NSDate timeIntervalSinceReferenceDate];
}

/**
 * The latency of the call to the mediated SDK.
 */
- (NSTimeInterval)getLatency {
    if ((self.latencyStart > 0) && (self.latencyStop > 0)) {
        return (self.latencyStop - self.latencyStart);
    }
    // return -1 if invalid.
    return -1;
}


#pragma mark - EPLNativeCustomAdapterRequestDelegate

- (void)didLoadNativeAd:(nonnull EPLNativeMediatedAdResponse *)response {
    // Add the AppNexusImpression trackers into the mediated response.
    response.impTrackers= [self.mediatedAd.impressionUrls copy];
    response.verificationScriptResource  = self.mediatedAd.verificationScriptResource;
    [self didReceiveAd:response];
}

- (void)didFailToLoadNativeAd:(EPLAdResponseCode *)errorCode {
    [self didFailToReceiveAd:errorCode];
}

@end
