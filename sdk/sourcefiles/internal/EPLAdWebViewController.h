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

#import "EPLAdViewInternalDelegate.h"
#import "EPLMRAIDUtil.h"
@import OMSDK_Microsoft;

@class EPLAdWebViewControllerConfiguration;
@class EPLMRAIDExpandProperties;
@class EPLMRAIDResizeProperties;
@class EPLMRAIDOrientationProperties;

@protocol EPLAdWebViewControllerANJAMDelegate;
@protocol EPLAdWebViewControllerBrowserDelegate;
@protocol EPLAdWebViewControllerLoadingDelegate;
@protocol EPLAdWebViewControllerMRAIDDelegate;
@protocol EPLAdWebViewControllerVideoDelegate;



@interface EPLAdWebViewController : NSObject

@property (nonatomic, readonly, assign)  BOOL         isMRAID;
@property (nonatomic, readonly, strong)  UIView      *contentView;
@property (nonatomic, readonly, assign)  BOOL         completedFirstLoad;
@property (nonatomic, readwrite, strong) OMIDMicrosoftAdSession *omidAdSession;

@property (nonatomic, readonly, strong)  EPLAdWebViewControllerConfiguration  *configuration;

@property (nonatomic, readwrite, weak)  id<EPLAdViewInternalDelegate>  adViewANJAMInternalDelegate;
@property (nonatomic, readwrite, weak)  id<EPLAdViewInternalDelegate>  adViewDelegate;

@property (nonatomic, readwrite, weak)  id<EPLAdWebViewControllerANJAMDelegate>      anjamDelegate;
@property (nonatomic, readwrite, weak)  id<EPLAdWebViewControllerBrowserDelegate>    browserDelegate;
@property (nonatomic, readwrite, weak)  id<EPLAdWebViewControllerLoadingDelegate>    loadingDelegate;
@property (nonatomic, readwrite, weak)  id<EPLAdWebViewControllerMRAIDDelegate>      mraidDelegate;
@property (nonatomic, readwrite, weak)  id<EPLAdWebViewControllerVideoDelegate>      videoDelegate;

@property (nonatomic, readwrite, assign)  NSTimeInterval  checkViewableTimeInterval;
@property (nonatomic, readonly, assign)  EPLVideoOrientation  videoAdOrientation;
@property (nonatomic, readonly, assign)  NSInteger  videoAdWidth;
@property (nonatomic, readonly, assign)  NSInteger  videoAdHeight;
@property (nonatomic, readwrite, assign) CGSize videoPlayerSize;


- (instancetype)initWithSize:(CGSize)size
                         URL:(NSURL *)URL
              webViewBaseURL:(NSURL *)baseURL;

- (instancetype)initWithSize:(CGSize)size
                         URL:(NSURL *)URL
              webViewBaseURL:(NSURL *)baseURL
               configuration:(EPLAdWebViewControllerConfiguration *)configuration;

- (instancetype)initWithSize:(CGSize)size
                        HTML:(NSString *)html
              webViewBaseURL:(NSURL *)baseURL;

- (instancetype)initWithSize:(CGSize)size
                        HTML:(NSString *)html
              webViewBaseURL:(NSURL *)baseURL
               configuration:(EPLAdWebViewControllerConfiguration *)configuration;

- (instancetype) initWithSize: (CGSize)size
                     videoXML: (NSString *)videoXML;


- (void)adDidFinishExpand;
- (void)adDidFinishResize:(BOOL)success
              errorString:(NSString *)errorString
                isResized:(BOOL)isResized;
- (void)adDidResetToDefault;
- (void)adDidHide;
- (void)adDidFailCalendarEditWithErrorString:(NSString *)errorString;
- (void)adDidFailPhotoSaveWithErrorString:(NSString *)errorString;

- (void)fireJavaScript:(NSString *)javascript;
- (void)updateViewability:(BOOL)isViewable;


@end




@interface EPLAdWebViewControllerConfiguration : NSObject <NSCopying>

@property (nonatomic, readwrite, assign)  BOOL          scrollingEnabled;
@property (nonatomic, readwrite, assign)  BOOL          navigationTriggersDefaultBrowser;
@property (nonatomic, readwrite, assign)  EPLMRAIDState  initialMRAIDState;
@property (nonatomic, readwrite, assign)  BOOL          userSelectionEnabled;
@property (nonatomic, readwrite, assign)  BOOL          isVASTVideoAd;

@end



#pragma mark - Protocol definitions.

@protocol EPLAdWebViewControllerANJAMDelegate <NSObject>

- (void)handleANJAMURL:(NSURL *)URL;

@end


@protocol EPLAdWebViewControllerBrowserDelegate <NSObject>

- (void)openDefaultBrowserWithURL:(NSURL *)URL;
- (void)openInAppBrowserWithURL:(NSURL *)URL;

@end


// NB  This delegate is used unconventionally as a means to call back through two class compositions:
//     EPLAdWebViewController calls EPLMRAIDContainerView calls EPLAdFetcher.
//
@protocol EPLAdWebViewControllerLoadingDelegate <NSObject>

@required
- (void) didCompleteFirstLoadFromWebViewController:(EPLAdWebViewController *)controller;

@optional
- (void) immediatelyRestartAutoRefreshTimerFromWebViewController:(EPLAdWebViewController *)controller;
- (void) stopAutoRefreshTimerFromWebViewController:(EPLAdWebViewController *)controller;

@end


@protocol EPLAdWebViewControllerMRAIDDelegate <NSObject>

- (CGRect)defaultPosition;
- (CGRect)currentPosition;
- (BOOL)isViewable;
- (CGRect)visibleRect;
- (CGFloat)exposedPercent;

- (void)adShouldExpandWithExpandProperties:(EPLMRAIDExpandProperties *)expandProperties;
- (void)adShouldAttemptResizeWithResizeProperties:(EPLMRAIDResizeProperties *)resizeProperties;
- (void)adShouldSetOrientationProperties:(EPLMRAIDOrientationProperties *)orientationProperties;
- (void)adShouldSetUseCustomClose:(BOOL)useCustomClose;
- (void)adShouldClose;

- (void)adShouldOpenCalendarWithCalendarDict:(NSDictionary *)calendarDict;
- (void)adShouldSavePictureWithUri:(NSString *)uri;
- (void)adShouldPlayVideoWithUri:(NSString *)uri;

@end


@protocol EPLAdWebViewControllerVideoDelegate <NSObject>

-(void) videoAdReady;
-(void) videoAdLoadFailed:(NSError *)error withAdResponseInfo:(EPLAdResponseInfo *)adResponseInfo;
- (void) videoAdError:(NSError *)error;

- (void) videoAdPlayerFullScreenEntered: (EPLAdWebViewController *)videoAd;
- (void) videoAdPlayerFullScreenExited: (EPLAdWebViewController *)videoAd;


@end

