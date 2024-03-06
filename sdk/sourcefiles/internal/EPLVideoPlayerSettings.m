/*   Copyright 2019 APPNEXUS INC
 
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

#import "EPLVideoPlayerSettings.h"
#import "EPLGlobal.h"
#import "EPLOMIDImplementation.h"
#import "EPLVideoPlayerSettings+EPLCategory.h"
#import "EPLSDKSettings.h"

NSString * const  EPLName = @"name";
NSString * const  EPLVersion = @"version";
NSString * const  EPLPartner = @"partner";
NSString * const  EPLEntry = @"entryPoint";

NSString * const  EPLInstreamVideo = @"INSTREAM_VIDEO";
NSString * const  EPLBanner = @"BANNER";

NSString * const  EPLAdText = @"adText";
NSString * const  EPLSeparator = @"separator";
NSString * const  EPLEnabled = @"enabled";
NSString * const  EPLText = @"text";
NSString * const  EPLLearnMore = @"learnMore";
NSString * const  EPLMute = @"showMute";
NSString * const  EPLAllowFullScreen = @"allowFullscreen";
NSString * const  EPLShowFullScreen = @"showFullScreenButton";
NSString * const  EPLDisableTopBar = @"disableTopBar";
NSString * const  EPLVideoOptions = @"videoOptions";
NSString * const  EPLInitialAudio = @"initialAudio";
NSString * const  EPLOn = @"on";
NSString * const  EPLOff = @"off";
NSString * const  EPLSkip = @"skippable";
NSString * const  EPLSkipDescription = @"skipText";
NSString * const  EPLSkipLabelName = @"skipButtonText";
NSString * const  EPLSkipOffset = @"videoOffset";

@interface EPLVideoPlayerSettings()

@property (nonatomic,strong) NSMutableDictionary *optionsDictionary;

@end

@implementation EPLVideoPlayerSettings

+ (nonnull instancetype)sharedInstance {
    static dispatch_once_t sdkSettingsToken;
    static EPLVideoPlayerSettings *videoSettings;
    dispatch_once(&sdkSettingsToken, ^{
        videoSettings = [[EPLVideoPlayerSettings alloc] init];
        videoSettings.showClickThruControl = YES;
        videoSettings.showFullScreenControl = YES;
        videoSettings.initalAudio = Default;
        videoSettings.optionsDictionary = [[NSMutableDictionary alloc] init];
        NSDictionary *partner = @{ EPLName : EPL_OMIDSDK_PARTNER_NAME , EPLVersion : EPL_SDK_VERSION};
        [videoSettings.optionsDictionary setObject:partner forKey:EPLPartner];
        [videoSettings.optionsDictionary setObject:EPLInstreamVideo forKey:EPLEntry];
        videoSettings.showAdText = YES;
        videoSettings.showVolumeControl = YES;
        videoSettings.showTopBar = YES;
        videoSettings.showSkip = YES;
        videoSettings.skipOffset = 5;
        
    });
    return videoSettings;
}

-(NSString *) videoPlayerOptions {
    
    NSMutableDictionary *publisherOptions = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *clickthruOptions = [[NSMutableDictionary alloc] init];
    if(self.showAdText && self.adText != nil){
        publisherOptions[EPLAdText] = self.adText;
    }else if(!self.showAdText){
        publisherOptions[EPLAdText] = @"";
        clickthruOptions[EPLSeparator] = @"";
    }
    clickthruOptions[EPLEnabled] =  [NSNumber numberWithBool:self.showClickThruControl];
    
    if(self.clickThruText != nil && self.showClickThruControl){
        clickthruOptions[EPLText] =  self.clickThruText;
    }
    
    
    if(clickthruOptions.count > 0){
        publisherOptions[EPLLearnMore] = clickthruOptions;
    }

    if([self.optionsDictionary[EPLEntry] isEqualToString:EPLInstreamVideo]){
         NSMutableDictionary *skipOptions = [[NSMutableDictionary alloc] init];
        if(self.showSkip){
            skipOptions[EPLSkipDescription] = self.skipDescription;
            skipOptions[EPLSkipLabelName] = self.skipLabelName;
            skipOptions[EPLSkipOffset] = [NSNumber numberWithInteger:self.skipOffset];
        }
        skipOptions[EPLEnabled] = [NSNumber numberWithBool:self.showSkip];
        publisherOptions[EPLSkip] = skipOptions;
    }
    
    if(!self.showVolumeControl){
        publisherOptions[EPLMute] = [NSNumber numberWithBool:self.showVolumeControl];
    }
    
    if([self.optionsDictionary[EPLEntry] isEqualToString:EPLBanner]){
        publisherOptions[EPLAllowFullScreen] = [NSNumber numberWithBool:self.showFullScreenControl];
        publisherOptions[EPLShowFullScreen] = [NSNumber numberWithBool:self.showFullScreenControl];
    }
    
    if(self.initalAudio != Default){
        if(self.initalAudio == SoundOn){
            publisherOptions[EPLInitialAudio] = EPLOn;
        }else {
            publisherOptions[EPLInitialAudio] = EPLOff;
        }
    }else {
        if(publisherOptions[EPLInitialAudio]){
            publisherOptions[EPLInitialAudio] = nil;
        }
    }
    
    if(!self.showTopBar){
        publisherOptions[EPLDisableTopBar] = [NSNumber numberWithBool:YES];
    }
    
    if(publisherOptions.count > 0){
        [self.optionsDictionary setObject:publisherOptions forKey:EPLVideoOptions];
    }
    NSError * err;
    NSData * jsonData = [NSJSONSerialization dataWithJSONObject:self.optionsDictionary options:0 error:&err];
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    
}


-(NSString *) fetchInStreamVideoSettings{
    [self.optionsDictionary setValue:EPLInstreamVideo forKey:EPLEntry];
    return [self videoPlayerOptions];
}

-(NSString *) fetchBannerSettings{
    [self.optionsDictionary setValue:EPLBanner forKey:EPLEntry];
    
    return [self videoPlayerOptions];
}

@end
