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

#import "ANAdAdapterBannerTimeoutThenSuccessful.h"
#import "NSTimer+ANCategory.h"
#import "ANGlobal.h"

@implementation ANAdAdapterBannerTimeoutThenSuccessful
@synthesize delegate;

- (void)requestBannerAdWithSize:(CGSize)size
             rootViewController:(UIViewController *)rootViewController
                serverParameter:(NSString *)parameterString
                       adUnitId:(NSString *)idString
            targetingParameters:(ANTargetingParameters *)targetingParameters {
    NSTimer *timer = [NSTimer timerWithTimeInterval:kAppNexusMediationNetworkTimeoutInterval + 5.0
                                             target:self
                                           selector:@selector(adDidLoad)
                                           userInfo:nil
                                            repeats:NO];
    [[NSRunLoop currentRunLoop] addTimer:timer
                                 forMode:NSRunLoopCommonModes];
}

- (void)adDidLoad {
    [self.delegate didLoadBannerAd:[UIView new]];
}

@end