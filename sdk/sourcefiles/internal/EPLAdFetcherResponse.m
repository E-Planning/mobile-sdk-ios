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

#import <Foundation/Foundation.h>

#import "EPLAdFetcherResponse.h"

#import "EPLLogging.h"

#if !APPNEXUS_NATIVE_MACOS_SDK
  #import <UIKit/UIKit.h>
#endif



#pragma mark -

@interface EPLAdFetcherResponse ()

@property (nonatomic, readwrite, assign, getter=isSuccessful)  BOOL  successful;
@property (nonatomic, readwrite)                               BOOL  isLazy;

@property (nonatomic, readwrite, strong, nullable) id adObjectHandler;

@property (nonatomic, readwrite, strong, nullable)  NSString  *adContent;
@property (nonatomic, readwrite)                    CGSize     sizeOfWebview;
@property (nonatomic, readwrite, strong, nullable)  NSURL     *baseURL;
@property (nonatomic, readwrite, strong, nullable)  id         anjamDelegate;

@property (nonatomic, readwrite, strong, nullable) NSError *error;

@end



#pragma mark -

@implementation EPLAdFetcherResponse

#pragma mark Lifecycle.

- (nonnull instancetype)initAdResponseFailWithError:(nonnull NSError *)error {
    self = [super init];
    if (self) {
        _error = error;
    }
    return self;
}


- (nonnull instancetype)initAdResponseWithAdObject: (nonnull id)adObject
                                andAdObjectHandler: (nullable id)adObjectHandler
{
    self = [super init];

    if (!self)  { return nil; }


    //
    _successful             = YES;

    _adObject               = adObject;
    _adObjectHandler        = adObjectHandler;

    return self;
}

- (nonnull EPLAdFetcherResponse *)initLazyResponseWithAdObject: (nonnull id)adObject
                                           andAdObjectHandler: (nonnull id)adObjectHandler
{
    self = [super init];

    if (!self)  { return nil; }


    //
    _successful                     = YES;
    _isLazy                         = YES;

    _adObject                       = adObject;
    _adObjectHandler                = adObjectHandler;

    return self;
}



#pragma mark - Class methods.

+ (nonnull EPLAdFetcherResponse *)responseWithError:(nonnull NSError *)error {
    return [[EPLAdFetcherResponse alloc] initAdResponseFailWithError:error];
}


+ (nonnull EPLAdFetcherResponse *)responseWithAdObject: (nonnull id)adObject
                                   andAdObjectHandler: (nullable id)adObjectHandler
{
    return [[EPLAdFetcherResponse alloc] initAdResponseWithAdObject: adObject
                                                andAdObjectHandler: adObjectHandler ];
}

+ (nonnull EPLAdFetcherResponse *)lazyResponseWithAdObject: (nonnull id)adObject
                                       andAdObjectHandler: (nonnull id)adObjectHandler
{
    return  [[EPLAdFetcherResponse alloc] initLazyResponseWithAdObject:adObject andAdObjectHandler:adObjectHandler];
}


@end
