/*   Copyright 2016 APPNEXUS INC
 
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

#import "EPLVideoAdPlayer.h"
#import "EPLLogging.h"
#import "EPLBrowserViewController.h"
#import "EPLGlobal.h"
#import "UIView+EPLCategory.h"
#import "EPLAdConstants.h"
#import "EPLSDKSettings+PrivateMethods.h"
#import "EPLOMIDImplementation.h"
#import "EPLVideoPlayerSettings.h"
#import "EPLVideoPlayerSettings+EPLCategory.h"
#import "EPLAdResponseCode.h"
#import "WKWebView+EPLCategory.h"

static NSTimeInterval const kANWebviewNilDelayInSeconds = 0.5;

@interface EPLVideoAdPlayer ()<EPLBrowserViewControllerDelegate>

@property (strong,nonatomic)              WKWebView                *webView;
@property (nonatomic, readwrite, strong)  EPLBrowserViewController  *browserViewController;
@property (nonatomic, strong)             NSString                 *vastContent;
@property (nonatomic, strong)             NSString                 *vastURL;
@property (nonatomic, strong)             NSString                 *jsonContent;
@property (nonatomic, strong)             NSString                 *creativeURL;
@property (nonatomic, assign)             NSUInteger                videoDuration;
@property (nonatomic, strong)             NSString                 *vastURLContent;
@property (nonatomic, strong)             NSString                 *vastXMLContent;
@property (nonatomic, readwrite, assign)  EPLVideoOrientation  videoAdOrientation;
@property (nonatomic, readwrite, assign)  NSInteger  videoAdWidth;
@property (nonatomic, readwrite, assign)  NSInteger  videoAdHeight;

@property (nonatomic, readonly)  EPLClickThroughAction   clickThroughAction;
@property (nonatomic, readonly)  BOOL                   landingPageLoadsInBackground;

@end




@implementation EPLVideoAdPlayer

#pragma mark - Lifecycle.

-(instancetype) init
{
    self = [super init];
    if (!self)  { return nil; }
    _creativeURL = @"";
    _videoDuration = 0;
    _vastURLContent = @"";
    _vastXMLContent = @"";
    _videoAdOrientation     = EPLUnknown;
    _videoAdWidth     = 0;
    _videoAdHeight     = 0;
    return self;
}

- (void) dealloc
{
    [self deregisterObserver];
}

-(void) registerObserver{
    [self deregisterObserver];
    [[NSNotificationCenter defaultCenter]addObserver:self
                                            selector:@selector(resumeAdVideo)
                                                name:UIApplicationDidBecomeActiveNotification
                                              object:nil];
    
    [[NSNotificationCenter defaultCenter]addObserver:self
                                            selector:@selector(pauseAdVideo)
                                                name:UIApplicationWillResignActiveNotification
                                              object:nil];
}

-(void) deregisterObserver{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

-(void) removePlayer{
    if(self.webView != nil){
        WKUserContentController *controller = self.webView.configuration.userContentController;
        [controller removeScriptMessageHandlerForName:@"observe"];
        [controller removeScriptMessageHandlerForName:@"interOp"];
        [self.webView setNavigationDelegate:nil];
        [self.webView setUIDelegate:nil];
        [self.webView removeFromSuperview];
        [self stopOMIDAdSession];
        
        // Delay is added to allow completion tracker to be fired successfully.
        // Setting up webView to nil immediately without adding any delay can cause failure of tracker
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kANWebviewNilDelayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            if(self.webView != nil){
                self.webView = nil;
            }
        });
    }
}

- (void)stopOMIDAdSession {
    if(self.omidAdSession != nil){
        [[EPLOMIDImplementation sharedInstance] stopOMIDAdSession:self.omidAdSession];
        self.omidAdSession = nil;
    }
}


#pragma mark - Getters/Setters.

- (BOOL) landingPageLoadsInBackground
{
    BOOL returnVal = YES;
    
    if ([self.delegate respondsToSelector:@selector(videoAdPlayerLandingPageLoadsInBackground)]) {
        returnVal = [self.delegate videoAdPlayerLandingPageLoadsInBackground];
    }
    
    return returnVal;
}

- (EPLClickThroughAction) clickThroughAction
{
    EPLClickThroughAction  returnVal  = NO;
    
    if ([self.delegate respondsToSelector:@selector(videoAdPlayerClickThroughAction)])  {
        returnVal = [self.delegate videoAdPlayerClickThroughAction];
    }
    
    return  returnVal;
}

- (EPLVideoOrientation) getVideoOrientation {
    return _videoAdOrientation;
}

- (NSInteger) getVideoWidth {
    return _videoAdWidth;
}

- (NSInteger) getVideoHeight {
    return _videoAdHeight;
}


#pragma mark - Public methods.

-(void) loadAdWithVastContent:(nonnull NSString *) vastContent{
    //Encode videoXML to Base64String
     self.vastContent = [[vastContent dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0];
    [self createVideoPlayer];
}

-(void) loadAdWithVastUrl:(nonnull NSString *) vastUrl {
    self.vastURL = vastUrl;
    [self createVideoPlayer];
}

-(void) loadAdWithJSONContent:(nonnull NSString *) jsonContent{
    self.jsonContent = jsonContent;
    [self createVideoPlayer];
}


-(void)playAdWithContainer:(nonnull UIView *) containerView
{
    if (!containerView)
    {
        if([self.delegate respondsToSelector:@selector(videoAdError:)]){
            NSError *error = EPLError(@"containerView is nil.", EPLAdResponseCode.INTERNAL_ERROR.code);
            [self.delegate videoAdError:error];
        }
        
        return;
    }
    
    
    //
    [self.webView removeFromSuperview];
    
    [self.webView setHidden:false];
    [containerView addSubview:self.webView];
    
    self.webView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.webView an_constrainToSizeOfSuperview];
    [self.webView an_alignToSuperviewWithXAttribute:NSLayoutAttributeLeft yAttribute:NSLayoutAttributeTop];
    
    
    //
    NSString *exec = @"playAd();";
    [self.webView evaluateJavaScript:exec completionHandler:nil];
}

- (NSUInteger) getAdDuration {
    return self.videoDuration;
}
- (nullable NSString *) getCreativeURL {
    return self.creativeURL;
}

- (nullable NSString *) getVASTURL {
    return self.vastURLContent;
}

- (nullable NSString *) getVASTXML {
    return self.vastXMLContent;
}

-(NSUInteger) getAdPlayElapsedTime {
    NSString *exec_template = @"getCurrentPlayHeadTime();";
    NSString *returnString = [_webView stringByEvaluatingJavaScriptFromString:exec_template];
    return [returnString integerValue];
}



#pragma mark - Helper methods.

- (void) createVideoPlayer
{
    NSURL *url = [[[EPLSDKSettings sharedInstance] baseUrlConfig] videoWebViewUrl];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];//Creating a WKWebViewConfiguration object so a controller can be added to it.
    
    WKUserContentController *controller = [[WKUserContentController alloc] init];//Creating the WKUserContentController.
    [controller addScriptMessageHandler:self name:@"observe"];//Adding a script handler to the controller and setting the userContentController property on the configuration.
    configuration.userContentController = controller;
    configuration.allowsInlineMediaPlayback = YES;
    
    //this configuration setting has no effect on our vast videoplayer
    //configuration.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone;
    [configuration.userContentController addScriptMessageHandler:self name:@"interOp"];
    
    // Set HttpCookie for Webview
    [EPLGlobal setWebViewCookie:self.webView];
 
    UIWindow *currentWindow = [EPLGlobal getKeyWindow];
    //provide the width & height of the webview else the video wont be displayed ********
    self.webView = [[WKWebView alloc] initWithFrame:CGRectMake(0,0,325,275) configuration:configuration];
    self.webView.scrollView.scrollEnabled = false;
    
    EPLLogInfo(@"width = %f, height = %f", self.webView.frame.size.width, self.webView.frame.size.height);
    
    [self.webView setNavigationDelegate:self];
    [self.webView setUIDelegate:self];
    self.webView.opaque = false;
    self.webView.backgroundColor = [UIColor blackColor];
    
    
    [self.webView loadRequest:request];//Load up webView with the url and add it to the view.
    
    [currentWindow addSubview:self.webView];
    [self.webView setHidden:true];
    
}


-(void)resumeAdVideo{
    NSString *exec = @"playAd();";
    [self.webView evaluateJavaScript:exec completionHandler:nil];
}

-(void)pauseAdVideo{
    NSString *exec = @"pauseAd();";
    [self.webView evaluateJavaScript:exec completionHandler:nil];
}


- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    
    if(message == nil)
        return;
    NSString *eventName = @"";
    NSDictionary *paramsDictionary = [NSDictionary new];
    
    if([message.body isKindOfClass:[NSString class]]){
        eventName = (NSString *)message.body;
    }
    else if([message.body isKindOfClass:[NSDictionary class]]){
        NSDictionary *messageDictionary = (NSDictionary *)message.body;
        if(messageDictionary.count > 0){
            eventName = [messageDictionary objectForKey:@"event"];
            paramsDictionary = [messageDictionary objectForKey:@"params"];
        }
    }
    
    EPLLogInfo(@"Parsed value %@",eventName);
    
    if ([eventName isEqualToString:@"video-complete"]) {
        EPLLogInfo(@"video-complete");
        [self stopOMIDAdSession];
        if ([self.delegate respondsToSelector:@selector(videoAdImpressionListeners:)]) {
            [self.delegate videoAdImpressionListeners:EPLVideoAdPlayerTrackerFourthQuartile];
        }
        
    } else if ([eventName isEqualToString:@"adReady"]) {
        EPLLogInfo(@"adReady");
        self.omidAdSession = [[EPLOMIDImplementation sharedInstance] createOMIDAdSessionforWebView:self.webView isVideoAd:true];
        if(paramsDictionary.count > 0){
            self.creativeURL = (NSString *)[paramsDictionary objectForKey:@"creativeUrl"];
            NSNumber *duration = [paramsDictionary objectForKey:@"duration"];
            self.vastURLContent = (NSString *)[paramsDictionary objectForKey:@"vastCreativeUrl"];
            self.vastXMLContent = (NSString *)[paramsDictionary objectForKey:@"vastXML"];
            self.videoAdOrientation = [EPLGlobal parseVideoOrientation:[paramsDictionary objectForKey:kANAspectRatio]];
            if(duration > 0){
                self.videoDuration = [duration intValue];
            }
            self.videoAdWidth = [[paramsDictionary objectForKey:@"width"] integerValue];
            self.videoAdHeight = [[paramsDictionary objectForKey:@"height"] integerValue];
        }
        if ([self.delegate respondsToSelector:@selector(videoAdReady)]) {
            [self.delegate videoAdReady];
        }
        
    } else if ([eventName isEqualToString:@"videoStart"]) {
        EPLLogInfo(@"%@", eventName);
        [self registerObserver];
        if ([self.delegate respondsToSelector:@selector(videoAdEventListeners:)]) {
            [self.delegate videoAdEventListeners:EPLVideoAdPlayerEventPlay];
        }
        
    } else if ([eventName isEqualToString:@"video-first-quartile"]) {
        EPLLogInfo(@"video-first-quartile");
        if ([self.delegate respondsToSelector:@selector(videoAdImpressionListeners:)]) {
            [self.delegate videoAdImpressionListeners:EPLVideoAdPlayerTrackerFirstQuartile];
        }
    }else if ([eventName isEqualToString:@"video-mid"]) {
        EPLLogInfo(@"video-mid");
        if ([self.delegate respondsToSelector:@selector(videoAdImpressionListeners:)]) {
            [self.delegate videoAdImpressionListeners:EPLVideoAdPlayerTrackerMidQuartile];
        }
        
    }else if ([eventName isEqualToString:@"video-third-quartile"]) {
        EPLLogInfo(@"video-third-quartile");
        if ([self.delegate respondsToSelector:@selector(videoAdImpressionListeners:)]) {
            [self.delegate videoAdImpressionListeners:EPLVideoAdPlayerTrackerThirdQuartile];
        }
    }
    
    else if ([eventName isEqualToString:@"video-skip"]) {
        EPLLogInfo(@"video-skip");
        [self stopOMIDAdSession];
        if ([self.delegate respondsToSelector:@selector(videoAdEventListeners:)]) {
            [self.webView removeFromSuperview];
            [self.delegate videoAdEventListeners:EPLVideoAdPlayerEventSkip];
        }
    }
    
    else if([eventName isEqualToString:@"video-fullscreen"] || [eventName isEqualToString:@"video-fullscreen-enter"]){
        EPLLogInfo(@"video-fullscreen");
        if ([self.delegate respondsToSelector:@selector(videoAdPlayerFullScreenEntered:)]) {
            [self.delegate videoAdPlayerFullScreenEntered:self];
            
        }
    }
    else if([eventName isEqualToString:@"video-fullscreen-exit"]){
        EPLLogInfo(@"video-fullscreen-exit");
        if ([self.delegate respondsToSelector:@selector(videoAdPlayerFullScreenExited:)]) {
            [self.delegate videoAdPlayerFullScreenExited:self];
            
        }
    }
    else if([eventName isEqualToString:@"video-error"] || [eventName isEqualToString:@"Timed-out"]){
        
        //we need to remove the webview to makesure we dont get any other response from the loaded index.html page
        [self removePlayer];
        EPLLogInfo(@"video player error");
        if([self.delegate respondsToSelector:@selector(videoAdLoadFailed:withAdResponseInfo:)]){
            NSError *error = EPLError(@"Timeout reached while parsing VAST", EPLAdResponseCode.INTERNAL_ERROR.code);
            [self.delegate videoAdLoadFailed:error withAdResponseInfo:nil];
        }
    }
    else if([eventName isEqualToString:@"audio-mute"]){
        EPLLogInfo(@"video player mute");
        if ([self.delegate respondsToSelector:@selector(videoAdEventListeners:)]) {
            [self.delegate videoAdEventListeners:EPLVideoAdPlayerEventMuteOn];
        }
    }
    else if ([eventName isEqualToString:@"audio-unmute"]){
        EPLLogInfo(@"video player unmute");
        if ([self.delegate respondsToSelector:@selector(videoAdEventListeners:)]) {
            [self.delegate videoAdEventListeners:EPLVideoAdPlayerEventMuteOff];
        }
    }
}

#pragma mark - WKNavigationDelegate.


- (WKWebView *)         webView: (WKWebView *)webView
 createWebViewWithConfiguration: (nonnull WKWebViewConfiguration *)inConfig
            forNavigationAction: (nonnull WKNavigationAction *)navigationAction
                 windowFeatures: (nonnull WKWindowFeatures *)windowFeatures
{
    if (navigationAction.targetFrame.isMainFrame)  { return nil; }
    
    //
    NSString *urlString = [[navigationAction.request URL] absoluteString];
    
    
    if (EPLClickThroughActionReturnURL != self.clickThroughAction) {
        if ([self.delegate respondsToSelector:@selector(videoAdWasClicked)]) {
            [self.delegate videoAdWasClicked];
        }
    }
    
    switch (self.clickThroughAction) {
        case EPLClickThroughActionReturnURL:
            [self resumeAdVideo];
            
            if ([self.delegate respondsToSelector:@selector(videoAdWasClickedWithURL:)]) {
                [self.delegate videoAdWasClickedWithURL:urlString];
            }
            
            EPLLogDebug(@"ClickThroughURL=%@", urlString);
            break;
            
        case EPLClickThroughActionOpenDeviceBrowser:
            if ([self.delegate respondsToSelector:@selector(videoAdWillLeaveApplication:)])  {
                [self.delegate videoAdWillLeaveApplication:self];
            }
            
            [EPLGlobal openURL:urlString];
            break;
            
        case EPLClickThroughActionOpenSDKBrowser:
            if (!self.browserViewController) {
                self.browserViewController = [[EPLBrowserViewController alloc] initWithURL: [NSURL URLWithString:urlString]
                                                                                 delegate: self
                                                                 delayPresentationForLoad: self.landingPageLoadsInBackground ];
                
                if (!self.browserViewController) {
                    if([self.delegate respondsToSelector:@selector(videoAdError:)]){
                        NSError *error = EPLError(@"EPLBrowserViewController initialization FAILED.", EPLAdResponseCode.INTERNAL_ERROR.code);
                        [self.delegate videoAdError:error];
                    }
                }
                
            } else {
                [self.browserViewController setUrl:[NSURL URLWithString:urlString]];
            }
            
            break;
            
        default:
            EPLLogError(@"UNKNOWN EPLClickThroughAction.  (%lu)", (unsigned long)self.clickThroughAction);
    }
    
    //
    return nil;
}


-(void) webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation{
    EPLLogInfo(@"web page loading started");
    
}

- (void) webView: (WKWebView *) webView didFinishNavigation: (WKNavigation *) navigation
{
    NSString *exec = @"";
    if([self.vastContent length] > 0){
        
        NSString *videoOptions = [[EPLVideoPlayerSettings sharedInstance] fetchInStreamVideoSettings];

        NSString *exec_template = @"createVastPlayerWithContent('%@','%@');";
        exec = [NSString stringWithFormat:exec_template, self.vastContent,videoOptions];

        [self.webView evaluateJavaScript:exec completionHandler:nil];
        
    }else if([self.vastURL length] > 0){
        EPLLogInfo(@"Not implemented");
    }else if([self.jsonContent length] > 0){
        NSString * mediationJsonString = [NSString stringWithFormat:@"processMediationAd('%@')",[self.jsonContent stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLFragmentAllowedCharacterSet]]];
        [self.webView evaluateJavaScript:mediationJsonString completionHandler:nil];
    }
    EPLLogInfo(@"web page loading completed");
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    NSURL *URL = navigationAction.request.URL;
    NSString *URLScheme = URL.scheme;
    
    if ([URLScheme isEqualToString:@"anwebconsole"]) {
        [self printConsoleLogWithURL:URL];
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }
    
    decisionHandler(WKNavigationActionPolicyAllow);
}




#pragma mark - EPLBrowserViewControllerDelegate.

- (UIViewController *)rootViewControllerForDisplayingBrowserViewController:(EPLBrowserViewController *)controller
{
    return [self.webView an_parentViewController] ;
}


- (void)browserViewController:(EPLBrowserViewController *)controller
     couldNotHandleInitialURL:(NSURL *)url
{
    EPLLogTrace(@"UNUSED.");
}


- (void)browserViewController:(EPLBrowserViewController *)controller
             browserIsLoading:(BOOL)isLoading
{
    EPLLogTrace(@"UNUSED.");
}


- (void)willPresentBrowserViewController:(EPLBrowserViewController *)controller
{
    if ([self.delegate respondsToSelector:@selector(videoAdWillPresent:)]) {
        [self.delegate videoAdWillPresent:self];
    }
}


- (void)didPresentBrowserViewController:(EPLBrowserViewController *)controller
{
    if ([self.delegate respondsToSelector:@selector(videoAdDidPresent:)]) {
        [self.delegate videoAdDidPresent:self];
    }
}


- (void)willDismissBrowserViewController:(EPLBrowserViewController *)controller
{
    if ([self.delegate respondsToSelector:@selector(videoAdWillClose:)]) {
        [self.delegate videoAdWillClose:self];
    }
}


- (void)didDismissBrowserViewController:(EPLBrowserViewController *)controller
{
    self.browserViewController = nil;
    [self resumeAdVideo];
}


- (void)willLeaveApplicationFromBrowserViewController:(EPLBrowserViewController *)controller
{
    EPLLogTrace(@"UNUSED.");
}

#pragma mark - EPLWebConsole

- (void)printConsoleLogWithURL:(NSURL *)URL {
    NSString *decodedString = [[URL absoluteString] stringByRemovingPercentEncoding];
    EPLLogDebug(@"%@", decodedString);
}
@end

