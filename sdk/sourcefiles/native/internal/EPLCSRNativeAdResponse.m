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

#import "EPLCSRNativeAdResponse.h"
#import "EPLTrackerManager.h"
#import "EPLOMIDImplementation.h"
#import "EPLNativeAdResponse+PrivateMethods.h"



@interface EPLCSRNativeAdResponse ()
@property (nonatomic, readwrite, strong) NSArray<NSString *> *impTrackers;
@property (nonatomic, readwrite, strong) NSArray<NSString *> *clickUrls;
@property (nonatomic, readwrite) BOOL impressionsHaveBeenTracked;
@property (nonatomic, readwrite) BOOL clickUrlsHaveBeenTracked;

@end

@implementation EPLCSRNativeAdResponse

-(void)registerOMID {
    [super registerOMID];
}

#pragma mark - Tracking

- (void)adWasClicked{
    [super adWasClicked];
    if (self.clickUrls && !self.clickUrlsHaveBeenTracked) {
        [EPLTrackerManager fireTrackerURLArray:self.clickUrls withBlock:nil];
    }
    self.clickUrlsHaveBeenTracked = YES;
}

@end
