/*   Copyright 2014 APPNEXUS INC
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import "XCTestCase+ANCategory.h"
#import "ANUniversalTagAdServerResponse.h"


static NSString *const kANAdResponseSuccessfulMRAID = @"SuccessfulMRAIDResponse";
static NSString *const kANAdResponseSuccessfulMediation = @"SuccessfulMediationResponse";
static NSString *const kANAdResponseSuccessfulMRAIDListener = @"SuccessfulMRAIDListenerResponse";


static NSString *const kANAdSuccessfulNativeStandardAdResponse = @"SuccessfulNativeStandardAdResponse";
static NSString *const kANAdSuccessfulANRTBVideoAdResponse = @"SuccessfulANRTBVideoAdResponse";
static NSString *const kStandardAdFromRTBObjectResponse = @"SuccessfulStandardAdFromRTBObjectResponse";

static NSString *const kANAdSuccessfulNativeStandardAdWithoutCreativeIdResponse = @"SuccessfulNativeStandardAdWithoutCreativeIdResponse";
static NSString *const kANAdSuccessfulANRTBVideoAdWithoutCreativeIdResponse = @"SuccessfulANRTBVideoAdWithoutCreativeIdResponse";
static NSString *const kStandardAdFromRTBObjectWithoutCreativeIdResponse = @"SuccessfulStandardAdFromRTBObjectWithoutCreativeIdResponse";

static NSString *const kSecondPriceForDFPSuccess = @"SecondPriceForDFPSuccess";
static NSString *const kSecondPriceForDFPParamIsUnset = @"SecondPriceForDFPParamIsUnset";



@interface XCTestCase (ANAdResponse)

- (NSMutableArray<id> *)adsArrayFromFirstTagInJSONResource:(NSString *)JSONResource;

@end
