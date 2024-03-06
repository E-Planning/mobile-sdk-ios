/*   Copyright 2018-2019 APPNEXUS INC
 
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

#import "EPLNativeRenderingViewController.h"
#import "EPLRTBNativeAdResponse.h"
#import "EPLSDKSettings+PrivateMethods.h"
#import "EPLNativeAdResponse+PrivateMethods.h"
#import "UIView+EPLCategory.h"
#import "EPLGlobal.h"
#import "EPLLogging.h"
#import "EPLBrowserViewController.h"
#import "EPLAdViewInternalDelegate.h"
#import "EPLClickOverlayView.h"
#import "EPLWebView.h"

static NSString *const kANNativeResponseObject= @"EPL_NATIVE_RENDERING_OBJECT";
static NSString *const kANNativeRenderingURL = @"EPL_NATIVE_RENDERING_URL";
static NSString *const kANativeRenderingInvalidURL = @"invalidRenderingURL";
static NSString *const kANativeRenderingValidURL = @"validRenderingURL";

@interface EPLNativeRenderingViewController()<WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler , EPLBrowserViewControllerDelegate>
@property (nonatomic, readwrite, strong)    EPLWebView      *webView;

@property (nonatomic, readwrite, strong)    UIView      *contentView;
@property (nonatomic, readwrite) BOOL isAdLoaded;
@property (nonatomic, readwrite, assign)  BOOL  completedFirstLoad;
@property (nonatomic, readwrite, strong) EPLBrowserViewController        *browserViewController;
@property (nonatomic, readwrite, strong) EPLClickOverlayView *clickOverlay;


@end

@implementation EPLNativeRenderingViewController

- (instancetype)initWithSize:(CGSize)size
                  BaseObject:(id)baseObject
{
    CGRect  initialRect  = CGRectMake(0, 0, size.width, size.height);
    self = [super initWithFrame:initialRect];
    if (!self)  { return nil; }
    self.backgroundColor = [UIColor clearColor];

    if([baseObject isKindOfClass:[EPLRTBNativeAdResponse class]]) {
        [self setUpNativeRenderingContentWithSize:size BaseObject:baseObject];
    }
    return self;
}

- (void)setUpNativeRenderingContentWithSize:(CGSize)size
                                BaseObject:(id)baseObject
{
    
    
    EPLRTBNativeAdResponse *baseAd = (EPLRTBNativeAdResponse *)baseObject;
    
    NSURL     *nativeRenderingUrl   = [[[EPLSDKSettings sharedInstance] baseUrlConfig] nativeRenderingUrl];
    NSString  *renderNativeAssetsHTML  = [NSString stringWithContentsOfURL: nativeRenderingUrl
                                                                  encoding: NSUTF8StringEncoding
                                                                     error: nil ];
    
    renderNativeAssetsHTML = [renderNativeAssetsHTML stringByReplacingOccurrencesOfString: kANNativeResponseObject
                                                                               withString: baseAd.nativeAdResponse.nativeRenderingObject];
    
    renderNativeAssetsHTML = [renderNativeAssetsHTML stringByReplacingOccurrencesOfString: kANNativeRenderingURL
                                                                               withString: baseAd.nativeAdResponse.nativeRenderingUrl];
    
    renderNativeAssetsHTML = [renderNativeAssetsHTML stringByReplacingOccurrencesOfString: kANativeRenderingValidURL withString: kANativeRenderingValidURL];
    
    renderNativeAssetsHTML = [renderNativeAssetsHTML stringByReplacingOccurrencesOfString: kANativeRenderingInvalidURL withString: kANativeRenderingInvalidURL];
    
     [self initANWebViewWithSize:size
                         HTML:renderNativeAssetsHTML];
}

- (void)initANWebViewWithSize:(CGSize)size
                        HTML:(NSString *)html
{
    NSURL  *base;
    
    if (!base) {
        base = [NSURL URLWithString:[[[EPLSDKSettings sharedInstance] baseUrlConfig] webViewBaseUrl]];
    }
    
    _webView = [[EPLWebView alloc] initWithSize:size content:html baseURL:base isNativeRenderingAd:YES];
    
   // [_webView loadWithSize:size content:html baseURL:base];
    
    [self configureWebView];
}


-(void) configureWebView {

    // This is required to avoid the crash :- "Attempt to add script message handler with name '' when one already exists."
    [self.webView.configuration.userContentController removeScriptMessageHandlerForName:@"rendererOp"];
    [self.webView.configuration.userContentController addScriptMessageHandler:self name:@"rendererOp"];
    
    self.webView.scrollView.scrollEnabled = NO;
    self.webView.scrollView.bounces = NO;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self.webView
                                                    name:UIKeyboardWillChangeFrameNotification
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self.webView
                                                    name:UIKeyboardDidChangeFrameNotification
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self.webView
                                                    name:UIKeyboardWillShowNotification
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self.webView
                                                    name:UIKeyboardWillHideNotification
                                                  object:nil];

    [self.webView setNavigationDelegate:self];
    [self.webView setUIDelegate:self];
    
    self.contentView = self.webView;
    
}
- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
    [self processWebViewDidFinishLoad];
}



- (void)                    webView: (WKWebView *)webView
    decidePolicyForNavigationAction: (WKNavigationAction *)navigationAction
                    decisionHandler: (void (^)(WKNavigationActionPolicy))decisionHandler
{
    NSURL *URL = navigationAction.request.URL;
    NSURL *mainDocumentURL = navigationAction.request.mainDocumentURL;
    NSString *URLScheme = URL.scheme;
    
    EPLLogDebug(@"Loading URL: %@", [[URL absoluteString] stringByRemovingPercentEncoding]);
    
    if (self.completedFirstLoad) {
        if (EPLHasHttpPrefix(URLScheme)) {
           
                if (([[mainDocumentURL absoluteString] isEqualToString:[URL absoluteString]]
                     || navigationAction.navigationType == WKNavigationTypeLinkActivated
                     || navigationAction.targetFrame == nil)) {
                    [self openDefaultBrowserWithURL:URL];
                    decisionHandler(WKNavigationActionPolicyCancel);
                    return;
                }
        }else {
                [self openDefaultBrowserWithURL:URL];
                decisionHandler(WKNavigationActionPolicyCancel);
                return;
        }
    }
    decisionHandler(WKNavigationActionPolicyAllow);
}



- (void)openDefaultBrowserWithURL:(NSURL *)URL
{
    if (!self.adViewDelegate) {
        EPLLogDebug(@"Ignoring attempt to trigger browser on ad while not attached to a view.");
        return;
    }

    if (EPLClickThroughActionReturnURL != [self.adViewDelegate clickThroughAction]) {
        [self.adViewDelegate adWasClicked];
    }
    
    switch ([self.adViewDelegate clickThroughAction])
    {
        case EPLClickThroughActionReturnURL:
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

-(void)setAdViewDelegate:(id<EPLAdViewInternalDelegate>)adViewDelegate{
    _adViewDelegate = adViewDelegate;
}


#pragma mark - EPLAdWebViewControllerLoadingDelegate

- (void)processWebViewDidFinishLoad
{
    if(!self.completedFirstLoad) {
        self.completedFirstLoad = YES;
    if (self.isAdLoaded && [self.loadingDelegate respondsToSelector:@selector(didCompleteFirstLoadFromNativeWebViewController:)])
    {
        // Attaching WKWebView to screen for an instant to allow it to fully load in the background
        //   before the call to [EPLAdDelegate adDidReceiveAd:self].
        //
        
        __weak EPLNativeRenderingViewController  *weakSelf  = self;
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.15 * NSEC_PER_SEC), dispatch_get_main_queue(),
                       ^{
                           __strong EPLNativeRenderingViewController  *strongSelf  = weakSelf;
                           if (!strongSelf)  {
                               EPLLogError(@"COULD NOT ACQUIRE strongSelf.");
                               return;
                           }
                           
                           UIView  *contentView  = strongSelf.contentView;
                           
                           contentView.translatesAutoresizingMaskIntoConstraints = NO;
                           
                           [strongSelf addSubview:contentView];
                           strongSelf.contentView.hidden = NO;
                           
                           [contentView an_constrainToSizeOfSuperview];
                           [contentView an_alignToSuperviewWithXAttribute:NSLayoutAttributeLeft
                                                               yAttribute:NSLayoutAttributeTop];
                           
                           [strongSelf.loadingDelegate didCompleteFirstLoadFromNativeWebViewController:strongSelf];
                       });
        
        
    }else{
        [self.loadingDelegate didFailToLoadNativeWebViewController];
        }
    }
}

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message{
    if (!message)  { return; }
    NSString        *eventName          = @"";
    if ([message.body isKindOfClass:[NSString class]])
    {
        eventName = (NSString *)message.body;
    }
    if (![eventName isEqualToString:kANativeRenderingInvalidURL]){
        self.isAdLoaded = YES;
    }else{
        self.isAdLoaded = NO;
    }
}

#pragma mark - EPLBrowserViewControllerDelegate

- (UIViewController *)rootViewControllerForDisplayingBrowserViewController:(EPLBrowserViewController *)controller
{
    return [self displayController];
}

- (void)didDismissBrowserViewController:(EPLBrowserViewController *)controller
{
    self.browserViewController = nil;
 
}

- (void)willLeaveApplicationFromBrowserViewController:(EPLBrowserViewController *)controller {
    [self.adViewDelegate adWillLeaveApplication];
}

#pragma mark - Helper methods.

- (UIViewController *)displayController {
    
    UIViewController *presentingVC = nil;
    
    presentingVC = [self.adViewDelegate displayController];
    
    if (EPLCanPresentFromViewController(presentingVC)) {
        return presentingVC;
    }
    return nil;
}
- (void) willMoveToSuperview: (UIView *)newSuperview
{
    [super willMoveToSuperview:newSuperview];
    
    // UIView already added to superview.
    if (newSuperview != nil)  {
        return;
    }
    [self stopWebViewLoadForDealloc];
}

- (void)stopWebViewLoadForDealloc
{
    if (self.webView)
    {
        [self.webView stopLoading];
        
        [self.webView setNavigationDelegate:nil];
        [self.webView setUIDelegate:nil];
        
        [self.webView removeFromSuperview];
        self.webView = nil;
        
    }
    self.contentView = nil;
}


@end
