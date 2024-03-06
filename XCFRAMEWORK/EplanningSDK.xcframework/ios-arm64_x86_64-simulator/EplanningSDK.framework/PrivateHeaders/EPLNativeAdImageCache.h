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
#import "EPLAdConstants.h"

#if !APPNEXUS_NATIVE_MACOS_SDK
#import <UIKit/UIKit.h>
#else
#import <AppKit/AppKit.h>
#endif
#import "EPLImage.h"

@interface EPLNativeAdImageCache : NSObject

+ (NSCache *)sharedImageCache;
+ (EPLImage *)imageForKey:(NSURL *)key;
+ (void)setImage:(EPLImage *)image forKey:(NSURL *)key;
+ (void)removeAllImages;

@end
