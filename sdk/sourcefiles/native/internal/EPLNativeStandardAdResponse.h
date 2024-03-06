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
#import "EPLGlobal.h"
#import "EPLNativeAdStarRating.h"
#import "EPLImage.h"
@interface EPLNativeStandardAdResponse : EPLNativeAdResponse

@property (nonatomic, readwrite, strong) NSString *title;
@property (nonatomic, readwrite, strong) NSString *body;
@property (nonatomic, readwrite, strong) NSString *callToAction;
@property (nonatomic, readwrite, strong) EPLNativeAdStarRating *rating;
@property (nonatomic, readwrite, strong) EPLImage *mainImage;
@property (nonatomic, readwrite, strong) EPLImage *iconImage;
@property (nonatomic, readwrite, assign) CGSize mainImageSize;
@property (nonatomic, readwrite, strong) NSURL *mainImageURL;
@property (nonatomic, readwrite, assign) CGSize iconImageSize;
@property (nonatomic, readwrite, strong) NSURL *iconImageURL;
@property (nonatomic, readwrite, strong) NSDictionary *customElements;
@property (nonatomic, readwrite, strong) NSString *adObjectMediaType;
@property (nonatomic, readwrite, strong) NSString *creativeId;
@property (nonatomic, readwrite, strong) NSString *additionalDescription;
@property (nonatomic, readwrite, strong) NSArray<NSString *> *clickTrackers;
@property (nonatomic, readwrite, strong) NSArray<NSString *> *impTrackers;
@property (nonatomic, readwrite, strong) NSURL *clickURL;
@property (nonatomic, readwrite, strong) NSURL *clickFallbackURL;
@property (nonatomic, readwrite, strong) NSString *sponsoredBy;
@property (nonatomic, readwrite, strong) NSString *vastXML;
@property (nonatomic, readwrite, strong) NSString *privacyLink;
@property (nonatomic, readwrite, strong) NSString *nativeRenderingUrl;
@property (nonatomic, readwrite, strong) NSString *nativeRenderingObject;
@property (nonatomic, readwrite, strong)  EPLAdResponseInfo *adResponseInfo;
@property (nonatomic, readwrite, assign)  EPLImpressionType      impressionType;

@end
