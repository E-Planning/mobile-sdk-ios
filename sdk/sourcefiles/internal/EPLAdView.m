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

#import "EPLAdView.h"
#import "EPLAdView+PrivateMethods.h"

#import "EPLAdViewInternalDelegate.h"
#import "EPLGlobal.h"
#import "EPLLogging.h"

#import "UIView+EPLCategory.h"

#import "EPLBannerAdView.h"

#import "EPLStandardAd.h"
#import "EPLRTBVideoAd.h"

#import "EPLMultiAdRequest+PrivateMethods.h"
#import "EPLAdView+PrivateMethods.h"




#define  DEFAULT_PUBLIC_SERVICE_ANNOUNCEMENT  NO




@interface EPLAdView () <EPLAdFetcherDelegate>

@property (nonatomic, readwrite, weak)    id<EPLAdDelegate>         delegate;
@property (nonatomic, readwrite, weak)    id<EPLAppEventDelegate>   appEventDelegate;

@property (nonatomic, readwrite, strong)  EPLAdFetcher    *adFetcher;

@property (nonatomic, readwrite)  BOOL  allowSmallerSizes;

@property (nonatomic, readwrite, weak, nullable)  EPLMultiAdRequest  *marManager;

@property (nonatomic, readwrite, strong, nonnull)   NSString  *utRequestUUIDString;

@property (nonatomic, readwrite, strong, nullable) NSMutableArray<UIView *> *obstructionViews;

@end



@implementation EPLAdView

// EPLAdProtocol properties.
//
@synthesize  placementId                            = __placementId;
@synthesize  publisherId                            = __publisherId;
@synthesize  memberId                               = __memberId;
@synthesize  inventoryCode                          = __invCode;

@synthesize  shouldServePublicServiceAnnouncements  = __shouldServePublicServiceAnnouncements;
@synthesize  location                               = __location;

@synthesize  reserve                                = __reserve;
@synthesize  age                                    = __age;
@synthesize  gender                                 = __gender;
@synthesize  customKeywords                         = __customKeywords;

@synthesize  forceCreativeId                        = __forceCreativeId;

@synthesize  clickThroughAction                     = __clickThroughAction;
@synthesize  landingPageLoadsInBackground           = __landingPageLoadsInBackground;

@synthesize  adResponseInfo                         = __adResponseInfo;
@synthesize  obstructionViews                       = __obstructionViews;
@synthesize  extInvCode                             = __extInvCode;
@synthesize  trafficSourceCode                      = __trafficSourceCode;




#pragma mark - Initialization

- (instancetype)init {
    self = [super init];
    
    if (self != nil) {
        [self initialize];
    }
    
    return self;
}

//NB  Any entry point that requires awakeFromNib must locally set the size parameters: adSize, adSizes, allowSmallerSizes.
//
- (void)awakeFromNib {
    [super awakeFromNib];
    [self initialize];
}

- (void)initialize {
    self.clipsToBounds = YES;
    
    self.utRequestUUIDString            = EPLUUID();

    __shouldServePublicServiceAnnouncements  = DEFAULT_PUBLIC_SERVICE_ANNOUNCEMENT;
    __location                               = nil;
    __reserve                                = 0.0f;
    __customKeywords                         = [[NSMutableDictionary alloc] init];

    __clickThroughAction                     = EPLClickThroughActionOpenSDKBrowser;
    __landingPageLoadsInBackground           = YES;
    __obstructionViews = [[NSMutableArray alloc] init];

}

- (void)dealloc
{
    EPLLogDebug(@"%@", self.utRequestUUIDString);   //DEBUG
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    if (_adFetcher) {
        [self.adFetcher stopAdLoad];
    }
}

- (BOOL) errorCheckConfiguration
{
    NSString      *errorString  = nil;
    NSDictionary  *errorInfo    = nil;
    NSError       *error        = nil;


    //
    BOOL  placementIdValid    = [self.placementId length] >= 1;
    BOOL  inventoryCodeValid  = ([self memberId] >=1 ) && [self inventoryCode];


    if (!placementIdValid && !inventoryCodeValid) {
        NSString      *errorString  = EPLErrorString(@"no_placement_id");
        NSDictionary  *errorInfo    = @{NSLocalizedDescriptionKey: errorString};
        NSError       *error        = [NSError errorWithDomain:EPL_ERROR_DOMAIN code:EPLAdResponseCode.INVALID_REQUEST.code userInfo:errorInfo];

        errorString  = EPLErrorString(@"no_placement_id");
        errorInfo    = @{NSLocalizedDescriptionKey: errorString};
        error        = [NSError errorWithDomain:EPL_ERROR_DOMAIN code:EPLAdResponseCode.INVALID_REQUEST.code userInfo:errorInfo];
    }

    if ([self isKindOfClass:[EPLBannerAdView class]])
    {
        EPLBannerAdView  *bav  = (EPLBannerAdView *)self;

        if (!bav.adSizes) {
            errorString  = EPLErrorString(@"adSizes_undefined");
            errorInfo    = @{NSLocalizedDescriptionKey: errorString};
            error        = [NSError errorWithDomain:EPL_ERROR_DOMAIN code:EPLAdResponseCode.INVALID_REQUEST.code userInfo:errorInfo];
        }
    }


    //
    if (error) {
        EPLLogError(@"%@", errorString);
        [self adRequestFailedWithError:error andAdResponseInfo:nil];

        return  NO;
    }

    return  YES;
}

- (void)loadAd
{
    if (! [self errorCheckConfiguration])  { return; }

    //
    [self.adFetcher stopAdLoad];
    [self.adFetcher requestAd];
    
    if (! self.adFetcher)  {
        EPLLogError(@"Fetcher is unallocated.  FAILED TO FETCH ad via UT.");
    }
}


- (void)loadAdFromHtml: (nonnull NSString *)html
                 width: (int)width
                height: (int)height
{
    EPLStandardAd  *standardAd  = [EPLUniversalTagAdServerResponse generateStandardAdUnitFromHTMLContent:html width:width height:height];

    NSMutableArray<id>  *adsArray  = [[NSMutableArray<id> alloc] initWithObjects:standardAd, nil];

    [self.adFetcher beginWaterfallWithAdObjects:adsArray];
}

- (void)loadAdFromVast: (nonnull NSString *)xml
                 width: (int)width
                height: (int)height
{
    EPLRTBVideoAd  *rtbVideoAd  = [EPLUniversalTagAdServerResponse generateRTBVideoAdUnitFromVASTObject:xml width:width height:height];

    NSMutableArray<id>  *adsArray  = [[NSMutableArray<id> alloc] initWithObjects:rtbVideoAd, nil];

    [self.adFetcher beginWaterfallWithAdObjects:adsArray];
}

/**
 *  This method provides a single point of entry for the MAR object to pass tag content received in the UT Request to the fetcher defined by the adunit.
 *  Adding this public method which is used only for an internal process is more desirable than making the adFetcher property public.
 */
- (void)ingestAdResponseTag: (NSDictionary<NSString *, id> *)tag
{
    [self.adFetcher prepareForWaterfallWithAdServerResponseTag:tag];
}




#pragma mark - EPLAdProtocol: Setter methods


- (void)setForceCreativeId:(NSInteger)forceCreativeId {
    if (forceCreativeId <= 0) {
        EPLLogError(@"Could not set forceCreativeId to %ld", (long)forceCreativeId);
        return;
    }
    if (forceCreativeId != __forceCreativeId) {
        EPLLogDebug(@"Setting forceCreativeId to %ld", (long)forceCreativeId);
        __forceCreativeId = forceCreativeId;
    }
}


- (void)setAdResponseInfo:(EPLAdResponseInfo *)adResponseInfo {
    if (!adResponseInfo) {
        EPLLogError(@"Could not set adResponseInfo");
        return;
    }
    if (adResponseInfo != __adResponseInfo) {
        EPLLogDebug(@"Setting adResponseInfo to %@", adResponseInfo);
        __adResponseInfo = adResponseInfo;
    }
}

- (void)setExtInvCode:(nullable NSString *)extInvCode{
    extInvCode = EPLConvertToNSString(extInvCode);
    if ([extInvCode length] < 1) {
        EPLLogError(@"Could not set extInvCode to non-string value");
        return;
    }
    if (extInvCode != __extInvCode) {
        EPLLogDebug(@"Setting extInvCode to %@", extInvCode);
        __extInvCode = extInvCode;
    }
}

- (void)setTrafficSourceCode:(nullable NSString *)trafficSourceCode{
    trafficSourceCode = EPLConvertToNSString(trafficSourceCode);
    if ([trafficSourceCode length] < 1) {
        EPLLogError(@"Could not set trafficSourceCode to non-string value");
        return;
    }
    if (trafficSourceCode != __trafficSourceCode) {
        EPLLogDebug(@"Setting trafficSourceCode to %@", __trafficSourceCode);
        __trafficSourceCode = trafficSourceCode;
    }
}



- (void)setPlacementId:(nullable NSString *)placementId {
    placementId = EPLConvertToNSString(placementId);
    if ([placementId length] < 1) {
        EPLLogError(@"Could not set placementId to non-string value");
        return;
    }
    if (placementId != __placementId) {
        EPLLogDebug(@"Setting placementId to %@", placementId);
        __placementId = placementId;
    }
}

- (void)setPublisherId:(NSInteger)newPublisherId
{
    if ((newPublisherId > 0) && self.marManager)
    {
        if (self.marManager.publisherId != newPublisherId) {
            EPLLogError(@"Arguments ignored because newPublisherID (%@) is not equal to publisherID used in Multi-Ad Request.", @(newPublisherId));
            return;
        }
    }

    EPLLogDebug(@"Setting publisher ID to %d", (int) newPublisherId);
    __publisherId = newPublisherId;
}


/**
 *  Set inventoryCode and memberId.
 *  When marMangerDelegate is set, then only inventoryCode can be set if memberId is already set.
 *
 *  NB  If bound to MultiAdRequest, memberId/inventoryCode cannot be set in exchange of placementId.
 */
- (void)setInventoryCode:(nullable NSString *)newInvCode memberId:(NSInteger)newMemberId
{
    if ((newMemberId > 0) && self.marManager)
    {
        if (self.marManager.memberId != newMemberId) {
            EPLLogError(@"Arguments ignored because newMemberId (%@) is not equal to memberID used in Multi-Ad Request.", @(newMemberId));
            return;
        }
    }

    //
    newInvCode = EPLConvertToNSString(newInvCode);
    if (newInvCode && newInvCode != __invCode) {
        EPLLogDebug(@"Setting inventory code to %@", newInvCode);
        __invCode = newInvCode;
    }
    if (newMemberId > 0 && newMemberId != __memberId) {
        EPLLogDebug(@"Setting member id to %d", (int) newMemberId);
        __memberId = newMemberId;
    }
}

- (void)removeOpenMeasurementFriendlyObstruction:(nonnull UIView*)obstructionView{
    if( [__obstructionViews containsObject:obstructionView] ){
        [__obstructionViews removeObject:obstructionView];
    }
}
- (void)removeAllOpenMeasurementFriendlyObstructions{
    if(__obstructionViews != nil && __obstructionViews.count > 0){
        [__obstructionViews removeAllObjects];
    }
}

- (void)addOpenMeasurementFriendlyObstruction:(nonnull UIView *)obstructionView{
    if(obstructionView == nil){
        EPLLogError(@"Invalid Friendly Obstruction View. Friendly obstruction view can not be nil.");
        return;
    }
    if([__obstructionViews containsObject:obstructionView]){
        EPLLogError(@"View is already added as Friendly Obstruction");
        return;
    }
    [__obstructionViews addObject:obstructionView];
}


- (void)setLocationWithLatitude:(CGFloat)latitude longitude:(CGFloat)longitude
                      timestamp:(nullable NSDate *)timestamp horizontalAccuracy:(CGFloat)horizontalAccuracy {
    self.location = [EPLLocation getLocationWithLatitude:latitude
                                              longitude:longitude
                                              timestamp:timestamp
                                     horizontalAccuracy:horizontalAccuracy];
}

- (void)setLocationWithLatitude:(CGFloat)latitude longitude:(CGFloat)longitude
                      timestamp:(nullable NSDate *)timestamp horizontalAccuracy:(CGFloat)horizontalAccuracy
                      precision:(NSInteger)precision {
    self.location = [EPLLocation getLocationWithLatitude:latitude
                                              longitude:longitude
                                              timestamp:timestamp
                                     horizontalAccuracy:horizontalAccuracy
                                              precision:precision];
}


- (void)addCustomKeywordWithKey:(nonnull NSString *)key
                          value:(nonnull NSString *)value
{
    if (([key length] < 1) || !value) {
        return;
    }
    
    if(self.customKeywords[key] != nil){
        NSMutableArray *valueArray = (NSMutableArray *)[self.customKeywords[key] mutableCopy];
        if (![valueArray containsObject:value]) {
            [valueArray addObject:value];
        }
        self.customKeywords[key] = [valueArray copy];
    } else {
        self.customKeywords[key] = @[value];
    }
}

- (void)removeCustomKeywordWithKey:(nonnull NSString *)key
{
    if (([key length] < 1)) {
        return;
    }
    
    //check if the key exist before calling remove
    NSArray *keysArray = [self.customKeywords allKeys];
    
    if([keysArray containsObject:key]){
        [self.customKeywords removeObjectForKey:key];
    }
    
}

- (void)clearCustomKeywords
{
    [self.customKeywords removeAllObjects];
}

- (void)setClickThroughAction:(EPLClickThroughAction)clickThroughAction
{
    __clickThroughAction = clickThroughAction;
}

/**
 * adFetcher getter returns fetcher conditional upon whether marManager is set.
 * Therefore, adFetcher must be cleared anytime marManager is set to a different value.
 * adFetcher will be lazily recreated next time it is needed.
 */
- (void)setMarManager:(EPLMultiAdRequest *)marManager
{
    if (_adFetcher  &&  (marManager != _marManager)) {
        [_adFetcher stopAdLoad];
        _adFetcher = nil;
    }

    _marManager = marManager;
}




#pragma mark - EPLAdProtocol: Getter methods

- (nullable EPLAdResponseInfo *)adResponseInfo {
    EPLLogDebug(@"EPLAdResponse returned %@", __adResponseInfo);
    return __adResponseInfo;
}

- (nullable NSString *)placementId {
    EPLLogDebug(@"placementId returned %@", __placementId);
    return __placementId;
}

- (NSInteger )memberId {
    EPLLogDebug(@"memberId returned %d", (int)__memberId);
    return __memberId;
}

- (nullable NSString *)inventoryCode {
    EPLLogDebug(@"inventoryCode returned %@", __invCode);
    return __invCode;
}

- (nullable EPLLocation *)location {
    EPLLogDebug(@"location returned %@", __location);
    return __location;
}

- (BOOL)shouldServePublicServiceAnnouncements {
    EPLLogDebug(@"shouldServePublicServeAnnouncements returned %d", __shouldServePublicServiceAnnouncements);
    return __shouldServePublicServiceAnnouncements;
}

- (BOOL)landingPageLoadsInBackground {
    EPLLogDebug(@"landingPageLoadsInBackground returned %d", __landingPageLoadsInBackground);
    return __landingPageLoadsInBackground;
}

- (EPLClickThroughAction)clickThroughAction {
    EPLLogDebug(@"clickThroughAction returned %lu", (unsigned long)__clickThroughAction);
    return __clickThroughAction;
}

- (CGFloat)reserve {
    EPLLogDebug(@"reserve returned %f", __reserve);
    return __reserve;
}

- (nullable NSString *)age {
    EPLLogDebug(@"age returned %@", __age);
    return __age;
}

- (EPLGender)gender {
    EPLLogDebug(@"gender returned %lu", (long unsigned)__gender);
    return __gender;
}


- (EPLAdFetcher *)adFetcher
{
    if (_adFetcher) {
        return  _adFetcher;
    }

    if (self.marManager) {
        _adFetcher = [[EPLAdFetcher alloc] initWithDelegate:self andAdUnitMultiAdRequestManager:self.marManager];
    } else {
        _adFetcher = [[EPLAdFetcher alloc] initWithDelegate:self];
    }

    return  _adFetcher;
}



#pragma mark - EPLUniversalAdFetcherDelegate

- (void)       adFetcher: (EPLAdFetcher *)fetcher
     didFinishRequestWithResponse: (EPLAdFetcherResponse *)response
{
    EPLLogError(@"ABSTRACT METHOD -- Implement in each adunit.");
}

- (NSArray<NSValue *> *)adAllowedMediaTypes
{
    EPLLogError(@"ABSTRACT METHOD -- Implement in each adunit.");
    return  nil;
}
- (BOOL)enableNativeRendering
{
    EPLLogDebug(@"ABSTRACT METHOD -- Implement in Banner adunit");
    return NO;
}
- (NSInteger)nativeAdRendererId
{
    EPLLogDebug(@"ABSTRACT METHOD -- Implement in Banner and Native adunit");
    return 0;
}
- (NSDictionary *) internalDelegateUniversalTagSizeParameters
{
    EPLLogError(@"ABSTRACT METHOD -- Implement in each adunit.");
    return  nil;
}

- (nonnull NSString *)internalGetUTRequestUUIDString
{
    return  self.utRequestUUIDString;
}

- (void)internalUTRequestUUIDStringReset
{
     self.utRequestUUIDString = EPLUUID();
}

- (CGSize)requestedSizeForAdFetcher:(EPLAdFetcher *)fetcher
{
    EPLLogError(@"ABSTRACT METHOD -- Implement in each adunit.");
    return  CGSizeMake(-1, -1);
}

- (EPLVideoAdSubtype) videoAdTypeForAdFetcher:(EPLAdFetcher *)fetcher
{
    EPLLogWarn(@"ABSTRACT METHOD -- Implement in each adunit.");
    return  EPLVideoAdSubtypeUnknown;
}



#pragma mark - EPLAdViewInternalDelegate

- (void)adWasClicked {
    if ([self.delegate respondsToSelector:@selector(adWasClicked:)]) {
        [self.delegate adWasClicked:self];
    }
}

- (void)adWasClickedWithURL:(NSString *)urlString {
    if ([self.delegate respondsToSelector:@selector(adWasClicked:withURL:)]) {
        [self.delegate adWasClicked:self withURL:urlString];
    }
}

- (void)adDidLogImpression {
    if ([self.delegate respondsToSelector:@selector(adDidLogImpression:)]) {
        [self.delegate adDidLogImpression:self];
    }
}

- (void)adWillPresent {
    if ([self.delegate respondsToSelector:@selector(adWillPresent:)]) {
        [self.delegate adWillPresent:self];
    }
}

- (void)adDidPresent {
    if ([self.delegate respondsToSelector:@selector(adDidPresent:)]) {
        [self.delegate adDidPresent:self];
    }
}

- (void)adWillClose {
    if ([self.delegate respondsToSelector:@selector(adWillClose:)]) {
        [self.delegate adWillClose:self];
    }
}

- (void)adDidClose {
    if ([self.delegate respondsToSelector:@selector(adDidClose:)]) {
        [self.delegate adDidClose:self];
    }
}

- (void)adWillLeaveApplication {
    if ([self.delegate respondsToSelector:@selector(adWillLeaveApplication:)]) {
        [self.delegate adWillLeaveApplication:self];
    }
}

- (void)adDidReceiveAppEvent:(NSString *)name withData:(NSString *)data {
    if ([self.appEventDelegate respondsToSelector:@selector(ad:didReceiveAppEvent:withData:)]) {
        [self.appEventDelegate ad:self didReceiveAppEvent:name withData:data];
    }
}


- (void)adDidReceiveAd:(id)adObject
{
    if ([self.delegate respondsToSelector:@selector(adDidReceiveAd:)]) {
        [self.delegate adDidReceiveAd:adObject];
    }
}

- (void)lazyAdDidReceiveAd:(nonnull id)adObject
{
    if ([self.delegate respondsToSelector:@selector(lazyAdDidReceiveAd:)])
    {
        [self.delegate lazyAdDidReceiveAd:adObject];
    }
}


- (void)ad:(id)loadInstance didReceiveNativeAd:(id)responseInstance
{
    if ([self.delegate respondsToSelector:@selector(ad:didReceiveNativeAd:)]) {
        [self.delegate ad:loadInstance didReceiveNativeAd:responseInstance];
    }   
}

- (void)adRequestFailedWithError:(NSError *)error andAdResponseInfo:(EPLAdResponseInfo *)adResponseInfo
{
    [self setAdResponseInfo:adResponseInfo];
    
    if ([self.delegate respondsToSelector:@selector(ad:requestFailedWithError:)]) {
        [self.delegate ad:self requestFailedWithError:error];
    }
}


- (void)adInteractionDidBegin
{
    EPLLogDebug(@"");
    [self.adFetcher stopAdLoad];
}

- (void)adInteractionDidEnd
{
    EPLLogDebug(@"");

    if (EPLAdTypeVideo != __adResponseInfo.adType) {
        [self.adFetcher restartAutoRefreshTimer];
        [self.adFetcher startAutoRefreshTimer];
    }
}

- (NSString *)adTypeForMRAID
{
    EPLLogDebug(@"ABSTRACT METHOD.  MUST be implemented by subclass.");
    return @"";
}

- (UIViewController *)displayController
{
    EPLLogDebug(@"ABSTRACT METHOD.  MUST be implemented by subclass.");
    return nil;
}

- (NSMutableDictionary<NSString *, NSArray<NSString *> *> *)customkeywordsForANJAM {
    return __customKeywords;
}


@end

