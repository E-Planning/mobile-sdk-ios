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


#import <sys/utsname.h>
#import <AdSupport/AdSupport.h>
#import "EPLGlobal.h"
#import "EPLLogging.h"
#import "EPLSDKSettings+PrivateMethods.h"
#import "EPLHTTPNetworkSession.h"
#import "EPLAdConstants.h"

#if !APPNEXUS_NATIVE_MACOS_SDK
#import "EPLOMIDImplementation.h"
#endif

#import "EPLGDPRSettings.h"
#if __has_include(<AppTrackingTransparency/AppTrackingTransparency.h>)
    #import <AppTrackingTransparency/AppTrackingTransparency.h>
#endif

NSString * __nonnull const  EPLInternalDelgateTagKeyPrimarySize                             = @"EPLInternalDelgateTagKeyPrimarySize";
NSString * __nonnull const  EPLInternalDelegateTagKeySizes                                  = @"EPLInternalDelegateTagKeySizes";
NSString * __nonnull const  EPLInternalDelegateTagKeyAllowSmallerSizes                      = @"EPLInternalDelegateTagKeyAllowSmallerSizes";

NSString * __nonnull const  kANUniversalAdFetcherWillRequestAdNotification                 = @"kANUniversalAdFetcherWillRequestAdNotification";
NSString * __nonnull const  kANUniversalAdFetcherAdRequestURLKey                           = @"kANUniversalAdFetcherAdRequestURLKey";
NSString * __nonnull const  kANUniversalAdFetcherWillInstantiateMediatedClassNotification  = @"kANUniversalAdFetcherWillInstantiateMediatedClassNotification";
NSString * __nonnull const  kANUniversalAdFetcherMediatedClassKey                          = @"kANUniversalAdFetcherMediatedClassKey";
 
NSString * __nonnull const  kANUniversalAdFetcherDidReceiveResponseNotification            = @"kANUniversalAdFetcherDidReceiveResponseNotification";
NSString * __nonnull const  kANUniversalAdFetcherAdResponseKey                             = @"kANUniversalAdFetcherAdResponseKey";


#define kANSDKResourcesBundleName @"EPLSDKResources"


NSMutableURLRequest  *utDefaultDomainMutableRequest = nil;
NSMutableURLRequest  *utSimpleDomainMutableRequest = nil;

NSString *anUserAgent = nil;
static BOOL userAgentQueryIsActive  = NO;


NSString *__nonnull EPLDeviceModel()
{
    struct utsname systemInfo;
    uname(&systemInfo);
    
    return @(systemInfo.machine);
}



NSString * __nonnull const kANFirstLaunchKey = @"kANFirstLaunchKey";

BOOL EPLIsFirstLaunch()
{
	BOOL isFirstLaunch = ![[NSUserDefaults standardUserDefaults] boolForKey:kANFirstLaunchKey];
	
	if (isFirstLaunch)
    {
		[[NSUserDefaults standardUserDefaults] setBool:YES forKey:kANFirstLaunchKey];
    }
    
    return isFirstLaunch;
}


NSString * __nonnull EPLUUID()
{
    return  [[[NSUUID alloc] init] UUIDString];
}

NSString *__nullable EPLAdvertisingIdentifier() {
    if (EPLSDKSettings.sharedInstance.disableIDFAUsage) { return nil; }
    NSString *advertisingIdentifier = [[ASIdentifierManager sharedManager].advertisingIdentifier UUIDString];
    if (advertisingIdentifier) {
        EPLLogInfo(@"IDFA = %@", advertisingIdentifier);
    } else {
        EPLLogWarn(@"No advertisingIdentifier retrieved. Cannot generate udidComponent.");
    }
    return advertisingIdentifier;
}

#if !APPNEXUS_NATIVE_MACOS_SDK
// a UUID that may be used to uniquely identify the device, same across apps from a single vendor. API is under UIKit which is not supported by macOS, https://developer.apple.com/documentation/uikit/uidevice/1620059-identifierforvendor
NSString *__nullable EPLIdentifierForVendor() {
    if (EPLSDKSettings.sharedInstance.disableIDFVUsage) { return nil; }
    
    NSString *idfv = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    if (idfv) {
        EPLLogInfo(@"idfv = %@", idfv);
    } else {
        EPLLogWarn(@"No IDFV retrieved.");
    }
    return idfv;
    return nil;
}


/*
True : Advertising Tracking Enabled
False : Advertising Tracking Disabled, Restricted or NotDetermined
 */
BOOL EPLAdvertisingTrackingEnabled() {
    // If a user does turn this off, use the unique identifier *only* for the following:
    // - Frequency capping
    // - Conversion events
    // - Estimating number of unique users
    // - Security and fraud detection
    // - Debugging
    
    if (@available(iOS 14, *)) {
#if __has_include(<AppTrackingTransparency/AppTrackingTransparency.h>)
        if ([ATTrackingManager trackingAuthorizationStatus] == ATTrackingManagerAuthorizationStatusAuthorized ){
            return YES;
        }else {
            return NO;
        }
#endif
    }
    return [ASIdentifierManager sharedManager].isAdvertisingTrackingEnabled;
}


CGRect EPLAdjustAbsoluteRectInWindowCoordinatesForOrientationGivenRect(CGRect rect) {
    // If portrait, no adjustment is necessary.
    if (EPLStatusBarOrientation() == UIInterfaceOrientationPortrait) {
        return rect;
    }
    
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    // iOS 8
    if (!CGPointEqualToPoint(screenBounds.origin, CGPointZero) || screenBounds.size.width > screenBounds.size.height) {
        return rect;
    }
    
    // iOS 7 and below
    CGFloat flippedOriginX = screenBounds.size.height - (rect.origin.y + rect.size.height);
    CGFloat flippedOriginY = screenBounds.size.width - (rect.origin.x + rect.size.width);
    
    CGRect adjustedRect;
    switch (EPLStatusBarOrientation()) {
        case UIInterfaceOrientationLandscapeLeft:
            adjustedRect = CGRectMake(flippedOriginX, rect.origin.x, rect.size.height, rect.size.width);
            break;
        case UIInterfaceOrientationLandscapeRight:
            adjustedRect = CGRectMake(rect.origin.y, flippedOriginY, rect.size.height, rect.size.width);
            break;
        case UIInterfaceOrientationPortraitUpsideDown:
            adjustedRect = CGRectMake(flippedOriginY, flippedOriginX, rect.size.width, rect.size.height);
            break;
        default:
            adjustedRect = rect;
            break;
    }
    
    return adjustedRect;
}


CGRect EPLPortraitScreenBounds() {
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    if (EPLStatusBarOrientation() != UIInterfaceOrientationPortrait) {
        if (!CGPointEqualToPoint(screenBounds.origin, CGPointZero) || screenBounds.size.width > screenBounds.size.height) {
            // need to orient screen bounds
            switch (EPLStatusBarOrientation()) {
                case UIInterfaceOrientationLandscapeLeft:
                    return CGRectMake(0, 0, screenBounds.size.height, screenBounds.size.width);
                    break;
                case UIInterfaceOrientationLandscapeRight:
                    return CGRectMake(0, 0, screenBounds.size.height, screenBounds.size.width);
                    break;
                case UIInterfaceOrientationPortraitUpsideDown:
                    return CGRectMake(0, 0, screenBounds.size.width, screenBounds.size.height);
                    break;
                default:
                    break;
            }
        }
    }
    return screenBounds;
}

CGRect EPLPortraitScreenBoundsApplyingSafeAreaInsets() {
    UIWindow *window = [EPLGlobal getKeyWindow];
    CGFloat topPadding = window.safeAreaInsets.top;
    CGFloat bottomPadding = window.safeAreaInsets.bottom;
    CGFloat leftPadding = window.safeAreaInsets.left;
    CGFloat rightPadding = window.safeAreaInsets.right;
    CGRect screenBounds = CGRectMake(leftPadding, topPadding, screenBounds.size.width - (leftPadding + rightPadding), screenBounds.size.height - (topPadding + bottomPadding));
    if (EPLStatusBarOrientation() != UIInterfaceOrientationPortrait) {
        if (!CGPointEqualToPoint(screenBounds.origin, CGPointZero) || screenBounds.size.width > screenBounds.size.height) {
            // need to orient screen bounds
            switch (EPLStatusBarOrientation()) {
                case UIInterfaceOrientationLandscapeLeft:
                    return CGRectMake(0, 0, screenBounds.size.height, screenBounds.size.width);
                    break;
                case UIInterfaceOrientationLandscapeRight:
                    return CGRectMake(0, 0, screenBounds.size.height, screenBounds.size.width);
                    break;
                case UIInterfaceOrientationPortraitUpsideDown:
                    return CGRectMake(0, 0, screenBounds.size.width, screenBounds.size.height);
                    break;
                default:
                    break;
            }
        }
    }
    return screenBounds;
}
BOOL EPLCanPresentFromViewController(UIViewController * __nullable viewController) {
    return viewController.view.window != nil ? YES : NO;
}

CGRect EPLStatusBarFrame(){
    CGRect statusBarFrame;
    if (@available(iOS 13.0, *)) {
        statusBarFrame = [[[[EPLGlobal getKeyWindow] windowScene] statusBarManager] statusBarFrame];
    }else {
        statusBarFrame = [[UIApplication sharedApplication] statusBarFrame];
    }
    return statusBarFrame;
}

BOOL EPLStatusBarHidden(){
    BOOL statusBarHidden;
    if (@available(iOS 13.0, *)) {
        statusBarHidden = [[[[EPLGlobal getKeyWindow] windowScene] statusBarManager] isStatusBarHidden];
    }else {
        statusBarHidden = [UIApplication sharedApplication].statusBarHidden;
    }
    return statusBarHidden;
}


UIInterfaceOrientation EPLStatusBarOrientation()
{
    UIInterfaceOrientation statusBarOrientation;
    
    if (@available(iOS 13.0, *)) {
        // On application launch, the value of [UIApplication sharedApplication].windows is nil, in this case, the [EPLGlobal getKeyWindow] returns the nil, then it picks device Orientation based screen size.
        
        if([EPLGlobal getKeyWindow] != nil){
            statusBarOrientation = [[[EPLGlobal getKeyWindow] windowScene] interfaceOrientation];
        }else{
            CGSize screenSize = [UIScreen mainScreen].bounds.size;
            if (screenSize.height < screenSize.width) {
                statusBarOrientation = UIInterfaceOrientationLandscapeLeft;
            }else{
                statusBarOrientation = UIInterfaceOrientationPortrait;
            }
        }
    }else{
        statusBarOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    }
    return statusBarOrientation;
}
#endif





NSString *__nonnull EPLErrorString( NSString * __nonnull key) {
    return NSLocalizedStringFromTableInBundle(key, EPL_ERROR_TABLE, EPLResourcesBundle(), @"");
}

NSError *__nonnull EPLError(NSString *__nonnull key, NSInteger code, ...) {
    NSDictionary *errorInfo = nil;
    va_list args;
    va_start(args, code);
    NSString *localizedDescription = EPLErrorString(key);
    if (localizedDescription) {
        localizedDescription = [[NSString alloc] initWithFormat:localizedDescription
                                                      arguments:args];
    } else {
        EPLLogWarn(@"Could not find localized error string for key %@", key);
        localizedDescription = @"";
    }
    va_end(args);
    errorInfo = @{NSLocalizedDescriptionKey: localizedDescription};
    return [NSError errorWithDomain:EPL_ERROR_DOMAIN
                               code:code
                           userInfo:errorInfo];
}

NSBundle *__nonnull EPLResourcesBundle() {
#ifdef SWIFT_PACKAGE
    return SWIFTPM_MODULE_BUNDLE;
#else
    static dispatch_once_t resBundleToken;
    static NSBundle *resBundle;
    static EPLGlobal *globalInstance;
    dispatch_once(&resBundleToken, ^{
        globalInstance = [[EPLGlobal alloc] init];
        NSBundle *resourcesBundle  = [NSBundle bundleForClass:[globalInstance class]];
        
        NSURL *resourcesBundleURL = [resourcesBundle URLForResource:kANSDKResourcesBundleName withExtension:@"bundle"];
        if(resourcesBundleURL){
            resBundle = [NSBundle bundleWithURL:resourcesBundleURL];
        }else{
            resBundle = resourcesBundle;
        }
        
    });
    return resBundle;
#endif
}

NSString *__nullable EPLPathForANResource(NSString *__nullable name, NSString *__nullable type) {
    NSString *path = [EPLResourcesBundle() pathForResource:name ofType:type];
    if (!path) {
        EPLLogError(@"Could not find resource %@.%@. Please make sure that all the resources in sdk/resources are included in your app target's \"Copy Bundle Resources\".", name, type);
    }
    return path;
}

NSString *__nullable EPLConvertToNSString(id __nullable value) {
    if ([value isKindOfClass:[NSString class]]) return value;
    if ([value respondsToSelector:@selector(stringValue)]) {
        return [value stringValue];
    }
    EPLLogWarn(@"Failed to convert to NSString");
    return nil;
}

NSString *__nullable EPLMRAIDBundlePath() {
    NSString *mraidPath = EPLPathForANResource(@"EPLMRAID", @"bundle");
    if (!mraidPath) {
        EPLLogError(@"Could not find EPLMRAID.bundle. Please make sure that EPLMRAID.bundle resource in sdk/resources is included in your app target's \"Copy Bundle Resources\".");
        return nil;
    }
    return mraidPath;
}

BOOL EPLHasHttpPrefix(NSString * __nonnull url) {
    return ([url hasPrefix:@"http"] || [url hasPrefix:@"https"]);
}

void EPLPostNotifications(NSString * __nonnull name, id __nullable object, NSDictionary * __nullable userInfo) {
    if ([EPLLogManager isNotificationsEnabled]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:name
                                                            object:object
                                                          userInfo:userInfo];
    }
}


NSMutableURLRequest * __nonnull EPLBasicRequestWithURL(NSURL * __nonnull URL) {
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:URL
                                                                cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                            timeoutInterval:kAppNexusRequestTimeoutInterval];
   
    [request setValue:[EPLGlobal userAgent] forHTTPHeaderField:@"User-Agent"];
    return [request copy];
}

NSNumber * __nullable EPLiTunesIDForURL(NSURL * __nonnull URL) {
    if ([URL.host isEqualToString:@"itunes.apple.com"]) {
        NSRegularExpression *idPattern = [[NSRegularExpression alloc] initWithPattern:@"id(\\d+)"
                                                                              options:0
                                                                                error:nil];
        NSRange idRange = [idPattern rangeOfFirstMatchInString:URL.absoluteString
                                                       options:0
                                                         range:NSMakeRange(0, URL.absoluteString.length)];
        if (idRange.length != 0) {
            NSString *idString = [[URL.absoluteString substringWithRange:idRange] substringFromIndex:2];
            return @([idString longLongValue]);
        }
    }
    return nil;
}

@implementation EPLGlobal

#if !APPNEXUS_NATIVE_MACOS_SDK



+ (void) openURL: (nonnull NSString *)urlString
{
    if([[UIApplication sharedApplication] respondsToSelector:@selector(openURL:options:completionHandler:)]){
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlString] options:@{} completionHandler:nil];
        return;
    }
}


#pragma mark - Get KeyWindow

+ (nonnull UIWindow *) getKeyWindow
{
    UIWindow *keyWindow = nil;
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        if (window.isKeyWindow) {
            keyWindow = window;
            break;
        }
    }
    return keyWindow;
}
#endif


+(nullable NSMutableURLRequest *) adServerRequestURL {
    if([EPLGDPRSettings canAccessDeviceData] && !EPLSDKSettings.sharedInstance.doNotTrack){
        if(utDefaultDomainMutableRequest == nil){
            utDefaultDomainMutableRequest =  [EPLGlobal constructAdServerRequestURLAndWarmup];
        }
        return utDefaultDomainMutableRequest;
    }else{
        if(utSimpleDomainMutableRequest == nil){
            utSimpleDomainMutableRequest =  [EPLGlobal constructAdServerRequestURLAndWarmup];
        }
        return utSimpleDomainMutableRequest;
    }
}

+ (NSMutableURLRequest *) constructAdServerRequestURLAndWarmup {
    NSString      *urlString  = [[[EPLSDKSettings sharedInstance] baseUrlConfig] utAdRequestBaseUrl];
    NSURL                *URL             = [NSURL URLWithString:urlString];
    
    NSMutableURLRequest *request = (NSMutableURLRequest *)EPLBasicRequestWithURL(URL);
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPMethod:@"POST"];
    [EPLGlobal performWarmUpRequest: [request copy]];// Always perform warmup request on a copy. This makes sure any properties applied below donot get carried forward.
    return request;
}

// Performs a warmup request.
// This makes consecutive requests to that domain from SDK faster.
+ (void) performWarmUpRequest:(NSMutableURLRequest *) warmupRequest{
    [warmupRequest setHTTPShouldHandleCookies:false]; // Cookies should not be allowed for Warmup request.
    [EPLHTTPNetworkSession startTaskWithHttpRequest:warmupRequest];
}


+ (void)handleUserAgentDidChangeNotification:(NSNotification *)notification {
  
    if(utDefaultDomainMutableRequest!=nil){
        [utDefaultDomainMutableRequest setValue:[EPLGlobal userAgent] forHTTPHeaderField:@"user-agent"];
    }
    
    if(utSimpleDomainMutableRequest!=nil){
        [utSimpleDomainMutableRequest setValue:[EPLGlobal userAgent] forHTTPHeaderField:@"user-agent"];
    }
    [[NSNotificationCenter defaultCenter] removeObserver:@"kUserAgentDidChangeNotification"];

}

#pragma mark - Custom keywords.

// See also [AdSettings -setCustomKeywordsAsMapInEntryPoint:].
//
// Use alias for default separator string of comma (,).
//
+ (NSMutableDictionary<NSString *, NSString *> * __nonnull)convertCustomKeywordsAsMapToStrings: (NSDictionary<NSString *, NSArray<NSString *> *> * __nonnull)keywordsMap
                                                                           withSeparatorString: (nonnull NSString *)separatorString
{
    NSMutableDictionary<NSString *, NSString *>  *keywordsMapToStrings  = [[NSMutableDictionary alloc] init];

    for (NSString *key in keywordsMap)
    {
        NSArray   *mapValuesArray  = [keywordsMap objectForKey:key];
        NSString  *mapValueString  = [mapValuesArray componentsJoinedByString:separatorString];

        [keywordsMapToStrings setObject:mapValueString forKey:key];
    }

    return  [keywordsMapToStrings mutableCopy];
}


// Use this method to test for the existence of a property, then return its value if it is implemented by the target object.
// Should also work for methods that have no arguments.
//
// NB  Does not distinguish between a return value of nil and the case where the object does not respond to the getter selector.
//
+ (nullable id) valueOfGetterProperty: (nonnull NSString *)stringOfGetterProperty
                            forObject: (nonnull id)objectImplementingGetterProperty
{
    SEL  getterMethod  = NSSelectorFromString(stringOfGetterProperty);

    if ([objectImplementingGetterProperty respondsToSelector:getterMethod]) {
        return  ((id (*)(id, SEL))[objectImplementingGetterProperty methodForSelector:getterMethod])(objectImplementingGetterProperty, getterMethod);
    }

    return  nil;
}

+ (EPLAdType) adTypeStringToEnum:(nonnull NSString *)adTypeString
{
    NSString  *adTypeStringVerified  = EPLConvertToNSString(adTypeString);

    if ([adTypeStringVerified length] < 1) {
        EPLLogError(@"Could not resolve string from adTypeString.");
        return  EPLAdTypeUnknown;
    }

    //
    NSString  *adTypeStringLowercase  = [adTypeString lowercaseString];

    if ([adTypeStringLowercase compare:@"banner"] == NSOrderedSame) {
        return  EPLAdTypeBanner;

    } else if ([adTypeStringLowercase compare:@"video"] == NSOrderedSame) {
        return  EPLAdTypeVideo;

    } else if ([adTypeStringLowercase compare:@"native"] == NSOrderedSame) {
        return  EPLAdTypeNative;
    }

    EPLLogError(@"UNRECOGNIZED adTypeString.  (%@)", adTypeString);
    return  EPLAdTypeUnknown;
}


+ (void) getUserAgent
{
    
    // Return customUserAgent if provided
    NSString *customUserAgent = EPLSDKSettings.sharedInstance.customUserAgent;
    if(customUserAgent && customUserAgent.length != 0){
        EPLLogDebug(@"userAgent=%@", customUserAgent);
        anUserAgent = customUserAgent;
    }
    
    if (!anUserAgent) {
        if (!userAgentQueryIsActive)
        {
            @synchronized (self) {
                userAgentQueryIsActive = YES;
            }
            
            dispatch_async(dispatch_get_main_queue(),
                           ^{
                @try {
                    anUserAgent = [[[WKWebView alloc] init] valueForKey:@"userAgent"];
                    EPLLogDebug(@"userAgent=%@", anUserAgent);
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"kUserAgentDidChangeNotification" object:nil userInfo:nil];
                    @synchronized (self) {
                        userAgentQueryIsActive = NO;
                    }
                }
                @catch (NSException *exception) {
                    EPLLogError(@"Failed to fetch UserAgent with exception  (%@)", exception);
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"kUserAgentFailedToChangeNotification" object:nil userInfo:nil];
                }
                
            });
        }
        EPLLogDebug(@"userAgent=%@", anUserAgent);
    }
}

+ (NSString *) userAgent {
    if(anUserAgent == nil){
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleUserAgentDidChangeNotification:) name:@"kUserAgentDidChangeNotification" object:nil];
        [EPLGlobal getUserAgent];
    }
    return anUserAgent;
}



#pragma mark - Get Video Orientation Method

+ (EPLVideoOrientation) parseVideoOrientation:(NSString *)aspectRatio {
    double aspectRatioValue = [aspectRatio doubleValue];
    return aspectRatio == 0? EPLUnknown : (aspectRatioValue == 1)? EPLSquare : (aspectRatioValue > 1)? EPLLandscape : EPLPortrait;
}

+ (void) setWebViewCookie:(nonnull WKWebView*)webView{
    if([EPLGDPRSettings canAccessDeviceData] && !EPLSDKSettings.sharedInstance.doNotTrack){
        
        for (NSHTTPCookie *cookie in [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies]) {
            // Skip cookies that will break our script
            if ([cookie.value rangeOfString:@"'"].location != NSNotFound) {
                continue;
            }
            [webView.configuration.websiteDataStore.httpCookieStore setCookie:cookie completionHandler:nil];
            
        }
    }
}

+ (void) setANCookieToRequest:(nonnull NSMutableURLRequest *)request {
    if([EPLGDPRSettings canAccessDeviceData] && !EPLSDKSettings.sharedInstance.doNotTrack){
        [request setHTTPShouldHandleCookies:true];
        NSString      *urlString  = [[[EPLSDKSettings sharedInstance] baseUrlConfig] webViewBaseUrl];
        NSURL                *URL             = [NSURL URLWithString:urlString];
        NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:URL];
        NSDictionary *cookieHeaders = [ NSHTTPCookie requestHeaderFieldsWithCookies: cookies];
        [request setAllHTTPHeaderFields:cookieHeaders];
    }else{
        [request setHTTPShouldHandleCookies:false];
    }
}


@end