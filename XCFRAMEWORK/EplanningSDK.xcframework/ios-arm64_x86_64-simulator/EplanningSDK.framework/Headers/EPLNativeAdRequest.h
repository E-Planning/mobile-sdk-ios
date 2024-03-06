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

#import "EPLNativeAdResponse.h"
#import "EPLAdProtocol.h"




@protocol EPLNativeAdRequestDelegate;
/*!
 * An EPLNativeAdRequest facilitates the loading of native ad assets from the server. Here is a sample workflow:
 *
 * @code
 * EPLNativeAdRequest *request = [[EPLNativeAdRequest alloc] init];
 * request.gender = MALE;
 * request.shouldLoadIconImage = YES;
 * request.delegate = self;
 * [request loadAd];
 * @endcode
 *
 * The response is received as part of the EPLNativeAdRequestDelegate callbacks. See EPLNativeAdResponse for more information.
 *
 * @code
 * - (void)adRequest:(EPLNativeAdRequest *)request didReceiveResponse:(EPLNativeAdResponse *)response {
 *      // Handle response
 * }
 *
 * - (void)adRequest:(EPLNativeAdRequest *)request didFailToLoadWithError:(NSError *)error {
 *      // Handle failure
 * }
 * @endcode
 *
 */
@interface EPLNativeAdRequest : NSObject <EPLNativeAdRequestProtocol>

/*!
 * If YES, an icon image will automatically be downloaded and included in the response.
 */
@property (nonatomic, readwrite, assign) BOOL shouldLoadIconImage;

/*!
 * If YES, a main image will automatically be downloaded and included in the response.
 */
@property (nonatomic, readwrite, assign) BOOL shouldLoadMainImage;

/*!
 * The delegate which is notified of a successful or failed request. This should be set before calling [EPLNativeAdRequest loadAd].
 */
@property (nonatomic, readwrite, weak, nullable) id<EPLNativeAdRequestDelegate> delegate;


/**
 *  rendererId :  Native Assembly renderer_id that is associated with the placement.
 *  If rendererId is not set, the default is zero (0).
 *  A value of zero indicates that renderer_id will not be sent in the UT Request.
 */
@property (nonatomic, readwrite)  NSInteger  rendererId;


/*!
 * Requests a set of native ad assets. This method may be called multiple times simultaneously. The delegate will
 * be notified once for each call to this method.
 */
- (void)loadAd;

@end




/*!
 * Defines the callbacks for each load of a EPLNativeAdRequest instance.
 */
@protocol EPLNativeAdRequestDelegate <NSObject>

/*!
 * Called when a native ad request was successful. If [EPLNativeAdRequest shouldLoadIconImage]
 * or [EPLNativeAdRequest shouldLoadMainImage] were set to YES, this method will be called only
 * after the image resources have been retrieved.
 *
 * @param response Contains the native ad assets.
 *
 * @note If errors are encountered in resource retrieval, this method will still be called. However, the
 * [EPLNativeAdResponse iconImage] or [EPLNativeAdResponse mainImage] properties may be nil.
 */
- (void)adRequest:(nonnull EPLNativeAdRequest *)request didReceiveResponse:(nonnull EPLNativeAdResponse *)response;

/*!
 * Called when a native ad request was unsuccessful.
 * @see EPLAdResponseCode in EPLAdConstants.h for possible error code values.
 */
- (void)adRequest:(nonnull EPLNativeAdRequest *)request didFailToLoadWithError:(nonnull NSError *)error withAdResponseInfo:(nullable EPLAdResponseInfo *)adResponseInfo;

@end
