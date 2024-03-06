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

#import "EPLMRAIDContainerView.h"
#import "UIView+EPLCategory.h"
#import "EPLGlobal.h"
#import "EPLMRAIDResizeViewManager.h"
#import "EPLAdViewInternalDelegate.h"
#import "EPLMRAIDCalendarManager.h"
#import "EPLMRAIDExpandViewController.h"
#import "EPLMRAIDExpandProperties.h"
#import "EPLMRAIDOrientationProperties.h"
#import "EPLLogging.h"
#import "EPLBrowserViewController.h"
#import "EPLClickOverlayView.h"
#import "EPLANJAMImplementation.h"
#import "EPLInterstitialAdViewController.h"
#import "EPLOMIDImplementation.h"


static CGFloat const kANOMIDSessionFinishDelay = 0.08f;


typedef NS_OPTIONS(NSUInteger, EPLMRAIDContainerViewAdInteraction)
{
    EPLMRAIDContainerViewAdInteractionExpandedOrResized = 1 << 0,
    EPLMRAIDContainerViewAdInteractionVideo = 1 << 1,
    EPLMRAIDContainerViewAdInteractionBrowser = 1 << 2,
    EPLMRAIDContainerViewAdInteractionCalendar = 1 << 3,
    EPLMRAIDContainerViewAdInteractionPicture = 1 << 4
};




@interface EPLMRAIDContainerView() <   EPLBrowserViewControllerDelegate,

                                      EPLAdWebViewControllerANJAMDelegate,
                                      EPLAdWebViewControllerBrowserDelegate, 
                                      EPLAdWebViewControllerLoadingDelegate,
                                      EPLAdWebViewControllerMRAIDDelegate, 
                                      EPLAdWebViewControllerVideoDelegate,
                                      EPLMRAIDCalendarManagerDelegate, 
                                      EPLMRAIDExpandViewControllerDelegate,
                                      EPLMRAIDResizeViewManagerDelegate
                                  >

@property (nonatomic, readwrite, assign) CGSize size;
@property (nonatomic, readwrite, strong) NSURL *baseURL;

@property (nonatomic, readwrite, strong) EPLAdWebViewController          *webViewController;
@property (nonatomic, readwrite, strong) EPLBrowserViewController        *browserViewController;
@property (nonatomic, readwrite, strong) EPLMRAIDCalendarManager         *calendarManager;
@property (nonatomic, readwrite, strong) EPLMRAIDExpandViewController    *expandController;
@property (nonatomic, readwrite, strong) EPLMRAIDOrientationProperties   *orientationProperties;
@property (nonatomic, readwrite, strong) EPLMRAIDResizeViewManager       *resizeManager;

@property (nonatomic, readwrite, strong)  EPLInterstitialAdViewController  *VASTVideofullScreenController;

@property (nonatomic, readwrite, assign) BOOL useCustomClose;
@property (nonatomic, readwrite, strong) UIButton *customCloseRegion;

@property (nonatomic, readwrite, strong) EPLClickOverlayView *clickOverlay;

@property (nonatomic, readwrite, assign) BOOL adInteractionInProgress;
@property (nonatomic, readwrite, assign) NSUInteger adInteractionValue;

@property (nonatomic, readwrite)                            BOOL  isBannerVideo;
@property (nonatomic, readonly, assign, getter=isExpanded)  BOOL  expanded;
@property (nonatomic, readonly, assign, getter=isResized)   BOOL  resized;
@property (nonatomic, readwrite)                            BOOL  isFullscreen;


@property (nonatomic, readwrite, assign) CGRect lastKnownDefaultPosition;
@property (nonatomic, readwrite, assign) CGRect lastKnownCurrentPosition;

@property (nonatomic, readwrite, strong)  EPLAdWebViewController  *expandWebViewController;

@property (nonatomic, readwrite, assign) BOOL userInteractedWithContentView;

@property (nonatomic, readwrite, assign) BOOL responsiveAd;

@end




@implementation EPLMRAIDContainerView

#pragma mark - Lifecycle.

- (instancetype) initWithSize:(CGSize)size
{
    CGSize   initialSize    = size;
    BOOL     responsiveAd   = NO;

    if (CGSizeEqualToSize(initialSize, CGSizeMake(1, 1))) {
        responsiveAd = YES;
        initialSize = EPLPortraitScreenBounds().size;
    }

    CGRect  initialRect  = CGRectMake(0, 0, initialSize.width, initialSize.height);

    self = [super initWithFrame:initialRect];
    if (!self)  { return nil; }

    //
    _size = size;
    _responsiveAd = responsiveAd;

    _lastKnownCurrentPosition = initialRect;
    _lastKnownDefaultPosition = initialRect;

    _isBannerVideo = NO;

    self.backgroundColor = [UIColor clearColor];

    self.isFullscreen                       = NO;
    
    return self;
}

- (instancetype)initWithSize:(CGSize)size
                        HTML:(NSString *)html
              webViewBaseURL:(NSURL *)baseURL
{
    self = [self initWithSize:size];

    if (self) {
        _baseURL = baseURL;
        self.webViewController = [[EPLAdWebViewController alloc] initWithSize: _lastKnownCurrentPosition.size
                                                                        HTML: html
                                                              webViewBaseURL: baseURL];

        self.webViewController.anjamDelegate    = self;
        self.webViewController.browserDelegate  = self;
        self.webViewController.loadingDelegate  = self;
        self.webViewController.mraidDelegate    = self;
    }

    return self;
}

- (instancetype)initWithSize: (CGSize)size
                    videoXML: (NSString *)videoXML
{
    self = [self initWithSize:size];

    if (!self)  { return nil; }

    self.webViewController = [[EPLAdWebViewController alloc] initWithSize: _lastKnownCurrentPosition.size
                                                                videoXML: videoXML ];

    self.webViewController.anjamDelegate    = self;
    self.webViewController.browserDelegate  = self;
    self.webViewController.loadingDelegate  = self;
    self.webViewController.mraidDelegate    = self;

    self.webViewController.videoDelegate    = self;
    self.isBannerVideo = YES;

    return self;
}


-(void) willMoveToSuperview:(UIView *)newSuperview {
    if(!newSuperview){
        if(self.webViewController.omidAdSession){
            [[EPLOMIDImplementation sharedInstance] stopOMIDAdSession:self.webViewController.omidAdSession];
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (kANOMIDSessionFinishDelay * NSEC_PER_SEC));
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void) {
                [super willMoveToSuperview:newSuperview];
                self.webViewController  = nil;
            });
        }else{
            [super willMoveToSuperview:newSuperview];
            self.webViewController  = nil;
        }
    }
    else{
        [super willMoveToSuperview:newSuperview];
    }
}

#pragma mark - Getters/setters.

- (void)setAdViewDelegate:(id<EPLAdViewInternalDelegate>)adViewDelegate
{
    _adViewDelegate                                     = adViewDelegate;
    self.webViewController.adViewDelegate               = adViewDelegate;
    self.webViewController.adViewANJAMInternalDelegate          = adViewDelegate;
    self.expandWebViewController.adViewDelegate         = adViewDelegate;
    self.expandWebViewController.adViewANJAMInternalDelegate    = adViewDelegate;

    if ([adViewDelegate conformsToProtocol:@protocol(EPLInterstitialAdViewInternalDelegate)])
    {
        id<EPLInterstitialAdViewInternalDelegate>  interstitialDelegate  = (id<EPLInterstitialAdViewInternalDelegate>)adViewDelegate;

        [interstitialDelegate adShouldSetOrientationProperties:self.orientationProperties];
        [interstitialDelegate adShouldUseCustomClose:self.useCustomClose];

        if (self.useCustomClose) {
            [self addSupplementaryCustomCloseRegion];
        }
    }
    
    
    if (self.isBannerVideo && [_adViewDelegate conformsToProtocol:@protocol(EPLBannerAdViewInternalDelegate)])
    {
        id<EPLBannerAdViewInternalDelegate>  bannerDelegate  = (id<EPLBannerAdViewInternalDelegate>)_adViewDelegate;
        
        UIView  *contentView = self.webViewController.contentView;
        CGSize   newPlayerSize    = kANAdSize1x1;
        switch (self.webViewController.videoAdOrientation){
            case EPLPortrait:
                newPlayerSize = bannerDelegate.portraitBannerVideoPlayerSize;
                break;
            case EPLSquare:
                newPlayerSize = bannerDelegate.squareBannerVideoPlayerSize;
                break;
            case EPLLandscape:
            case EPLUnknown:
                newPlayerSize = bannerDelegate.landscapeBannerVideoPlayerSize;
                break;
        }
        
        if (!CGSizeEqualToSize(newPlayerSize, CGSizeMake(1, 1))) {
            self.webViewController.videoPlayerSize = newPlayerSize;
            CGRect  updatedRect  = CGRectMake(0, 0, newPlayerSize.width, newPlayerSize.height);
            [self setFrame:updatedRect];
            
            contentView.translatesAutoresizingMaskIntoConstraints = NO;
            [contentView an_constrainToSizeOfSuperview];
            [contentView an_alignToSuperviewWithXAttribute:NSLayoutAttributeLeft
                                                                       yAttribute:NSLayoutAttributeTop];
        }
    }
}

- (void)setAdInteractionInProgress:(BOOL)adInteractionInProgress {
    BOOL oldValue = _adInteractionInProgress;
    _adInteractionInProgress = adInteractionInProgress;
    BOOL newValue = _adInteractionInProgress;
    if (oldValue != newValue) {
        if (_adInteractionInProgress) {
            [self.adViewDelegate adInteractionDidBegin];
        } else {
            [self.adViewDelegate adInteractionDidEnd];
        }
    }
}

#pragma mark - Helper methods.

- (UIViewController *)displayController {
    
    UIViewController *presentingVC = nil;
    
    if(self.isExpanded){
        presentingVC = self.expandController;
    } else if(self.isFullscreen){
        presentingVC = self.VASTVideofullScreenController;
    } else {
        presentingVC = [self.adViewDelegate displayController];
    }
    
    if (EPLCanPresentFromViewController(presentingVC)) {
        return presentingVC;
    }
    return nil;
}

- (void)adInteractionBeganWithInteraction:(EPLMRAIDContainerViewAdInteraction)interaction {
    self.adInteractionValue = self.adInteractionValue | interaction;
    self.adInteractionInProgress = self.adInteractionValue != 0;
}

- (void)adInteractionEndedForInteraction:(EPLMRAIDContainerViewAdInteraction)interaction {
    self.adInteractionValue = self.adInteractionValue & ~interaction;
    self.adInteractionInProgress = self.adInteractionValue != 0;
}


#pragma mark - User Interaction Testing

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *viewThatWasHit = [super hitTest:point withEvent:event];
    if (!self.userInteractedWithContentView && [viewThatWasHit isDescendantOfView:self.webViewController.contentView]) {
        EPLLogDebug(@"Detected user interaction with ad");
        self.userInteractedWithContentView = YES;
    }
    return viewThatWasHit;
}


#pragma mark - EPLBrowserViewControllerDelegate

- (UIViewController *)rootViewControllerForDisplayingBrowserViewController:(EPLBrowserViewController *)controller
{
    return [self displayController];
}

- (void) browserViewController: (EPLBrowserViewController *)controller
              browserIsLoading: (BOOL)isLoading
{
    if ([self.adViewDelegate landingPageLoadsInBackground]) {
        if (!controller.completedInitialLoad) {
            isLoading ? [self showClickOverlay] : [self hideClickOverlay];
        } else {
            [self hideClickOverlay];
        }
    }
}

- (void) browserViewController: (EPLBrowserViewController *)controller
      couldNotHandleInitialURL: (NSURL *)url
{
    [self adInteractionEndedForInteraction:EPLMRAIDContainerViewAdInteractionBrowser];
}

- (void)handleBrowserLoadingForMRAIDStateChange
{
    [self.browserViewController stopLoading];
    [self adInteractionEndedForInteraction:EPLMRAIDContainerViewAdInteractionBrowser];
}

- (void)willPresentBrowserViewController:(EPLBrowserViewController *)controller
{
    if (!self.embeddedInModalView && !self.isExpanded) {
        [self.adViewDelegate adWillPresent];
    }
    self.resizeManager.resizeView.hidden = YES;
    [self adInteractionBeganWithInteraction:EPLMRAIDContainerViewAdInteractionBrowser];
}

- (void)didPresentBrowserViewController:(EPLBrowserViewController *)controller
{
    if (!self.embeddedInModalView && !self.isExpanded) {
        [self.adViewDelegate adDidPresent];

        
    }
}

- (void)willDismissBrowserViewController:(EPLBrowserViewController *)controller
{
    if (!self.embeddedInModalView && !self.isExpanded)
    {
        [self.adViewDelegate adWillClose];
    }

    if (self.shouldDismissOnClick) {
        [controller dismissViewControllerAnimated:NO completion:nil];
    }

    self.resizeManager.resizeView.hidden = NO;
}

- (void)didDismissBrowserViewController:(EPLBrowserViewController *)controller
{
    self.browserViewController = nil;

    if (!self.embeddedInModalView && !self.isExpanded) {
        [self.adViewDelegate adDidClose];
    }

    [self hideClickOverlay];
    [self adInteractionEndedForInteraction:EPLMRAIDContainerViewAdInteractionBrowser];
}

- (void)willLeaveApplicationFromBrowserViewController:(EPLBrowserViewController *)controller {
    [self.adViewDelegate adWillLeaveApplication];
}

# pragma mark - Click overlay

- (void)showClickOverlay {
    if (!self.clickOverlay.superview) {
        self.clickOverlay = [EPLClickOverlayView addOverlayToView:[self viewToDisplayClickOverlay]];
        self.clickOverlay.alpha = 0.0;
    }

    if (!CGAffineTransformIsIdentity(self.transform)) {
        // In the case that EPLMRAIDContainerView is magnified it is necessary to invert this magnification for the click overlay
        self.clickOverlay.transform = CGAffineTransformInvert(self.transform);
    }

    self.clickOverlay.hidden = NO;

    [UIView animateWithDuration:0.5
                     animations:^{
                         self.clickOverlay.alpha = 1.0;
                     }];
}

- (UIView *)viewToDisplayClickOverlay {
    if (self.isExpanded) {
        return self.expandController.view;
    } else if(self.isFullscreen){
        return self.VASTVideofullScreenController.view;
    }
    else if (self.isResized) {
        return self.resizeManager.resizeView;
    } else {
        return self;
    }
}

- (void)hideClickOverlay {
    if ([self.clickOverlay superview]) {
        [UIView animateWithDuration:0.5
                         animations:^{
                             self.clickOverlay.alpha = 0.0;
                         } completion:^(BOOL finished) {
                             self.clickOverlay.hidden = YES;
                         }];
    }
}




#pragma mark - EPLWebViewControllerANJAMDelegate

- (void) handleANJAMURL:(NSURL *)URL
{
    [EPLANJAMImplementation handleURL:URL withWebViewController:self.webViewController];
}




#pragma mark - EPLWebViewControllerBrowserDelegate

- (void)openDefaultBrowserWithURL:(NSURL *)URL
{
    if (!self.adViewDelegate) {
        EPLLogDebug(@"Ignoring attempt to trigger browser on ad while not attached to a view.");
        return;
    }
    if (!self.userInteractedWithContentView) {
        EPLLogDebug(@"Ignoring attempt to trigger browser as no hit was registered on the ad");
        return;
    }

    if (EPLClickThroughActionReturnURL != [self.adViewDelegate clickThroughAction]) {
        [self.adViewDelegate adWasClicked];
    }

    switch ([self.adViewDelegate clickThroughAction])
    {
        case EPLClickThroughActionReturnURL:
            [self.webViewController updateViewability:[self isViewable]];
            [self.adViewDelegate adWasClickedWithURL:[URL absoluteString]];

            EPLLogDebug(@"ClickThroughURL=%@", URL);
            break;

        case EPLClickThroughActionOpenDeviceBrowser:
            if ([[UIApplication sharedApplication] canOpenURL:URL]) {
                [self.adViewDelegate adWillLeaveApplication];
                [EPLGlobal openURL:[URL absoluteString]];

            } else {
                EPLLogWarn(@"opening_url_failed %@", URL);
            }

            break;

        case EPLClickThroughActionOpenSDKBrowser:
            [self openInAppBrowserWithURL:URL];
            break;

        default:
            EPLLogError(@"UNKNOWN EPLClickThroughAction.  (%lu)", (unsigned long)[self.adViewDelegate clickThroughAction]);
    }
}

- (void)openInAppBrowserWithURL:(NSURL *)URL {
    if (!self.userInteractedWithContentView) {
        EPLLogDebug(@"Ignoring attempt to trigger browser as no hit was registered on the ad");
        return;
    }

    [self adInteractionBeganWithInteraction:EPLMRAIDContainerViewAdInteractionBrowser];
    if (!self.browserViewController) {
        self.browserViewController = [[EPLBrowserViewController alloc] initWithURL:URL
                                                                         delegate:self
                                                         delayPresentationForLoad:[self.adViewDelegate landingPageLoadsInBackground]];
        if (!self.browserViewController) {
            EPLLogError(@"Browser controller did not instantiate correctly.");
            return;
        }
    } else {
        self.browserViewController.url = URL;
    }
}

#pragma mark - EPLAdWebViewControllerLoadingDelegate

- (void)didCompleteFirstLoadFromWebViewController:(EPLAdWebViewController *)controller
{
    if (controller == self.webViewController)
    {
        // Attaching WKWebView to screen for an instant to allow it to fully load in the background
        //   before the call to [EPLAdDelegate adDidReceiveAd:self].
        //
        // NB  For banner video, this step has already occured in [EPLAdViewWebController initWithSize:videoXML:].
        //
        if (! self.isBannerVideo) {
            self.webViewController.contentView.hidden = YES;
            [[EPLGlobal getKeyWindow] insertSubview:self.webViewController.contentView
                                                               atIndex:0];
        }

        __weak EPLMRAIDContainerView  *weakSelf  = self;

        dispatch_async(dispatch_get_main_queue(),
        ^{
            __strong EPLMRAIDContainerView  *strongSelf  = weakSelf;

            if (!strongSelf)  {
                EPLLogError(@"COULD NOT ACQUIRE strongSelf.");
                return;
            }

            UIView  *contentView  = strongSelf.webViewController.contentView;

            contentView.translatesAutoresizingMaskIntoConstraints = NO;

            [strongSelf addSubview:contentView];
            strongSelf.webViewController.contentView.hidden = NO;
            
            [contentView an_constrainToSizeOfSuperview];
            [contentView an_alignToSuperviewWithXAttribute:NSLayoutAttributeLeft
                                                yAttribute:NSLayoutAttributeTop];

            [strongSelf.loadingDelegate didCompleteFirstLoadFromWebViewController:controller];
        });
    }
}

- (void) immediatelyRestartAutoRefreshTimerFromWebViewController:(EPLAdWebViewController *)controller
{
    if ([self.loadingDelegate respondsToSelector:@selector(immediatelyRestartAutoRefreshTimerFromWebViewController:)]) {
        [self.loadingDelegate immediatelyRestartAutoRefreshTimerFromWebViewController:controller];
    }
}

- (void) stopAutoRefreshTimerFromWebViewController:(EPLAdWebViewController *)controller
{
    if ([self.loadingDelegate respondsToSelector:@selector(stopAutoRefreshTimerFromWebViewController:)]) {
        [self.loadingDelegate stopAutoRefreshTimerFromWebViewController:controller];
    }
}




#pragma mark - EPLAdWebViewControllerMRAIDDelegate

- (CGRect)defaultPosition {
    if (self.window) {
        CGRect absoluteContentViewFrame = [self convertRect:self.bounds toView:nil];
        CGRect position = EPLAdjustAbsoluteRectInWindowCoordinatesForOrientationGivenRect(absoluteContentViewFrame);
        if (!CGAffineTransformIsIdentity(self.transform)) {
            // In the case of a magnified webview, need to pass the non-magnified size to the webview
            position.size = [self an_originalFrame].size;
        }
        self.lastKnownDefaultPosition = position;
        return position;
    } else {
        return self.lastKnownDefaultPosition;
    }
}

- (CGRect)currentPosition {
    UIView *contentView = self.webViewController.contentView;
    if (self.expandWebViewController.contentView.window) {
        contentView = self.expandWebViewController.contentView;
    }
    
    if (contentView) {
        CGRect absoluteContentViewFrame = [contentView convertRect:contentView.bounds toView:nil];
        CGRect position = EPLAdjustAbsoluteRectInWindowCoordinatesForOrientationGivenRect(absoluteContentViewFrame);
        if (!CGAffineTransformIsIdentity(self.transform)) {
            // In the case of a magnified webview, need to pass the non-magnified size to the webview
            position.size = [contentView an_originalFrame].size;
        }
        self.lastKnownCurrentPosition = position;
        return position;
    } else {
        return self.lastKnownCurrentPosition;
    }
}

- (BOOL)isViewable {
    if (self.isBannerVideo) {
        return  [self.webViewController.contentView an_isAtLeastHalfViewable];

    } else {
        return  self.expandWebViewController    ? [self.expandWebViewController.contentView an_isViewable]
                                                : [self.webViewController.contentView an_isViewable];
    }
}

- (CGFloat)exposedPercent{
    return self.expandWebViewController    ? [self.expandWebViewController.contentView an_exposedPercentage]
                                           : [self.webViewController.contentView an_exposedPercentage];
    
}
- (CGRect)visibleRect{
    return self.expandWebViewController    ? [self.expandWebViewController.contentView an_visibleRectangle]
                                           : [self.webViewController.contentView an_visibleRectangle];
}

- (void)adShouldExpandWithExpandProperties:(EPLMRAIDExpandProperties *)expandProperties {
    UIViewController *presentingController = [self displayController];
    if (!presentingController) {
        EPLLogDebug(@"Ignoring call to mraid.expand() - no root view controller to present from");
        return;
    }
    if (!self.userInteractedWithContentView) {
        EPLLogDebug(@"Ignoring attempt to expand ad as no hit was detected on ad");
        return;
    }
    
    [self handleBrowserLoadingForMRAIDStateChange];
    [self adInteractionBeganWithInteraction:EPLMRAIDContainerViewAdInteractionExpandedOrResized];
    
    EPLLogDebug(@"Expanding with expand properties: %@", [expandProperties description]);
    [self.adViewDelegate adWillPresent];
    if (self.isResized) {
        [self.resizeManager detachResizeView];
        self.resizeManager = nil;
    }
    
    UIView *expandContentView = self.webViewController.contentView;

    BOOL presentWithAnimation = NO;
    
    if (expandProperties.URL.absoluteString.length)
    {
        EPLAdWebViewControllerConfiguration *customConfig = [[EPLAdWebViewControllerConfiguration alloc] init];

        customConfig.scrollingEnabled = YES;
        customConfig.navigationTriggersDefaultBrowser = NO;
        customConfig.initialMRAIDState = EPLMRAIDStateExpanded;
        customConfig.userSelectionEnabled = YES;

        self.expandWebViewController = [[EPLAdWebViewController alloc] initWithSize: [EPLMRAIDUtil screenSize]
                                                                               URL: expandProperties.URL
                                                                    webViewBaseURL: self.baseURL
                                                                     configuration: customConfig];
        self.expandWebViewController.mraidDelegate = self;
        self.expandWebViewController.browserDelegate = self;
        self.expandWebViewController.anjamDelegate = self;
        self.expandWebViewController.adViewDelegate = self.adViewDelegate;

        expandContentView = self.expandWebViewController.contentView;
        presentWithAnimation = YES;
    }
    
    self.expandController = [[EPLMRAIDExpandViewController alloc] initWithContentView:expandContentView
                                                                    expandProperties:expandProperties];
    if (self.orientationProperties) {
        [self adShouldSetOrientationProperties:self.orientationProperties];
    }
    [self.expandController setModalPresentationStyle:UIModalPresentationFullScreen];
    self.expandController.delegate = self;
    [presentingController presentViewController: self.expandController
                                       animated: presentWithAnimation
                                     completion: ^{
                                             [self.adViewDelegate adDidPresent];
                                             [self.webViewController adDidFinishExpand];
                                         }
     ];
}

- (void)adShouldSetOrientationProperties:(EPLMRAIDOrientationProperties *)orientationProperties {
    EPLLogDebug(@"Setting orientation properties: %@", [orientationProperties description]);
    self.orientationProperties = orientationProperties;
    if (self.expandController) {
        self.expandController.orientationProperties = orientationProperties;
    } else if ([self.adViewDelegate conformsToProtocol:@protocol(EPLInterstitialAdViewInternalDelegate)]) {
        id<EPLInterstitialAdViewInternalDelegate> interstitialDelegate = (id<EPLInterstitialAdViewInternalDelegate>)self.adViewDelegate;
        [interstitialDelegate adShouldSetOrientationProperties:orientationProperties];
    }
}

- (void)adShouldSetUseCustomClose:(BOOL)useCustomClose {
    EPLLogDebug(@"Setting useCustomClose: %d", useCustomClose);
    self.useCustomClose = useCustomClose;
    if ([self.adViewDelegate conformsToProtocol:@protocol(EPLInterstitialAdViewInternalDelegate)]) {
        id<EPLInterstitialAdViewInternalDelegate> interstitialDelegate = (id<EPLInterstitialAdViewInternalDelegate>)self.adViewDelegate;
        [interstitialDelegate adShouldUseCustomClose:useCustomClose];
        if (useCustomClose) {
            [self addSupplementaryCustomCloseRegion];
        }
    }
}

- (void)addSupplementaryCustomCloseRegion
{
    self.customCloseRegion = [UIButton buttonWithType:UIButtonTypeCustom];
    self.customCloseRegion.translatesAutoresizingMaskIntoConstraints = NO;

    [self insertSubview:self.customCloseRegion
           aboveSubview:self.webViewController.contentView];

    [self.customCloseRegion an_constrainWithSize:CGSizeMake(50.0, 50.0)];
    [self.customCloseRegion an_alignToSuperviewWithXAttribute:NSLayoutAttributeRight
                                                   yAttribute:NSLayoutAttributeTop];

    [self.customCloseRegion addTarget: self
                               action: @selector(closeInterstitial:)
                     forControlEvents: UIControlEventTouchUpInside];
}

- (void)closeInterstitial:(id)sender {
    if ([self.adViewDelegate conformsToProtocol:@protocol(EPLInterstitialAdViewInternalDelegate)]) {
        id<EPLInterstitialAdViewInternalDelegate> interstitialDelegate = (id<EPLInterstitialAdViewInternalDelegate>)self.adViewDelegate;
        [interstitialDelegate adShouldClose];
    }
}

- (void)adShouldAttemptResizeWithResizeProperties:(EPLMRAIDResizeProperties *)resizeProperties {
    if (!self.userInteractedWithContentView) {
        EPLLogDebug(@"Ignoring attempt to resize ad as no hit was detected on ad");
        return;
    }

    EPLLogDebug(@"Attempting resize with resize properties: %@", [resizeProperties description]);
    [self handleBrowserLoadingForMRAIDStateChange];
    [self adInteractionBeganWithInteraction:EPLMRAIDContainerViewAdInteractionExpandedOrResized];
    
    if (!self.resizeManager) {
        self.resizeManager = [[EPLMRAIDResizeViewManager alloc] initWithContentView:self.webViewController.contentView
                                                                        anchorView:self];
        self.resizeManager.delegate = self;
    }
    
    NSString *errorString;
    BOOL resizeHappened = [self.resizeManager attemptResizeWithResizeProperties:resizeProperties
                                                                    errorString:&errorString];
    [self.webViewController adDidFinishResize:resizeHappened
                                  errorString:errorString
                                    isResized:self.isResized];
    if (!self.isResized) {
        [self adInteractionEndedForInteraction:EPLMRAIDContainerViewAdInteractionExpandedOrResized];
    }
}

- (void)adShouldClose {
    if (self.isResized || self.isExpanded) {
        [self adShouldResetToDefault];
    } else {
        [self adShouldHide];
    }
    
    [self adInteractionEndedForInteraction:EPLMRAIDContainerViewAdInteractionExpandedOrResized];
}

- (void)adShouldResetToDefault {
    [self.resizeManager detachResizeView];
    self.resizeManager = nil;

    [self handleBrowserLoadingForMRAIDStateChange];
    
    if (self.isExpanded) {
        [self.adViewDelegate adWillClose];
        
        BOOL dismissWithAnimation = NO;
        UIView *detachedContentView = [self.expandController detachContentView];
        if (detachedContentView == self.expandWebViewController.contentView) {
            dismissWithAnimation = YES;
        }
        
        [self.expandController dismissViewControllerAnimated:dismissWithAnimation
                                                  completion:^{
                                                      [self.adViewDelegate adDidClose];
                                                  }];
        self.expandController = nil;
    }
    
    self.expandWebViewController = nil;

    UIView *contentView = self.webViewController.contentView;
    if (contentView.superview != self) {
        [self addSubview:contentView];
        [contentView removeConstraints:contentView.constraints];
        [contentView an_constrainToSizeOfSuperview];
        [contentView an_alignToSuperviewWithXAttribute:NSLayoutAttributeLeft
                                            yAttribute:NSLayoutAttributeTop];
    }

    [self.webViewController adDidResetToDefault];
    [self adInteractionEndedForInteraction:EPLMRAIDContainerViewAdInteractionExpandedOrResized];
}

- (void)adShouldHide {
    [self handleBrowserLoadingForMRAIDStateChange];
    
    if (self.embeddedInModalView && [self.adViewDelegate conformsToProtocol:@protocol(EPLInterstitialAdViewInternalDelegate)]) {
        id<EPLInterstitialAdViewInternalDelegate> interstitialDelegate = (id<EPLInterstitialAdViewInternalDelegate>)self.adViewDelegate;
        [interstitialDelegate adShouldClose];
        
    } else {
        [UIView animateWithDuration:kAppNexusAnimationDuration
                         animations:^{
                             self.webViewController.contentView.alpha = 0.0f;
                         } completion:^(BOOL finished) {
                             self.webViewController.contentView.hidden = YES;
                         }];
        [self.webViewController adDidHide];
    }
    [self adInteractionEndedForInteraction:EPLMRAIDContainerViewAdInteractionExpandedOrResized];
}

- (void)adShouldOpenCalendarWithCalendarDict:(NSDictionary *)calendarDict {
    if (!self.userInteractedWithContentView) {
        EPLLogDebug(@"Ignoring attempt to open calendar as no hit was detected on ad");
        return;
    }
    
    [self adInteractionBeganWithInteraction:EPLMRAIDContainerViewAdInteractionCalendar];
    self.calendarManager = [[EPLMRAIDCalendarManager alloc] initWithCalendarDictionary:calendarDict
                                                                        delegate:self];
}

- (void)adShouldSavePictureWithUri:(NSString *)uri {
    if (!self.userInteractedWithContentView) {
        EPLLogDebug(@"Ignoring attempt to save picture as no hit was detected on ad");
        return;
    }
    
    [self adInteractionBeganWithInteraction:EPLMRAIDContainerViewAdInteractionPicture];
    [EPLMRAIDUtil storePictureWithUri:uri
                withCompletionTarget:self
                  completionSelector:@selector(image:didFinishSavingWithError:contextInfo:)];
}

- (void)                image: (UIImage *)image
     didFinishSavingWithError: (NSError *)error
                  contextInfo: (void *)contextInfo
{
    if (error) {
        [self.webViewController adDidFailPhotoSaveWithErrorString:error.localizedDescription];
        [self.expandWebViewController adDidFailPhotoSaveWithErrorString:error.localizedDescription];
    }
    [self adInteractionEndedForInteraction:EPLMRAIDContainerViewAdInteractionPicture];
}

- (void)adShouldPlayVideoWithUri:(NSString *)uri {
    UIViewController *presentingViewController = [self displayController];
    if (!presentingViewController) {
        EPLLogDebug(@"Ignoring call to mraid.playVideo() - no root view controller to present from");
        return;
    }
    if (!self.userInteractedWithContentView) {
        EPLLogDebug(@"Ignoring attempt to play video as no hit was detected on ad");
        return;
    }
    
    [self adInteractionBeganWithInteraction:EPLMRAIDContainerViewAdInteractionVideo];
    self.resizeManager.resizeView.hidden = YES;
    [EPLMRAIDUtil playVideoWithUri:uri
           fromRootViewController:presentingViewController
             withCompletionTarget:self
               completionSelector:@selector(moviePlayerDidFinish:)];
}

- (void)moviePlayerDidFinish:(NSNotification *)notification {
    self.resizeManager.resizeView.hidden = NO;
    [self adInteractionEndedForInteraction:EPLMRAIDContainerViewAdInteractionVideo];
}

- (BOOL)isExpanded {
    return self.expandController.presentingViewController ? YES : NO;
}

- (BOOL)isResized {
    return self.resizeManager.isResized;
}




#pragma mark - UIView observer methods.

- (void)didMoveToWindow {
    [self.resizeManager didMoveAnchorViewToWindow];
}


#pragma mark - EPLMRAIDCalendarManagerDelegate

- (UIViewController *)rootViewControllerForPresentationForCalendarManager:(EPLMRAIDCalendarManager *)calendarManager {
    return [self displayController];
}

- (void)willDismissCalendarEditForCalendarManager:(EPLMRAIDCalendarManager *)calendarManager {
    if (!self.embeddedInModalView && !self.isExpanded) {
        [self.adViewDelegate adWillClose];
    }
    self.resizeManager.resizeView.hidden = NO;
}

- (void)didDismissCalendarEditForCalendarManager:(EPLMRAIDCalendarManager *)calendarManager {
    if (!self.embeddedInModalView && !self.isExpanded) {
        [self.adViewDelegate adDidClose];
    }
    [self adInteractionEndedForInteraction:EPLMRAIDContainerViewAdInteractionCalendar];
}

- (void)willPresentCalendarEditForCalendarManager:(EPLMRAIDCalendarManager *)calendarManager {
    if (!self.embeddedInModalView && !self.isExpanded) {
        [self.adViewDelegate adWillPresent];
    }
    self.resizeManager.resizeView.hidden = YES;
}

- (void)didPresentCalendarEditForCalendarManager:(EPLMRAIDCalendarManager *)calendarManager {
    if (!self.embeddedInModalView && !self.isExpanded) {
        [self.adViewDelegate adDidPresent];
    }
}

- (void)calendarManager:(EPLMRAIDCalendarManager *)calendarManager calendarEditFailedWithErrorString:(NSString *)errorString {
    [self.webViewController adDidFailCalendarEditWithErrorString:errorString];
    [self.expandWebViewController adDidFailPhotoSaveWithErrorString:errorString];
    [self adInteractionEndedForInteraction:EPLMRAIDContainerViewAdInteractionCalendar];
}




#pragma mark - EPLMRAIDExpandViewControllerDelegate

- (void)closeButtonWasTappedOnExpandViewController:(EPLMRAIDExpandViewController *)controller {
    [self adShouldResetToDefault];
}

- (void)dismissAndPresentAgainForPreferredInterfaceOrientationChange
{
    __weak EPLMRAIDContainerView     *weakSelf                   = self;
    UIViewController                *presentingViewController   = self.expandController.presentingViewController;

    [presentingViewController dismissViewControllerAnimated: NO
                                                 completion: ^{
                                                     EPLMRAIDContainerView  *strongSelf  = weakSelf;
                                                     if (!strongSelf)  {
                                                         EPLLogError(@"COULD NOT ACQUIRE strongSelf.");
                                                         return;
                                                     }
                                                    [strongSelf.expandController setModalPresentationStyle:UIModalPresentationFullScreen];

                                                     [presentingViewController presentViewController: strongSelf.expandController
                                                                                            animated: NO
                                                                                          completion: nil];
                                                 } ];
}


#pragma mark - EPLMRAIDResizeViewManagerDelegate

- (void)resizeViewClosedByResizeViewManager:(EPLMRAIDResizeViewManager *)manager {
    [self adShouldResetToDefault];
}


#pragma mark - EPLAdWebViewControllerVideoDelegate.

// NB  self.webViewController embeds its contentView into self.contentViewContainer.
//     VAST fullscreen option is implemented by changing the frame size of self.contentViewContainer.
//
- (void)videoAdReady
{
    [self didCompleteFirstLoadFromWebViewController:self.webViewController];
}

- (void)videoAdLoadFailed:(NSError *)error withAdResponseInfo:(EPLAdResponseInfo *)adResponseInfo
{
    if ([self.adViewDelegate respondsToSelector:@selector(adRequestFailedWithError:andAdResponseInfo:)]) {
        [self.adViewDelegate adRequestFailedWithError:error andAdResponseInfo:adResponseInfo];
    }
}

- (void) videoAdError:(NSError *)error
{
    NSString  *errorString  = [NSString stringWithFormat:@"NSError: code=%@ domain=%@ userInfo=%@", @(error.code), error.domain, error.userInfo];
    EPLLogError(@"%@", errorString);
}

- (void) videoAdPlayerFullScreenEntered: (EPLAdWebViewController *)videoAd
{
    UIViewController *presentingController = [self displayController];
    if (!presentingController) {
        EPLLogDebug(@"Ignoring call to mraid.expand() - no root view controller to present from");
        return;
    }
    self.VASTVideofullScreenController           = [[EPLInterstitialAdViewController alloc] init];
    self.VASTVideofullScreenController.needCloseButton = false;
    self.VASTVideofullScreenController.contentView = videoAd.contentView;
    [self.VASTVideofullScreenController setModalPresentationStyle:UIModalPresentationFullScreen];
    if (self.backgroundColor) {
        self.VASTVideofullScreenController.backgroundColor = self.backgroundColor;
    }
    [presentingController presentViewController: self.VASTVideofullScreenController
                                       animated: NO
                                     completion:nil
     ];
    
    self.isFullscreen = YES;
    
}

- (void) videoAdPlayerFullScreenExited: (EPLAdWebViewController *)videoAd
{
    UIView  *contentView  = videoAd.contentView;
                       
    contentView.translatesAutoresizingMaskIntoConstraints = NO;
                       
    [self addSubview:contentView];
    
    [contentView an_constrainToSizeOfSuperview];
    [contentView an_alignToSuperviewWithXAttribute:NSLayoutAttributeLeft
                                                           yAttribute:NSLayoutAttributeTop];
    
    [self.VASTVideofullScreenController.presentingViewController dismissViewControllerAnimated:NO completion:nil];
    self.VASTVideofullScreenController = nil;
    self.isFullscreen = NO;
}


@end
