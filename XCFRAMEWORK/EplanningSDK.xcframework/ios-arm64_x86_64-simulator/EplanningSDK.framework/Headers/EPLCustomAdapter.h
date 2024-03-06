/*   Copyright 2013 APPNEXUS INC
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import "EPLTargetingParameters.h"
#import "EPLAdConstants.h"
#import "EPLAdResponseCode.h"




@protocol EPLCustomAdapterDelegate <NSObject>
- (void)didFailToLoadAd:(nonnull EPLAdResponseCode *)errorCode;
- (void)adWasClicked;
- (void)willPresentAd;
- (void)didPresentAd;
- (void)willCloseAd;
- (void)didCloseAd;
- (void)adDidLogImpression;
- (void)willLeaveApplication;
@end




@protocol EPLCustomAdapter <NSObject>
@property (nonatomic, readwrite, weak, nullable) id delegate;
@end




@protocol EPLCustomAdapterBannerDelegate;

@protocol EPLCustomAdapterBanner <EPLCustomAdapter>

- (void)requestBannerAdWithSize:(CGSize)size
             rootViewController:(nullable UIViewController *)rootViewController
                serverParameter:(nullable NSString *)parameterString
                       adUnitId:(nullable NSString *)idString
            targetingParameters:(nullable EPLTargetingParameters *)targetingParameters;


@end




@protocol EPLCustomAdapterInterstitialDelegate;

@protocol EPLCustomAdapterInterstitial <EPLCustomAdapter>

- (void)requestInterstitialAdWithParameter:(nullable NSString *)parameterString
                                  adUnitId:(nullable NSString *)idString
                       targetingParameters:(nullable EPLTargetingParameters *)targetingParameters;
- (void)presentFromViewController:(nullable UIViewController *)viewController;

@optional
- (BOOL)isReady;

@end




@protocol EPLCustomAdapterBannerDelegate <EPLCustomAdapterDelegate>
- (void)didLoadBannerAd:(nullable UIView *)view;
@end




@protocol EPLCustomAdapterInterstitialDelegate <EPLCustomAdapterDelegate>
- (void)didLoadInterstitialAd:(nullable id<EPLCustomAdapterInterstitial>)adapter;
- (void)failedToDisplayAd;
@end
