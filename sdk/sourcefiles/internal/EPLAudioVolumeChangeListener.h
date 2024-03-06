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

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>

@protocol EPLAudioVolumeChangeListenerDelegate;

@interface EPLAudioVolumeChangeListener : NSObject

@property (nonatomic, readwrite, assign)  BOOL isAudioSessionActive;
@property (nonatomic, readwrite, weak) id<EPLAudioVolumeChangeListenerDelegate> delegate;

- (id)initWithDelegate:(id<EPLAudioVolumeChangeListenerDelegate>)delegate;
- (NSNumber *)getAudioVolumePercentage;

@end

@protocol EPLAudioVolumeChangeListenerDelegate <NSObject>

- (void)didUpdateAudioLevel:(NSNumber *)volumePercentage;

@end
