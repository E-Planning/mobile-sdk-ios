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

#import "EPLAdWebViewController.h"
#import "EPLGlobal.h"
#import "EPLLogging.h"
#import "EPLMRAIDJavascriptUtil.h"
#import "EPLMRAIDOrientationProperties.h"
#import "EPLMRAIDExpandProperties.h"
#import "EPLMRAIDResizeProperties.h"
#import "EPLAdViewInternalDelegate.h"

#import "NSString+EPLCategory.h"
#import "NSTimer+EPLCategory.h"
#import "UIView+EPLCategory.h"

#import "EPLSDKSettings+PrivateMethods.h"
#import "EPLAdConstants.h"

#import "EPLOMIDImplementation.h"
#import "EPLWebView.h"
#import "EPLVideoPlayerSettings+EPLCategory.h"
#import "EPLAudioVolumeChangeListener.h"
NSString *const kANWebViewControllerMraidJSFilename = @"mraid.js";



NSString * __nonnull const  kANUISupportedInterfaceOrientations   = @"UISupportedInterfaceOrientations";
NSString * __nonnull const  kANUIInterfaceOrientationPortrait     = @"UIInterfaceOrientationPortrait";
NSString * __nonnull const  kANUIInterfaceOrientationPortraitUpsideDown     = @"UIInterfaceOrientationPortraitUpsideDown";
NSString * __nonnull const  kANUIInterfaceOrientationLandscapeLeft     = @"UIInterfaceOrientationLandscapeLeft";
NSString * __nonnull const  kANUIInterfaceOrientationLandscapeRight     = @"UIInterfaceOrientationLandscapeRight";
NSString * __nonnull const  kANPortrait     = @"portrait";
NSString * __nonnull const  kANLandscape     = @"landscape";



@interface EPLAdWebViewController () <WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler, EPLAudioVolumeChangeListenerDelegate>

@property (nonatomic, readwrite, strong)    UIView      *contentView;
@property (nonatomic, readwrite, strong)    EPLWebView      *webView;
@property (nonatomic, readwrite, assign)  BOOL  isMRAID;
@property (nonatomic, readwrite, assign)  BOOL  completedFirstLoad;
@property (nonatomic, readwrite, strong)  WKNavigation *firstNavigation;

@property (nonatomic, readwrite, strong)                        NSTimer     *viewabilityTimer;
@property (nonatomic, readwrite, assign, getter=isViewable)     BOOL         viewable;

@property (nonatomic, readwrite, assign)  CGRect  defaultPosition;
@property (nonatomic, readwrite, assign)  CGRect  currentPosition;
@property (nonatomic, readwrite, assign)  CGFloat  lastKnownExposedPercentage;
@property (nonatomic, readwrite, assign)  CGRect  lastKnownVisibleRect;

@property (nonatomic, readwrite, assign)  BOOL  rapidTimerSet;

@property (nonatomic, readwrite, strong)  EPLAdWebViewControllerConfiguration  *configuration;

@property (nonatomic, readwrite, assign)  NSRunLoopMode  checkViewableRunLoopMode;

@property (nonatomic, readwrite, strong)  NSString  *videoXML;
@property (nonatomic, readwrite)          BOOL       appIsInBackground;
@property (nonatomic, readwrite, assign)  EPLVideoOrientation  videoAdOrientation;
@property (nonatomic, readwrite, assign)  NSInteger  videoAdWidth;
@property (nonatomic, readwrite, assign)  NSInteger  videoAdHeight;
@property (nonatomic, readwrite, strong)  EPLAudioVolumeChangeListener* audioVolumeChange;

@end

@implementation EPLAdWebViewController
    
- (instancetype)initWithConfiguration:(EPLAdWebViewControllerConfiguration *)configuration
{
    if (self = [super init])
    {
        if (configuration) {
            _configuration = [configuration copy];
        } else {
            _configuration = [[EPLAdWebViewControllerConfiguration alloc] init];
        }
        
        _checkViewableTimeInterval = kAppNexusMRAIDCheckViewableFrequency;
        _checkViewableRunLoopMode = NSRunLoopCommonModes;
        
        _appIsInBackground = NO;
        
    }
    return self;
}

- (instancetype)initWithSize:(CGSize)size
                         URL:(NSURL *)URL
              webViewBaseURL:(NSURL *)baseURL
{
    self = [self initWithSize:size
                          URL:URL
               webViewBaseURL:baseURL
                configuration:nil];
    return self;
    
}

- (instancetype)initWithSize:(CGSize)size
                         URL:(NSURL *)URL
              webViewBaseURL:(NSURL *)baseURL
               configuration:(EPLAdWebViewControllerConfiguration *)configuration
{
    self = [self initWithConfiguration:configuration];
    if (!self)  { return nil; }
    
    _webView = [[EPLWebView alloc]initWithSize:(CGSize)size
                                   URL:(NSURL *)URL
                               baseURL:(NSURL *)baseURL];
    [self loadWebViewWithUserScripts];
    
    return self;
}

- (instancetype)initWithSize:(CGSize)size
                        HTML:(NSString *)html
              webViewBaseURL:(NSURL *)baseURL
{
    self = [self initWithSize:size
                         HTML:html
               webViewBaseURL:baseURL
                configuration:nil];
    return self;
}

- (instancetype)initWithSize:(CGSize)size
                        HTML:(NSString *)html
              webViewBaseURL:(NSURL *)baseURL
               configuration:(EPLAdWebViewControllerConfiguration *)configuration
{
    self = [self initWithConfiguration:configuration];
    if (!self)  { return nil; }
    
    //
    NSRange      mraidJSRange   = [html rangeOfString:kANWebViewControllerMraidJSFilename];
    NSURL       *base           = baseURL;
    
    _isMRAID = (mraidJSRange.location != NSNotFound);
    
    if (!base) {
        base = [NSURL URLWithString:[[[EPLSDKSettings sharedInstance] baseUrlConfig] webViewBaseUrl]];
    }
    
    NSString  *htmlToLoad  = html;
      
    if (!_configuration.scrollingEnabled) {
        htmlToLoad = [[self class] prependViewportToHTML:htmlToLoad];
    }
    self.webView = [EPLWebView fetchWebView];
    //self.webView = [[EPLWarmupWebView sharedInstance] fetchWarmedUpWebView];
    [self loadWebViewWithUserScripts];
    
    __weak EPLAdWebViewController  *weakSelf  = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong EPLAdWebViewController  *strongSelf  = weakSelf;
            if (!strongSelf)  {
                return;
            }
            strongSelf.firstNavigation = [strongSelf.webView loadHTMLString:htmlToLoad baseURL:base];
        });
    
    return self;
}

- (instancetype) initWithSize: (CGSize)size
                     videoXML: (NSString *)videoXML;
{
    self = [self initWithConfiguration:nil];
    if (!self)  { return nil; }
    
    self.configuration.scrollingEnabled = NO;
    self.configuration.isVASTVideoAd = YES;
    
    //Encode videoXML to Base64String
    _videoXML = [[videoXML dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0];
    
    [self handleMRAIDURL:[NSURL URLWithString:@"mraid://enable"]];
    
    _webView = [[EPLWebView alloc] initWithSize:size URL:[[[EPLSDKSettings sharedInstance] baseUrlConfig] videoWebViewUrl] isVASTVideoAd:true];
    self.firstNavigation = _webView.navigation;
    self.videoPlayerSize = size;
    [self loadWebViewWithUserScripts];
    
    UIWindow  *currentWindow  = [EPLGlobal getKeyWindow];
    [currentWindow addSubview:self.webView];
    [self.webView setHidden:true];
    
    //
    return  self;
}
    


- (void)stopOMIDAdSession {
    if(self.omidAdSession != nil){
        [[EPLOMIDImplementation sharedInstance] stopOMIDAdSession:self.omidAdSession];
    }
}

- (void) dealloc
{
    [self deallocActions];
}

- (void) deallocActions
{
    [self stopOMIDAdSession];
    [self stopWebViewLoadForDealloc];
    [self.viewabilityTimer invalidate];
    self.audioVolumeChange = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Scripts

+ (NSString *)prependViewportToHTML:(NSString *)html
{
    return [NSString stringWithFormat:@"%@%@", @"<meta name=\"viewport\" content=\"initial-scale=1.0, user-scalable=no\">", html];
}

//+ (NSString *)prependScriptsToHTML:(NSString *)html {
//    return [NSString stringWithFormat:@"%@%@%@", [[self class] anjamHTML], [[self class] mraidHTML], html];
//}


#pragma mark - configure WKWebView
 
-(void) loadWebViewWithUserScripts {
    
    WKUserContentController  *controller  = self.webView.configuration.userContentController;
    
    if (!self.configuration.userSelectionEnabled)
    {
        NSString *userSelectionSuppressionJS = @"document.documentElement.style.webkitUserSelect='none';";
        
        WKUserScript *userSelectionSuppressionScript = [[WKUserScript alloc] initWithSource: userSelectionSuppressionJS
                                                                              injectionTime: WKUserScriptInjectionTimeAtDocumentEnd
                                                                           forMainFrameOnly: NO];
        [controller addUserScript:userSelectionSuppressionScript];
    }
    // Set HttpCookie for Webview
    [EPLGlobal setWebViewCookie:self.webView];
    
    // Attach  OMID JS script to WKWebview for HTML Banner Ad's
    // This is used inplace of [OMIDScriptInjector injectScriptContent] because it scrambles the creative HTML. See MS-3707 for more details.
    if(!self.configuration.isVASTVideoAd){
        
        if(![controller.userScripts containsObject:[EPLWebView omidScript]]){
            [controller addUserScript:[EPLWebView omidScript]];
        }
        
    }
    
    if (self.configuration.scrollingEnabled) {
        self.webView.scrollView.scrollEnabled = YES;
        self.webView.scrollView.bounces = YES;
        
    } else {
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
    }
    if(self.configuration.isVASTVideoAd){
        // This is required to avoid the crash :- "Attempt to add script message handler with name '' when one already exists."
        [self.webView.configuration.userContentController removeScriptMessageHandlerForName:@"observe"];
        [self.webView.configuration.userContentController removeScriptMessageHandlerForName:@"interOp"];
        
        [self.webView.configuration.userContentController addScriptMessageHandler:self name:@"observe"];
        self.webView.configuration.allowsInlineMediaPlayback = YES;
        [self.webView.configuration.userContentController addScriptMessageHandler:self name:@"interOp"];
        
        self.webView.backgroundColor = [UIColor blackColor];
    }
    [self.webView setNavigationDelegate:self];
    [self.webView setUIDelegate:self];
    
    self.contentView = self.webView;
}

#pragma mark - WKNavigationDelegate


-(void) webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation
{
    EPLLogInfo(@"");
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
    if (navigation == self.firstNavigation) {
        [self processWebViewDidFinishLoad];
    }
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    EPLLogDebug(@"%@ %@", NSStringFromSelector(_cmd), error);
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    EPLLogDebug(@"%@ %@", NSStringFromSelector(_cmd), error);
}

- (void)                    webView: (WKWebView *)webView
    decidePolicyForNavigationAction: (WKNavigationAction *)navigationAction
                    decisionHandler: (void (^)(WKNavigationActionPolicy))decisionHandler
{
    NSURL *URL = navigationAction.request.URL;
    NSURL *mainDocumentURL = navigationAction.request.mainDocumentURL;
    NSString *URLScheme = URL.scheme;
    
    if ([URLScheme isEqualToString:@"anwebconsole"]) {
        [self printConsoleLogWithURL:URL];
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }
    
    EPLLogDebug(@"Loading URL: %@", [[URL absoluteString] stringByRemovingPercentEncoding]);
    
    // For security reasons, test for fragment of path to vastVideo.html.
    //
    if ([URLScheme isEqualToString:@"file"])
    {
        NSString  *filePathContainsThisString  = @"/vastVideo.html";
        
        if ([[URL absoluteString] rangeOfString:filePathContainsThisString].location == NSNotFound) {
            return;
        }
        
        decisionHandler(WKNavigationActionPolicyAllow);
        return;
    }
    
    if (self.completedFirstLoad) {
        if (EPLHasHttpPrefix(URLScheme)) {
            if (([[mainDocumentURL absoluteString] isEqualToString:[URL absoluteString]]
                 || navigationAction.navigationType == WKNavigationTypeLinkActivated
                 || navigationAction.targetFrame == nil)
                && self.configuration.navigationTriggersDefaultBrowser) {
                [self.browserDelegate openDefaultBrowserWithURL:URL];
                decisionHandler(WKNavigationActionPolicyCancel);
                return;
            }
        } else if ([URLScheme isEqualToString:@"mraid"]) {
            [self handleMRAIDURL:URL];
            decisionHandler(WKNavigationActionPolicyCancel);
            return;
        } else if ([URLScheme isEqualToString:@"anjam"]) {
            [self.anjamDelegate handleANJAMURL:URL];
            decisionHandler(WKNavigationActionPolicyCancel);
            return;
        } else if ([URLScheme isEqualToString:@"about"]) {
            if (navigationAction.targetFrame && navigationAction.targetFrame.mainFrame == NO) {
                decisionHandler(WKNavigationActionPolicyAllow);
            } else {
                decisionHandler(WKNavigationActionPolicyCancel);
            }
            return;
        } else {
            if (self.configuration.navigationTriggersDefaultBrowser) {
                [self.browserDelegate openDefaultBrowserWithURL:URL];
                decisionHandler(WKNavigationActionPolicyCancel);
                return;
            }
        }
    } else {
        if ([URLScheme isEqualToString:@"mraid"]) {
            if ([URL.host isEqualToString:@"enable"]) {
                [self handleMRAIDURL:URL];
            }
            decisionHandler(WKNavigationActionPolicyCancel);
            return;
        } else if ([URLScheme isEqualToString:@"anjam"]) {
            decisionHandler(WKNavigationActionPolicyCancel);
            return;
        }
    }
    
    decisionHandler(WKNavigationActionPolicyAllow);
}



#pragma mark - WKUIDelegate

- (WKWebView *)         webView: (WKWebView *)webView
 createWebViewWithConfiguration: (WKWebViewConfiguration *)configuration
            forNavigationAction: (WKNavigationAction *)navigationAction
                 windowFeatures: (WKWindowFeatures *)windowFeatures
{
    if (navigationAction.targetFrame == nil) {
        [self.browserDelegate openDefaultBrowserWithURL:navigationAction.request.URL];
    }
    
    return nil;
}

#pragma mark - WKScriptMessageHandler.

- (void) userContentController: (WKUserContentController *)userContentController
       didReceiveScriptMessage: (WKScriptMessage *)message
{
    if (!message)  { return; }
    
    NSString        *eventName          = @"";
    NSDictionary    *paramsDictionary   = [NSDictionary new];
    
    if ([message.body isKindOfClass:[NSString class]])
    {
        eventName = (NSString *)message.body;
        
    } else if ([message.body isKindOfClass:[NSDictionary class]]) {
        NSDictionary  *messageDictionary  = (NSDictionary *)message.body;
        
        if (messageDictionary.count > 0) {
            eventName           = [messageDictionary objectForKey:@"event"];
            paramsDictionary    = [messageDictionary objectForKey:@"params"];
        }
    }
    
    EPLLogInfo(@"Event: %@", eventName);
    
    if ([eventName isEqualToString:@"adReady"])
    {
        if(paramsDictionary.count > 0){
            self.videoAdOrientation = [EPLGlobal parseVideoOrientation:[paramsDictionary objectForKey:kANAspectRatio]];
        }
        self.videoAdWidth = [[paramsDictionary objectForKey:@"width"] integerValue];
        self.videoAdHeight = [[paramsDictionary objectForKey:@"height"] integerValue];
        // For VideoAds's wait unitll adReady to create AdSession if not the adsession will run in limited access mode.
        self.omidAdSession = [[EPLOMIDImplementation sharedInstance] createOMIDAdSessionforWebView:self.webView isVideoAd:true];
        if ([self.videoDelegate respondsToSelector:@selector(videoAdReady)]) {
            [self.videoDelegate videoAdReady];
        }
        
    } else if ([eventName isEqualToString:@"videoStart"] || [eventName isEqualToString:@"videoRewind"]) {
        [self.viewabilityTimer fire];
        
        if ([self.mraidDelegate respondsToSelector:@selector(isViewable)]) {
            [self updateViewability:[self.mraidDelegate isViewable]];
        }
        
        
    } else if([eventName isEqualToString:@"video-fullscreen-enter"]) {
        if ([self.videoDelegate respondsToSelector:@selector(videoAdPlayerFullScreenEntered:)]) {
            [self.videoDelegate videoAdPlayerFullScreenEntered:self];
            
        }
        
    } else if([eventName isEqualToString:@"video-fullscreen-exit"]) {
        if ([self.videoDelegate respondsToSelector:@selector(videoAdPlayerFullScreenExited:)]) {
            [self.videoDelegate videoAdPlayerFullScreenExited:self];
        }
        
        
    } else if([eventName isEqualToString:@"video-error"] || [eventName isEqualToString:@"Timed-out"]) {
        //we need to remove the webview to makesure we dont get any other response from the loaded index.html page
        [self deallocActions];
        
        if([self.videoDelegate respondsToSelector:@selector(videoAdError:)]){
            NSError *error = EPLError(@"Timeout reached while parsing VAST", EPLAdResponseCode.INTERNAL_ERROR.code);
            [self.videoDelegate videoAdError:error];
        }
        
        if ([self.loadingDelegate respondsToSelector:@selector(immediatelyRestartAutoRefreshTimerFromWebViewController:)]) {
            [self.loadingDelegate immediatelyRestartAutoRefreshTimerFromWebViewController:self];
        }
        
        
    }else if([eventName isEqualToString:@"video-complete"]) {
        
        [self stopOMIDAdSession];
        
    }else if (      ([self.videoXML length] > 0)
               && (      [eventName isEqualToString:@"video-first-quartile"]
                   || [eventName isEqualToString:@"video-mid"]
                   || [eventName isEqualToString:@"video-third-quartile"]
                   || [eventName isEqualToString:@"audio-mute"]
                   || [eventName isEqualToString:@"audio-unmute"]
                   )
               )
    {
        //EMPTY -- Silently ignore spurious VAST playback errors that might scare a client-dev into thinking something is wrong...
        
    } else {
        EPLLogError(@"UNRECOGNIZED video event.  (%@)", eventName);
    }
}

# pragma mark - MRAID

- (void)processWebViewDidFinishLoad
{
    
    if (!self.completedFirstLoad)
    {
        self.completedFirstLoad = YES;
        self.firstNavigation = nil;
        // If it is VAST ad then donot call didCompleteFirstLoadFromWebViewController videoAdReady will call it later.
        if ([self.videoXML length] > 0)
        {
            @synchronized(self) {
                [self processVideoViewDidFinishLoad];
            }
        }else if ([self.loadingDelegate respondsToSelector:@selector(didCompleteFirstLoadFromWebViewController:)])
        {
            @synchronized(self) {
                [self.loadingDelegate didCompleteFirstLoadFromWebViewController:self];
            }
        }
        
        //
        if (self.isMRAID) {
            [self finishMRAIDLoad];
        }
        if(!([self.videoXML length] > 0)){
             self.omidAdSession = [[EPLOMIDImplementation sharedInstance] createOMIDAdSessionforWebView:self.webView isVideoAd:false];
        }
        
        
       
    }
}

- (void)finishMRAIDLoad
{
    [self fireJavaScript:[EPLMRAIDJavascriptUtil feature:@"sms"
                                            isSupported:[EPLMRAIDUtil supportsSMS]]];
    [self fireJavaScript:[EPLMRAIDJavascriptUtil feature:@"tel"
                                            isSupported:[EPLMRAIDUtil supportsTel]]];
    [self fireJavaScript:[EPLMRAIDJavascriptUtil feature:@"calendar"
                                            isSupported:[EPLMRAIDUtil supportsCalendar]]];
    [self fireJavaScript:[EPLMRAIDJavascriptUtil feature:@"inlineVideo"
                                            isSupported:[EPLMRAIDUtil supportsInlineVideo]]];
    [self fireJavaScript:[EPLMRAIDJavascriptUtil feature:@"storePicture"
                                            isSupported:[EPLMRAIDUtil supportsStorePicture]]];
    [self updateCurrentAppOrientation];

    [self updateWebViewOnOrientation];
    
    
    [self updateWebViewOnPositionAndViewabilityStatus];
    
    
    if (self.configuration.initialMRAIDState == EPLMRAIDStateExpanded || self.configuration.initialMRAIDState == EPLMRAIDStateResized)
    {
        [self setupRapidTimerForCheckingPositionAndViewability];
        self.rapidTimerSet = YES;
    } else {
        [self setupTimerForCheckingPositionAndViewability];
    }
    
    [self setupApplicationBackgroundNotifications];
    [self setupOrientationChangeNotification];
    
    if ([self.adViewDelegate adTypeForMRAID]) {
        [self fireJavaScript:[EPLMRAIDJavascriptUtil placementType:[self.adViewDelegate adTypeForMRAID]]];
    }
    [self fireJavaScript:[EPLMRAIDJavascriptUtil stateChange:self.configuration.initialMRAIDState]];
    [self fireJavaScript:[EPLMRAIDJavascriptUtil readyEvent]];
}

- (void)setupApplicationBackgroundNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleApplicationDidEnterBackground:)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:[UIApplication sharedApplication]];
    
    [[NSNotificationCenter defaultCenter]addObserver:self
                                            selector:@selector(handleApplicationDidBecomeActive:)
                                                name:UIApplicationDidBecomeActiveNotification
                                              object:nil];
    
}

- (void)handleApplicationDidEnterBackground:(NSNotification *)notification
{
    self.viewable = NO;
    self.appIsInBackground = YES;
    
    if (self.videoDelegate) {
        [self updateViewability:NO];
    } else {
        [self fireJavaScript:[EPLMRAIDJavascriptUtil isViewable:NO]];
    }
}

-(void)handleApplicationDidBecomeActive:(NSNotification *)notification
{
    self.appIsInBackground = NO;
    if (self.audioVolumeChange) {
        self.audioVolumeChange.isAudioSessionActive = YES;
    }
}

- (void)setupOrientationChangeNotification {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleOrientationChange:)
                                                 name:UIApplicationDidChangeStatusBarOrientationNotification
                                               object:[UIApplication sharedApplication]];
}

- (void)handleOrientationChange:(NSNotification *)notification {
    [self updateWebViewOnOrientation];
}

- (void)setupTimerForCheckingPositionAndViewability
{
    [self enableViewabilityTimerWithTimeInterval:self.checkViewableTimeInterval
                                            mode:self.checkViewableRunLoopMode];
}

- (void)setupRapidTimerForCheckingPositionAndViewability
{
    [self enableViewabilityTimerWithTimeInterval:0.1
                                            mode:NSRunLoopCommonModes];
}

- (void)setCheckViewableTimeInterval:(NSTimeInterval)timeInterval
{
    _checkViewableTimeInterval = timeInterval;
    _checkViewableRunLoopMode = NSRunLoopCommonModes;
    if (self.viewabilityTimer) {
        [self enableViewabilityTimerWithTimeInterval:_checkViewableTimeInterval
                                                mode:_checkViewableRunLoopMode];
    } // Otherwise will be enabled in finishMRAIDLoad method
}

- (void)enableViewabilityTimerWithTimeInterval:(NSTimeInterval)timeInterval mode:(NSRunLoopMode)mode
{
    EPLLogDebug(@"");
    if (self.viewabilityTimer) {
        [self.viewabilityTimer invalidate];
    }
    __weak EPLAdWebViewController *weakSelf = self;
    if (mode == NSRunLoopCommonModes) {
        self.viewabilityTimer = [NSTimer an_scheduledTimerWithTimeInterval:timeInterval
                                                                     block:^{
                                                                         EPLAdWebViewController *strongSelf = weakSelf;
                                                                         [strongSelf updateWebViewOnPositionAndViewabilityStatus];
                                                                     }
                                                                   repeats:YES
                                                                      mode:mode];
    } else {
        self.viewabilityTimer = [NSTimer an_scheduledTimerWithTimeInterval:timeInterval
                                                                     block:^ {
                                                                         EPLAdWebViewController *strongSelf = weakSelf;
                                                                         [strongSelf updateWebViewOnPositionAndViewabilityStatus];
                                                                     }
                                                                   repeats:YES];
    }
}

- (void)updateWebViewOnPositionAndViewabilityStatus
{
    CGRect updatedDefaultPosition = [self.mraidDelegate defaultPosition];
    if (!CGRectEqualToRect(self.defaultPosition, updatedDefaultPosition)) {
        EPLLogDebug(@"Default position change: %@", NSStringFromCGRect(updatedDefaultPosition));
        self.defaultPosition = updatedDefaultPosition;
        [self fireJavaScript:[EPLMRAIDJavascriptUtil defaultPosition:self.defaultPosition]];
    }
    
    CGRect updatedCurrentPosition = [self.mraidDelegate currentPosition];
    if (!CGRectEqualToRect(self.currentPosition, updatedCurrentPosition)) {
        EPLLogDebug(@"Current position change: %@", NSStringFromCGRect(updatedCurrentPosition));
        self.currentPosition = updatedCurrentPosition;
        [self fireJavaScript:[EPLMRAIDJavascriptUtil currentPosition:self.currentPosition]];
    }
    
    BOOL isCurrentlyViewable = (!self.appIsInBackground && [self.mraidDelegate isViewable]);
    
    if (self.isViewable != isCurrentlyViewable) {
        EPLLogDebug(@"Viewablity change: %d", isCurrentlyViewable);
        self.viewable = isCurrentlyViewable;
        
        if (self.videoDelegate) {
            [self updateViewability:self.isViewable];
        } else {
            [self fireJavaScript:[EPLMRAIDJavascriptUtil isViewable:self.isViewable]];
        }
        if (self.audioVolumeChange) {
          [self updateWebViewOnAudioVolumeChange:[self.audioVolumeChange getAudioVolumePercentage]];
        }
    }
    
    CGFloat updatedExposedPercentage = [self.mraidDelegate exposedPercent]; // updatedExposedPercentage from MRAID Delegate
    CGRect updatedVisibleRectangle = [self.mraidDelegate visibleRect]; // updatedVisibleRectangle from MRAID Delegate
    
    // Send exposureChange Event only when there is an update from the previous.
    if(self.lastKnownExposedPercentage != updatedExposedPercentage || !CGRectEqualToRect(self.lastKnownVisibleRect,updatedVisibleRectangle)){
        self.lastKnownExposedPercentage = updatedExposedPercentage;
        self.lastKnownVisibleRect = updatedVisibleRectangle;
        [self fireJavaScript:[EPLMRAIDJavascriptUtil exposureChangeExposedPercentage:self.lastKnownExposedPercentage visibleRectangle:self.lastKnownVisibleRect]];
    }
}

- (void)updateWebViewOnOrientation {
    [self fireJavaScript:[EPLMRAIDJavascriptUtil screenSize:[EPLMRAIDUtil screenSize]]];
    [self fireJavaScript:[EPLMRAIDJavascriptUtil maxSize:[EPLMRAIDUtil maxSizeSafeArea]]];
}

- (void)updateWebViewOnAudioVolumeChange:(NSNumber *)volumePercentage {
    if (self.viewable) {
        EPLLogDebug(@"AudioVolume change percentage : %@", volumePercentage);
        [self fireJavaScript:[EPLMRAIDJavascriptUtil audioVolumeChange:volumePercentage]];
    }
}

- (void)updateCurrentAppOrientation {
    
    UIInterfaceOrientation currentAppOrientation = EPLStatusBarOrientation();
    NSString *currentAppOrientationString = (UIInterfaceOrientationIsPortrait(currentAppOrientation)) ? kANPortrait : kANLandscape;
    
    NSArray *supportedOrientations = [[[NSBundle mainBundle] infoDictionary]
                                      objectForKey:kANUISupportedInterfaceOrientations];
    BOOL isPortraitOrientationSupported = ([supportedOrientations containsObject:kANUIInterfaceOrientationPortrait] || [supportedOrientations containsObject:kANUIInterfaceOrientationPortraitUpsideDown]);
    BOOL isLandscapeOrientationSupported  = ([supportedOrientations containsObject:kANUIInterfaceOrientationLandscapeLeft] || [supportedOrientations containsObject:kANUIInterfaceOrientationLandscapeRight]);
    
    BOOL lockedOrientation = !(isPortraitOrientationSupported && isLandscapeOrientationSupported);
    
    
    [self fireJavaScript:[EPLMRAIDJavascriptUtil setCurrentAppOrientation:currentAppOrientationString lockedOrientation:lockedOrientation]];

}

- (void)fireJavaScript:(NSString *)javascript {
        [self.webView evaluateJavaScript:javascript completionHandler:nil];
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

- (void)handleMRAIDURL:(NSURL *)URL {
    EPLLogDebug(@"Received MRAID query: %@", URL);
    
    NSString *mraidCommand = [URL host];
    NSString *query = [URL query];
    NSDictionary *queryComponents = [query an_queryComponents];
    
    EPLMRAIDAction action = [EPLMRAIDUtil actionForCommand:mraidCommand];
    switch (action) {
        case EPLMRAIDActionUnknown:
            EPLLogDebug(@"Unknown MRAID action requested: %@", mraidCommand);
            return;
        case EPLMRAIDActionExpand:
            [self.adViewDelegate adWasClicked];
            [self forwardExpandRequestWithQueryComponents:queryComponents];
            break;
        case EPLMRAIDActionClose:
            [self forwardCloseAction];
            break;
        case EPLMRAIDActionResize:
            [self.adViewDelegate adWasClicked];
            [self forwardResizeRequestWithQueryComponents:queryComponents];
            break;
        case EPLMRAIDActionCreateCalendarEvent: {
            [self.adViewDelegate adWasClicked];
            NSString *w3cEventJson = [queryComponents[@"p"] description];
            [self forwardCalendarEventRequestWithW3CJSONString:w3cEventJson];
            break;
        }
        case EPLMRAIDActionPlayVideo: {
            [self.adViewDelegate adWasClicked];
            NSString *uri = [queryComponents[@"uri"] description];
            [self.mraidDelegate adShouldPlayVideoWithUri:uri];
            break;
        }
        case EPLMRAIDActionStorePicture: {
            [self.adViewDelegate adWasClicked];
            NSString *uri = [queryComponents[@"uri"] description];
            [self.mraidDelegate adShouldSavePictureWithUri:uri];
            break;
        }
        case EPLMRAIDActionSetOrientationProperties:
            [self forwardOrientationPropertiesWithQueryComponents:queryComponents];
            break;
        case EPLMRAIDActionSetUseCustomClose: {
            NSString *value = [queryComponents[@"value"] description];
            BOOL useCustomClose = [value isEqualToString:@"true"];
            [self.mraidDelegate adShouldSetUseCustomClose:useCustomClose];
            break;
        }
        case EPLMRAIDActionOpenURI: {
            NSString *uri = [queryComponents[@"uri"] description];
            NSURL *URL = [NSURL URLWithString:uri];
            if (uri.length && URL) {
                [self.browserDelegate openDefaultBrowserWithURL:URL];
            }
            break;
        }
        case EPLMRAIDActionAudioVolumeChange:
            if (self.audioVolumeChange == nil) {
                //Initialize Audio Volume Change Listener for Outstream Video
                self.audioVolumeChange = [[EPLAudioVolumeChangeListener alloc] initWithDelegate:self];
                [self updateWebViewOnAudioVolumeChange:@(100.0 * [AVAudioSession sharedInstance].outputVolume)];
            }
            break;
        case EPLMRAIDActionEnable:
            if (self.isMRAID) return;
            self.isMRAID = YES;
            if (self.completedFirstLoad) [self finishMRAIDLoad];
            break;
        default:
            EPLLogError(@"Known but unhandled MRAID action: %@", mraidCommand);
            break;
    }
}

- (void)forwardCloseAction {
    [self.mraidDelegate adShouldClose];
}

- (void)forwardResizeRequestWithQueryComponents:(NSDictionary *)queryComponents {
    EPLMRAIDResizeProperties *resizeProperties = [EPLMRAIDResizeProperties resizePropertiesFromQueryComponents:queryComponents];
    [self.mraidDelegate adShouldAttemptResizeWithResizeProperties:resizeProperties];
}

- (void)forwardExpandRequestWithQueryComponents:(NSDictionary *)queryComponents
{
    if (!self.rapidTimerSet) {
        [self setupRapidTimerForCheckingPositionAndViewability];
        self.rapidTimerSet = YES;
    }
    EPLMRAIDExpandProperties *expandProperties = [EPLMRAIDExpandProperties expandPropertiesFromQueryComponents:queryComponents];
    [self forwardOrientationPropertiesWithQueryComponents:queryComponents];
    [self.mraidDelegate adShouldExpandWithExpandProperties:expandProperties];
}

- (void)forwardOrientationPropertiesWithQueryComponents:(NSDictionary *)queryComponents {
    EPLMRAIDOrientationProperties *orientationProperties = [EPLMRAIDOrientationProperties orientationPropertiesFromQueryComponents:queryComponents];
    [self.mraidDelegate adShouldSetOrientationProperties:orientationProperties];
}

- (void)forwardCalendarEventRequestWithW3CJSONString:(NSString *)json {
    NSError *error;
    id jsonObject = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding]
                                                    options:kNilOptions
                                                      error:&error];
    if (!error && [jsonObject isKindOfClass:[NSDictionary class]]) {
        [self.mraidDelegate adShouldOpenCalendarWithCalendarDict:(NSDictionary *)jsonObject];
    }
}

- (void)updatePlacementType:(NSString *)placementType {
    if (self.isMRAID) {
        [self fireJavaScript:[EPLMRAIDJavascriptUtil placementType:placementType]];
    }
}




#pragma mark - MRAID Callbacks

- (void)adDidFinishExpand {
    [self fireJavaScript:[EPLMRAIDJavascriptUtil stateChange:EPLMRAIDStateExpanded]];
}

- (void)adDidFinishResize:(BOOL)success
              errorString:(NSString *)errorString
                isResized:(BOOL)isResized {
    if (success) {
        [self fireJavaScript:[EPLMRAIDJavascriptUtil stateChange:EPLMRAIDStateResized]];
    } else {
        [self fireJavaScript:[EPLMRAIDJavascriptUtil error:errorString
                                              forFunction:@"mraid.resize()"]];
    }
}

- (void)adDidResetToDefault {
    [self fireJavaScript:[EPLMRAIDJavascriptUtil stateChange:EPLMRAIDStateDefault]];
}

- (void)adDidHide {
    [self fireJavaScript:[EPLMRAIDJavascriptUtil stateChange:EPLMRAIDStateHidden]];
    [self stopWebViewLoadForDealloc];
}

- (void)adDidFailCalendarEditWithErrorString:(NSString *)errorString {
    [self fireJavaScript:[EPLMRAIDJavascriptUtil error:errorString
                                          forFunction:@"mraid.createCalendarEvent()"]];
}

- (void)adDidFailPhotoSaveWithErrorString:(NSString *)errorString {
    [self fireJavaScript:[EPLMRAIDJavascriptUtil error:errorString
                                          forFunction:@"mraid.storePicture()"]];
}




#pragma mark - EPLWebConsole

- (void)printConsoleLogWithURL:(NSURL *)URL {
    NSString *decodedString = [[URL absoluteString] stringByRemovingPercentEncoding];
    NSLog(@"------- %@", decodedString);
}




#pragma mark - EPLAdViewInternalDelegate

- (void)setAdViewDelegate:(id<EPLAdViewInternalDelegate>)adViewDelegate {
    _adViewDelegate = adViewDelegate;
    if (_adViewDelegate) {
        [self fireJavaScript:[EPLMRAIDJavascriptUtil placementType:[_adViewDelegate adTypeForMRAID]]];
    }
}




#pragma mark - Banner Video.

- (void) processVideoViewDidFinishLoad
{
    NSString *videoOptions = [[EPLVideoPlayerSettings sharedInstance] fetchBannerSettings];
    
    NSString *exec_template = @"createVastPlayerWithContent('%@','%@');";
    NSString *exec = [NSString stringWithFormat:exec_template, self.videoXML,videoOptions];
    
    [self.webView evaluateJavaScript:exec completionHandler:nil];
}

- (void) updateViewability:(BOOL)isViewable
{
    NSString  *exec  = [NSString stringWithFormat:@"viewabilityUpdate('%@');", isViewable ? @"true" : @"false"];
    [self.webView evaluateJavaScript:exec completionHandler:nil];
}


#pragma mark - EPLAudioVolumeChangeDelegate

- (void)didUpdateAudioLevel:(NSNumber *)volumePercentage {
    [self updateWebViewOnAudioVolumeChange:volumePercentage];
}

@end   //EPLAdWebViewController




#pragma mark - EPLAdWebViewControllerConfiguration Implementation

@implementation EPLAdWebViewControllerConfiguration

- (instancetype)init {
    if (self = [super init]) {
        _scrollingEnabled = NO;
        _navigationTriggersDefaultBrowser = YES;
        _initialMRAIDState = EPLMRAIDStateDefault;
        _userSelectionEnabled = NO;
        _isVASTVideoAd = NO;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    EPLAdWebViewControllerConfiguration *configurationCopy = [[EPLAdWebViewControllerConfiguration alloc] init];
    configurationCopy.scrollingEnabled = self.scrollingEnabled;
    configurationCopy.navigationTriggersDefaultBrowser = self.navigationTriggersDefaultBrowser;
    configurationCopy.initialMRAIDState = self.initialMRAIDState;
    configurationCopy.userSelectionEnabled = self.userSelectionEnabled;
    configurationCopy.isVASTVideoAd = self.isVASTVideoAd;
    return configurationCopy;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"(scrollingEnabled: %d, navigationTriggersDefaultBrowser: %d, \
            initialMRAIDState: %lu, userSelectionEnabled: %d, isBannerVideo: %d", self.scrollingEnabled,
            self.navigationTriggersDefaultBrowser, (long unsigned)self.initialMRAIDState,
            self.userSelectionEnabled, self.isVASTVideoAd];
}

@end   //EPLAdWebViewControllerConfiguration
