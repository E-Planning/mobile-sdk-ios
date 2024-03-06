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


#import "EPLAudioVolumeChangeListener.h"
#import "EPLLogging.h"

@interface EPLAudioVolumeChangeListener ()

@property (nonatomic, readwrite, strong) UISlider *audioVolumeSlider;

@end

@implementation EPLAudioVolumeChangeListener

#pragma mark - Init

- (id)initWithDelegate:(id<EPLAudioVolumeChangeListenerDelegate>)delegate {
    self = [super init];
    if ( self ) {
        self.delegate = delegate;
        [self setupVolumeView];
    }
    
    return self;
}


#pragma mark - MPVolumeView Setup

- (void)setupVolumeView
{
    MPVolumeView *viewVolume = [[MPVolumeView alloc] init];
    __block UISlider *slider = nil;
    [viewVolume.subviews enumerateObjectsUsingBlock:^(UISlider *obj, NSUInteger idx, BOOL *stop) {
        if ([obj isKindOfClass:[UISlider class]]){
            slider = obj;
            *stop = YES;
        }
    }];
    if (slider == nil){
        self.isAudioSessionActive = NO;
        EPLLogDebug(@"Unable to find MPVolumeSlider in MPVolumeView");
        return;
    }
    self.isAudioSessionActive = YES;
    self.audioVolumeSlider = [[UISlider alloc] initWithFrame:CGRectZero];
    self.audioVolumeSlider = slider;
    [self.audioVolumeSlider addTarget:self action:@selector(volumeViewSliderValueChanged:) forControlEvents:UIControlEventValueChanged];
}

#pragma mark - Responding to Volume level change

- (void)volumeViewSliderValueChanged:(UISlider *)slider{
    if (self.isAudioSessionActive) {
        [self.delegate didUpdateAudioLevel:@(100.0 * slider.value)];
    }else{
        [self.delegate didUpdateAudioLevel:nil];
    }
}

-(NSNumber *) getAudioVolumePercentage {   
    if (!self.isAudioSessionActive) {
        return nil;
    }
    return @(100.0 * self.audioVolumeSlider.value);
}

#pragma mark - Dealloc

- (void)dealloc {
    self.audioVolumeSlider = nil;
}

@end
