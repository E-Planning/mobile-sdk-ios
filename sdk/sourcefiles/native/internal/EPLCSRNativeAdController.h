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

#import "EPLCSRAd.h"
#import "EPLAdProtocol.h"
#import "EPLNativeAdFetcher.h"
#import "EPLNativeMediatedAdController.h"

@interface EPLCSRNativeAdController : EPLNativeMediatedAdController

// Designated initializer for CSR NativeBanner Adapter
+ (instancetype)initCSRAd: (EPLCSRAd *)csrAd
      withFetcher: (EPLNativeAdFetcher *)adFetcher
             adRequestDelegate: (id<EPLNativeAdFetcherDelegate>)adRequestDelegate;
@end
