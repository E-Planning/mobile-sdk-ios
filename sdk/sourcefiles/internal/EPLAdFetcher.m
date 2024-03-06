/*   Copyright 2015 APPNEXUS INC
 
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

#import "EPLAdFetcher.h"
#import "EPLLogging.h"
#import "EPLUniversalTagRequestBuilder.h"

#import "EPLStandardAd.h"
#import "EPLRTBVideoAd.h"
#import "EPLCSMVideoAd.h"
#import "EPLSSMStandardAd.h"
#import "EPLSDKSettings+PrivateMethods.h"
#import "EPLNativeStandardAdResponse.h"

#import "EPLMRAIDContainerView.h"
#import "EPLMediatedAd.h"
#import "EPLMediationAdViewController.h"
#import "EPLNativeMediatedAdController.h"
#import "EPLSSMMediationAdViewController.h"
#import "EPLTrackerInfo.h"
#import "EPLTrackerManager.h"
#import "NSTimer+EPLCategory.h"
#import "EPLNativeRenderingViewController.h"
#import "EPLRTBNativeAdResponse.h"
#import "EPLAdView+PrivateMethods.h"
#import "EPLMultiAdRequest+PrivateMethods.h"
#import "EPLVideoAdProcessor.h"



@interface EPLAdFetcher() <     EPLVideoAdProcessorDelegate,
                                        EPLAdWebViewControllerLoadingDelegate,
                                        EPLNativeRenderingViewControllerLoadingDelegate
                                    >

@property (nonatomic, readwrite, strong)  EPLMRAIDContainerView              *adView;
@property (nonatomic, readwrite, strong)  EPLNativeRenderingViewController   *nativeAdView;
@property (nonatomic, readwrite, strong)  EPLMediationAdViewController       *mediationController;
@property (nonatomic, readwrite, strong)  EPLNativeMediatedAdController      *nativeMediationController;
@property (nonatomic, readwrite, strong)  EPLSSMMediationAdViewController    *ssmMediationController;

@property (nonatomic, readwrite, strong) NSTimer *autoRefreshTimer;

@end




#pragma mark -

@implementation EPLAdFetcher

#pragma mark Lifecycle.

- (nonnull instancetype)initWithDelegate:(nonnull id)delegate
{
    self = [self init];
    if (!self)  { return nil; }

    //
    self.delegate = delegate;

    return  self;
}

- (void)dealloc
{
    [self stopAdLoad];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (void)clearMediationController
{
    /*
     * Ad fetcher gets cleared, in the event the mediation controller lives beyond the ad fetcher.  The controller maintains a weak reference to the
     * ad fetcher delegate so that messages to the delegate can proceed uninterrupted.  Currently, the controller will only live on if it is still
     * displaying inside a banner ad view (in which case it will live on until the individual ad is destroyed).
     */
    self.mediationController = nil;
    
    self.nativeMediationController = nil;
    
    self.ssmMediationController = nil;
}

#pragma mark - Ad Request

- (void)stopAdLoad
{
    [super stopAdLoad];
    [self clearMediationController];
    [self stopAutoRefreshTimer];
}




#pragma mark - Ad Response

- (void)finishRequestWithError:(NSError *)error andAdResponseInfo:(EPLAdResponseInfo *)adResponseInfo
{
    self.isFetcherLoading = NO;
    
    NSTimeInterval interval = [self getAutoRefreshFromDelegate];
    if (interval > 0.0) {
        EPLLogInfo(@"No ad received. Will request ad in %f seconds. Error: %@", interval, error.localizedDescription);
    } else {
        EPLLogInfo(@"No ad received. Error: %@", error.localizedDescription);
    }
    
    EPLAdFetcherResponse *response = [EPLAdFetcherResponse responseWithError:error];
    response.adResponseInfo = adResponseInfo;
    [self processFinalResponse:response];
}

- (void)processFinalResponse:(EPLAdFetcherResponse *)response
{
    self.ads = nil;
    self.isFetcherLoading = NO;


    // MAR case.
    //
    if (self.fetcherMARManager)
    {
        if (!response.isSuccessful) {
            [self.fetcherMARManager internalMultiAdRequestDidFailWithError:response.error];
        } else {
            EPLLogError(@"MultiAdRequest manager SHOULD NEVER CALL processFinalResponse, except on error.");
        }

        return;
    }


    // AdUnit case.
    //
    // Stop auto-refreush timer for video and Native, but start it for everything else,
    //   unless it is the first pass for Lazy AdUnit.
    //
    if ([self.delegate respondsToSelector:@selector(adFetcher:didFinishRequestWithResponse:)]) {
        [self.delegate adFetcher:self didFinishRequestWithResponse:response];
    }

    // Restrict Auto Refresh for Banner and Native
    if ( (   [response.adObject isKindOfClass:[EPLMRAIDContainerView class]]
          && ((EPLMRAIDContainerView *)response.adObject).isBannerVideo) || ([response.adObjectHandler isKindOfClass:[EPLNativeStandardAdResponse class]]))
    {
        [self stopAutoRefreshTimer];
        return;
    }

    // This below condition should be exected only for a Regular Non-Lazy HTML Banner load. This should not be executed during both the first and second pass of lazyLoad HTML Banner.
    // For Lazy load cases startAutoRefreshTimer is called from allocateAndSetWebviewFromCachedAdObjectHandler when second pass is running.
    BOOL  isLazyLoadSecondPass  = [self.delegate respondsToSelector:@selector(valueOfIsLazySecondPassThroughAdUnit)] && [self.delegate valueOfIsLazySecondPassThroughAdUnit];
    if (!response.isLazy && !isLazyLoadSecondPass)
    {
        [self startAutoRefreshTimer];
    }
}

//NB  continueWaterfall is co-functional the ad handler methods.
//    The loop of the waterfall lifecycle is managed by methods calling one another
//      until a valid ad object is found OR when the waterfall runs out.
//
- (void)continueWaterfall:(EPLAdResponseCode *)reason
{
    // stop waterfall if delegate reference was lost
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
    
    
    if ([nextAd isKindOfClass:[EPLRTBVideoAd class]]) {
        [self handleRTBVideoAd:nextAd];
        
    } else if([nextAd isKindOfClass:[EPLCSMVideoAd class]]){
        [self handleCSMVideoAd:nextAd];
        
    } else if ( [nextAd isKindOfClass:[EPLStandardAd class]] ) {
        [self handleStandardAd:nextAd];
        
    } else if ( [nextAd isKindOfClass:[EPLMediatedAd class]] ) {
        [self handleCSMSDKMediatedAd:nextAd];
        
    } else if ( [nextAd isKindOfClass:[EPLSSMStandardAd class]] ) {
        [self handleSSMMediatedAd:nextAd];
        
    } else if ( [nextAd isKindOfClass:[EPLNativeStandardAdResponse class]] ) {
        [self handleNativeAd:nextAd];
        
    } else {
        EPLLogError(@"Implementation error: Unknown ad in ads waterfall.  (class=%@)", [nextAd class]);
    }
}


#pragma mark - Auto refresh timer.

- (void)startAutoRefreshTimer
{
    if (!self.autoRefreshTimer) {
        EPLLogDebug(@"fetcher_stopped");
    } else if ([self.autoRefreshTimer an_isScheduled]) {
        EPLLogDebug(@"AutoRefresh timer already scheduled.");
    } else {
        [self.autoRefreshTimer an_scheduleNow];
    }
}

// NB  Invocation of this method MUST ALWAYS be followed by invocation of startAutoRefreshTimer.
//
- (void)restartAutoRefreshTimer
{
    // stop old autoRefreshTimer
    [self stopAutoRefreshTimer];

    // setup new autoRefreshTimer if refresh interval positive
    NSTimeInterval interval = [self getAutoRefreshFromDelegate];
    if (interval > 0.0f)
    {
        self.autoRefreshTimer = [NSTimer timerWithTimeInterval:interval
                                                        target:self
                                                      selector:@selector(autoRefreshTimerDidFire:)
                                                      userInfo:nil
                                                       repeats:NO];
    }
}

- (void)stopAutoRefreshTimer
{
    [self.autoRefreshTimer invalidate];
    self.autoRefreshTimer = nil;
}

- (void)autoRefreshTimerDidFire:(NSTimer *)timer
{
    [self stopAdLoad];
    [self requestAd];
}

- (NSTimeInterval)getAutoRefreshFromDelegate {
    if ([self.delegate respondsToSelector:@selector(autoRefreshIntervalForAdFetcher:)]) {
        return [self.delegate autoRefreshIntervalForAdFetcher:self];
    }

    return  0.0f;
}




#pragma mark - Ad handlers.

// VAST ad.
//
- (void)handleRTBVideoAd:(EPLRTBVideoAd *)videoAd
{
    if (!videoAd.assetURL && !videoAd.content) {
        [self continueWaterfall:EPLAdResponseCode.UNABLE_TO_FILL];
    }
    
    NSString *notifyUrlString = videoAd.notifyUrlString;
    
    if (notifyUrlString.length > 0) {
        EPLLogDebug(@"(notify_url, %@)", notifyUrlString);
        [EPLTrackerManager fireTrackerURL:notifyUrlString];
    }

    EPLVideoAdSubtype  videoAdType  = EPLVideoAdSubtypeUnknown;
    if ([self.delegate respondsToSelector:@selector(videoAdTypeForAdFetcher:)]) {
        videoAdType = [self.delegate videoAdTypeForAdFetcher:self];
    }

    if (EPLVideoAdSubtypeBannerVideo == videoAdType)
    {
        CGSize  sizeOfWebView  = [self getWebViewSizeForCreativeWidth:videoAd.width andHeight:videoAd.height];

        BOOL  returnValue  = [self allocateAndSetWebviewWithSize:sizeOfWebView content:videoAd.content isXMLForVideo:YES];

        if (!returnValue) {
            EPLLogError(@"FAILED to allocate self.adView.");
        }

    } else {
        if (! [[EPLVideoAdProcessor alloc] initWithDelegate: self
                                        withAdVideoContent: videoAd ] )
        {
            EPLLogError(@"FAILED to create EPLVideoAdProcessor object.");
        }
    }
}



// Video ad.
//
-(void) handleCSMVideoAd:(EPLCSMVideoAd *) videoAd
{
    if (! [[EPLVideoAdProcessor alloc] initWithDelegate:self withAdVideoContent:videoAd])  {
        EPLLogError(@"FAILED to create EPLVideoAdProcessor object.");
    }
}


- (void)handleStandardAd:(EPLStandardAd *)standardAd
{
    CGSize  sizeOfWebview  = [self getWebViewSizeForCreativeWidth: standardAd.width
                                                        andHeight: standardAd.height];

    
    //
    if ([self.delegate respondsToSelector:@selector(valueOfEnableLazyLoad)] && [self.delegate valueOfEnableLazyLoad])
    {
        EPLAdFetcherResponse  *fetcherResponse  = [EPLAdFetcherResponse lazyResponseWithAdObject: standardAd
                                                                            andAdObjectHandler: self.adObjectHandler ];
        [self processFinalResponse:fetcherResponse];

        return;
    }


    //
    BOOL  returnValue  = [self allocateAndSetWebviewWithSize:sizeOfWebview content:standardAd.content isXMLForVideo:NO];

    if (!returnValue) {
        EPLLogError(@"FAILED to allocate self.adView.");
    }
}


- (void)handleCSMSDKMediatedAd:(EPLMediatedAd *)mediatedAd
{
    if (mediatedAd.isAdTypeNative)
    {
        self.nativeMediationController = [EPLNativeMediatedAdController initMediatedAd: mediatedAd
                                                                          withFetcher: self
                                                                    adRequestDelegate: self.delegate ];
    } else {
        self.mediationController = [EPLMediationAdViewController initMediatedAd: mediatedAd
                                                                   withFetcher: self
                                                                adViewDelegate: self.delegate];
    }
}


- (void)handleSSMMediatedAd:(EPLSSMStandardAd *)mediatedAd
{
    self.ssmMediationController = [EPLSSMMediationAdViewController initMediatedAd:mediatedAd
                                                                     withFetcher:self
                                                                  adViewDelegate:self.delegate];
}

- (void)handleNativeAd:(EPLNativeStandardAdResponse *)nativeAd
{
    

    BOOL enableNativeRendering = NO;
    if ([self.delegate respondsToSelector:@selector(enableNativeRendering)]) {
        enableNativeRendering = [self.delegate enableNativeRendering];
        if (([nativeAd.nativeRenderingUrl length] > 0) && enableNativeRendering){
            
            
            EPLRTBNativeAdResponse *rtnNativeAdResponse = [[EPLRTBNativeAdResponse alloc] init];
            rtnNativeAdResponse.nativeAdResponse = nativeAd ;
            
            // Lazy Load Return before rendering native ad during first pass.
            if ([self.delegate respondsToSelector:@selector(valueOfEnableLazyLoad)] && [self.delegate valueOfEnableLazyLoad])
            {
                EPLAdFetcherResponse  *fetcherResponse  = [EPLAdFetcherResponse lazyResponseWithAdObject: rtnNativeAdResponse
                                                                                    andAdObjectHandler: self.adObjectHandler ];
                [self processFinalResponse:fetcherResponse];

                return;
            }else{
                [self renderNativeAd:rtnNativeAdResponse];
                return;
            }
        }
    }
    // Traditional native ad instance.
    [self traditionalNativeAd:nativeAd];
 
}

-(void)traditionalNativeAd:(EPLNativeStandardAdResponse *)nativeAd{
    EPLAdFetcherResponse  *fetcherResponse = [EPLAdFetcherResponse responseWithAdObject:nativeAd andAdObjectHandler:nil];
    [self processFinalResponse:fetcherResponse];

}

-(void) renderNativeAd:(EPLBaseAdObject *)nativeRenderingElement {
    
    CGSize sizeofWebView = [self getAdSizeFromDelegate];
    
    
    if (self.nativeAdView) {
        self.nativeAdView = nil;
    }
    
    self.nativeAdView = [[EPLNativeRenderingViewController alloc] initWithSize:sizeofWebView BaseObject:nativeRenderingElement];
     self.nativeAdView.loadingDelegate = self;
}

- (void) checkifBeginToRenderAndFireImpressionTracker:(EPLBaseAdObject *) ad {
    
    NSArray *mediaTypes = [self.delegate adAllowedMediaTypes];
    BOOL isBanner = (![mediaTypes containsObject:@(EPLAllowedMediaTypeInterstitial)]);
    //fire the impression tracker earlier in the lifecycle. immediatley after creating the webView if it is Begin to Render
    if (isBanner && ad.impressionType == EPLBeginToRender){
            EPLLogDebug(@"Impression tracker fired on Begin To Render %@", ad.impressionUrls.firstObject);
            [EPLTrackerManager fireTrackerURLArray:ad.impressionUrls withBlock:nil];
            ad.impressionUrls = nil;
        
        }
}


- (void) didFailToLoadNativeWebViewController{
    if ([self.adObjectHandler isKindOfClass:[EPLNativeStandardAdResponse class]]) {
        EPLNativeStandardAdResponse *nativeStandardAdResponse = (EPLNativeStandardAdResponse *)self.adObjectHandler;
        [self traditionalNativeAd:nativeStandardAdResponse];
    }else{
        NSError  *error  = EPLError(@"EPLAdWebViewController is UNDEFINED.", EPLAdResponseCode.INTERNAL_ERROR.code);
        EPLAdFetcherResponse  *fetcherResponse = [EPLAdFetcherResponse responseWithError:error];
        [self processFinalResponse:fetcherResponse];
    }
}

- (void) didCompleteFirstLoadFromNativeWebViewController:(EPLNativeRenderingViewController *)controller{
    EPLAdFetcherResponse  *fetcherResponse  = nil;

    if (self.nativeAdView == controller)
    {
        fetcherResponse = [EPLAdFetcherResponse responseWithAdObject:controller andAdObjectHandler:self.adObjectHandler];
        [self processFinalResponse:fetcherResponse];
    } else {
        [self didFailToLoadNativeWebViewController];
    }
}


#pragma mark - EPLAdFetcherDelegate.

- (CGSize) getAdSizeFromDelegate
{
    if ([self.delegate respondsToSelector:@selector(requestedSizeForAdFetcher:)]) {
        return [self.delegate requestedSizeForAdFetcher:self];
    }
    return CGSizeZero;
}




#pragma mark - EPLAdWebViewControllerLoadingDelegate.

- (void) didCompleteFirstLoadFromWebViewController:(EPLAdWebViewController *)controller
{
    EPLAdFetcherResponse  *fetcherResponse  = nil;

    if (self.adView.webViewController == controller)
    {
        if (controller.videoAdOrientation) {
            if ([self.delegate respondsToSelector:@selector(setVideoAdOrientation:)]) {
                [self.delegate setVideoAdOrientation:controller.videoAdOrientation];
            }
        }
        
        if (controller.videoAdWidth) {
            if ([self.delegate respondsToSelector:@selector(setVideoAdWidth:)]) {
                [self.delegate setVideoAdWidth:controller.videoAdWidth];
            }
        }
        
        if (controller.videoAdHeight) {
            if ([self.delegate respondsToSelector:@selector(setVideoAdHeight:)]) {
                [self.delegate setVideoAdHeight:controller.videoAdHeight];
            }
        }

        fetcherResponse = [EPLAdFetcherResponse responseWithAdObject: self.adView
                                                 andAdObjectHandler: self.adObjectHandler ];
         
    } else {
        NSError  *error  = EPLError(@"EPLAdWebViewController is UNDEFINED.", EPLAdResponseCode.INTERNAL_ERROR.code);
        fetcherResponse = [EPLAdFetcherResponse responseWithError:error];
    }

    //
    [self processFinalResponse:fetcherResponse];
}


- (void) immediatelyRestartAutoRefreshTimerFromWebViewController:(EPLAdWebViewController *)controller
{
    [self autoRefreshTimerDidFire:nil];

}

- (void) stopAutoRefreshTimerFromWebViewController:(EPLAdWebViewController *)controller
{
    [self stopAutoRefreshTimer];
}




#pragma mark - EPLVideoAdProcessor delegate

- (void) videoAdProcessor:(nonnull EPLVideoAdProcessor *)videoProcessor didFinishVideoProcessing: (nonnull EPLVideoAdPlayer *)adVideo
{
        dispatch_async(dispatch_get_main_queue(), ^{
            EPLAdFetcherResponse *adFetcherResponse = [EPLAdFetcherResponse responseWithAdObject:adVideo andAdObjectHandler:self.adObjectHandler];
            [self processFinalResponse:adFetcherResponse];
        });
}

- (void) videoAdProcessor:(nonnull EPLVideoAdProcessor *)videoAdProcessor didFailVideoProcessing: (nonnull NSError *)error
{
    [self continueWaterfall:EPLAdResponseCode.UNABLE_TO_FILL];
}



#pragma mark - Helper methods.
// common for Banner / Interstitial RTB and SSM.
- (CGSize)getWebViewSizeForCreativeWidth:(nonnull NSString *)width
                               andHeight:(nonnull NSString *)height
{
    
    // Compare the size of the received impression with what the requested ad size is. If the two are different, send the ad delegate a message.
    CGSize receivedSize = CGSizeMake([width floatValue], [height floatValue]);
    CGSize requestedSize = [self getAdSizeFromDelegate];
    
    CGRect receivedRect = CGRectMake(CGPointZero.x, CGPointZero.y, receivedSize.width, receivedSize.height);
    CGRect requestedRect = CGRectMake(CGPointZero.x, CGPointZero.y, requestedSize.width, requestedSize.height);
    
    if (!CGRectContainsRect(requestedRect, receivedRect)) {
        EPLLogInfo(@"adsize_too_big %d%d%d%d",   (int)receivedRect.size.width,  (int)receivedRect.size.height,
                  (int)requestedRect.size.width, (int)requestedRect.size.height );
    }
    
    CGSize sizeOfCreative = (    (receivedSize.width > 0)
                             && (receivedSize.height > 0)) ? receivedSize : requestedSize;
    
    return sizeOfCreative;
}

/**
 *  Return: YES on success; otherwise NO.
 */
- (BOOL)allocateAndSetWebviewWithSize: (CGSize)webviewSize
                              content: (nonnull NSString *)webviewContent
                        isXMLForVideo: (BOOL)isContentXMLForVideo
{
    if (self.adView) {
        self.adView.loadingDelegate = nil;
    }

    //
    if (isContentXMLForVideo)
    {
        self.adView = [[EPLMRAIDContainerView alloc] initWithSize: webviewSize
                                                        videoXML: webviewContent ];

    } else {
        
        EPLStandardAd  *standardAd  = (EPLStandardAd *)self.adObjectHandler;

        self.adView = [[EPLMRAIDContainerView alloc] initWithSize: webviewSize
                                                            HTML: webviewContent
                                                  webViewBaseURL: [NSURL URLWithString:[[[EPLSDKSettings sharedInstance] baseUrlConfig] webViewBaseUrl]] ];
        
        
        //TODO-Kowshick Will this cause trouble for Interstitial Imp Tracking
        [self checkifBeginToRenderAndFireImpressionTracker:standardAd];
        
        
    }

    if (!self.adView)
    {
        NSError  *error  = EPLError(@"EPLAdWebViewController is UNDEFINED.", EPLAdResponseCode.INTERNAL_ERROR.code);
        EPLAdFetcherResponse  *fetcherResponse = [EPLAdFetcherResponse responseWithError:error];
        [self processFinalResponse:fetcherResponse];

        return  NO;
    }

    //
    self.adView.loadingDelegate = self;

    // Allow EPLJAM events to always be passed to the EPLAdView
    self.adView.webViewController.adViewANJAMInternalDelegate = self.delegate;

    return  YES;
}

- (BOOL)allocateAndSetWebviewFromCachedAdObjectHandler
{
    
    
    
    if ( [self.adObjectHandler isKindOfClass:[EPLStandardAd class]] ) {
        
        EPLStandardAd  *lazyStandardAd  = (EPLStandardAd *)self.adObjectHandler;

        CGSize         sizeOfWebview   = [self getWebViewSizeForCreativeWidth: lazyStandardAd.width
                                                                    andHeight: lazyStandardAd.height];

        // Optimistically restart activated autorefresh timer.
        // Successful load of lazy AdUnit webview will stop autorefresh timer.
        //
        [self restartAutoRefreshTimer];
        [self startAutoRefreshTimer];
        
        
        return  [self allocateAndSetWebviewWithSize: sizeOfWebview
                                            content: lazyStandardAd.content
                                      isXMLForVideo: NO ];
        
    } else if ( [self.adObjectHandler isKindOfClass:[EPLNativeStandardAdResponse class]] ) {
        EPLRTBNativeAdResponse *rtnNativeAdResponse = [[EPLRTBNativeAdResponse alloc] init];
        rtnNativeAdResponse.nativeAdResponse = self.adObjectHandler ;
        [self renderNativeAd:rtnNativeAdResponse];
        return YES;
    }
    return NO;
}


@end
