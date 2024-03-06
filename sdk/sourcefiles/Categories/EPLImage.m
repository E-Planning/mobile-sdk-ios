/*   Copyright 2022 EPL INC
 
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

#import "EPLImage.h"

@implementation EPLImage
#if !APPNEXUS_NATIVE_MACOS_SDK

+ (nullable EPLImage *)getImageWithData:(NSData *_Nonnull)data{
    return   [EPLImage imageWithData:data];
}
#else
+ (nullable EPLImage *)getImageWithData:(NSData *_Nonnull)data{
    return [[EPLImage alloc] initWithData:data];
}
#endif
    


@end
