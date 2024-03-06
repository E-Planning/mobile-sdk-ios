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

#import "EPLMediatedAd.h"
#import "EPLAdProtocol.h"
#import "EPLNativeAdFetcher.h"
#import "EPLTargetingParameters.h"
#import "EPLNativeCustomAdapter.h"
@protocol EPLNativeMediationAdControllerDelegate;




@interface EPLNativeMediatedAdController : NSObject

// variables for measuring latency.
@property (nonatomic, readwrite, assign) NSTimeInterval latencyStart;
@property (nonatomic, readwrite, assign) NSTimeInterval latencyStop;

@property (nonatomic, readwrite, assign) BOOL hasSucceeded;
@property (nonatomic, readwrite, assign) BOOL hasFailed;
@property (nonatomic, readwrite, assign) BOOL timeoutCanceled;


@property (nonatomic, readwrite, weak)  EPLNativeAdFetcher  *adFetcher;
@property (nonatomic, readwrite, weak)  id<EPLNativeAdFetcherDelegate>     adRequestDelegate;

// Designated initializer for CSM Mediation
+ (instancetype)initMediatedAd:(EPLMediatedAd *)mediatedAd
                   withFetcher: (EPLNativeAdFetcher *)adFetcher
             adRequestDelegate:(id<EPLNativeAdRequestProtocol>)adRequestDelegate;



// Adapter helper methods
- (EPLTargetingParameters *)targetingParameters;
- (NSString *)createResponseURLRequest:(NSString *)baseString reason:(int)reasonCode;
- (void)didReceiveAd:(id)adObject;
- (BOOL)checkIfMediationHasResponded;
- (void)setAdapter:(id<EPLNativeCustomAdapter>)adapter;
- (void)clearAdapter;
- (void)didFailToReceiveAd:(EPLAdResponseCode *)errorCode;


// Adapter Error Handling
- (void)finish:(EPLAdResponseCode *)errorCode withAdObject:(id)adObject;
- (void)handleInstantiationFailure:(NSString *)className errorCode:(EPLAdResponseCode *)errorCode errorInfo:(NSString *)errorInfo;


// Adapter Latency Measurement
- (void)markLatencyStart;
- (void)markLatencyStop;
- (NSTimeInterval)getLatency;

// Adapter Timeout handler
- (void)startTimeout;
- (void)cancelTimeout;

@end

