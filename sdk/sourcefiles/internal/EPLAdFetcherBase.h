/*   Copyright 2019 APPNEXUS INC
 
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

#import "EPLAdFetcherResponse.h"
#import "EPLAdProtocol.h"
#import "EPLUniversalTagAdServerResponse.h"
#import "EPLAdConstants.h"

#import "EPLNativeAdRequest.h"
#import "EPLMultiAdRequest.h"
#if !APPNEXUS_NATIVE_MACOS_SDK
#import "EPLAdViewInternalDelegate.h"
#endif

#pragma mark -

@protocol  EPLRequestTagBuilderCore

// customKeywords is shared between the adunits and the fetcher.
//
// NB  This definition of customKeywords should not be confused with the public facing EPLTargetingParameters.customKeywords
//       which is shared between fetcher and the mediation adapters.
//     The version here is a dictionary of arrays of strings, the public facing version is simply a dictionary of strings.
//
@property (nonatomic, readwrite, strong, nullable)  NSMutableDictionary<NSString *, NSArray<NSString *> *>  *customKeywords;

// NB  Represents lazy evaluation as a means to get most current value of primarySize (eg: from self.containerSize).
//     In addition, this method combines collection of all three size parameters to avoid synchronization issues.
//
- (nonnull NSDictionary *) internalDelegateUniversalTagSizeParameters;

- (nonnull NSString *)internalGetUTRequestUUIDString;
- (void)internalUTRequestUUIDStringReset;

- (nonnull NSArray<NSValue *> *)adAllowedMediaTypes;

@optional
//
//   If rendererId is not set, the default is zero (0).
//   A value of zero indicates that renderer_id will not be sent in the UT Request.
//   nativeRendererId is sufficient for EPLBannerAdView and EPLNativeAdRequest entry point.
//
- (NSInteger) nativeAdRendererId;

@end


@protocol  EPLMultiAdProtocol

@property (nonatomic, readwrite, weak, nullable)  EPLMultiAdRequest                                    *marManager;


/**
 This property is only used with EPLMultiAdRequest.
 It associates a unique identifier with each adunit per request, allowing ad objects in the UT Response to be
   matched with adunit elements of the UT Request.
 NB  This value is updated for each UT Request.  It does not persist across the lifecycle of the instance.
 */
@property (nonatomic, readwrite, strong, nonnull)  NSString  *utRequestUUIDString;

/*!
 * Used only in MultiAdRequest to pass ad object returned by impbus directly to the adunit though it was requested by MAR UT Request.
 */
- (void)ingestAdResponseTag: (nonnull id)tag;

@end


@interface EPLAdFetcherBase : NSObject

@property (nonatomic, readwrite, strong, nullable)  NSMutableArray<id>    *ads;
@property (nonatomic, readwrite, strong, nullable)  NSString              *noAdUrl;

@property (nonatomic, readwrite)                    BOOL  isFetcherLoading;
@property (nonatomic, readwrite, strong, nullable)  id    adObjectHandler;

@property (nonatomic, readwrite, weak, nullable)    id                  delegate;
@property (nonatomic, readwrite, weak, nullable)    EPLMultiAdRequest   *fetcherMARManager;
@property (nonatomic, readwrite, weak, nullable)    EPLMultiAdRequest   *adunitMARManager;


//
- (nonnull instancetype)init;
- (nonnull instancetype)initWithDelegate:(nonnull id)delegate andAdUnitMultiAdRequestManager:(nonnull EPLMultiAdRequest *)adunitMARManager;
- (nonnull instancetype)initWithMultiAdRequestManager:(nonnull EPLMultiAdRequest *)marManager;
- (void)requestAd;
- (void)stopAdLoad;
- (void)fireResponseURL:(nullable NSString *)responseURLString
                 reason:(nonnull EPLAdResponseCode *)reason
               adObject:(nonnull id)adObject;


- (void)prepareForWaterfallWithAdServerResponseTag: (nullable NSDictionary<NSString *, id> *)ads;

- (void) beginWaterfallWithAdObjects:(nonnull NSMutableArray<id> *)ads;


@end





