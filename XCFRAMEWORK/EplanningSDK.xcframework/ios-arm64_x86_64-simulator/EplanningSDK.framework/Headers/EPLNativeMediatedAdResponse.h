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

@protocol EPLNativeCustomAdapter;

/*!
 * Represents a response which should be created, populated, and returned
 * by a custom adapter.
 * @see EPLNativeAdResponse for descriptions of all the properties.
 */
@interface EPLNativeMediatedAdResponse : EPLNativeAdResponse

/*!
 * Designated initializer.
 *
 * @param adapter The mediation adapter which provided the native assets for this response.
 * @param networkCode The network code for the mediated adapter.
 */
- (nullable instancetype)initWithCustomAdapter:(nullable id<EPLNativeCustomAdapter>)adapter
                          networkCode:(EPLNativeAdNetworkCode)networkCode;

@property (nonatomic, readwrite, strong, nullable) NSString *title;
@property (nonatomic, readwrite, strong, nullable) NSString *body;
@property (nonatomic, readwrite, strong, nullable) NSString *callToAction;
@property (nonatomic, readwrite, strong, nullable) EPLNativeAdStarRating *rating;
@property (nonatomic, readwrite, strong, nullable) UIImage *mainImage;
@property (nonatomic, readwrite, strong, nullable) NSURL *mainImageURL;
@property (nonatomic, readwrite, strong, nullable) UIImage *iconImage;
@property (nonatomic, readwrite, strong, nullable) NSURL *iconImageURL;
@property (nonatomic, readwrite, strong, nullable) NSDictionary *customElements;

/*!
 * The mediation adapter which provided the native assets for this response.
 */
@property (nonatomic, readonly, strong, nullable) id<EPLNativeCustomAdapter> adapter;

@end