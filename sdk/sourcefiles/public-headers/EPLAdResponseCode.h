/*   Copyright 2020 APPNEXUS INC

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

#pragma mark - ResponseCode Local contants

@interface EPLAdResponseCode : NSObject
/**
 * Get Code assigned to this instance of ResponseCode
*/
@property (nonatomic, readonly, assign) NSInteger code;
/**
 * Get Message assigned to this instance of ResponseCode
*/
@property (nonatomic, readonly, strong, nonnull) NSString *message;
/**
 * @brief This initializer method can be used to obtain a new instance of ResponseCode, by passing in the code
 * @discussion Initial default value
 */
+ (nonnull EPLAdResponseCode *)DEFAULT;
/**
 * @brief This initializer method can be used to obtain a new instance of ResponseCode, by passing in the code
 * @discussion The ad loaded successfully.
 */
+ (nonnull EPLAdResponseCode *)SUCCESS;
/**
 * @brief This initializer method can be used to obtain a new instance of ResponseCode, by passing in the code
 * @discussion The ad request failed due to an invalid configuration (for example, size
 * or placement ID not set).
 */
+ (nonnull EPLAdResponseCode *)INVALID_REQUEST;
/**
 * @brief This initializer method can be used to obtain a new instance of ResponseCode, by passing in the code
 * @discussion The network did not return an ad in this call.
 */
+ (nonnull EPLAdResponseCode *)UNABLE_TO_FILL;
/**
 * @brief This initializer method can be used to obtain a new instance of ResponseCode, by passing in the code
 * @discussion Used internally when the third-party SDK is not available.
 */
+ (nonnull EPLAdResponseCode *)MEDIATED_SDK_UNAVAILABLE;
/**
 * @brief This initializer method can be used to obtain a new instance of ResponseCode, by passing in the code
 * @discussion The ad request failed due to a network error.
 */
+ (nonnull EPLAdResponseCode *)NETWORK_ERROR;
/**
 * @brief This initializer method can be used to obtain a new instance of ResponseCode, by passing in the code
 * @discussion An internal error is detected in the interacting with the
 * third-party SDK.
 */
+ (nonnull EPLAdResponseCode *)INTERNAL_ERROR;
/**
 * @brief This initializer method can be used to obtain a new instance of ResponseCode, by passing in the code
 * @discussion Called loadAd too many times
 */
+ (nonnull EPLAdResponseCode *)REQUEST_TOO_FREQUENT;
/**
 * @brief This initializer method can be used to obtain a new instance of ResponseCode, by passing in the code
 * @discussion The server responded with ads, but in an unexpected format
 */
+ (nonnull EPLAdResponseCode *)BAD_FORMAT;
/**
 * @brief This initializer method can be used to obtain a new instance of ResponseCode, by passing in the code
 * @discussion Unable to make request because of a malformed URL
 */
+ (nonnull EPLAdResponseCode *)BAD_URL;
/**
 * @brief This initializer method can be used to obtain a new instance of ResponseCode, by passing in the code
 * @discussion Unable to make request because of a bad URL connection
 */
+ (nonnull EPLAdResponseCode *)BAD_URL_CONNECTION;
/**
 * @brief This initializer method can be used to obtain a new instance of ResponseCode, by passing in the code
 * @discussion Response can't be viewable
 */
+ (nonnull EPLAdResponseCode *)NON_VIEW_RESPONSE;
/**
 * @brief This initializer method can be used to obtain a new instance of ResponseCode, by passing in the code
 * @discussion Pass errors from adapters to users
 */
+ (nonnull EPLAdResponseCode *)CUSTOM_ADAPTER_ERROR:(nonnull NSString *) message;

@end

