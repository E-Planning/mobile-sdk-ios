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

#import <UIKit/UIKit.h>

#import "EPLAdConstants.h"
#import "EPLAdProtocol.h"
#import "EPLAdFetcherResponse.h"

// NB  Native does not use EPLAdViewInternalDelegate, but instead has its own specific delegates for the
//       request and response halves of Native entry point.
//     See EPLNativeAdRequestDelegate and EPLNativeAdDelegate (for response).
//
@protocol EPLAdViewInternalDelegate <NSObject>

@optional
- (EPLClickThroughAction)clickThroughAction;

- (void)adWasClickedWithURL:(NSString *)urlString;

- (void)adDidReceiveAd:(id)adObject;
- (void)ad:(id)loadInstance didReceiveNativeAd:(id)responseInstance;
- (void)lazyAdDidReceiveAd:(id)adObject;

- (BOOL)valueOfEnableLazyLoad;
- (BOOL)valueOfIsLazySecondPassThroughAdUnit;

@required
- (void)adRequestFailedWithError:(NSError *)error andAdResponseInfo:(EPLAdResponseInfo *)adResponseInfo;

- (void)adWasClicked;
- (void)adDidLogImpression;
- (void)adWillPresent;
- (void)adDidPresent;
- (void)adWillClose;
- (void)adDidClose;
- (void)adWillLeaveApplication;
- (void)adDidReceiveAppEvent:(NSString *)name withData:(NSString *)data;

- (NSString *)adTypeForMRAID;
- (NSMutableDictionary<NSString *, NSArray<NSString *> *> *)customkeywordsForANJAM;

- (UIViewController *)displayController;
- (BOOL)landingPageLoadsInBackground;

- (void)adInteractionDidBegin;
- (void)adInteractionDidEnd;


@end



@protocol EPLBannerAdViewInternalDelegate <EPLAdViewInternalDelegate>

- (NSNumber *)transitionInProgress;
- (CGSize) landscapeBannerVideoPlayerSize;
- (CGSize) portraitBannerVideoPlayerSize;
- (CGSize) squareBannerVideoPlayerSize;

@end



@class EPLMRAIDOrientationProperties;

@protocol EPLInterstitialAdViewInternalDelegate <EPLAdViewInternalDelegate>

- (void)adFailedToDisplay;
- (void)adShouldClose;
- (void)adShouldSetOrientationProperties:(EPLMRAIDOrientationProperties *)orientationProperties;
- (void)adShouldUseCustomClose:(BOOL)useCustomClose;

@end

