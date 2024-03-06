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

#import <Foundation/Foundation.h>

#define APPNEXUS_NATIVE_MACOS_SDK (!(TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_WATCH))

typedef NS_ENUM(NSUInteger, EPLGender) {
    EPLGenderUnknown,
    EPLGenderMale,
    EPLGenderFemale
};

typedef NS_ENUM(NSUInteger, EPLNativeAdRegisterErrorCode) {
    EPLNativeAdRegisterErrorCodeInvalidView = 200,
    EPLNativeAdRegisterErrorCodeInvalidRootViewController,
    EPLNativeAdRegisterErrorCodeExpiredResponse,
    EPLNativeAdRegisterErrorCodeBadAdapter,
    EPLNativeAdRegisterErrorCodeInternalError
};

typedef NS_ENUM(NSUInteger, EPLNativeAdNetworkCode) {
    EPLNativeAdNetworkCodeAppNexus = 0,
    EPLNativeAdNetworkCodeFacebook,
    EPLNativeAdNetworkCodeCustom,
    EPLNativeAdNetworkCodeAdMob
};

typedef NS_ENUM(NSUInteger, EPLAdType) {
    EPLAdTypeUnknown  = 0,
    EPLAdTypeBanner   = 1,
    EPLAdTypeVideo    = 2,
    EPLAdTypeNative   = 3
};

typedef NS_ENUM(NSUInteger, EPLClickThroughAction) {
// ClickThrough as return URL is supported by macOS
#if !APPNEXUS_NATIVE_MACOS_SDK
    EPLClickThroughActionReturnURL,
    EPLClickThroughActionOpenDeviceBrowser,
    EPLClickThroughActionOpenSDKBrowser
#else
    EPLClickThroughActionReturnURL
#endif

};
/*
 * VideoOrientation maps to the orientation of the Video being rendered
 * */
typedef NS_ENUM(NSUInteger, EPLVideoOrientation) {
    EPLUnknown,
    EPLPortrait,
    EPLLandscape,
    EPLSquare    
};







