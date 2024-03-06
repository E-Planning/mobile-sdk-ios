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

#import "EPLNativeStandardAdResponse.h"
#import "EPLGlobal.h"
#import "EPLLogging.h"
#import "EPLNativeAdResponse+PrivateMethods.h"
#import "NSTimer+EPLCategory.h"
#import "EPLTrackerManager.h"
#import "EPLAdConstants.h"
#import "EPLRealTimer.h"
#import "EPLAdConstants.h"

#if !APPNEXUS_NATIVE_MACOS_SDK
#import "UIView+EPLCategory.h"
#import "EPLOMIDImplementation.h"
#import "EPLBrowserViewController.h"
#else
#import <AppKit/AppKit.h>
#import "NSView+EPLCategory.h"
#endif

#import "EPLSDKSettings.h"

#if !APPNEXUS_NATIVE_MACOS_SDK
@interface EPLNativeStandardAdResponse() <EPLBrowserViewControllerDelegate, EPLRealTimerDelegate>
@property (nonatomic, readwrite, strong) EPLBrowserViewController *inAppBrowser;
#else
@interface EPLNativeStandardAdResponse() <EPLRealTimerDelegate>
#endif
@property (nonatomic, readwrite, strong) NSDate *dateCreated;
@property (nonatomic, readwrite, assign) EPLNativeAdNetworkCode networkCode;
@property (nonatomic, readwrite, assign, getter=hasExpired) BOOL expired;

@property (nonatomic, readwrite, strong) NSTimer *viewabilityTimer;
@property (nonatomic, readwrite, assign) BOOL impressionHasBeenTracked;

@property (nonatomic, readwrite)          BOOL  isAdVisible100Percent;
@end




@implementation EPLNativeStandardAdResponse

@synthesize title = _title;
@synthesize body = _body;
@synthesize callToAction = _callToAction;
@synthesize rating = _rating;
@synthesize mainImage = _mainImage;
@synthesize iconImage = _iconImage;
@synthesize mainImageSize = _mainImageSize;
@synthesize mainImageURL = _mainImageURL;
@synthesize iconImageURL = _iconImageURL;
@synthesize customElements = _customElements;
@synthesize iconImageSize = _iconImageSize;
@synthesize networkCode = _networkCode;
@synthesize expired = _expired;
@synthesize sponsoredBy = _sponsoredBy;
@synthesize creativeId = _creativeId;
@synthesize additionalDescription = _additionalDescription;
@synthesize vastXML = _vastXML;
@synthesize privacyLink = _privacyLink;
@synthesize nativeRenderingUrl = _nativeRenderingUrl;
@synthesize nativeRenderingObject = _nativeRenderingObject;
@synthesize adResponseInfo = _adResponseInfo;


#pragma mark - Lifecycle.

- (instancetype)init {
    if (self = [super init]) {
        _networkCode = EPLNativeAdNetworkCodeAppNexus;
        _dateCreated = [NSDate date];
        _impressionHasBeenTracked = NO;
        _isAdVisible100Percent    = NO;
        _impressionType = EPLBeginToRender;

    }
    return self;
}

- (void)dealloc {
    [self.viewabilityTimer invalidate];
}




#pragma mark - Registration

- (BOOL)registerResponseInstanceWithNativeView:(EPLView *)view
                            rootViewController:(EPLViewController *)controller
                                clickableViews:(NSArray *)clickableViews
                                         error:(NSError *__autoreleasing *)error {
    [self setupViewabilityTracker];
#if !APPNEXUS_NATIVE_MACOS_SDK
    [self attachGestureRecognizersToNativeView:view
                            withClickableViews:clickableViews];
#endif

    return YES;
}


- (void)unregisterViewFromTracking {
    [super unregisterViewFromTracking];
    [self.viewabilityTimer invalidate];
}



#pragma mark - Impression Tracking

- (void)setupViewabilityTracker
{

    if ((self.impressionType == EPLViewableImpression || [EPLSDKSettings sharedInstance].enableOMIDOptimization)) {
        [EPLRealTimer addDelegate:self];
    }
    
    if(self.impressionType == EPLBeginToRender) {
            [self trackImpression];
    }
}

- (void) checkIfViewIs1pxOnScreen {

    CGRect updatedVisibleInViewRectangle = [self.viewForTracking an_visibleInViewRectangle];
#if !APPNEXUS_NATIVE_MACOS_SDK
    EPLLogInfo(@"visible rectangle Native: %@", NSStringFromCGRect(updatedVisibleInViewRectangle));
#else
    EPLLogInfo(@"visible rectangle Native: %@", NSStringFromRect(updatedVisibleInViewRectangle));
#endif

    if(!self.impressionHasBeenTracked){
        if(updatedVisibleInViewRectangle.size.width > 0 && updatedVisibleInViewRectangle.size.height > 0){
            EPLLogInfo(@"Impression tracker fired when 1px native on screen");
            [self trackImpression];
        }
    }
// OMID is not supported by macOS
#if !APPNEXUS_NATIVE_MACOS_SDK
    if([EPLSDKSettings sharedInstance].enableOMIDOptimization){
        if(updatedVisibleInViewRectangle.size.width == self.viewForTracking.frame.size.width && updatedVisibleInViewRectangle.size.height ==  self.viewForTracking.frame.size.height && !self.isAdVisible100Percent){
            self.isAdVisible100Percent = YES;
        }else  if(updatedVisibleInViewRectangle.size.width == 0 && updatedVisibleInViewRectangle.size.height == 0 && self.isAdVisible100Percent){
            if (self.omidAdSession != nil){
                [[EPLOMIDImplementation sharedInstance] stopOMIDAdSession:self.omidAdSession];
                [EPLRealTimer removeDelegate:self];
                
                
            }
        }
    }
#endif

}

- (void)trackImpression {
    if (!self.impressionHasBeenTracked) {

        EPLLogDebug(@"Firing impression trackers");
        [self fireImpTrackers];
        [self.viewabilityTimer invalidate];
        self.impressionHasBeenTracked = YES;       
        if(self.impressionType == EPLViewableImpression || ![EPLSDKSettings sharedInstance].enableOMIDOptimization){
            [EPLRealTimer removeDelegate:self];
        }
    }
}

- (void)fireImpTrackers {
   
    if (self.impTrackers) {
        [EPLTrackerManager fireTrackerURLArray:self.impTrackers withBlock:^(BOOL isTrackerFired) {
            if (isTrackerFired) {
                [super adDidLogImpression];
            }
        }];
    }
// OMID is not supported by macOS
#if !APPNEXUS_NATIVE_MACOS_SDK
    if(self.omidAdSession != nil){
        [[EPLOMIDImplementation sharedInstance] fireOMIDImpressionOccuredEvent:self.omidAdSession];
    }
#endif
}

- (void) handle1SecTimerSentNotification {
    [self checkIfViewIs1pxOnScreen];
}




#pragma mark - Click handling

- (void)handleClick
{
    [self fireClickTrackers];

    if (EPLClickThroughActionReturnURL == self.clickThroughAction)
    {
        [self adWasClickedWithURL:[self.clickURL absoluteString] fallbackURL:[self.clickFallbackURL absoluteString]];
        
        EPLLogDebug(@"ClickThroughURL=%@", self.clickURL);
        EPLLogDebug(@"ClickThroughFallbackURL=%@", self.clickFallbackURL);
        return;
    }

    //
    [self adWasClicked];

    if ([self openIntendedBrowserWithURL:self.clickURL])  { return; }
    EPLLogDebug(@"Could not open click URL: %@", self.clickURL);

    if ([self openIntendedBrowserWithURL:self.clickFallbackURL])  { return; }
    EPLLogError(@"Could not open click fallback URL: %@", self.clickFallbackURL);
}

- (BOOL)openIntendedBrowserWithURL:(NSURL *)URL
{
    switch (self.clickThroughAction)
    {
// Open URL in SDK Browser is not supported by macOS, macOS supports ClickThrough as return URL only
#if !APPNEXUS_NATIVE_MACOS_SDK
        case EPLClickThroughActionOpenSDKBrowser:
            // Try to use device browser even if SDK browser was requested in cases
            //   where the structure of the URL cannot be handled by the SDK browser.
            //
            if (!EPLHasHttpPrefix(URL.absoluteString) && !EPLiTunesIDForURL(URL))
            {
                return  [self openURLWithExternalBrowser:URL];
            }

            if (!self.inAppBrowser) {
                self.inAppBrowser = [[EPLBrowserViewController alloc] initWithURL: URL
                                                                        delegate: self
                                                        delayPresentationForLoad: self.landingPageLoadsInBackground ];
            } else {
                self.inAppBrowser.url = URL;
            }
            return  YES;
            break;

        case EPLClickThroughActionOpenDeviceBrowser:
            return  [self openURLWithExternalBrowser:URL];
            break;
#endif
        case EPLClickThroughActionReturnURL:
            //NB -- This case handled by calling method.
            /*NOT REACHED*/

        default:
            EPLLogError(@"UNKNOWN EPLClickThroughAction.  (%lu)", (unsigned long)self.clickThroughAction);
            return  NO;
    }
}

- (BOOL) openURLWithExternalBrowser:(NSURL *)url
{
// Open URL in ExternalBrowser is not supported by macOS, macOS supports ClickThrough as return URL only
#if !APPNEXUS_NATIVE_MACOS_SDK
    if (![[UIApplication sharedApplication] canOpenURL:url])  { return NO; }
    [self willLeaveApplication];
    [EPLGlobal openURL:[url absoluteString]];
#endif

    return  YES;
}


- (void)fireClickTrackers
{
    [EPLTrackerManager fireTrackerURLArray:self.clickTrackers withBlock:nil];
}




#pragma mark - EPLBrowserViewControllerDelegate
// BrowserViewController is not supported by macOS, macOS supports ClickThrough as return URL only
#if !APPNEXUS_NATIVE_MACOS_SDK

- (UIViewController *)rootViewControllerForDisplayingBrowserViewController:(EPLBrowserViewController *)controller {
    return self.rootViewController;
}


- (void)didDismissBrowserViewController:(EPLBrowserViewController *)controller {
    self.inAppBrowser = nil;
    [self didCloseAd];
}

- (void)willPresentBrowserViewController:(EPLBrowserViewController *)controller {
    [self willPresentAd];
}

- (void)didPresentBrowserViewController:(EPLBrowserViewController *)controller {
    [self didPresentAd];
}

- (void)willDismissBrowserViewController:(EPLBrowserViewController *)controller {
    [self willCloseAd];
}


- (void)willLeaveApplicationFromBrowserViewController:(EPLBrowserViewController *)controller {
    [self willLeaveApplication];
}
#endif

- (void)registerAdWillExpire{
    [self registerAdAboutToExpire];
}


@end
