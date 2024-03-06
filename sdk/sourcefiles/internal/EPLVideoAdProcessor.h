/*   Copyright 2017 APPNEXUS INC
 
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
#import "EPLLogging.h"
#import "EPLCSMVideoAd.h"
#import "EPLGlobal.h"
#import "EPLVideoAdPlayer.h"


@protocol EPLVideoAdProcessorDelegate;

@interface EPLVideoAdProcessor : NSObject<EPLVideoAdPlayerDelegate>

- (nonnull instancetype)initWithDelegate:(nonnull id<EPLVideoAdProcessorDelegate>)delegate withAdVideoContent:(nonnull id) videoAdContent;

@end


@protocol  EPLVideoAdProcessorDelegate<NSObject>

    - (void) videoAdProcessor:(nonnull EPLVideoAdProcessor *)videoAdProcessor didFinishVideoProcessing: (nonnull EPLVideoAdPlayer *)adVideoPlayer;
    - (void) videoAdProcessor:(nonnull EPLVideoAdProcessor *)videoAdProcessor didFailVideoProcessing: (nonnull NSError *)error;

@end
