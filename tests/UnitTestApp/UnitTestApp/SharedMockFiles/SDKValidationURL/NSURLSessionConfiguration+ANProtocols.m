/*   Copyright 2019 APPNEXUS INC
 
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
#import "NSURLSessionConfiguration+ANProtocols.h"
#import "SDKValidationURLProtocol.h"

@import ObjectiveC.runtime;

@implementation NSURLSessionConfiguration (ANProtocols)

+ (NSURLSessionConfiguration *)zw_defaultSessionConfiguration {
    NSURLSessionConfiguration *configuration = [self zw_defaultSessionConfiguration];
    NSArray *protocolClasses = @[[SDKValidationURLProtocol class]];
    configuration.protocolClasses = protocolClasses;
    return configuration;
}
+ (void)load{
    Method systemMethod = class_getClassMethod([NSURLSessionConfiguration class], @selector(defaultSessionConfiguration));
    Method zwMethod = class_getClassMethod([self class], @selector(zw_defaultSessionConfiguration));
    method_exchangeImplementations(systemMethod, zwMethod);
}

@end
