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

#import "EPLBannerAdView.h"
#import "EPLAdView+PrivateMethods.h"
#import "EPLMRAIDContainerView.h"
#import "EPLSDKSettings.h"
#import "EPLAdFetcher.h"
#import "EPLLogging.h"
#import "EPLTrackerManager.h"
#import "EPLRealTimer.h"
#import "UIView+EPLCategory.h"
#import "EPLBannerAdView+EPLContentViewTransitions.h"
#import "EPLAdView+PrivateMethods.h"

#import "EPLStandardAd.h"
#import "EPLRTBVideoAd.h"
#import "EPLMediationContainerView.h"
#import "EPLMediatedAd.h"

#import "EPLNativeAdRequest.h"
#import "EPLNativeStandardAdResponse.h"
#import "EPLNativeAdImageCache.h"
#import "EPLOMIDImplementation.h"
#import "EPLNativeAdResponse+PrivateMethods.h"
#import "EPLNativeRenderingViewController.h"

#import "EPLMRAIDContainerView.h"
#import "EPLWebView.h"




#pragma mark - Local constants.

static NSString *const kANAdType        = @"adType";
static NSString *const kANBannerWidth   = @"width";
static NSString *const kANBannerHeight  = @"height";
static NSString *const kANInline        = @"inline";
static CGFloat const kANOMIDSessionFinishDelay = 0.08f;




#pragma mark -

@interface EPLBannerAdView() <EPLBannerAdViewInternalDelegate, EPLRealTimerDelegate>

@property (nonatomic, readwrite, strong)  UIView  *contentView;

@property (nonatomic, readwrite, strong)  NSNumber  *transitionInProgress;

@property (nonatomic, readwrite, strong)  NSArray<NSString *>  *impressionURLs;

@property (nonatomic, strong)             EPLNativeAdResponse  *nativeAdResponse;

@property (nonatomic, readwrite)          BOOL  loadAdHasBeenInvoked;

@property (nonatomic, readwrite)          BOOL  isAdVisible100Percent;

@property (nonatomic, readwrite, assign)  EPLVideoOrientation  videoAdOrientation;

@property (nonatomic, readwrite, assign)  NSInteger  videoAdWidth;

@property (nonatomic, readwrite, assign)  NSInteger  videoAdHeight;

@property (nonatomic, readwrite, assign) EPLImpressionType impressionType;

/**
 * This flag remembers whether the initial return of the ad object from UT Response processing
 *   indicated that the AdUnit was lazy loaded.
 *
 * NOTE: Because EPLBannerAdView is a multi-format AdUnit, it may return an ad object that is NOT lazy loaded
 *       even if the feature flag is set for lazy loading (enableLazyLoad).
 *       For example when video or native ad is returnd to EPLBannerAdView with enableLazyLoad=YES.
 */
@property (nonatomic, readwrite)  BOOL  didBecomeLazyAdUnit;

/**
 * This flag is set by loadLazyAd before loading the webview.  It allows the fetcher to distinguish
 *   whether the ad object is returned from UT Response processing (first pass), or is being handled
 *   only to load the webview of a lazy loaded AdUnit (second pass).
 */
@property (nonatomic, readwrite)  BOOL  isLazySecondPassThroughAdUnit;

@end




#pragma mark -

@implementation EPLBannerAdView

@synthesize  autoRefreshInterval            = __autoRefreshInterval;
@synthesize  contentView                    = _contentView;
@synthesize  adSize                         = _adSize;
@synthesize  loadedAdSize                   = _loadedAdSize;
@synthesize  shouldAllowBannerDemand        = _shouldAllowBannerDemand;
@synthesize  shouldAllowVideoDemand         = _shouldAllowVideoDemand;
@synthesize  shouldAllowNativeDemand        = _shouldAllowNativeDemand;
@synthesize  shouldAllowHighImpactDemand    = _shouldAllowHighImpactDemand;
@synthesize  nativeAdRendererId             = _nativeAdRendererId;
@synthesize  enableNativeRendering          = _enableNativeRendering;
@synthesize  adResponseInfo                 = _adResponseInfo;
@synthesize  minDuration                    = __minDuration;
@synthesize  maxDuration                    = __maxDuration;
@synthesize  enableLazyLoad                 = _enableLazyLoad;
@synthesize  landscapeBannerVideoPlayerSize                 = _landscapeBannerVideoPlayerSize;
@synthesize  portraitBannerVideoPlayerSize                 = _portraitBannerVideoPlayerSize;
@synthesize  squareBannerVideoPlayerSize                 = _squareBannerVideoPlayerSize;


#pragma mark - Lifecycle.

- (void)initialize {
    [super initialize];
    
    self.autoresizingMask = UIViewAutoresizingNone;
    
    // Defaults.
    //
    __autoRefreshInterval         = kANBannerDefaultAutoRefreshInterval;
    _transitionDuration           = kAppNexusBannerAdTransitionDefaultDuration;
    _loadedAdSize                 = APPNEXUS_SIZE_UNDEFINED;
    _adSize                       = APPNEXUS_SIZE_UNDEFINED;
    _adSizes                      = nil;

    _shouldAllowBannerDemand      = YES;
    _shouldAllowVideoDemand       = NO;
    _shouldAllowNativeDemand      = NO;
    _shouldAllowHighImpactDemand  = NO;

    _nativeAdRendererId           = 0;
    _videoAdOrientation           = EPLUnknown;
    _videoAdWidth                 = 0;
    _videoAdHeight                = 0;
    _landscapeBannerVideoPlayerSize = CGSizeMake(1, 1);
    _portraitBannerVideoPlayerSize = CGSizeMake(1, 1);
    _squareBannerVideoPlayerSize = CGSizeMake(1, 1);

    self.allowSmallerSizes        = NO;
    self.loadAdHasBeenInvoked     = NO;
    self.enableNativeRendering    = NO;

    _enableLazyLoad                 = NO;
    _didBecomeLazyAdUnit            = NO;
    _isLazySecondPassThroughAdUnit  = NO;
    _isAdVisible100Percent          = NO;
    _impressionType                 = EPLBeginToRender;

    //
    [[EPLOMIDImplementation sharedInstance] activateOMIDandCreatePartner];
    
}

- (void)awakeFromNib {
    [super awakeFromNib];
    self.adSize = self.frame.size;
}

+ (nonnull EPLBannerAdView *)adViewWithFrame:(CGRect)frame placementId:(nonnull NSString *)placementId {
    return [[[self class] alloc] initWithFrame:frame placementId:placementId adSize:frame.size];
}

+ (nonnull EPLBannerAdView *)adViewWithFrame:(CGRect)frame placementId:(nonnull NSString *)placementId adSize:(CGSize)size{
    return [[[self class] alloc] initWithFrame:frame placementId:placementId adSize:size];
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    
    if (self != nil) {
        [self initialize];

        self.backgroundColor  = [UIColor clearColor];
    }
    
    return self;
}

- (nonnull instancetype)initWithFrame:(CGRect)frame placementId:(nonnull NSString *)placementId {
    self = [self initWithFrame:frame];
    
    if (self != nil) {
        self.placementId = placementId;
    }
    
    return self;
}

- (nonnull instancetype)initWithFrame:(CGRect)frame placementId:(nonnull NSString *)placementId adSize:(CGSize)size {
    self = [self initWithFrame:frame placementId:placementId];
    
    if (self != nil) {
        self.adSize = size;
    }
    
    return self;
}

- (nonnull instancetype)initWithFrame:(CGRect)frame memberId:(NSInteger)memberId inventoryCode:(nonnull NSString *)inventoryCode {
    self = [self initWithFrame:frame];
    if (self != nil) {
        [self setInventoryCode:inventoryCode memberId:memberId];
    }
    
    return self;
    
}

- (nonnull instancetype)initWithFrame:(CGRect)frame memberId:(NSInteger)memberId inventoryCode:(nonnull NSString *)inventoryCode adSize:(CGSize)size{
    self = [self initWithFrame:frame memberId:memberId inventoryCode:inventoryCode];
    if (self != nil) {
        self.adSize = size;
    }
    return self;
}

- (void) loadAd
{
    self.loadAdHasBeenInvoked = YES;

    self.didBecomeLazyAdUnit            = NO;
    self.isLazySecondPassThroughAdUnit  = NO;

    [super loadAd];
}


- (BOOL)loadLazyAd
{
    if (!self.didBecomeLazyAdUnit) {
        EPLLogWarn(@"AdUnit is NOT A CANDIDATE FOR LAZY LOADING.");
        return  NO;
    }

    if (self.contentView) {
        EPLLogWarn(@"AdUnit LAZY LOAD IS ALREADY COMPLETED.");
        return  NO;
    }


    //
    self.isLazySecondPassThroughAdUnit = YES;

    BOOL  returnValue  = [self.adFetcher allocateAndSetWebviewFromCachedAdObjectHandler];

    if (!returnValue)
    {
        NSError  *error  = EPLError(@"lazy_ad_load_failed", EPLAdResponseCode.INTERNAL_ERROR.code);
        EPLLogError(@"%@", error);
        return  NO;
    }


    return  returnValue;
}




#pragma mark - Getter and Setter methods

-(void)setVideoAdOrientation:(EPLVideoOrientation)videoOrientation{
    _videoAdOrientation = videoOrientation;
}

- (EPLVideoOrientation) getVideoOrientation {
    return _videoAdOrientation;
}

-(void)setVideoAdWidth:(NSInteger)videoWidth{
    _videoAdWidth = videoWidth;
}

- (NSInteger) getVideoWidth {
    return _videoAdWidth;
}

-(void)setVideoAdHeight:(NSInteger)videoHeight{
    _videoAdHeight = videoHeight;
}

- (NSInteger) getVideoHeight {
    return _videoAdHeight;
}

- (CGSize)adSize {
    EPLLogDebug(@"adSize returned %@", NSStringFromCGSize(_adSize));
    return  _adSize;
}

// adSize represents Universal Tag "primary_size".
//
- (void)setAdSize:(CGSize)adSize
{
    if (CGSizeEqualToSize(adSize, _adSize)) { return; }
    
    if ((adSize.width <= 0) || (adSize.height <= 0))  {
        EPLLogError(@"Width and height of adSize must both be GREATER THAN ZERO.  (%@)", NSStringFromCGSize(adSize));
        return;
    }
    
    //
    self.adSizes = @[ [NSValue valueWithCGSize:adSize] ];
    
    EPLLogDebug(@"Setting adSize to %@, NO smaller sizes.", NSStringFromCGSize(adSize));
}


// adSizes represents Universal Tag "sizes".
//
- (void)setAdSizes:(nonnull NSArray<NSValue *> *)adSizes
{
    NSValue  *adSizeAsValue  = [adSizes firstObject];
    if (!adSizeAsValue) {
        EPLLogError(@"adSizes array IS EMPTY.");
        return;
    }
    
    for (NSValue *valueElement in adSizes)
    {
        CGSize  sizeElement  = [valueElement CGSizeValue];
        
        if ((sizeElement.width <= 0) || (sizeElement.height <= 0)) {
            EPLLogError(@"One or more elements of adSizes have a width or height LESS THAN ONE (1). (%@)", adSizes);
            return;
        }
    }
    
    //
    _adSize                 = [adSizeAsValue CGSizeValue];
    _adSizes                = [[NSArray alloc] initWithArray:adSizes copyItems:YES];
    self.allowSmallerSizes  = NO;
}


// If auto refresh interval is above zero (0), enable auto refresh,
// though never with a refresh interval value below kANBannerMinimumAutoRefreshInterval.
//
- (void)setAutoRefreshInterval:(NSTimeInterval)autoRefreshInterval
{
    if (autoRefreshInterval <= kANBannerAutoRefreshThreshold) {
        __autoRefreshInterval = kANBannerAutoRefreshThreshold;
        EPLLogDebug(@"Turning auto refresh off");

        return;
    }

    if (autoRefreshInterval < kANBannerMinimumAutoRefreshInterval)
    {
        __autoRefreshInterval = kANBannerMinimumAutoRefreshInterval;
        EPLLogWarn(@"setAutoRefreshInterval called with value %f, autoRefreshInterval set to minimum allowed value %f.",
                      autoRefreshInterval, kANBannerMinimumAutoRefreshInterval );
    } else {
        __autoRefreshInterval = autoRefreshInterval;
        EPLLogDebug(@"AutoRefresh interval set to %f seconds", __autoRefreshInterval);
    }


    //
    if (self.loadAdHasBeenInvoked) {
        [self loadAd];
    }
}

- (NSTimeInterval)autoRefreshInterval {
    EPLLogDebug(@"autoRefreshInterval returned %f seconds", __autoRefreshInterval);
    return __autoRefreshInterval;
}

- (void)setEnableLazyLoad:(BOOL)booleanValue
{
    if (YES == _enableLazyLoad) {
        EPLLogWarn(@"enableLazyLoad is already ENABLED.");
        return;
    }

    if (NO == booleanValue) {
        EPLLogWarn(@"CANNOT DISABLE enableLazyLoad once it is set.");
        return;
    }

    // NB  Best effort to set critical section around fetcher for enableLazyLoad property.
    //
    if (self.loadAdHasBeenInvoked && (YES == self.adFetcher.isFetcherLoading)) {
        EPLLogWarn(@"CANNOT ENABLE enableLazyLoad while fetcher is loading.");
        return;
    }

    //
    _enableLazyLoad = YES;
}




#pragma mark - Helper methods.

- (void)fireTrackerAndOMID
{
    if(self.impressionURLs != nil) {
        //this check is needed to know if the impression was fired early or when attached to window. if impressionURL is nil then either it was fired early & removed or there was no urls in the response
        EPLLogDebug(@"Impression tracker fired");
        [EPLTrackerManager fireTrackerURLArray:self.impressionURLs withBlock:^(BOOL isTrackerFired) {
            if (isTrackerFired && [self.delegate respondsToSelector:@selector(adDidLogImpression:)]) {
                [self.delegate adDidLogImpression:self];
            }
        }];
        self.impressionURLs = nil;
    }
    
    [self fireOMIDImpression];

}

- (void)fireOMIDImpression
{
    // Fire OMID - Impression event only for AppNexus WKWebview TRUE for RTB and SSM
    //
    if ([self.contentView isKindOfClass:[EPLMRAIDContainerView class]])
    {
        EPLMRAIDContainerView  *standardAdView  = (EPLMRAIDContainerView *)self.contentView;

        if (standardAdView.webViewController.omidAdSession != nil)
        {
            [[EPLOMIDImplementation sharedInstance] fireOMIDImpressionOccuredEvent:standardAdView.webViewController.omidAdSession];
        }
    }

}



#pragma mark - Transitions

- (void)setContentView:(UIView *)newContentView
{
    // Do not update lazy loaded webview unless the new webview candidate is defined.
    //
    if (!newContentView && self.isLazySecondPassThroughAdUnit)  {
        //reset this property so that the refresh of banner doesnt get affected - https://jira.xandr-services.com/browse/MS-4573
        _contentView = newContentView;
        return;
        
    }

    //
    if (newContentView != _contentView)
    {
        UIView *oldContentView = _contentView;
        _contentView = newContentView;
        
        if ([newContentView isKindOfClass:[EPLMRAIDContainerView class]]) {
            EPLMRAIDContainerView *adView = (EPLMRAIDContainerView *)newContentView;
            adView.adViewDelegate = self;
        }
        
        if ([oldContentView isKindOfClass:[EPLMRAIDContainerView class]]) {
            EPLMRAIDContainerView *adView = (EPLMRAIDContainerView *)oldContentView;
            adView.adViewDelegate = nil;
        }
        
        if ([newContentView isKindOfClass:[EPLNativeRenderingViewController class]]) {
            EPLNativeRenderingViewController *adView = (EPLNativeRenderingViewController *)newContentView;
            adView.adViewDelegate = self;
        }
        
        if ([oldContentView isKindOfClass:[EPLNativeRenderingViewController class]]) {
            EPLNativeRenderingViewController *adView = (EPLNativeRenderingViewController *)oldContentView;
            adView.adViewDelegate = nil;
        }
        
        [self performTransitionFromContentView:oldContentView
                                 toContentView:newContentView];
    }
}

- (void)addOpenMeasurementFriendlyObstruction:(nonnull UIView *)obstructionView{
    [super addOpenMeasurementFriendlyObstruction:obstructionView];
    [self setFriendlyObstruction];
}

- (void)setFriendlyObstruction
{
    if ([self.contentView isKindOfClass:[EPLMRAIDContainerView class]]) {
        EPLMRAIDContainerView *adView = (EPLMRAIDContainerView *)self.contentView;
        if(adView.webViewController != nil && adView.webViewController.omidAdSession != nil){
            for (UIView *obstructionView in self.obstructionViews){
                [[EPLOMIDImplementation sharedInstance] addFriendlyObstruction:obstructionView toOMIDAdSession:adView.webViewController.omidAdSession];
            }
        }
    }
}

- (void)removeOpenMeasurementFriendlyObstruction:(UIView *)obstructionView{
    [super removeOpenMeasurementFriendlyObstruction:obstructionView];
    if([self.contentView isKindOfClass:[EPLMRAIDContainerView class]]){
        EPLMRAIDContainerView *adView = (EPLMRAIDContainerView *)self.contentView;
        if(adView.webViewController != nil && adView.webViewController.omidAdSession != nil){
            [[EPLOMIDImplementation sharedInstance] removeFriendlyObstruction:obstructionView toOMIDAdSession:adView.webViewController.omidAdSession];
        }
    }
}

- (void)removeAllOpenMeasurementFriendlyObstructions{
    [super removeAllOpenMeasurementFriendlyObstructions];
    if ([self.contentView isKindOfClass:[EPLMRAIDContainerView class]]) {
        EPLMRAIDContainerView *adView = (EPLMRAIDContainerView *)self.contentView;
        if(adView.webViewController != nil && adView.webViewController.omidAdSession != nil){
            [[EPLOMIDImplementation sharedInstance] removeAllFriendlyObstructions:adView.webViewController.omidAdSession];
        }
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    if (self.shouldResizeAdToFitContainer)
    {
        CGFloat  horizontalScaleFactor   = self.frame.size.width / [self.contentView an_originalFrame].size.width;
        CGFloat  verticalScaleFactor     = self.frame.size.height / [self.contentView an_originalFrame].size.height;
        CGFloat  scaleFactor             = horizontalScaleFactor < verticalScaleFactor ? horizontalScaleFactor : verticalScaleFactor;
        CGAffineTransform transform = CGAffineTransformMakeScale(scaleFactor, scaleFactor);
        self.contentView.transform = transform;
    }
}

- (NSNumber *)transitionInProgress {
    if (!_transitionInProgress) _transitionInProgress = @(NO);
    return _transitionInProgress;
}



#pragma mark - Implementation of abstract methods from EPLAdView

- (void)loadAdFromHtml: (nonnull NSString *)html
                 width: (int)width
                height: (int)height
{
    self.adSize = CGSizeMake(width, height);
    [super loadAdFromHtml:html width:width height:height];
}




#pragma mark - EPLUniversalAdFetcherDelegate

/**
 * NOTE:  How are flags used to distinguish lazy loading from regular loading of AdUnits?
 *        With the introduction of lazy loading, there are three different cases that call adFetcher:didfinishRequestWithResponse:.
 *
 *        AdUnit is lazy loaded -- first return to AdUnit from UT Response processing.
 *              response.isLazy==YES
 *        Lazy AdUnit is loading webview -- second return to AdUnit, initiated by the AdUnit itself (loadLazyAd)
 *              response.isLazy==NO  &&  AdUnit.isLazySecondPassThroughAdUnit==YES
 *        AdUnit is NOT lazy loaded
 *              response.isLazy==NO  &&  AdUnit.isLazySecondPassThroughAdUnit==NO
 */
- (void)adFetcher:(EPLAdFetcher *)fetcher didFinishRequestWithResponse:(EPLAdFetcherResponse *)response
{
    id  adObject         = response.adObject;
    id  adObjectHandler  = response.adObjectHandler;

    NSError  *error  = nil;


    // Try to get EPLAdResponseInfo from anything that comes through.
    //
    if (adObjectHandler) {
        _adResponseInfo = (EPLAdResponseInfo *) [EPLGlobal valueOfGetterProperty:kANAdResponseInfo forObject:adObjectHandler];
        if (_adResponseInfo) {
            [self setAdResponseInfo:_adResponseInfo];
        }
        
        if([adObjectHandler isKindOfClass:[EPLBaseAdObject class]]){
            EPLBaseAdObject  *baseAdObject  = (EPLBaseAdObject *)response.adObjectHandler;
            self.impressionType = baseAdObject.impressionType;
        }
    }
    


    //
    if (!response.isSuccessful)
    {
        [self finishRequest:response withReponseError:response.error];

        if (self.enableLazyLoad) {
            [self.adFetcher restartAutoRefreshTimer];
            [self.adFetcher startAutoRefreshTimer];
        }

        return;
    }
    
    //Check if its banner only & not native or native renderer
    if(self.impressionType == EPLViewableImpression){
        BOOL shouldAddDelegate = TRUE;
        
        if([adObjectHandler isKindOfClass:[EPLNativeStandardAdResponse class]] || [adObject isKindOfClass:[EPLNativeAdResponse class]]){
            shouldAddDelegate = FALSE;
        }
        
        if(response.isLazy == NO && self.isLazySecondPassThroughAdUnit == YES){
            shouldAddDelegate = TRUE;
        }
        
        if(shouldAddDelegate){
            [EPLRealTimer addDelegate:self];
        }
    }else if([EPLSDKSettings sharedInstance].enableOMIDOptimization && !([adObjectHandler isKindOfClass:[EPLNativeStandardAdResponse class]] || [adObject isKindOfClass:[EPLNativeAdResponse class]]) ){
        [EPLRealTimer addDelegate:self];
    }
    
    // Capture state for all AdUnits.  UNLESS this is the second pass of lazy AdUnit.
    //
    if ( (!response.isLazy && !self.isLazySecondPassThroughAdUnit) || response.isLazy )
    {
        self.loadAdHasBeenInvoked = YES;

        self.contentView = nil;
        self.impressionURLs = nil;

        _adResponseInfo = (EPLAdResponseInfo *) [EPLGlobal valueOfGetterProperty:kANAdResponseInfo forObject:adObjectHandler];
        if (_adResponseInfo) {
            [self setAdResponseInfo:_adResponseInfo];
        }

    }

    // Process AdUnit according to class type of UIView.
    //
    if ([adObject isKindOfClass:[UIView class]] || response.isLazy)
    {
        self.impressionURLs = (NSArray<NSString *> *) [EPLGlobal valueOfGetterProperty:kANImpressionUrls forObject:adObjectHandler];
        
        if ( (!response.isLazy && !self.isLazySecondPassThroughAdUnit) || response.isLazy )
        {
            NSString  *width   = (NSString *) [EPLGlobal valueOfGetterProperty:kANBannerWidth  forObject:adObjectHandler];
            NSString  *height  = (NSString *) [EPLGlobal valueOfGetterProperty:kANBannerHeight forObject:adObjectHandler];


            if (width && height)
            {
                CGSize receivedSize = CGSizeMake([width floatValue], [height floatValue]);
                _loadedAdSize = receivedSize;
            } else {
                _loadedAdSize = self.adSize;
            }
        }


        // Return early if AdUnit is lazy loaded.
        //
        if (response.isLazy)
        {
            self.didBecomeLazyAdUnit = YES;
            self.isLazySecondPassThroughAdUnit = NO;

            [self.adFetcher stopAutoRefreshTimer];

            [self lazyAdDidReceiveAd:self];
            return;

        }


        // Handle AdUnit that is NOT lazy loaded.
        //
        if(self.contentView == nil){
            self.contentView = adObject;
        }
        
        // Once the contentView is set Video will resize based on user set size(landscape/portrait/squareBannerVideoPlayerSize),
        // we need to update the loaded Ad Size
        if ((_adResponseInfo.adType == EPLAdTypeVideo))
        {
            if([self.contentView isKindOfClass:[EPLMRAIDContainerView class]]){
                EPLMRAIDContainerView *adView = (EPLMRAIDContainerView *)self.contentView;
                _loadedAdSize = adView.webViewController.videoPlayerSize;
            }
        }

        // Only Fire OMID Impression here for Begin to Render Cases. If it is Begin To Render then impression would have already fired from [EPLAdFetcher fireImpressionTrackersEarly]
        if(self.impressionType == EPLBeginToRender){
           [self fireOMIDImpression];
        }


        if ((_adResponseInfo.adType == EPLAdTypeBanner) || (_adResponseInfo.adType == EPLAdTypeVideo))
        {
          [self setFriendlyObstruction];
        }

        if ([adObjectHandler isKindOfClass:[EPLNativeStandardAdResponse class]])
        {
            NSError  *registerError  = nil;

            self.nativeAdResponse  = (EPLNativeAdResponse *)response.adObjectHandler;
            [self setAdResponseInfo:self.nativeAdResponse.adResponseInfo];

            if ((self.obstructionViews != nil) && (self.obstructionViews.count > 0))
            {
                [self.nativeAdResponse registerViewForTracking: self.contentView
                                        withRootViewController: self.displayController
                                                clickableViews: @[]
                           openMeasurementFriendlyObstructions: self.obstructionViews
                                                         error: &registerError];
            } else {
                [self.nativeAdResponse registerViewForTracking: self.contentView
                                        withRootViewController: self.displayController
                                                clickableViews: @[]
                                                         error: &registerError];
            }
        }

        [self adDidReceiveAd:self];


    // Process AdUnit according to class type of EPLNativeAdResponse.
    //
    } else if ([adObject isKindOfClass:[EPLNativeAdResponse class]]) {
        EPLNativeAdResponse  *nativeAdResponse  = (EPLNativeAdResponse *)response.adObject;
        
        if(nativeAdResponse.adResponseInfo){ // For native mediation cases response info is set in the beginning and responseinfo here will be nil
            [self setAdResponseInfo:nativeAdResponse.adResponseInfo];
        }

        nativeAdResponse.clickThroughAction           = self.clickThroughAction;
        nativeAdResponse.landingPageLoadsInBackground = self.landingPageLoadsInBackground;

        //
        [self ad:self didReceiveNativeAd:nativeAdResponse];


    // AdUnit class type is UNRECOGNIZED.
    //
    } else {
        NSString  *unrecognizedResponseErrorMessage  = [NSString stringWithFormat:@"UNRECOGNIZED ad response.  (%@)", [adObject class]];

        NSDictionary  *errorInfo  = @{NSLocalizedDescriptionKey: NSLocalizedString(
                                                                     unrecognizedResponseErrorMessage,
                                                                     @"Error: UNKNOWN ad object returned as response to multi-format ad request."
                                                                   )
                                    };

        error = [NSError errorWithDomain:EPL_ERROR_DOMAIN
                                    code:EPLAdResponseCode.NON_VIEW_RESPONSE.code
                                userInfo:errorInfo];

        [self finishRequest:response withReponseError:error];
    }
}

- (void)finishRequest:(EPLAdFetcherResponse *)response withReponseError:(NSError *)error
{
    self.contentView          = nil;
    self.didBecomeLazyAdUnit  = NO;

    // Preserve existing EPLAdResponseInfo whan AdUnit is lazy loaded.
    //
    if (self.enableLazyLoad && self.isLazySecondPassThroughAdUnit) {
        response.adResponseInfo = self.adResponseInfo;
    }

    [self adRequestFailedWithError:error andAdResponseInfo:response.adResponseInfo];
}


- (NSTimeInterval)autoRefreshIntervalForAdFetcher:(EPLAdFetcher *)fetcher {
    return self.autoRefreshInterval;
}

- (CGSize)requestedSizeForAdFetcher:(EPLAdFetcher *)fetcher {
    return self.adSize;
}

- (EPLVideoAdSubtype) videoAdTypeForAdFetcher:(EPLAdFetcher *)fetcher {
    return  EPLVideoAdSubtypeBannerVideo;
}

- (NSDictionary *) internalDelegateUniversalTagSizeParameters
{
    CGSize  containerSize  = self.adSize;
    
    if (CGSizeEqualToSize(self.adSize, APPNEXUS_SIZE_UNDEFINED))
    {
        containerSize           = self.frame.size;
        self.adSizes            = @[ [NSValue valueWithCGSize:containerSize] ];
        self.allowSmallerSizes  = YES;
    }
    
    //
    NSMutableDictionary  *delegateReturnDictionary  = [[NSMutableDictionary alloc] init];
    [delegateReturnDictionary setObject:[NSValue valueWithCGSize:containerSize]  forKey:EPLInternalDelgateTagKeyPrimarySize];
    [delegateReturnDictionary setObject:self.adSizes                             forKey:EPLInternalDelegateTagKeySizes];
    [delegateReturnDictionary setObject:@(self.allowSmallerSizes)                forKey:EPLInternalDelegateTagKeyAllowSmallerSizes];
    
    return  delegateReturnDictionary;
}




#pragma mark - EPLAdViewInternalDelegate

- (NSString *) adTypeForMRAID  {
    return kANInline;
}

- (NSArray<NSValue *> *)adAllowedMediaTypes
{
    NSMutableArray *mediaTypes  = [[NSMutableArray alloc] init];
    if(_shouldAllowBannerDemand){
        [mediaTypes addObject:@(EPLAllowedMediaTypeBanner)];
    }
    if(_shouldAllowNativeDemand){
        [mediaTypes addObject:@(EPLAllowedMediaTypeNative)];
    }
    if(_shouldAllowVideoDemand){
        [mediaTypes addObject:@(EPLAllowedMediaTypeVideo)];
    }
    if(_shouldAllowHighImpactDemand){
        [mediaTypes addObject:@(EPLAllowedMediaTypeHighImpact)];
    }
    return  [mediaTypes copy];
}

-(NSInteger) nativeAdRendererId{
    return _nativeAdRendererId;
}

-(BOOL) enableNativeRendering{
    return _enableNativeRendering;
}

- (UIViewController *)displayController
{
    UIViewController *displayController = self.rootViewController;

    if (!displayController) {
        displayController = [self an_parentViewController];
    }

    return displayController;
}

- (BOOL)valueOfEnableLazyLoad
{
    return  self.enableLazyLoad;
}

- (BOOL)valueOfIsLazySecondPassThroughAdUnit
{
    return  self.isLazySecondPassThroughAdUnit;
}


#pragma mark - UIView observer methods.


-(void) willMoveToSuperview:(UIView *)newSuperview {
    if(!newSuperview && _adResponseInfo.adType == EPLAdTypeNative && self.nativeAdResponse != nil){
        [self.nativeAdResponse unregisterViewFromTracking];
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (kANOMIDSessionFinishDelay * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void) {
            [super willMoveToSuperview:newSuperview];
            self.nativeAdResponse = nil;
        });
    }
    else{
        [super willMoveToSuperview:newSuperview];
    }
}


#pragma mark - Check if on screen & fire impression trackers

- (void) handle1SecTimerSentNotification {
    CGRect updatedVisibleInViewRectangle = [self.contentView an_visibleInViewRectangle];
    
    EPLLogInfo(@"exposed rectangle: %@",  NSStringFromCGRect(updatedVisibleInViewRectangle));
    
    if(updatedVisibleInViewRectangle.size.width > 0 && updatedVisibleInViewRectangle.size.height > 0 && self.impressionURLs != nil && self.impressionType == EPLViewableImpression){
        EPLLogDebug(@"Impression tracker fired on Viewable Impression");
        //Fire impression tracker here
        [self fireTrackerAndOMID];
        //Firing the impression tracker & set the delegate to nil to not duplicate the firing of impressions
        if(![EPLSDKSettings sharedInstance].enableOMIDOptimization){
            [EPLRealTimer removeDelegate:self];
        }
    }
    
    if([EPLSDKSettings sharedInstance].enableOMIDOptimization){
        if(updatedVisibleInViewRectangle.size.width == self.loadedAdSize.width && updatedVisibleInViewRectangle.size.height == self.loadedAdSize.height && !self.isAdVisible100Percent){
            self.isAdVisible100Percent = YES;
        }else  if(updatedVisibleInViewRectangle.size.width == 0 && updatedVisibleInViewRectangle.size.height == 0 && self.isAdVisible100Percent){
            if ([self.contentView isKindOfClass:[EPLMRAIDContainerView class]])
            {
                EPLMRAIDContainerView  *standardAdView  = (EPLMRAIDContainerView *)self.contentView;
                if (standardAdView.webViewController.omidAdSession != nil)
                {
                    [[EPLOMIDImplementation sharedInstance] stopOMIDAdSession:standardAdView.webViewController.omidAdSession];
                    [EPLRealTimer removeDelegate:self];
                }
            }
        }
    }
}


@end
