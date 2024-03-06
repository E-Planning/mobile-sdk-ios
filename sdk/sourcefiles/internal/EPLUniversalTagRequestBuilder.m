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

#import "EPLUniversalTagRequestBuilder.h"
#import "EPLGlobal.h"
#import "EPLLogging.h"
#import "EPLReachability.h"
#import "EPLGDPRSettings.h"
#import "EPLUSPrivacySettings.h"
#import "EPLCarrierObserver.h"
#import "EPLMultiAdRequest+PrivateMethods.h"
#import "EPLSDKSettings.h"
#import "EPLAdProtocol.h"
#import "EPLAdConstants.h"
#import "EPLGPPSettings.h"
#import "EPLDSASettings.h"
#import "EPLDSATransparencyInfo.h"

#if !APPNEXUS_NATIVE_MACOS_SDK
#import "EPLOMIDImplementation.h"
#import "EPLAdViewInternalDelegate.h"
#import "EPLAdFetcher.h"
#endif

#if __has_include(<AppTrackingTransparency/AppTrackingTransparency.h>)
    #import <AppTrackingTransparency/AppTrackingTransparency.h>
#endif
#import "EPLNativeAdFetcher.h"

#pragma mark - Private constants.


#pragma mark -


// This protocol definition meant for local use only, to simplify typecasting of MAR Manager objects.
#if !APPNEXUS_NATIVE_MACOS_SDK
// User for iOS Banner,Native, Interstitial and Video
@protocol  EPLUniversalTagRequestBuilderFetcherDelegate  <EPLAdFetcherDelegate, EPLAdProtocolVideo>
    //EMPTY
@end
#else
// Used for MacOS Native
@protocol  EPLUniversalTagRequestBuilderFetcherDelegate  <EPLNativeAdFetcherDelegate>
    //EMPTY
@end

#endif



#pragma mark -

@interface EPLUniversalTagRequestBuilder()

// NB  adFetcherDelegate and marManager are mutually exclusive in initialization methods.
//
@property (nonatomic, readwrite, weak)  id<EPLUniversalTagRequestBuilderFetcherDelegate>  adFetcherDelegate;

@property (nonatomic, readwrite, weak)  EPLMultiAdRequest    *fetcherMARManager;
@property (nonatomic, readwrite, weak)  EPLMultiAdRequest    *adunitMARManager;

@end




#pragma mark -

@implementation EPLUniversalTagRequestBuilder

#pragma mark Lifecycle.

// NB  Protocol type of adFetcherDelegate can be EPLUniversalAdFetcherDelegate or EPLUniversalNativeAdFetcherDelegate.
// NB  marManager is defined when this class is involed by MultiAdRequest, otherwise it is nil.
//
+ (nullable NSURLRequest *)buildRequestWithAdFetcherDelegate: (nonnull id)adFetcherDelegate
{
    EPLUniversalTagRequestBuilder *requestBuilder = [[EPLUniversalTagRequestBuilder alloc] initWithAdFetcherDelegate: adFetcherDelegate
                                                                         optionallyWithAdunitMultiAdRequestManager: nil
                                                                                           orMultiAdRequestManager: nil];
    return [requestBuilder request];
}



+ (nullable NSURLRequest *)buildRequestWithAdFetcherDelegate: (nonnull id)adFetcherDelegate
                                 adunitMultiAdRequestManager: (nonnull EPLMultiAdRequest *)adunitMARManager
{
    EPLUniversalTagRequestBuilder *requestBuilder = [[EPLUniversalTagRequestBuilder alloc] initWithAdFetcherDelegate: adFetcherDelegate
                                                                         optionallyWithAdunitMultiAdRequestManager: adunitMARManager
                                                                                           orMultiAdRequestManager: nil];
    return [requestBuilder request];
}

+ (nullable NSURLRequest *)buildRequestWithMultiAdRequestManager: (nonnull EPLMultiAdRequest *)marManager
{
    EPLUniversalTagRequestBuilder *requestBuilder =
        [[EPLUniversalTagRequestBuilder alloc] initWithAdFetcherDelegate: (id<EPLUniversalTagRequestBuilderFetcherDelegate>)marManager
                              optionallyWithAdunitMultiAdRequestManager: nil
                                                orMultiAdRequestManager: marManager];
    return [requestBuilder request];
}


- (instancetype)initWithAdFetcherDelegate: (nullable id)adFetcherDelegate
optionallyWithAdunitMultiAdRequestManager: (nullable EPLMultiAdRequest *)adunitMARManager
                  orMultiAdRequestManager: (nullable EPLMultiAdRequest *)fetcherMARManager
{
    self = [super init];
    if (!self)  { return nil; }


    //
    _adFetcherDelegate  = adFetcherDelegate;
    _fetcherMARManager  = fetcherMARManager;
    _adunitMARManager   = adunitMARManager;
    return self;
}



#pragma mark - UT Request builder methods.

- (NSURLRequest *)request
{
    NSMutableURLRequest  *mutableRequest  = [EPLGlobal adServerRequestURL];
    
    NSError       *error       = nil;
    NSData        *postData    = nil;
    NSDictionary  *jsonObject  = [self requestBody];

    if (!jsonObject)
    {
        NSDictionary  *userInfo  = @{ NSLocalizedDescriptionKey : @"[EPLUniversalTagRequestBuilder requestBody] returned nil." };
        error = [NSError errorWithDomain:EPL_ERROR_DOMAIN code:EPLAdResponseCode.INTERNAL_ERROR.code userInfo:userInfo];
    }

    if (!error) {
        postData = [NSJSONSerialization dataWithJSONObject: jsonObject
                                                   options: kNilOptions
                                                     error: &error ];
    }

    if (error) {
        EPLLogError(@"Error formulating Universal Tag request: %@", error);
        return nil;
    }

    //
    NSString  *jsonString  = [[NSString alloc] initWithData:postData encoding:NSUTF8StringEncoding];

    EPLLogDebug(@"Post JSON: %@", jsonString);
    EPLLogDebug(@"[self requestBody] = %@", jsonObject);   //DEBUG

    [mutableRequest setHTTPBody:postData];
    return [mutableRequest copy];
}


- (NSDictionary *)requestBody
{
    NSMutableDictionary<NSString *, id>  *requestDict  = [[NSMutableDictionary<NSString *, id> alloc] init];

    
    // Set tags node array.
    //
    NSMutableArray<NSDictionary<NSString *, id> *>  *arrayOfTags  = [[NSMutableArray<NSDictionary<NSString *, id> *> alloc] init];

        if (!self.fetcherMARManager)
        {
            NSDictionary<NSString *, id>  *singleTag =  [self tag:requestDict];

            if (singleTag) {
                arrayOfTags = [@[singleTag] mutableCopy];
            }

        } else {
            NSPointerArray  *arrayOfAdUnits  = [self.fetcherMARManager internalGetAdUnits];

            //
            for (id au in arrayOfAdUnits)
            {
                if (!au) {
                    EPLLogWarn(@"IGNORING nil ELEMENT in array of AdUnits.");
                    continue;
                }
                
                self.adFetcherDelegate = au;

                NSDictionary<NSString *, id>  *tagFromAdUnit  = [self tag:requestDict];

                if (tagFromAdUnit) {
                    [arrayOfTags addObject:tagFromAdUnit];
                }
            }

            self.adFetcherDelegate = (id<EPLUniversalTagRequestBuilderFetcherDelegate>)self.fetcherMARManager;
        }

    if (arrayOfTags.count > 0) {
        requestDict[@"tags"] = arrayOfTags;
    } else {
        EPLLogError(@"FAILED TO GENERATE AT LEAST ONE TAG for this UT Request.");
        return  nil;
    }

        // If the festcher is loading an individual AdUnit that is encapsulated by MultiAdRequest,
        //   begin using the MultiAdRequest context to define page global fields.
        //
        if (!self.fetcherMARManager && self.adunitMARManager) {
            self.fetcherMARManager = self.adunitMARManager;
            self.adFetcherDelegate = (id<EPLUniversalTagRequestBuilderFetcherDelegate>)self.adunitMARManager;
        }


        // For MultiAdRequest (AdUnit is encapsulated in MAR): set nodes for member_id and/or publisher_id.
        //   Compare to similar case in [self tag:].
        //
        if (self.fetcherMARManager)
        {
            if (self.fetcherMARManager.memberId > 0) {
                requestDict[@"member_id"] = @(self.fetcherMARManager.memberId);
            }

            if (self.fetcherMARManager.publisherId > 0) {
                requestDict[@"publisher_id"]  = @(self.fetcherMARManager.publisherId);
            }
        }


    // Set remaining page global nodes (user, device, app, keywords, sdk) and other fields.
    //
    NSDictionary<NSString *, id> *user = [self user];
    if (user) {
        requestDict[@"user"] = user;
    }
    

    NSDictionary<NSString *, id> *device = [self device];
    if (device) {
        requestDict[@"device"] = device;
    }
    
    NSDictionary *contentLanguage = [self contentLanguage];
    if (contentLanguage) {
        requestDict[@"request_content"] = contentLanguage;
    }
    
    NSDictionary<NSString *, id> *app = [self app];
    if (app) {
        requestDict[@"app"] = app;
    }

        if (self.fetcherMARManager) {
            NSArray<NSSet<NSString *> *>  *keywords  = [self keywords];
            if (keywords) {
                requestDict[@"keywords"] = keywords;
            }
        }
        

 
    NSDictionary<NSString *, id>  *sdk  = [self sdk];
    if (sdk) {
        requestDict[@"sdk"] = sdk;
    }
    
    requestDict[@"sdkver"] = EPL_SDK_VERSION;  //LEGACY.  Replaced by sdk object.
    
    requestDict[@"supply_type"] = @"mobile_app";
    
    // Update logic to pass PPID to impbus
    NSArray<EPLUserId *>  *userIdArray  = [EPLSDKSettings.sharedInstance userIdArray];
    // Set EUID node, EUID - Third & First party id solutions
    //
    if ([userIdArray count] > 0) {
        NSArray<NSDictionary<NSString *, NSString *> *>  *externalUserIds  = [self externalUserIds:userIdArray];

        if([externalUserIds count] > 0){
            requestDict[@"eids"] = externalUserIds;
        }
    }

    #if !APPNEXUS_NATIVE_MACOS_SDK
        if(EPLSDKSettings.sharedInstance.enableOpenMeasurement){
            requestDict[@"iab_support"]  = [self getIABSupport];
        }
    #endif


    
    // add GDPR Consent
    NSDictionary *gdprConsent = [self getGDPRConsentObject];
    if (gdprConsent) {
        requestDict[@"gdpr_consent"] = gdprConsent;
    }
    
    // add GPP Privacy data
    NSDictionary *gppPrivacyObject = [self getGPPPrivacyObject];
    if (gppPrivacyObject) {
        requestDict[@"privacy"] = gppPrivacyObject;
    }
    
    // add DSA Privacy
    NSDictionary *dsaPrivacyObject = [self getDSAPrivacyObject];
    if (dsaPrivacyObject.allKeys.count > 0) {
        requestDict[@"dsa"] = dsaPrivacyObject;
    }
    
    // add Facebook bidder token if available
    NSArray *tpuids = [self appendFBToken];
    if(tpuids != nil){
        requestDict[@"tpuids"] = tpuids;
    }
    
    // add USPrivacy String
    NSString *privacyString = [EPLUSPrivacySettings getUSPrivacyString];
    if (privacyString.length != 0) {
        requestDict[@"us_privacy"] = privacyString;
    }
    
    NSUInteger auctionTimeout  = [[EPLSDKSettings sharedInstance] auctionTimeout];
    if (auctionTimeout > 0 &&  auctionTimeout < NSIntegerMax) {
        requestDict[@"auction_timeout_ms"] = @(auctionTimeout);
    }
    
    // override  Country code and  Zip code
    NSDictionary<NSString *, id> *geoOverrideCountryZipCode = [self geoOverrideCountryZipCode];
    if ([geoOverrideCountryZipCode count] != 0) {
        requestDict[@"geoOverride"] = geoOverrideCountryZipCode;
    }
    
    return [requestDict copy];
}

-(NSString *)getFacebookBidderToken{
    // check to see if an instance of this class exists
    Class csrClass = NSClassFromString(@"EPLFBSettings");
    if (!csrClass) {
        EPLLogDebug(@"EPLFBSettings Class not found");
        return nil;
    }
    SEL  getterMethod  = NSSelectorFromString(@"getBidderToken");
    if ([csrClass respondsToSelector:getterMethod]) {
        IMP methodIMP = [csrClass methodForSelector:getterMethod];
        NSString* (*func)(id,SEL) = (NSString* (*)(id,SEL))methodIMP;
        EPLLogDebug(@"FacebookBidderToken : %@",(func)(csrClass, getterMethod));
        return (func)(csrClass, getterMethod);
    }
    return nil;
}

-(NSArray *)appendFBToken{
    NSString *token = [self getFacebookBidderToken];
    if(token != nil){
        NSDictionary *fan = @{
            @"provider"  : @"audienceNetwork",
            @"user_id"   : token
        };
        return @[fan];
    }
    return nil;
}

- (NSDictionary *)tag:(NSMutableDictionary *)requestDict
{
    NSMutableDictionary<NSString *, id>  *tagDict  = [[NSMutableDictionary<NSString *, id> alloc] init];

    
    //
    [self.adFetcherDelegate internalUTRequestUUIDStringReset];

    tagDict[@"uuid"] = [self.adFetcherDelegate internalGetUTRequestUUIDString];

    // For AdUnit (MultiAdRequest is not active): set nodes for member_id and/or publisher_id.
    //   Compare to similar case in [self requestbody].
    //
    NSInteger   placementId  = [[self.adFetcherDelegate placementId] integerValue];
    NSInteger   publisherId  = [self.adFetcherDelegate publisherId];
    NSInteger   memberId     = [self.adFetcherDelegate memberId];
    NSString   *invCode      = [self.adFetcherDelegate inventoryCode];
    
    if (invCode && memberId>0)
    {
        tagDict[@"code"] = invCode;
            
            if (!self.fetcherMARManager)
            {
                if (memberId > 0) {
                    requestDict[@"member_id"]     = @(memberId);
                }

                if (publisherId > 0) {
                    requestDict[@"publisher_id"]  = @(publisherId);
                }
            }
    } else {
        tagDict[@"id"] = @(placementId);
    }
    
    
    // Set nodes for primary_size, sizes, allow_smaller_sizes.
    //
 
#if !APPNEXUS_NATIVE_MACOS_SDK
    NSDictionary<NSString *, id>  *delegateReturnDictionary  = [self.adFetcherDelegate internalDelegateUniversalTagSizeParameters];

    CGSize                    primarySize         = [[delegateReturnDictionary  objectForKey:EPLInternalDelgateTagKeyPrimarySize] CGSizeValue];
    NSMutableSet<NSValue *>  *sizes               = [delegateReturnDictionary   objectForKey:EPLInternalDelegateTagKeySizes];
    BOOL                      allowSmallerSizes   = [[delegateReturnDictionary  objectForKey:EPLInternalDelegateTagKeyAllowSmallerSizes] boolValue];
    
    tagDict[@"primary_size"] = @{
                                    @"width"  : @(primarySize.width),
                                    @"height" : @(primarySize.height)
                                };
    
    NSMutableArray<NSDictionary<NSString *, id> *>  *sizesArray  = [[NSMutableArray alloc] init];

    for (id sizeElement in sizes)
    {
        if ([sizeElement isKindOfClass:[NSValue class]])
        {
            CGSize  sizeValue  = [sizeElement CGSizeValue];

            [sizesArray addObject: @{
                                         @"width"  : @(sizeValue.width),
                                         @"height" : @(sizeValue.height)
                                     } ];
        }
    }
    tagDict[@"sizes"] = sizesArray;
    tagDict[@"allow_smaller_sizes"] = [NSNumber numberWithBool:allowSmallerSizes];

#else

    
    NSDictionary<NSString *, id>  *delegateReturnDictionary  = [self.adFetcherDelegate internalDelegateUniversalTagSizeParameters];
    
    NSSize size = [[delegateReturnDictionary objectForKey:EPLInternalDelgateTagKeyPrimarySize] sizeValue];
    
    CGSize                    primarySize         = NSSizeToCGSize(size);
    
    NSMutableSet<NSValue *>  *sizes               = [delegateReturnDictionary   objectForKey:EPLInternalDelegateTagKeySizes];
    BOOL                      allowSmallerSizes   = [[delegateReturnDictionary  objectForKey:EPLInternalDelegateTagKeyAllowSmallerSizes] boolValue];
    
    tagDict[@"primary_size"] = @{
                                     @"width"  : @(primarySize.width),
                                     @"height" : @(primarySize.height)
                                 };
    
    NSMutableArray<NSDictionary<NSString *, id> *>  *sizesArray  = [[NSMutableArray alloc] init];
    
    for (id sizeElement in sizes)
    {
        if ([sizeElement isKindOfClass:[NSValue class]])
        {
            CGSize  sizeValue  = NSSizeToCGSize([sizeElement sizeValue]);

            [sizesArray addObject: @{
                                         @"width"  : @(sizeValue.width),
                                         @"height" : @(sizeValue.height)
                                     } ];
        }
    }
    tagDict[@"sizes"] = sizesArray;
    tagDict[@"allow_smaller_sizes"] = [NSNumber numberWithBool:allowSmallerSizes];


#endif

    
    
    NSString    *extInvCode  = [self.adFetcherDelegate extInvCode];
    if(extInvCode.length > 0 ){
        tagDict[@"ext_inv_code"] = extInvCode;
    }
    
    NSString    *trafficSourceCode   = [self.adFetcherDelegate trafficSourceCode];
    if(trafficSourceCode.length > 0 ){
        tagDict[@"traffic_source_code"] = trafficSourceCode;
    }
    
    


    //
    tagDict[@"allowed_media_types"] = [self.adFetcherDelegate adAllowedMediaTypes];

    if ([self.adFetcherDelegate respondsToSelector:@selector(forceCreativeId)]){
        NSInteger   forceCreativeId  = [self.adFetcherDelegate forceCreativeId];
        if (forceCreativeId > 0) {
            tagDict[@"force_creative_id"] = @(forceCreativeId);
        }
    }
    
    if(EPLSDKSettings.sharedInstance.enableOpenMeasurement){
        [self getAdFramework:tagDict];
    }

    //
    if ([self.adFetcherDelegate respondsToSelector:@selector(shouldServePublicServiceAnnouncements)]) {
        tagDict[@"disable_psa"] = [NSNumber numberWithBool:![self.adFetcherDelegate shouldServePublicServiceAnnouncements]];
    } else {
        tagDict[@"disable_psa"] = [NSNumber numberWithBool:YES];
        
    }
    
    //
    tagDict[@"require_asset_url"] = [NSNumber numberWithBool:0];
    
    NSDictionary<NSString *, id>  *nativeRendererRequest  = [self nativeRendererRequest];
    if (nativeRendererRequest) {
        tagDict[@"native"] = nativeRendererRequest;
    }
    #if !APPNEXUS_NATIVE_MACOS_SDK
        NSDictionary *video = [self video];
        if(video){
            tagDict[@"video"] = video;
        }
        
    #endif

  
    //
    CGFloat  reservePrice  = [self.adFetcherDelegate reserve];
    if (reservePrice > 0)  {
        tagDict[@"reserve"] = @(reservePrice);
    }

    //
    NSArray<NSSet<NSString *> *>  *keywords  = [self keywords];
    if (keywords) {
        tagDict[@"keywords"] = keywords;
    }

    //
    return [tagDict copy];
}

-(void)getAdFramework:(NSMutableDictionary *)tag{
    
    NSArray *mediaTypes = [self.adFetcherDelegate adAllowedMediaTypes];
    for(int mediaTypeIndex = 0; mediaTypeIndex < mediaTypes.count; mediaTypeIndex++) {
        EPLAllowedMediaType mediaType = [mediaTypes[mediaTypeIndex] intValue];
        switch(mediaType)
        {
            case EPLAllowedMediaTypeBanner:
            case EPLAllowedMediaTypeInterstitial:
            case EPLAllowedMediaTypeHighImpact:
                tag[@"banner_frameworks"] =  @[@(6)];
                break;
            case EPLAllowedMediaTypeNative:
                tag[@"native_frameworks"] =  @[@(6)];
                break;
            case EPLAllowedMediaTypeVideo:
                tag[@"video_frameworks"] =  @[@(6)];
                break;
        }
    }
}

- (NSDictionary<NSString *, id> *)nativeRendererRequest
{
    if ([self.adFetcherDelegate respondsToSelector:@selector(nativeAdRendererId)])
    {
        NSInteger   rendererId              = [self.adFetcherDelegate nativeAdRendererId];
        NSArray    *adAllowedMediaTypes     = [self.adFetcherDelegate adAllowedMediaTypes];

        if ((rendererId != 0) && [adAllowedMediaTypes containsObject:@(EPLAllowedMediaTypeNative)])
        {
            return @{
                         @"renderer_id": [NSNumber numberWithInteger:rendererId]
                     };
        }
    }
    return nil;
}

#if !APPNEXUS_NATIVE_MACOS_SDK

- (NSDictionary<NSString *, id> *) video
{
    NSMutableDictionary<NSString *, id>  *videoDict  = [[NSMutableDictionary alloc] init];

    if ([self.adFetcherDelegate respondsToSelector:@selector(minDuration)])
    {
        NSUInteger minDurationValue = [self.adFetcherDelegate minDuration];

        if (minDurationValue > 0) {
            videoDict[@"minduration"] = @(minDurationValue);
        }
    }

    if ([self.adFetcherDelegate respondsToSelector:@selector(maxDuration)])
    {
        NSUInteger maxDurationValue = [self.adFetcherDelegate maxDuration];

        if (maxDurationValue > 0) {
            videoDict[@"maxduration"] = @(maxDurationValue);
        }
    }

    if ([videoDict count] > 0) {
        return videoDict;
    } else {
        return nil;
    }
}
#endif


- (NSDictionary<NSString *, id> *)user
{
    NSMutableDictionary<NSString *, id>  *userDict  = [[NSMutableDictionary<NSString *, id> alloc] init];


    //
    NSInteger ageValue = [[self.adFetcherDelegate age] integerValue];   // TBDFIX  Fails for hyphenated age range.
    if (ageValue > 0) {
        userDict[@"age"] = @(ageValue);
    }


    //
    EPLGender    genderValue  = [self.adFetcherDelegate gender];
    NSUInteger  gender;

    switch (genderValue)
    {
        case EPLGenderMale:
            gender = 1;
            break;
        case EPLGenderFemale:
            gender = 2;
            break;
        default:
            gender = 0;
            break;
    }
    userDict[@"gender"] = @(gender);


    //
    NSString *language = [NSLocale preferredLanguages][0];
    if (language.length) {
        userDict[@"language"] = language;
    }
    
    //
    NSString *publisherUserId = [[EPLSDKSettings sharedInstance] publisherUserId];
    // Use publisherFirstPartyID if it is present. External Id in EPLAdProtocol is deprecated.
    if (publisherUserId) {
        userDict[@"external_uid"] = publisherUserId;
    }
  #if !APPNEXUS_NATIVE_MACOS_SDK
    else if (!EPLAdvertisingTrackingEnabled()){
        // Pass IDFV as external_uid when there is no Publisher First Party Id and IDFA, IDFV is not support by macOS.
        NSString *idfv = EPLIdentifierForVendor();
        if (idfv) {
            userDict[@"external_uid"] = idfv;
        }
    }
  #endif

    if ([[EPLSDKSettings sharedInstance] doNotTrack]) {
        userDict[@"dnt"] = [NSNumber numberWithBool:YES];
    }

    return [userDict copy];
}

- (NSDictionary<NSString *, id> *)device
{
    NSMutableDictionary<NSString *, id>  *deviceDict  = [[NSMutableDictionary<NSString *, id> alloc] init];

    //
    NSString *userAgent = [EPLGlobal userAgent];
    if (userAgent) {
        deviceDict[@"useragent"] = userAgent;
    }


    //
    NSDictionary<NSString *, id> *geo = [self geo];
    if (geo) {
        deviceDict[@"geo"] = geo;
    }


    //
    deviceDict[@"make"] = @"Apple";
    
    NSString *deviceModel = EPLDeviceModel();
    if (deviceModel) {
        deviceDict[@"model"] = deviceModel;
    }

#if !APPNEXUS_NATIVE_MACOS_SDK
//    App should be able to handle changes to the user’s cellular service provider. For example, the user could swap the device’s SIM card with one from another provider while app is running. Not applicable for macOS to know more click link https://developer.apple.com/documentation/coretelephony/cttelephonynetworkinfo

    EPLCarrierObserver   *carrierObserver    = EPLCarrierObserver.shared;
    EPLCarrierMeta       *carrierMeta        = carrierObserver.carrierMeta;

    if (carrierMeta.name.length > 0) {
        deviceDict[@"carrier"] = carrierMeta.name;
    }
    
    if (carrierMeta.countryCode.length > 0) {
        deviceDict[@"mcc"] = @([carrierMeta.countryCode integerValue]);
    }
    
    if (carrierMeta.networkCode.length > 0) {
        deviceDict[@"mnc"] = @([carrierMeta.networkCode integerValue]);
    }
    if(EPLAdvertisingTrackingEnabled()){
        deviceDict[@"limit_ad_tracking"] = [NSNumber numberWithBool:NO];
    }
    NSDictionary<NSString *, id> *deviceId = [self deviceId];
    if (deviceId) {
        deviceDict[@"device_id"] = deviceId;
    }
#endif
   
    
    EPLReachability      *reachability    = [EPLReachability sharedReachabilityForInternetConnection];
    EPLNetworkStatus      status          = [reachability currentReachabilityStatus];
    NSUInteger           connectionType  = 0;

    switch (status) {
        case EPLNetworkStatusReachableViaWiFi:
            connectionType = 1;
            break;
        case EPLNetworkStatusReachableViaWWAN:
            connectionType = 2;
            break;
        default:
            connectionType = 0;
            break;
    }

    deviceDict[@"connectiontype"] = @(connectionType);


    


    //
    NSInteger timeInMiliseconds = (NSInteger)[[NSDate date] timeIntervalSince1970];
    deviceDict[@"devtime"] = @(timeInMiliseconds);


    //
    return [deviceDict copy];
}

- (NSDictionary<NSString *, id> *)geo
{

    EPLLocation  *location  = [self.adFetcherDelegate location];

    if (!location)  { return nil; }
    
    NSMutableDictionary<NSString *, id>  *geoDict  = [[NSMutableDictionary<NSString *, id> alloc] init];


    //
    if (location)
    {
        CGFloat  latitude   = location.latitude;
        CGFloat  longitude  = location.longitude;
        
        if (location.precision >= 0)
        {
            NSNumberFormatter *nf = [[self class] precisionNumberFormatter];

            nf.maximumFractionDigits = location.precision;
            nf.minimumFractionDigits = location.precision;

            geoDict[@"lat"] = [nf numberFromString:[NSString stringWithFormat:@"%f", location.latitude]];
            geoDict[@"lng"] = [nf numberFromString:[NSString stringWithFormat:@"%f", location.longitude]];

        } else {
            geoDict[@"lat"] = @(latitude);
            geoDict[@"lng"] = @(longitude);
        }
        
        NSDate          *locationTimestamp      = location.timestamp;
        NSTimeInterval   ageInSeconds           = -1.0 * [locationTimestamp timeIntervalSinceNow];
        NSInteger        ageInMilliseconds      = (NSInteger)(ageInSeconds * 1000);
        
        geoDict[@"loc_age"]         = @(ageInMilliseconds);
        geoDict[@"loc_precision"]   = @((NSInteger)location.horizontalAccuracy);
    }


    //
    return [geoDict copy];
}
#if !APPNEXUS_NATIVE_MACOS_SDK
- (NSDictionary<NSString *, id> *)deviceId
{
    if([EPLGDPRSettings canAccessDeviceData] && EPLAdvertisingTrackingEnabled() && !EPLSDKSettings.sharedInstance.doNotTrack){
        return [self fetchAdvertisingIdentifier];
    }
    
    return nil;
}
-(NSDictionary<NSString *, id> *) fetchAdvertisingIdentifier {
    NSString *idfa = EPLAdvertisingIdentifier();

    if (idfa) {
        return  @{ @"idfa" : idfa };
    } else {
        return  nil;
    }
}
#endif


- (NSDictionary<NSString *, id> *)app
{
    NSString  *appId  = [[NSBundle mainBundle] infoDictionary][@"CFBundleIdentifier"];

    if (appId) {
        return  @{ @"appid" : appId };
    } else {
        return  nil;
    }
}


// RETURN:  NSArray of NSDictionaries containing key/value pairs where the value is an NSArray of NSString.
//
- (NSArray<NSSet<NSString *> *> *)keywords
{
    NSDictionary<NSString *, NSArray<NSString *> *>  *customKeywords  = [self.adFetcherDelegate customKeywords];

    if ([customKeywords count] <= 0)  { return nil; }


    //
    NSMutableArray<NSDictionary<NSString *, id> *>  *kvSegmentsArray  = [[NSMutableArray<NSDictionary<NSString *, id> *> alloc] init];

    for (NSString *key in customKeywords)
    {
        NSArray<NSString *>  *valueArray  = [customKeywords objectForKey:key];

        if ([valueArray count] <= 0)  {
            EPLLogWarn(@"DISCARDING entry with values that are empty arrays.  (%@)", key);
            continue;
        }

        NSSet<NSString *>  *setOfUniqueArrayValues  = [NSSet setWithArray:valueArray];

        [kvSegmentsArray addObject:@{
                                         @"key"      : key,
                                         @"value"    : [setOfUniqueArrayValues allObjects]
                                     } ];
    }

    //
    return [kvSegmentsArray copy];
}

/**
 Get externalUserIds based on EPLAdvertisingTrackingEnabled() for iOS and isFirstParytId in iOS and macOS
 */
- (NSArray<NSDictionary<NSString *, NSString *> *> *)externalUserIds:(NSArray<EPLUserId *> *)userIdArray
{
    BOOL isAdvertisingTrackingEnabled =  NO;
    #if !APPNEXUS_NATIVE_MACOS_SDK
        isAdvertisingTrackingEnabled = EPLAdvertisingTrackingEnabled();
    #endif

    NSMutableArray<NSDictionary<NSString *, NSString *> *>  *transformedeuidArray  = [[NSMutableArray<NSDictionary<NSString *, NSString *> *> alloc] init];
    
        for (EPLUserId *userId in userIdArray)
        {
            // if EPLAdvertisingTracking is Enabled we will be sending the externalUserIds
            if(isAdvertisingTrackingEnabled){
                if([userId.source isEqualToString:@"adserver.org"]){
                    [transformedeuidArray addObject:@{
                        @"source"      : @"adserver.org",
                        @"id"          : userId.userId,
                        @"rti_partner"      : @"TDID"
                    } ];
                }else if ([userId.source isEqualToString:@"uidapi.com"]){
                    [transformedeuidArray addObject:@{
                        @"source"      : @"uidapi.com",
                        @"id"          : userId.userId,
                        @"rti_partner"      : @"UID2"
                    } ];
                    
                }else{
                    [transformedeuidArray addObject:@{
                        @"source"      : userId.source,
                        @"id"          : userId.userId
                    } ];
                }
                
            }else if(userId.isFirstParytId){
                // if EPLAdvertisingTracking is Diabled we will be sending the externalUserIds as First party Ids
                [transformedeuidArray addObject:@{
                    @"source"      : userId.source,
                    @"id"          : userId.userId
                } ];
                
            }
        }
    return [transformedeuidArray copy];
}

- (NSDictionary *)sdk {
    return  @{
        @"source" : @"ansdk",
        @"version" : EPL_SDK_VERSION
    };
    
}

- (NSDictionary *)getGDPRConsentObject
{
    NSNumber  *gdprRequired  = [EPLGDPRSettings getConsentRequired];
    if (gdprRequired != nil)
    {
        NSString  *gdprConsent   = [EPLGDPRSettings getConsentString];
        NSArray  *additionalConsentArray   = [EPLGDPRSettings getGoogleACMConsentArray];
        return  @{
                    @"consent_required"  : [NSNumber numberWithBool:gdprRequired.boolValue],
                    @"consent_string"    : gdprConsent,
                    @"addtl_consent"    : additionalConsentArray
                 };

    } else {
        return  nil;
    }
}


- (NSDictionary *)getGPPPrivacyObject
{
    NSString  *gpp_string   = [EPLGPPSettings getGPPString];
    NSArray  *gpp_sid_array   = [EPLGPPSettings getGPPSIDArray];
    if(gpp_sid_array){
        return  @{
                    @"gpp_sid"  : gpp_sid_array,
                    @"gpp"      : gpp_string
                 };
    }else{
        return nil;
    }
}

#if !APPNEXUS_NATIVE_MACOS_SDK

- (NSDictionary *)getIABSupport
{
    return  @{
        @"omidpn"  : EPL_OMIDSDK_PARTNER_NAME,
        @"omidpv"    : EPL_SDK_VERSION
    };
    return @{};
}
#endif

- (NSDictionary<NSString *, id> *)geoOverrideCountryZipCode
{
    NSMutableDictionary<NSString *, id>  *geoOverrideCountryZipCode  = [[NSMutableDictionary<NSString *, id> alloc] init];

    NSString *countryCode = [[EPLSDKSettings sharedInstance] geoOverrideCountryCode];
    if (countryCode.length != 0) {
        geoOverrideCountryZipCode[@"countryCode"] = countryCode;
    }
    NSString *zipCode = [[EPLSDKSettings sharedInstance] geoOverrideZipCode];
    if (zipCode.length != 0) {
        geoOverrideCountryZipCode[@"zip"] = zipCode;
    }
    return [geoOverrideCountryZipCode copy];
}

- (NSDictionary *)contentLanguage
{
    NSString *contentLang = [[EPLSDKSettings sharedInstance] contentLanguage];
    if (contentLang.length != 0) {
        return @{@"language" : contentLang};
    } else {
        return  nil;
    }
}

- (NSDictionary *)getDSAPrivacyObject {
    NSMutableDictionary *dsaPrivacyObject = [NSMutableDictionary dictionary];
    if ([EPLDSASettings.sharedInstance dsaRequired] > -1) {
        dsaPrivacyObject[@"dsarequired"] = @([EPLDSASettings.sharedInstance dsaRequired]);
    }
    if ([EPLDSASettings.sharedInstance pubRender] > -1) {
        dsaPrivacyObject[@"pubrender"] = @([EPLDSASettings.sharedInstance pubRender]);
    }
    if ([EPLDSASettings.sharedInstance dataToPub] > -1) {
        dsaPrivacyObject[@"datatopub"] = @([EPLDSASettings.sharedInstance dataToPub]);
    }

    NSArray<EPLDSATransparencyInfo *> *transparencyList = [EPLDSASettings.sharedInstance transparencyList];
    if (transparencyList && transparencyList.count > 0) {
        NSMutableArray *transparencyArray = [NSMutableArray array];
        for (EPLDSATransparencyInfo *transparency in transparencyList) {
            NSString *domain = [transparency domain];
            if (domain.length != 0) {
                NSMutableDictionary *transparencyObject = [NSMutableDictionary dictionary];
                transparencyObject[@"domain"] = domain;

                NSArray<NSNumber *> *dsaparams = [transparency dsaparams];
                if (dsaparams) {
                    transparencyObject[@"dsaparams"] = dsaparams;
                }

                [transparencyArray addObject:transparencyObject];
            }
        }
        dsaPrivacyObject[@"transparency"] = transparencyArray;
    }

    return dsaPrivacyObject;
}

#pragma mark - Class methods.

+ (NSNumberFormatter *)precisionNumberFormatter
{
    static  NSNumberFormatter  *precisionNumberFormatter;
    static  dispatch_once_t     precisionNumberFormatterToken;

    dispatch_once(&precisionNumberFormatterToken, ^{
        precisionNumberFormatter         = [[NSNumberFormatter alloc] init];
        precisionNumberFormatter.locale  = [NSLocale localeWithLocaleIdentifier:@"en_US"];
    });

    return  precisionNumberFormatter;
}

@end