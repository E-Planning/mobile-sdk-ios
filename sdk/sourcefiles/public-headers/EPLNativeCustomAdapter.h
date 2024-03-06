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

#import "EPLAdConstants.h"
#import "EPLTargetingParameters.h"
#import "EPLNativeMediatedAdResponse.h"

@protocol EPLNativeCustomAdapterRequestDelegate;
@protocol EPLNativeCustomAdapterAdDelegate;

/*!
 * Defines a protocol by which an external native ad SDK can be mediated by AppNexus.
 */
@protocol EPLNativeCustomAdapter <NSObject>

@required
/*!
 * Allows the AppNexus SDK to be notified of a successful or failed request load.
 */
@property (nonatomic, readwrite, weak, nullable) id<EPLNativeCustomAdapterRequestDelegate> requestDelegate;
/*!
 * Allows the AppNexus SDK to be notified of actions performed on the native view.
 */
@property (nonatomic, readwrite, weak, nullable) id<EPLNativeCustomAdapterAdDelegate> nativeAdDelegate;


@optional
/*!
 * @return YES if the response is no longer valid, for example, if too much time has elapsed
 * since receiving it. NO if the response is still valid.
 */
@property (nonatomic, readwrite, assign, getter=hasExpired) BOOL expired;

/*! 
 * Will be called by the AppNexus SDK when a mediated native ad request should be initiated.
 */
- (void)requestNativeAdWithServerParameter:(nullable NSString *)parameterString
                                  adUnitId:(nullable NSString *)adUnitId
                       targetingParameters:(nullable EPLTargetingParameters *)targetingParameters;

/*!
* Will be called by the AppNexus SDK when a CSR native ad request should be initiated.
*/
- (void) requestAdwithPayload:(nonnull NSString *) payload targetingParameters:(nullable EPLTargetingParameters *)targetingParameters;

@optional
/*!
 * Should be implemented if the mediated SDK handles both impression tracking and click tracking automatically.
 */
- (void)registerViewForImpressionTrackingAndClickHandling:(nonnull UIView *)view
                                   withRootViewController:(nonnull UIViewController *)rvc
                                           clickableViews:(nullable NSArray *)clickableViews;

/*!
 * Should be implemented if the mediated SDK handles only impression tracking automatically, and needs to
 * be manually notified that a user click has been detected.
 *
 * @note handleClickFromRootViewController: should be implemented as well.
 */
- (void)registerViewForImpressionTracking:(nonnull UIView *)view;

/*!
 * Should notify the mediated SDK that a click was registered, and that a click-through should be
 * action should be performed.
 */
- (void)handleClickFromRootViewController:(nonnull UIViewController *)rvc;

/*!
 * Should notify the mediated SDK that the native view should no longer be tracked.
 */
- (void)unregisterViewFromTracking;

@end

/*!
 * Callbacks for when the native ad assets are being loaded.
 */
@protocol EPLNativeCustomAdapterRequestDelegate <NSObject>

@optional
- (void)didLoadNativeAd:(nonnull EPLNativeMediatedAdResponse *)response;
- (void)didFailToLoadNativeAd:(nonnull EPLAdResponseCode *)errorCode;

@end

/*!
 * Callbacks for when the native view has been registered and is being tracked.
 */
@protocol EPLNativeCustomAdapterAdDelegate <NSObject>

@optional
-(void)didInteractWithParams;

- (void)adWasClicked;
- (void)willPresentAd;
- (void)didPresentAd;
- (void)willCloseAd;
- (void)didCloseAd;
- (void)willLeaveApplication;
- (void)adDidLogImpression;

@end
