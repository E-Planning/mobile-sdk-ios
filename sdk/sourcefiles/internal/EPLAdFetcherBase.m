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

#import "EPLAdFetcherBase+PrivateMethods.h"
#import "EPLUniversalTagRequestBuilder.h"
#import "EPLSDKSettings+PrivateMethods.h"
#import "EPLLogging.h"
#import "EPLGlobal.h"
#import "EPLStandardAd.h"
#import "EPLRTBVideoAd.h"
#import "EPLCSMVideoAd.h"
#import "EPLSSMStandardAd.h"
#import "EPLNativeStandardAdResponse.h"
#import "EPLMediatedAd.h"
#import "EPLAdConstants.h"

#if !APPNEXUS_NATIVE_MACOS_SDK
#import "EPLNativeMediatedAdController.h"
#endif


#import "EPLTrackerInfo.h"
#import "EPLTrackerManager.h"
#import "NSTimer+EPLCategory.h"
#import "EPLUniversalTagAdServerResponse.h"
#if !APPNEXUS_NATIVE_MACOS_SDK
    #import "EPLAdView+PrivateMethods.h"
#endif

#import "EPLGDPRSettings.h"
#import "EPLHTTPNetworkSession.h"
#import "EPLMultiAdRequest+PrivateMethods.h"
#import "EPLAd.h"

#pragma mark -

@interface EPLAdFetcherBase()

@end




#pragma mark -

@implementation EPLAdFetcherBase

#pragma mark Lifecycle.

- (nonnull instancetype)init
{
    self = [super init];
    if (!self)  { return nil; }
    
    return  self;
}

- (nonnull instancetype)initWithDelegate:(nonnull id)delegate andAdUnitMultiAdRequestManager:(nonnull EPLMultiAdRequest *)adunitMARManager
{
    self = [self init];
    if (!self)  { return nil; }
    
    //
    self.delegate = delegate;
    self.adunitMARManager = adunitMARManager;
    return  self;
}
- (nonnull instancetype)initWithMultiAdRequestManager: (nonnull EPLMultiAdRequest *)marManager
{
    self = [self init];
    if (!self)  { return nil; }
    
    //
    self.fetcherMARManager = marManager;
    
    return  self;
}

- (void)cookieSync:(NSHTTPURLResponse *)response
{
    if([EPLGDPRSettings canAccessDeviceData] && !EPLSDKSettings.sharedInstance.doNotTrack){
        NSArray *cookies = [NSHTTPCookie cookiesWithResponseHeaderFields:[response allHeaderFields] forURL:[response URL]];
        [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookies:cookies forURL:[response URL] mainDocumentURL:nil];
    }
    
}

-(void) stopAdLoad{
    self.isFetcherLoading = NO;
    self.ads = nil;
    
}
-(void)requestFailedWithError:(NSString *)error{
    NSError  *sessionError  = nil;
    if (self.fetcherMARManager) {
        sessionError = EPLError(@"multi_ad_request_failed %@", EPLAdResponseCode.NETWORK_ERROR.code,  error);
        [self.fetcherMARManager internalMultiAdRequestDidFailWithError:sessionError];
    }else{
        sessionError = EPLError(@"ad_request_failed %@", EPLAdResponseCode.NETWORK_ERROR.code, error);
        EPLAdFetcherResponse *response = [EPLAdFetcherResponse responseWithError:sessionError];
        [self processFinalResponse:response];
    }
    EPLLogError(@"%@", sessionError);
}

- (void)requestAd
{
    if (self.isFetcherLoading)  { return; }
    
    // If EPLAd.init is not called stop here and throw an exception. Dont process any further
    if(!EPLAd.sharedInstance.isInitialised){
        NSException* sdkInitException = [NSException
                exceptionWithName:@"SDKNotInitialized"
                reason:@"EPL SDK must be initialised before making an Ad Request."
                userInfo:nil];
         [sdkInitException raise];
    }
        
    
    NSMutableURLRequest  *request    = nil;
    
    if (self.fetcherMARManager) {
        request = [[EPLUniversalTagRequestBuilder buildRequestWithMultiAdRequestManager:self.fetcherMARManager] mutableCopy];
    } else if (self.adunitMARManager) {
        request = [[EPLUniversalTagRequestBuilder buildRequestWithAdFetcherDelegate:self.delegate adunitMultiAdRequestManager:self.adunitMARManager] mutableCopy];
    } else {
        request = [[EPLUniversalTagRequestBuilder buildRequestWithAdFetcherDelegate:self.delegate] mutableCopy];
    }
    
    
    if (!request){
        [self requestFailedWithError:@"request is nil."];
        return;
    }
    
    
    [EPLGlobal setANCookieToRequest:request];
    
    if(EPLSDKSettings.sharedInstance.enableTestMode){
        [request setValue:@"1" forHTTPHeaderField:@"X-Is-Test"];
    }
    
    NSString  *requestContent  = [NSString stringWithFormat:@"%@ /n %@", [request URL],[[NSString alloc] initWithData:[request HTTPBody] encoding:NSUTF8StringEncoding] ];
    
    EPLPostNotifications(kANUniversalAdFetcherWillRequestAdNotification, self,
                        @{kANUniversalAdFetcherAdRequestURLKey: requestContent});
    
    __weak __typeof__(self) weakSelf = self;
    [EPLHTTPNetworkSession startTaskWithHttpRequest:request responseHandler:^(NSData * _Nonnull data, NSHTTPURLResponse * _Nonnull response) {
        __typeof__(self) strongSelf = weakSelf;
        
        if (!strongSelf)  {
            EPLLogError(@"COULD NOT ACQUIRE strongSelf.");
            return;
        }
        
        if (!strongSelf.fetcherMARManager) {
            [strongSelf restartAutoRefreshTimer];
        }
        strongSelf.isFetcherLoading = YES;
        [strongSelf cookieSync:response];
        NSString *responseString = [[NSString alloc] initWithData:data
                                                         encoding:NSUTF8StringEncoding];
        if (! strongSelf.fetcherMARManager) {
            EPLLogDebug(@"Response JSON (for single tag requests ONLY)... %@", responseString);
        }
        
        EPLPostNotifications(kANUniversalAdFetcherDidReceiveResponseNotification, strongSelf,
                            @{kANUniversalAdFetcherAdResponseKey: (responseString ? responseString : @"")});
        
        [strongSelf handleAdServerResponse:data];
        
    } errorHandler:^(NSError * _Nonnull error) {
        NSError  *sessionError  = nil;
        __typeof__(self) strongSelf = weakSelf;
        
        if (!strongSelf)  {
            EPLLogError(@"COULD NOT ACQUIRE strongSelf.");
            return;
        }
        
        strongSelf.isFetcherLoading = NO;
        
        if (!strongSelf.fetcherMARManager) {
            [strongSelf restartAutoRefreshTimer];
        }
        
        [strongSelf requestFailedWithError:error.localizedDescription];
        EPLLogError(@"%@", sessionError);
    }];
}




#pragma mark - Response processing methods.

/**
 * Start with raw data from a UT Response.
 * Transform the data into an array of dictionaries representing UT Response tags.
 *
 * If the fetcher is called by an ad unit, the process the tag with the existing fetcher.
 * If the fetcher is called in Multi-Ad Request Mode, then process each tag with fetcher from the ad unit that generated the tag.
 */
- (void)handleAdServerResponse:(NSData *)data
{
    NSArray<NSDictionary *>  *arrayOfTags  = [EPLUniversalTagAdServerResponse generateTagsFromResponseData:data];
    
    if (!self.fetcherMARManager)
    {
        // If the UT Response is for a single adunit only, there should only be one ad object.
        //
        if (arrayOfTags.count > 1) {
            EPLLogWarn(@"UT Response contains MORE THAN ONE TAG (%@).  Using FIRST TAG ONLY and ignoring the rest...", @(arrayOfTags.count));
        }
        
        [self prepareForWaterfallWithAdServerResponseTag:[arrayOfTags firstObject]];
        
        return;
        
    } else {
        [self handleAdServerResponseForMultiAdRequest:arrayOfTags];
    }
}

- (void)handleAdServerResponseForMultiAdRequest:(NSArray<NSDictionary *> *)arrayOfTags
{
    // Multi-Ad Request Mode.
    //
    if (arrayOfTags.count <= 0)
    {
        NSError  *responseError  = EPLError(@"multi_ad_request_failed %@", EPLAdResponseCode.UNABLE_TO_FILL.code, @"UT Response FAILED to return any ad objects.");
        
        [self.fetcherMARManager internalMultiAdRequestDidFailWithError:responseError];
        return;
    }
    
    [self.fetcherMARManager internalMultiAdRequestDidComplete];
    
    // Process each ad object in turn, matching with adunit via UUID.
    //
    if (self.fetcherMARManager.countOfAdUnits != [arrayOfTags count]) {
        EPLLogWarn(@"Number of tags in UT Response (%@) DOES NOT MATCH number of ad units in MAR instance (%@).",
                  @([arrayOfTags count]), @(self.fetcherMARManager.countOfAdUnits));
    }
    
    for (NSDictionary<NSString *, id> *tag in arrayOfTags)
    {
        NSString  *uuid     = tag[kANUniversalTagAdServerResponseKeyTagUUID];
        id<EPLMultiAdProtocol> adunit   = [self.fetcherMARManager internalGetAdUnitByUUID:uuid];
        
        if (!adunit) {
            EPLLogWarn(@"UT Response tag UUID DOES NOT MATCH any ad unit in MAR instance.  Ignoring this tag...  (%@)", uuid);
            
        } else {
            [adunit ingestAdResponseTag:tag];
        }
    }
}


/**
 * Accept a single tag from an UT Response.
 * Divide the tag into ad objects and begin to process them via the waterfall.
 */
- (void)prepareForWaterfallWithAdServerResponseTag: (NSDictionary<NSString *, id> *)tag
{
    if (!tag) {
        EPLLogError(@"tag is nil.");
        [self finishRequestWithError:EPLError(@"response_no_ads", EPLAdResponseCode.UNABLE_TO_FILL.code) andAdResponseInfo:nil];
        return;
    }
    
    if (tag[kANUniversalTagAdServerResponseKeyNoBid])
    {
        BOOL  noBid  = [tag[kANUniversalTagAdServerResponseKeyNoBid] boolValue];
        
        if (noBid) {
            EPLLogWarn(@"response_no_ads");
            
            //
            EPLAdResponseInfo *adResponseInfo = [[EPLAdResponseInfo alloc] init];
            
            NSString *placementId  = @"";
            NSString *auctionId  = @"";
            if(tag[kANUniversalTagAdServerResponseKeyAdsTagId] != nil)
            {
                placementId = [NSString stringWithFormat:@"%@",tag[kANUniversalTagAdServerResponseKeyAdsTagId]];
            }
            
            if(tag[kANUniversalTagAdServerResponseKeyAdsAuctionId] != nil)
            {
                auctionId = [NSString stringWithFormat:@"%@",tag[kANUniversalTagAdServerResponseKeyAdsAuctionId]];
            }
                      
            adResponseInfo.placementId = placementId;
            adResponseInfo.auctionId = auctionId;

            [self finishRequestWithError:EPLError(@"response_no_ads", EPLAdResponseCode.UNABLE_TO_FILL.code) andAdResponseInfo:adResponseInfo];
            return;
        }
    }
    
    //
    NSMutableArray<id>  *ads            = [EPLUniversalTagAdServerResponse generateAdObjectInstanceFromJSONAdServerResponseTag:tag];
    NSString            *noAdURLString  = tag[kANUniversalTagAdServerResponseKeyTagNoAdUrl];
    
    if (ads.count <= 0)
    {
        EPLLogWarn(@"response_no_ads");
        [self finishRequestWithError:EPLError(@"response_no_ads", EPLAdResponseCode.UNABLE_TO_FILL.code) andAdResponseInfo:nil];
        return;
    }
    
    if (noAdURLString) {
        self.noAdUrl = noAdURLString;
    }
    
    //
    [self beginWaterfallWithAdObjects:ads];
}

- (void) beginWaterfallWithAdObjects:(nonnull NSMutableArray<id> *)ads
{
    self.ads = ads;
    
    [self clearMediationController];
    [self continueWaterfall:EPLAdResponseCode.UNABLE_TO_FILL];
}


- (void)fireResponseURL:(nullable NSString *)urlString
                 reason:(nonnull EPLAdResponseCode *)reason
               adObject:(nonnull id)adObject
{
    if (urlString) {
        [EPLTrackerManager fireTrackerURL:urlString];
    }
    
    if (reason.code == EPLAdResponseCode.SUCCESS.code) {
        EPLAdFetcherResponse *response = [EPLAdFetcherResponse responseWithAdObject:adObject andAdObjectHandler:self.adObjectHandler];
        [self processFinalResponse:response];
        
    } else {
        EPLLogError(@"FAILED with reason=%@.", reason.message);
        
        // mediated ad failed. clear mediation controller
        [self clearMediationController];
        
        // stop waterfall if delegate reference (adview) was lost
        if (!self.delegate) {
            self.isFetcherLoading = NO;
            return;
        }

        [self continueWaterfall:reason];
    }
}

- (void)finishRequestWithResponseCode:(EPLAdResponseCode *)reason
{
    EPLLogError(@"%@", reason.message);
    [self finishRequestWithError:EPLError(reason.message, reason.code, nil) andAdResponseInfo:nil];
}

@end
