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

#import <Foundation/Foundation.h>
#import "EPLTrackerInfo.h"
#import "EPLUniversalTagAdServerResponse.h"
#import "EPLAdFetcherResponse.h"
#import "EPLLocation.h"
#import "EPLAdConstants.h"
#import "EPLAdViewInternalDelegate.h"
#import "EPLAdProtocol.h"
#import "EPLGlobal.h"
#import "EPLAdFetcherBase+PrivateMethods.h"
#import "EPLAdFetcherBase.h"



@interface EPLAdFetcher : EPLAdFetcherBase

- (nonnull instancetype)initWithDelegate:(nonnull id)delegate;

- (void)startAutoRefreshTimer;
- (void)restartAutoRefreshTimer;
- (void)stopAutoRefreshTimer;

- (CGSize)getWebViewSizeForCreativeWidth:(nonnull NSString *)width
                               andHeight:(nonnull NSString *)height;

- (BOOL)allocateAndSetWebviewWithSize: (CGSize)webviewSize
                              content: (nonnull NSString *)webviewContent
                        isXMLForVideo: (BOOL)isContentXMLForVideo;

- (BOOL)allocateAndSetWebviewFromCachedAdObjectHandler;

// fire impression trackers for Begin To Render cases
- (void) checkifBeginToRenderAndFireImpressionTracker:(nonnull EPLBaseAdObject *) ad;

@end


#pragma mark -

// NB  EPLAdFetcherFoundationDelegate is used in EPLInstreamVideoAd entry point.
@protocol  EPLAdFetcherFoundationDelegate <EPLRequestTagBuilderCore, EPLAdProtocolFoundation>


@optional
//
- (void)       adFetcher: (nonnull EPLAdFetcherBase *)fetcher
     didFinishRequestWithResponse: (nonnull EPLAdFetcherResponse *)response;
@end



#pragma mark -

// NB  EPLAdFetcherDelegate is used for Banner, Interstitial entry point.
//
@protocol  EPLAdFetcherDelegate <EPLAdFetcherFoundationDelegate, EPLAdProtocolBrowser, EPLAdProtocolPublicServiceAnnouncement, EPLAdViewInternalDelegate>

@required

- (CGSize)requestedSizeForAdFetcher:(nonnull EPLAdFetcherBase *)fetcher;


@optional

// NB  autoRefreshIntervalForAdFetcher: and videoAdTypeForAdFetcher: are required for EPLBannerAdView,
//       but are not used by any other adunit.
//
- (NSTimeInterval) autoRefreshIntervalForAdFetcher:(nonnull EPLAdFetcher *)fetcher;
- (EPLVideoAdSubtype) videoAdTypeForAdFetcher:(nonnull EPLAdFetcher *)fetcher;


//   If enableNativeRendering is not set, the default is false.
//   A value of false Indicates that NativeRendering is disabled
//   enableNativeRendering is sufficient to BannerAd entry point.
-(BOOL) enableNativeRendering;

//   Set the Orientation of the Video rendered to BannerAdView taken from  EPLAdWebViewController
//   setVideoAdOrientation is sufficient to BannerAd entry point.
-(void)setVideoAdOrientation:(EPLVideoOrientation)videoOrientation;

-(void)setVideoAdWidth:(NSInteger)videoAdWidth;

-(void)setVideoAdHeight:(NSInteger)videoAdHeight;

@end


