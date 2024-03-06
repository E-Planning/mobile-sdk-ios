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

#import "EPLNativeAdRequest.h"
#import "EPLNativeAdFetcher.h"
#import "EPLGlobal.h"
#import "EPLLogging.h"
#import "EPLAdConstants.h"

#if !APPNEXUS_NATIVE_MACOS_SDK
#import "EPLOMIDImplementation.h"
#import "EPLNativeMediatedAdResponse.h"
#endif
#import "EPLNativeAdImageCache.h"
#import "EPLMultiAdRequest+PrivateMethods.h"
#import "EPLHTTPNetworkSession.h"
#import "EPLNativeAdResponse+PrivateMethods.h"
#import "EPLImage.h"



@interface EPLNativeAdRequest() <EPLNativeAdFetcherDelegate>

@property (nonatomic, readwrite, strong) EPLNativeAdFetcher *adFetcher;

@property (nonatomic, strong)     NSMutableSet<NSValue *>  *allowedAdSizes;
@property (nonatomic, readwrite)  BOOL                      allowSmallerSizes;
@property (nonatomic, readwrite, weak, nullable)  EPLMultiAdRequest  *marManager;


@property (nonatomic, readwrite, strong, nonnull)  NSString  *utRequestUUIDString;

@end




@implementation EPLNativeAdRequest

#pragma mark - EPLNativeAdRequestProtocol properties.

// EPLNativeAdRequestProtocol properties.
//
@synthesize  placementId     = __placementId;
@synthesize  publisherId     = __publisherId;
@synthesize  memberId        = __memberId;
@synthesize  inventoryCode   = __invCode;
@synthesize  location        = __location;
@synthesize  reserve         = __reserve;
@synthesize  age             = __age;
@synthesize  gender          = __gender;
@synthesize  customKeywords  = __customKeywords;
@synthesize  forceCreativeId     = __forceCreativeId;
@synthesize  rendererId             = _rendererId;
@synthesize  extInvCode             = __extInvCode;
@synthesize  trafficSourceCode      = __trafficSourceCode;
@synthesize  shouldServePublicServiceAnnouncements  = __shouldServePublicServiceAnnouncements;




#pragma mark - Lifecycle.

- (instancetype)init
{
    self = [super init];
    if (!self)  { return nil; }


    //
    self.customKeywords = [[NSMutableDictionary alloc] init];

    [self setupSizeParametersAs1x1];
#if !APPNEXUS_NATIVE_MACOS_SDK
    [[EPLOMIDImplementation sharedInstance] activateOMIDandCreatePartner];
#endif

    
    self.utRequestUUIDString = EPLUUID();
    return self;
}

- (void) setupSizeParametersAs1x1
{
#if !APPNEXUS_NATIVE_MACOS_SDK
    self.allowedAdSizes     = [NSMutableSet setWithObject:[NSValue valueWithCGSize:kANAdSize1x1]];
#else
    self.allowedAdSizes     = [NSMutableSet setWithObject:[NSValue valueWithSize:kANAdSize1x1]];
#endif
    self.allowSmallerSizes  = NO;
    _rendererId             = 0;
}

- (void)loadAd
{
    if (!self.delegate) {
        EPLLogError(@"EPLNativeAdRequestDelegate must be set on EPLNativeAdRequest in order for an ad to begin loading");
        return;
    }
    [self createAdFetcher];
    [self.adFetcher requestAd];
}

/**
 *  This method provides a single point of entry for the MAR object to pass tag content received in the UT Request to the fetcher defined by the adunit.
 *  Adding this public method which is used only for an internal process is more desirable than making the adFetcher property public.
 */
- (void)ingestAdResponseTag: (NSDictionary<NSString *, id> *)tag
{
    if (!self.delegate) {
        EPLLogError(@"EPLNativeAdRequestDelegate must be set on EPLNativeAdRequest in order for an ad to be ingested.");
        return;
    }

    [self createAdFetcher];

    [self.adFetcher prepareForWaterfallWithAdServerResponseTag:tag];
}

- (void)createAdFetcher
{
    if (self.marManager) {
        self.adFetcher = [[EPLNativeAdFetcher alloc] initWithDelegate:self andAdUnitMultiAdRequestManager:self.marManager];
    } else {
        self.adFetcher  = [[EPLNativeAdFetcher alloc] initWithDelegate:self];
    }
}




#pragma mark - EPLNativeAdFetcherDelegate.

-(void)didFinishRequestWithResponse: (nonnull EPLAdFetcherResponse *)response
{
    NSError  *error  = nil;

    if (!response.isSuccessful) {
        error = response.error;

    } else if (! [response.adObject isKindOfClass:[EPLNativeAdResponse class]]) {
        error = EPLError(@"native_request_invalid_response", EPLAdResponseCode.BAD_FORMAT.code);
    }

    if (error) {
        if ([self.delegate respondsToSelector:@selector(adRequest:didFailToLoadWithError:withAdResponseInfo:)]) {
            [self.delegate adRequest:self didFailToLoadWithError:error withAdResponseInfo:response.adResponseInfo];
        }

        return;
    }


    //
    __weak EPLNativeAdRequest  *weakSelf        = self;
    EPLNativeAdResponse        *nativeResponse  = (EPLNativeAdResponse *)response.adObject;
    
    // register AdWillExpire
    [nativeResponse registerAdWillExpire];
        
    // In case of Mediation
    if (nativeResponse.adResponseInfo == nil) {
        EPLAdResponseInfo *adResponseInfo  = (EPLAdResponseInfo *) [EPLGlobal valueOfGetterProperty:kANAdResponseInfo forObject:response.adObjectHandler];
        if (adResponseInfo) {
            [self setAdResponseInfo:adResponseInfo onObject:nativeResponse forKeyPath:kANAdResponseInfo];
        }
    }

    //
    dispatch_queue_t  backgroundQueue  = dispatch_queue_create(__PRETTY_FUNCTION__, DISPATCH_QUEUE_SERIAL);

    dispatch_async(backgroundQueue,
    ^{
        __strong EPLNativeAdRequest  *strongSelf  = weakSelf;

        if (!strongSelf) {
           EPLLogError(@"FAILED to access strongSelf.");
           return;
        }

        //
        dispatch_semaphore_t  semaphoreMainImage  = nil;
        dispatch_semaphore_t  semaphoreIconImage  = nil;

        
        if (self.shouldLoadMainImage && [nativeResponse respondsToSelector:@selector(setMainImage:)])
        {
            semaphoreMainImage = [self setImageInBackgroundForImageURL: nativeResponse.mainImageURL
                                                              onObject: nativeResponse
                                                            forKeyPath: @"mainImage" ];
        }

        if (self.shouldLoadIconImage && [nativeResponse respondsToSelector:@selector(setIconImage:)])
        {
            semaphoreIconImage = [self setImageInBackgroundForImageURL: nativeResponse.iconImageURL
                                                              onObject: nativeResponse
                                                            forKeyPath: @"iconImage" ];
        }

        if (semaphoreMainImage)  {
            dispatch_semaphore_wait(semaphoreMainImage, DISPATCH_TIME_FOREVER);
        }

        if (semaphoreIconImage)  {
            dispatch_semaphore_wait(semaphoreIconImage, DISPATCH_TIME_FOREVER);
        }


        dispatch_async(dispatch_get_main_queue(), ^{
            EPLLogDebug(@"...END NSURL sessions.");

            if ([strongSelf.delegate respondsToSelector:@selector(adRequest:didReceiveResponse:)]) {
                [strongSelf.delegate adRequest:strongSelf didReceiveResponse:nativeResponse];
            }
        });
    });
}

- (NSArray<NSValue *> *)adAllowedMediaTypes
{
    return  @[ @(EPLAllowedMediaTypeNative) ];
}

-(NSInteger) nativeAdRendererId{
    return _rendererId;
}

- (NSDictionary *) internalDelegateUniversalTagSizeParameters
{
    NSMutableDictionary  *delegateReturnDictionary  = [[NSMutableDictionary alloc] init];
 
#if !APPNEXUS_NATIVE_MACOS_SDK
    [delegateReturnDictionary setObject:[NSValue valueWithCGSize:kANAdSize1x1]  forKey:EPLInternalDelgateTagKeyPrimarySize];
#else
    [delegateReturnDictionary setObject:[NSValue valueWithSize:kANAdSize1x1]  forKey:EPLInternalDelgateTagKeyPrimarySize];
#endif
    [delegateReturnDictionary setObject:self.allowedAdSizes                     forKey:EPLInternalDelegateTagKeySizes];
    [delegateReturnDictionary setObject:@(self.allowSmallerSizes)               forKey:EPLInternalDelegateTagKeyAllowSmallerSizes];

  
    return  delegateReturnDictionary;
}

- (NSString *)internalGetUTRequestUUIDString
{
    return  self.utRequestUUIDString;
}

- (void)internalUTRequestUUIDStringReset
{
    self.utRequestUUIDString = EPLUUID();
}


// NB  Some duplication between EPLNativeAd* and the other entry points is inevitable because EPLNativeAd* does not inherit from EPLAdView.
//
#pragma mark - EPLUniversalAdFetcherFoundationDelegate helper methods.


- (void)setAdResponseInfo:(EPLAdResponseInfo *)adResponseInfo
             onObject:(id)object forKeyPath:(NSString *)keyPath
{
    [object setValue:adResponseInfo forKeyPath:keyPath];
}

// RETURN:  dispatch_semaphore_t    For first time image requests.
//          nil                     When image is cached  -OR-  if imageURL is undefined.
//
// If semaphore is defined, call dispatch_semaphore_wait(semaphor, DISPATCH_TIME_FOREVER) to wait for this background task
//   before continuing in the calling method.
// Wait period is limited by NSURLRequest with timeoutInterval of kAppNexusNativeAdImageDownloadTimeoutInterval.
//

- (dispatch_semaphore_t) setImageInBackgroundForImageURL: (NSURL *)imageURL
                                                onObject: (id)object
                                              forKeyPath: (NSString *)keyPath
{
    if (!imageURL)  { return nil; }

   
    EPLImage *cachedImage = [EPLNativeAdImageCache imageForKey:imageURL];
    
    if (cachedImage) {
        [object setValue:cachedImage forKeyPath:keyPath];
        return  nil;
    }

    //
    dispatch_semaphore_t  semaphore  = dispatch_semaphore_create(0);

    NSURLRequest  *request  = [NSURLRequest requestWithURL: imageURL
                                               cachePolicy: NSURLRequestReloadIgnoringLocalCacheData
                                           timeoutInterval: kAppNexusNativeAdImageDownloadTimeoutInterval];
    
    
    [EPLHTTPNetworkSession startTaskWithHttpRequest:request responseHandler:^(NSData * _Nonnull data, NSHTTPURLResponse * _Nonnull response) {
        
        EPLImage  *image  = [EPLImage getImageWithData:data];
        if (image) {
            [EPLNativeAdImageCache setImage:image forKey:imageURL];
            [object setValue:image forKeyPath:keyPath];
        }
        dispatch_semaphore_signal(semaphore);
        
    } errorHandler:^(NSError * _Nonnull error) {
        EPLLogError(@"Error downloading image: %@", error);
        dispatch_semaphore_signal(semaphore);
    }];
    //
    return  semaphore;
}



#pragma mark - EPLNativeAdRequestProtocol methods.

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
    
    [self.customKeywords removeObjectForKey:key];
}

- (void)clearCustomKeywords
{
    [self.customKeywords removeAllObjects];
}

@end

