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

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>
#import "EPLAdConstants.h"



#pragma mark - Constants


#define EPL_ERROR_DOMAIN @"com.appnexus.sdk"
#define EPL_ERROR_TABLE @"errors"

#define EPL_DEFAULT_PLACEMENT_ID		@"default_placement_id"


#if !APPNEXUS_NATIVE_MACOS_SDK
    #define EPL_SDK_VERSION                  @"8.11.0"
#else
    #define EPL_SDK_VERSION                  @"8.11.0-mac"
#endif




#define APPNEXUS_BANNER_SIZE		CGSizeMake(320, 50)
#define APPNEXUS_MEDIUM_RECT_SIZE	CGSizeMake(300, 250)
#define APPNEXUS_LEADERBOARD_SIZE	CGSizeMake(728, 90)
#define APPNEXUS_WIDE_SKYSCRAPER_SIZE	CGSizeMake(160, 600)

#define APPNEXUS_SIZE_UNDEFINED         CGSizeMake(-1, -1)


#define kAppNexusNativeAdAboutToExpireInterval 60
#define kAppNexusRequestTimeoutInterval 30.0
#define kAppNexusAnimationDuration 0.4f
#define kAppNexusMediationNetworkTimeoutInterval 15.0
#define kAppNexusMRAIDCheckViewableFrequency 1.0
#define kAppNexusBannerAdTransitionDefaultDuration 1.0
#define kAppNexusNativeAdImageDownloadTimeoutInterval 10.0
#define kAppNexusNativeAdCheckViewabilityForTrackingFrequency 0.25
#define kAppNexusNativeAdIABShouldBeViewableForTrackingDuration 1.0

#define kANAdSize1x1 CGSizeMake(1,1)

typedef NS_ENUM(NSUInteger, EPLAllowedMediaType) {
    EPLAllowedMediaTypeBanner        = 1,
    EPLAllowedMediaTypeInterstitial  = 3,
    EPLAllowedMediaTypeVideo         = 4,
    EPLAllowedMediaTypeHighImpact    = 11,
    EPLAllowedMediaTypeNative        = 12
};

typedef NS_ENUM(NSUInteger, EPLVideoAdSubtype) {
    EPLVideoAdSubtypeUnknown = 0,
    EPLVideoAdSubtypeInstream,
    EPLVideoAdSubtypeBannerVideo
};

typedef NS_ENUM(NSUInteger, EPLImpressionType) {
    EPLBeginToRender, // When WebView starts to load the html content
    EPLViewableImpression // When 1px of the Ad is Visible to user
};



extern NSString * __nonnull const  EPLInternalDelgateTagKeyPrimarySize;
extern NSString * __nonnull const  EPLInternalDelegateTagKeySizes;
extern NSString * __nonnull const  EPLInternalDelegateTagKeyAllowSmallerSizes;

extern NSString * __nonnull const  kANUniversalAdFetcherWillRequestAdNotification;
extern NSString * __nonnull const  kANUniversalAdFetcherAdRequestURLKey;
extern NSString * __nonnull const  kANUniversalAdFetcherWillInstantiateMediatedClassNotification;
extern NSString * __nonnull const  kANUniversalAdFetcherMediatedClassKey;

extern NSString * __nonnull const  kANUniversalAdFetcherDidReceiveResponseNotification;
extern NSString * __nonnull const  kANUniversalAdFetcherAdResponseKey;                 

static NSString * __nonnull const kANCreativeId             = @"creativeId";
static NSString * __nonnull const kANImpressionUrls         = @"impressionUrls";
static NSString * __nonnull const kANAspectRatio            = @"aspectRatio";
static NSString * __nonnull const kANAdResponseInfo     = @"adResponseInfo";


#pragma mark - Banner AutoRefresh

// These constants control the default behavior of the ad view autorefresh (i.e.,
// how often the view will fetch a new ad).  Ads will only autorefresh
// when they are visible.

// Default autorefresh interval: By default, your ads will autorefresh
// at this interval.
#define kANBannerDefaultAutoRefreshInterval 30.0

// Minimum autorefresh interval: The minimum time between refreshes.
// kANBannerMinimumAutoRefreshInterval MUST be greater than kANBannerAutoRefreshThreshold.
//
#define kANBannerMinimumAutoRefreshInterval 15.0

// Autorefresh threshold: time value to disable autorefresh
#define kANBannerAutoRefreshThreshold 0.0

// Interstitial Close Button Delay
#define kANInterstitialDefaultCloseButtonDelay 10.0
#define kANInterstitialMaximumCloseButtonDelay 10.0


#pragma mark - Global functions.

NSString *__nonnull EPLDeviceModel(void);
BOOL EPLIsFirstLaunch(void);

NSString * __nonnull EPLUUID(void);
NSString *__nullable EPLAdvertisingIdentifier(void);
NSString *__nullable EPLIdentifierForVendor(void);

NSString *__nonnull EPLErrorString( NSString * __nonnull key);
NSError *__nonnull EPLError(NSString *__nonnull key, NSInteger code, ...) NS_FORMAT_FUNCTION(1,3);
NSBundle *__nonnull EPLResourcesBundle(void);
NSString *__nullable EPLPathForANResource(NSString *__nullable name, NSString *__nullable type);
NSString *__nullable EPLConvertToNSString(id __nullable value);
CGRect EPLAdjustAbsoluteRectInWindowCoordinatesForOrientationGivenRect(CGRect rect);
NSString *__nullable EPLMRAIDBundlePath(void);
BOOL EPLHasHttpPrefix(NSString  * __nonnull url);

void EPLPostNotifications(NSString * __nonnull name, id __nullable object, NSDictionary * __nullable userInfo);
CGRect EPLPortraitScreenBounds(void);
CGRect EPLPortraitScreenBoundsApplyingSafeAreaInsets(void);
NSMutableURLRequest * __nonnull EPLBasicRequestWithURL(NSURL * __nonnull URL);
NSNumber * __nullable EPLiTunesIDForURL(NSURL * __nonnull URL);
BOOL EPLStatusBarHidden(void);
CGRect EPLStatusBarFrame(void);
#if !APPNEXUS_NATIVE_MACOS_SDK
BOOL EPLAdvertisingTrackingEnabled(void);
UIInterfaceOrientation EPLStatusBarOrientation(void);
BOOL EPLCanPresentFromViewController(UIViewController * __nullable viewController);
#endif

#pragma mark - Global class.

@interface EPLGlobal : NSObject


+ (NSMutableDictionary<NSString *, NSString *> * __nonnull)convertCustomKeywordsAsMapToStrings: (NSDictionary<NSString *, NSArray<NSString *> *> * __nonnull)keywordsMap
                                                                 withSeparatorString: (nonnull NSString *)separatorString;

+ (nullable id) valueOfGetterProperty: (nonnull NSString *)stringOfGetterProperty
                   forObject: (nonnull id)objectImplementingGetterProperty;

+ (EPLAdType) adTypeStringToEnum:(nonnull NSString *)adTypeString;

+ (nonnull NSString *) userAgent;
#if !APPNEXUS_NATIVE_MACOS_SDK
+ (void) openURL: (nonnull NSString *)urlString;

+ (nonnull UIWindow *) getKeyWindow;
#endif

+ (EPLVideoOrientation) parseVideoOrientation:(nullable NSString *)aspectRatio;

+ (nullable NSMutableURLRequest *) adServerRequestURL;

+ (void) setWebViewCookie:(nonnull WKWebView*)webView;

+ (void) setANCookieToRequest:(nonnull NSMutableURLRequest *)request;

@end
