/*   Copyright 2019 APPNEXUS INC
 
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

#import "EPLNativeAdFetcher.h"
#import "EPLUniversalTagRequestBuilder.h"
#import "EPLSDKSettings+PrivateMethods.h"
#import "EPLLogging.h"
#import "EPLAdResponseInfo.h"
#import "EPLStandardAd.h"
#import "EPLRTBVideoAd.h"
#import "EPLCSMVideoAd.h"
#import "EPLSSMStandardAd.h"
#import "EPLNativeStandardAdResponse.h"
#import "EPLMediatedAd.h"
#import "EPLAdConstants.h"

#if !APPNEXUS_NATIVE_MACOS_SDK
    #import "EPLNativeMediatedAdController.h"
    #import "EPLCSRAd.h"
    #import "EPLCSRNativeAdController.h"
#endif

              
#import "EPLTrackerInfo.h"
#import "EPLTrackerManager.h"
#import "NSTimer+EPLCategory.h"

@interface EPLNativeAdFetcher()
#if !APPNEXUS_NATIVE_MACOS_SDK
@property (nonatomic, readwrite, strong)  EPLNativeMediatedAdController      *nativeMediationController;
@property (nonatomic, readwrite, strong)  EPLCSRNativeAdController      *nativeBannerMediatedAdController;
#endif

@end

@implementation EPLNativeAdFetcher

-(nonnull instancetype) initWithDelegate:(nonnull id)delegate
{
    if (self = [self init]) {
        self.delegate = delegate;
    }
    return self;
}

- (void)clearMediationController {
    /*
     * Ad fetcher gets cleared, in the event the mediation controller lives beyond the ad fetcher.  The controller maintains a weak reference to the
     * ad fetcher delegate so that messages to the delegate can proceed uninterrupted.  Currently, the controller will only live on if it is still
     * displaying inside a banner ad view (in which case it will live on until the individual ad is destroyed).
     */
    
#if !APPNEXUS_NATIVE_MACOS_SDK
    self.nativeMediationController = nil;
#endif
    
}



#pragma mark - UT ad response processing methods
- (void)finishRequestWithError:(NSError *)error andAdResponseInfo:(EPLAdResponseInfo *)adResponseInfo
{
    self.isFetcherLoading = NO;
    EPLLogInfo(@"No ad received. Error: %@", error.localizedDescription);
    EPLAdFetcherResponse *response = [EPLAdFetcherResponse responseWithError:error];
    response.adResponseInfo = adResponseInfo;
    [self processFinalResponse:response];
}

- (void)processFinalResponse:(EPLAdFetcherResponse *)response
{
    self.ads = nil;
    self.isFetcherLoading = NO;
    
    if ([self.delegate respondsToSelector:@selector(didFinishRequestWithResponse:)]) {
        [self.delegate didFinishRequestWithResponse:response];
    }
}

//NB  continueWaterfall is co-functional the ad handler methods.
//    The loop of the waterfall lifecycle is managed by methods calling one another
//      until a valid ad object is found OR when the waterfall runs out.
//
- (void)continueWaterfall:(EPLAdResponseCode *)reason
{
    // stop waterfall if delegate reference (adview) was lost
    if (!self.delegate) {
        self.isFetcherLoading = NO;
        return;
    }
    
    BOOL adsLeft = (self.ads.count > 0);
    
    if (!adsLeft) {
        if (self.noAdUrl) {
             EPLLogDebug(@"(no_ad_url, %@)", self.noAdUrl);
             [EPLTrackerManager fireTrackerURL:self.noAdUrl];
         }
        [self finishRequestWithResponseCode:reason];
        return;
    }
    
    
    //
    id nextAd = [self.ads firstObject];
    [self.ads removeObjectAtIndex:0];
    
    self.adObjectHandler = nextAd;
    
#if !APPNEXUS_NATIVE_MACOS_SDK
    // CSR need to be checked first as It's inheriting EPLMediatedAd
    if ([nextAd isKindOfClass:[EPLCSRAd class]] ){
        [self handleCSRNativeAd:nextAd];
    }else if ( [nextAd isKindOfClass:[EPLMediatedAd class]] ) {
        [self handleCSMSDKMediatedAd:nextAd];
    }else if ( [nextAd isKindOfClass:[EPLNativeStandardAdResponse class]] ) {
        [self handleNativeStandardAd:nextAd];
    }else {
        EPLLogError(@"Implementation error: Unspported ad in native ads waterfall.  (class=%@)", [nextAd class]);
        [self continueWaterfall:EPLAdResponseCode.UNABLE_TO_FILL]; // skip this ad an jump to next ad
    }
#else
    if ( [nextAd isKindOfClass:[EPLNativeStandardAdResponse class]] ) {
        [self handleNativeStandardAd:nextAd];
    }
#endif
  
}


-(void) stopAdLoad {
    [super stopAdLoad];
}


- (void)startAutoRefreshTimer
{
    // Implemented only by EPLAdFetcher
}

- (void)restartAutoRefreshTimer
{
    // Implemented only by EPLAdFetcher
}




#pragma mark - Ad handlers.
#if !APPNEXUS_NATIVE_MACOS_SDK

- (void)handleCSRNativeAd:(EPLCSRAd *)csrAd
{
    self.nativeBannerMediatedAdController = [EPLCSRNativeAdController initCSRAd: csrAd
                                                                                withFetcher: self
                                                                          adRequestDelegate: self.delegate];
}

- (void)handleCSMSDKMediatedAd:(EPLMediatedAd *)mediatedAd
{
    if (mediatedAd.isAdTypeNative)
    {
        self.nativeMediationController = [EPLNativeMediatedAdController initMediatedAd: mediatedAd
                                                                          withFetcher: self
                                                                    adRequestDelegate: self.delegate ];
    } else {
        // TODO: should do something here
    }
}
#endif

- (void)handleNativeStandardAd:(EPLNativeStandardAdResponse *)nativeStandardAd
{
    
    EPLAdFetcherResponse  *fetcherResponse  = [EPLAdFetcherResponse responseWithAdObject:nativeStandardAd andAdObjectHandler:nil];
    [self processFinalResponse:fetcherResponse];
}

@end
