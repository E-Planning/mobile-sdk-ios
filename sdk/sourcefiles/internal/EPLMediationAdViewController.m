/*   Copyright 2013 APPNEXUS INC
 
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

#import "EPLMediationAdViewController.h"
#import "EPLAdConstants.h"

#import "EPLBannerAdView.h"
#import "EPLInterstitialAd.h"
#import "EPLLogging.h"
#import "EPLMediatedAd.h"
#import "NSString+EPLCategory.h"
#import "EPLMediationContainerView.h"
#import "NSObject+EPLCategory.h"



@interface EPLMediationAdViewController () <EPLCustomAdapterBannerDelegate, EPLCustomAdapterInterstitialDelegate>

@property (nonatomic, readwrite, strong)  EPLMediatedAd                      *mediatedAd;

@property (nonatomic, readwrite, strong)  id<EPLCustomAdapter>                currentAdapter;
@property (nonatomic, readwrite, assign)  BOOL                               hasSucceeded;
@property (nonatomic, readwrite, assign)  BOOL                               hasFailed;
@property (nonatomic, readwrite, assign)  BOOL                               timeoutCanceled;

@property (nonatomic, readwrite, weak)    id<EPLAdFetcherDelegate>   adViewDelegate;

// variables for measuring latency.
@property (nonatomic, readwrite, assign)  NSTimeInterval  latencyStart;
@property (nonatomic, readwrite, assign)  NSTimeInterval  latencyStop;

@end

@implementation EPLMediationAdViewController

#pragma mark - Lifecycle.

+ (EPLMediationAdViewController *)initMediatedAd:(EPLMediatedAd *)mediatedAd
                                    withFetcher:(EPLAdFetcher *)adFetcher
                                 adViewDelegate:(id<EPLAdFetcherDelegate>)adViewDelegate
{

    EPLMediationAdViewController *controller = [[EPLMediationAdViewController alloc] init];
    controller.adFetcher = adFetcher;
    controller.adViewDelegate = adViewDelegate;
    
    if ([controller requestForAd:mediatedAd]) {
        return controller;
    } else {
        return nil;
    }
}

- (BOOL)requestForAd:(EPLMediatedAd *)ad {

    // variables to pass into the failure handler if necessary
    NSString *className = nil;
    NSString *errorInfo = nil;
    EPLAdResponseCode *errorCode = EPLAdResponseCode.DEFAULT;
    
    do {
        // check that the ad is non-nil
        if (!ad) {
            errorInfo = @"null mediated ad object";
            errorCode = EPLAdResponseCode.UNABLE_TO_FILL;
            break;
        }
        
        self.mediatedAd = ad;
        className = ad.className;
        
        // notify that a mediated class name was received
        EPLPostNotifications(kANUniversalAdFetcherWillInstantiateMediatedClassNotification, self,
                            @{kANUniversalAdFetcherMediatedClassKey: className});
        
        EPLLogDebug(@"instantiating_class %@", className);
        
        // check to see if an instance of this class exists
        Class adClass = NSClassFromString(className);
        if (!adClass) {
            errorInfo = @"ClassNotFoundError";
            errorCode = EPLAdResponseCode.MEDIATED_SDK_UNAVAILABLE;
            break;
        }
        
        id adInstance = [[adClass alloc] init];
        if (!adInstance
            || ![adInstance respondsToSelector:@selector(setDelegate:)]
            || ![adInstance conformsToProtocol:@protocol(EPLCustomAdapter)]) {
            errorInfo = @"InstantiationError";
            errorCode = EPLAdResponseCode.MEDIATED_SDK_UNAVAILABLE;
            break;
        }
        
        // instance valid - request a mediated ad
        id<EPLCustomAdapter> adapter = (id<EPLCustomAdapter>)adInstance;
        adapter.delegate = self;
        self.currentAdapter = adapter;
        
        // Grab the size of the ad - interstitials will ignore this value
        CGSize sizeOfCreative = CGSizeMake([ad.width floatValue], [ad.height floatValue]);
        
        BOOL requestedSuccessfully = [self requestAd:sizeOfCreative
                                     serverParameter:ad.param
                                            adUnitId:ad.adId
                                              adView:self.adViewDelegate];
        
        if (!requestedSuccessfully) {
            // don't add class to invalid networks list for this failure
            className = nil;
            errorInfo = @"ClassCastError";
            errorCode = EPLAdResponseCode.MEDIATED_SDK_UNAVAILABLE;
            break;
        }
        
    } while (false);
    
    
    if (errorCode.code != EPLAdResponseCode.DEFAULT.code) {
        [self handleInstantiationFailure: className
                               errorCode: errorCode
                               errorInfo: errorInfo ];
        return NO;
    }
    
    // otherwise, no error yet
    // wait for a mediation adapter to hit one of our callbacks.
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


- (void)setAdapter:adapter {
    self.currentAdapter = adapter;
}


- (void)clearAdapter {
    if (self.currentAdapter) {
        self.currentAdapter.delegate = nil;
    }
    self.currentAdapter = nil;
    self.hasSucceeded = NO;
    self.hasFailed = YES;
    self.adFetcher = nil;
    self.adViewDelegate = nil;
    self.mediatedAd = nil;

    [self cancelTimeout];

    EPLLogInfo(@"mediation_finish");
}

- (BOOL)requestAd:(CGSize)size
  serverParameter:(NSString *)parameterString
         adUnitId:(NSString *)idString
           adView:(id<EPLAdFetcherDelegate>)adView
{
    EPLTargetingParameters *targetingParameters = [[EPLTargetingParameters alloc] init];
    
    NSMutableDictionary<NSString *, NSString *>  *customKeywordsAsStrings  = [EPLGlobal convertCustomKeywordsAsMapToStrings: adView.customKeywords
                                                                                                       withSeparatorString: @"," ];


    targetingParameters.customKeywords    = customKeywordsAsStrings;
    targetingParameters.age               = adView.age;
    targetingParameters.gender            = adView.gender;
    targetingParameters.location          = adView.location;
    NSString *idfa = EPLAdvertisingIdentifier();
    if(idfa){
        targetingParameters.idforadvertising  = idfa;
    }
    
    //
    if ([adView isKindOfClass:[EPLBannerAdView class]]) {
        // make sure the container and protocol match
        if (    [[self.currentAdapter class] conformsToProtocol:@protocol(EPLCustomAdapterBanner)]
             && [self.currentAdapter respondsToSelector:@selector(requestBannerAdWithSize:rootViewController:serverParameter:adUnitId:targetingParameters:)])
        {
            
            [self markLatencyStart];
            [self startTimeout];
            
            EPLBannerAdView *banner = (EPLBannerAdView *)adView;
            id<EPLCustomAdapterBanner> bannerAdapter = (id<EPLCustomAdapterBanner>) self.currentAdapter;
            [bannerAdapter requestBannerAdWithSize:size
                                rootViewController:banner.rootViewController
                                   serverParameter:parameterString
                                          adUnitId:idString
                               targetingParameters:targetingParameters];
            return YES;
        } else {
            EPLLogError(@"instance_exception %@", @"CustomAdapterBanner");
        }
        
    } else if ([adView isKindOfClass:[EPLInterstitialAd class]]) {
        // make sure the container and protocol match
        if (    [[self.currentAdapter class] conformsToProtocol:@protocol(EPLCustomAdapterInterstitial)]
            && [self.currentAdapter respondsToSelector:@selector(requestInterstitialAdWithParameter:adUnitId:targetingParameters:)])
        {
            
            [self markLatencyStart];
            [self startTimeout];
            
            id<EPLCustomAdapterInterstitial> interstitialAdapter = (id<EPLCustomAdapterInterstitial>) self.currentAdapter;
            [interstitialAdapter requestInterstitialAdWithParameter:parameterString
                                                           adUnitId:idString
                                                targetingParameters:targetingParameters];
            return YES;
        } else {
            EPLLogError(@"instance_exception %@", @"CustomAdapterInterstitial");
        }
        
    } else {
        EPLLogError(@"UNRECOGNIZED Entry Point classname.  (%@)", [adView class]);
    }
    
    
    // executes iff request was unsuccessful
    return NO;
}



#pragma mark - EPLCustomAdapterBannerDelegate

- (void)didLoadBannerAd:(nullable UIView *)view {
    [self didReceiveAd:view];
}



#pragma mark - EPLCustomAdapterInterstitialDelegate

- (void)didLoadInterstitialAd:(nullable id<EPLCustomAdapterInterstitial>)adapter {
    [self didReceiveAd:adapter];
}



#pragma mark - EPLCustomAdapterDelegate

- (void)didFailToLoadAd:(EPLAdResponseCode *)errorCode {
    [self didFailToReceiveAd:errorCode];
}

- (void)adWasClicked {
    if (self.hasFailed) return;
    [self runInBlock:^(void) {
        [self.adViewDelegate adWasClicked];
    }];
}

- (void)adDidLogImpression {
    if (self.hasFailed) return;
    [self runInBlock:^(void) {
        [self.adViewDelegate adDidLogImpression];
    }];
}

- (void)willPresentAd {
    if (self.hasFailed) return;
    [self runInBlock:^(void) {
        [self.adViewDelegate adWillPresent];
    }];
}

- (void)didPresentAd {
    if (self.hasFailed) return;
    [self runInBlock:^(void) {
        [self.adViewDelegate adDidPresent];
    }];
}

- (void)willCloseAd {
    if (self.hasFailed) return;
    [self runInBlock:^(void) {
        [self.adViewDelegate adWillClose];
    }];
}

- (void)didCloseAd {
    if (self.hasFailed) return;
    [self runInBlock:^(void) {
        [self.adViewDelegate adDidClose];
    }];
}

- (void)willLeaveApplication {
    if (self.hasFailed) return;
    [self runInBlock:^(void) {
        [self.adViewDelegate adWillLeaveApplication];
    }];
}

- (void)failedToDisplayAd {
    if (self.hasFailed) return;
    [self runInBlock:^(void) {
        if ([self.adViewDelegate conformsToProtocol:@protocol(EPLInterstitialAdViewInternalDelegate)]) {
            id<EPLInterstitialAdViewInternalDelegate> interstitialDelegate = (id<EPLInterstitialAdViewInternalDelegate>)self.adViewDelegate;
            [interstitialDelegate adFailedToDisplay];
        }
    }];
}



#pragma mark - helper methods

- (BOOL)checkIfHasResponded {
    // we received a callback from mediation adaptor, cancel timeout
    [self cancelTimeout];
    // don't succeed or fail more than once per mediated ad
    return (self.hasSucceeded || self.hasFailed);
}

- (void)didReceiveAd:(id)adObject
{
    if ([self checkIfHasResponded])  { return; }
    
    if (!adObject) {
        [self didFailToReceiveAd:EPLAdResponseCode.INTERNAL_ERROR];
        return;
    }
    
    //
    self.hasSucceeded = YES;
    [self markLatencyStop];
    
    EPLLogDebug(@"received an ad from the adapter");
    
    if ([adObject isKindOfClass:[UIView class]]) {
        UIView *adView = (UIView *)adObject;
        EPLMediationContainerView *containerView = [[EPLMediationContainerView alloc] initWithMediatedView:adView];
        containerView.controller = self;
        adObject = containerView;
    }
    //fire impressionURLS much earlier in the lifecycle
    [self.adFetcher checkifBeginToRenderAndFireImpressionTracker:self.mediatedAd];
    
    [self finish:EPLAdResponseCode.SUCCESS withAdObject:adObject];
    
}

- (void)didFailToReceiveAd:(EPLAdResponseCode *)errorCode {

    if ([self checkIfHasResponded]) return;
    [self markLatencyStop];
    self.hasFailed = YES;
    [self finish:errorCode withAdObject:nil];
}


- (void)finish: (EPLAdResponseCode *)errorCode
  withAdObject: (id)adObject
{

    // use queue to force return
    [self runInBlock:^(void) {
        EPLAdFetcher *fetcher = self.adFetcher;
        
        NSString *responseURL = [self.mediatedAd.responseURL an_responseTrackerReasonCode: (int)errorCode
                                                                                  latency: ([self getLatency] * 1000) ];

        // fireResponseURL will clear the adapter if fetcher exists
        if (!fetcher) {
            [self clearAdapter];
        }
        [fetcher fireResponseURL:responseURL reason:errorCode adObject:adObject];
    }];
}




#pragma mark - Timeout handler

- (void)startTimeout {

    if (self.timeoutCanceled) return;
    __weak EPLMediationAdViewController *weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 self.mediatedAd.networkTimeout * NSEC_PER_MSEC),
                   dispatch_get_main_queue(), ^{
                       EPLMediationAdViewController *strongSelf = weakSelf;
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


- (void)dealloc {

    [self clearAdapter];
}

@end

