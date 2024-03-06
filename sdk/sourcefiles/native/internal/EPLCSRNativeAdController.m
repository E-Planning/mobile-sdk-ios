/*   Copyright 2020 APPNEXUS INC
 
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

#import "EPLNativeCustomAdapter.h"
#import "EPLCSRNativeAdController.h"
#import "EPLNativeAdFetcher.h"
#import "EPLLogging.h"
#import "NSString+EPLCategory.h"
#import "NSObject+EPLCategory.h"
#import "EPLNativeAdResponse+PrivateMethods.h"
#import "EPLNativeMediatedAdResponse+PrivateMethods.h"

@interface EPLCSRNativeAdController () <EPLNativeCustomAdapterRequestDelegate>

@property (nonatomic, readwrite, strong) EPLCSRAd *csrAd;
@property (nonatomic, readwrite, strong) id<EPLNativeCustomAdapter> currentAdapter;

@end



@implementation EPLCSRNativeAdController
@synthesize adFetcher;
@synthesize adRequestDelegate;


+ (instancetype)initCSRAd: (EPLCSRAd *)csrAd
                   withFetcher: (EPLNativeAdFetcher *)adFetcher
             adRequestDelegate: (id<EPLNativeAdFetcherDelegate>)adRequestDelegate
{
    EPLCSRNativeAdController *controller = [[EPLCSRNativeAdController alloc] initCSRAd: csrAd
                                                                                          withFetcher: adFetcher
                                                                                    adRequestDelegate: adRequestDelegate];
    if ([controller initializeRequest]) {
        return controller;
    } else {
        return nil;
    }

}

- (instancetype)initCSRAd: (EPLCSRAd *)csrAd
                   withFetcher: (EPLNativeAdFetcher *)adFetcher
             adRequestDelegate: (id<EPLNativeAdFetcherDelegate>)adRequestDelegate
{
    self = [super init];
    if (self) {
        self.adFetcher  = adFetcher;
        self.adRequestDelegate = adRequestDelegate;
        self.csrAd = csrAd;
    }
    return self;
}


- (BOOL)initializeRequest {
    NSString *className = nil;
    NSString *errorInfo = nil;
    EPLAdResponseCode *errorCode = EPLAdResponseCode.DEFAULT;

    do {
        // check that the ad is non-nil
        if (!self.csrAd) {
            errorInfo = @"null csrAd ad object";
            errorCode = EPLAdResponseCode.UNABLE_TO_FILL;
            break;
        }
        
        className = self.csrAd.className;
        EPLLogDebug(@"instantiating_class %@", className);
        
        // notify that a csrAd class name was received
        EPLPostNotifications(kANUniversalAdFetcherWillInstantiateMediatedClassNotification, self,
                            @{kANUniversalAdFetcherMediatedClassKey: className});

        // check to see if an instance of this class exists
        Class adClass = NSClassFromString(className);
        if (!adClass) {
            errorInfo = @"ClassNotFoundError";
            errorCode = EPLAdResponseCode.MEDIATED_SDK_UNAVAILABLE;
            break;
        }
        
        id adInstance = [[adClass alloc] init];
        if (![self validAdInstance:adInstance]) {
            errorInfo = @"InstantiationError";
            errorCode = EPLAdResponseCode.MEDIATED_SDK_UNAVAILABLE;
            break;
        }
        
        // instance valid - request a csr ad
        id<EPLNativeCustomAdapter> adapter = (id<EPLNativeCustomAdapter>)adInstance;
        adapter.requestDelegate = self;
        self.currentAdapter = adapter;
        
        [self markLatencyStart];
        [self startTimeout];
        [self.currentAdapter requestAdwithPayload:self.csrAd.payload targetingParameters:[self targetingParameters]];
         
    } while (false);

    if (errorCode.code != EPLAdResponseCode.DEFAULT.code) {
        [self handleInstantiationFailure:className
                               errorCode:errorCode
                               errorInfo:errorInfo];
        return NO;
    }
    
    return YES;
}

- (BOOL)validAdInstance:(id)adInstance {
    if (!adInstance) {
        return NO;
    }
    if (![adInstance conformsToProtocol:@protocol(EPLNativeCustomAdapter)]) {
        return NO;
    }
    if (![adInstance respondsToSelector:@selector(setRequestDelegate:)]) {
        return NO;
    }
    if (![adInstance respondsToSelector:@selector(requestAdwithPayload:targetingParameters:)]) {
        return NO;
    }
    return YES;
}

#pragma mark - Timeout handler

- (void)startTimeout {
    if (self.timeoutCanceled) return;
    __weak EPLCSRNativeAdController *weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                  kAppNexusMediationNetworkTimeoutInterval
                                  * NSEC_PER_SEC),
                   dispatch_get_main_queue(), ^{
                       EPLCSRNativeAdController *strongSelf = weakSelf;
                       if (!strongSelf || strongSelf.timeoutCanceled) return;
                       EPLLogWarn(@"csr_timeout");
                       [strongSelf didFailToReceiveAd:EPLAdResponseCode.INTERNAL_ERROR];
                   });
}

#pragma mark - EPLNativeCustomAdapterRequestDelegate

- (void)didLoadNativeAd:(nonnull EPLNativeMediatedAdResponse *)response {
    // Add the AppNexusImpression trackers into the CSR response.
    response.impTrackers= [self.csrAd.impressionUrls copy];
    response.verificationScriptResource  = self.csrAd.verificationScriptResource;
    response.clickUrls = self.csrAd.clickUrls;
    [self didReceiveAd:response];
}

- (void)didFailToLoadNativeAd:(EPLAdResponseCode *)errorCode {
    [self didFailToReceiveAd:errorCode];
}


@end
