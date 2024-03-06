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

#import "EPLAdResponseCode.h"

static const NSInteger DEFAULT = -1 ;
static const NSInteger SUCCESS = 0 ;
static const NSInteger INVALID_REQUEST = 1 ;
static const NSInteger UNABLE_TO_FILL = 2 ;
static const NSInteger MEDIATED_SDK_UNAVAILABLE = 3 ;
static const NSInteger NETWORK_ERROR = 4 ;
static const NSInteger INTERNAL_ERROR = 5 ;
static const NSInteger REQUEST_TOO_FREQUENT = 6 ;
static const NSInteger BAD_FORMAT = 7 ;
static const NSInteger BAD_URL = 8 ;
static const NSInteger BAD_URL_CONNECTION = 9 ;
static const NSInteger NON_VIEW_RESPONSE = 10 ;
static const NSInteger CUSTOM_ADAPTER_ERROR = 11 ;


@interface EPLAdResponseCode ()

@property (nonatomic, readwrite, assign) NSInteger code;
@property (nonatomic, readwrite, strong, nonnull) NSString *message;

@end

@implementation EPLAdResponseCode

#pragma mark - Class methods

+ (nonnull EPLAdResponseCode *)DEFAULT{
    EPLAdResponseCode *responseCode = [EPLAdResponseCode new];
    responseCode.code = DEFAULT;
    responseCode.message = @"DEFAULT";
    return responseCode;
}

+ (nonnull EPLAdResponseCode *)SUCCESS{
    EPLAdResponseCode *responseCode = [EPLAdResponseCode new];
    responseCode.code = SUCCESS;
    responseCode.message = @"SUCCESS";
    return responseCode;
}

+ (nonnull EPLAdResponseCode *)INVALID_REQUEST{
    EPLAdResponseCode *responseCode = [EPLAdResponseCode new];
    responseCode.code = INVALID_REQUEST;
    responseCode.message = @"invalid_request_error";
    return responseCode;
}

+ (nonnull EPLAdResponseCode *)UNABLE_TO_FILL{
    EPLAdResponseCode *responseCode = [EPLAdResponseCode new];
    responseCode.code = UNABLE_TO_FILL;
    responseCode.message = @"response_no_ads";
    return responseCode;
}

+ (nonnull EPLAdResponseCode *)MEDIATED_SDK_UNAVAILABLE{
    EPLAdResponseCode *responseCode = [EPLAdResponseCode new];
    responseCode.code = MEDIATED_SDK_UNAVAILABLE;
    responseCode.message = @"MEDIATED_SDK_UNAVAILABLE";
    return responseCode;
}

+ (nonnull EPLAdResponseCode *)NETWORK_ERROR{
    EPLAdResponseCode *responseCode = [EPLAdResponseCode new];
    responseCode.code = NETWORK_ERROR;
    responseCode.message = @"ad_network_error";
    return responseCode;
}

+ (nonnull EPLAdResponseCode *)INTERNAL_ERROR{
    EPLAdResponseCode *responseCode = [EPLAdResponseCode new];
    responseCode.code = INTERNAL_ERROR;
    responseCode.message = @"ad_internal_error";
    return responseCode;
}

+ (nonnull EPLAdResponseCode *)REQUEST_TOO_FREQUENT{
    EPLAdResponseCode *responseCode = [EPLAdResponseCode new];
    responseCode.code = REQUEST_TOO_FREQUENT;
    responseCode.message = @"ad_request_too_frequent_error";
    return responseCode;
}

+ (nonnull EPLAdResponseCode *)BAD_FORMAT{
    EPLAdResponseCode *responseCode = [EPLAdResponseCode new];
    responseCode.code = BAD_FORMAT;
    responseCode.message = @"BAD_FORMAT";
    return responseCode;
}

+ (nonnull EPLAdResponseCode *)BAD_URL{
    EPLAdResponseCode *responseCode = [EPLAdResponseCode new];
    responseCode.code = BAD_URL;
    responseCode.message = @"BAD_URL";
    return responseCode;
}

+ (nonnull EPLAdResponseCode *)BAD_URL_CONNECTION{
    EPLAdResponseCode *responseCode = [EPLAdResponseCode new];
    responseCode.code = BAD_URL_CONNECTION;
    responseCode.message = @"BAD_URL_CONNECTION";
    return responseCode;
}

+ (nonnull EPLAdResponseCode *)NON_VIEW_RESPONSE{
    EPLAdResponseCode *responseCode = [EPLAdResponseCode new];
    responseCode.code = NON_VIEW_RESPONSE;
    responseCode.message = @"NON_VIEW_RESPONSE";
    return responseCode;
}

+ (nonnull EPLAdResponseCode *)CUSTOM_ADAPTER_ERROR:(nonnull NSString *) message{
    EPLAdResponseCode *responseCode = [EPLAdResponseCode new];
    responseCode.code = CUSTOM_ADAPTER_ERROR;
    responseCode.message = message;
    return responseCode;
}

@end
