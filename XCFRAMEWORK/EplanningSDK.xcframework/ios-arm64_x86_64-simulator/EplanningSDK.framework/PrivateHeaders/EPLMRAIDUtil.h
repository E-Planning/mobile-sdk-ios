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

#import <UIKit/UIKit.h>
#import <AVKit/AVKit.h>

typedef NS_ENUM(NSUInteger, EPLMRAIDOrientation) {
    EPLMRAIDOrientationPortrait,
    EPLMRAIDOrientationLandscape,
    EPLMRAIDOrientationNone
};

typedef NS_ENUM(NSUInteger, EPLMRAIDCustomClosePosition) {
    EPLMRAIDCustomClosePositionUnknown,
    EPLMRAIDCustomClosePositionTopLeft,
    EPLMRAIDCustomClosePositionTopCenter,
    EPLMRAIDCustomClosePositionTopRight,
    EPLMRAIDCustomClosePositionCenter,
    EPLMRAIDCustomClosePositionBottomLeft,
    EPLMRAIDCustomClosePositionBottomCenter,
    EPLMRAIDCustomClosePositionBottomRight
};

typedef NS_ENUM(NSUInteger, EPLMRAIDState) {
    EPLMRAIDStateUnknown,
    EPLMRAIDStateLoading,
    EPLMRAIDStateDefault,
    EPLMRAIDStateExpanded,
    EPLMRAIDStateHidden,
    EPLMRAIDStateResized
};

typedef NS_ENUM(NSUInteger, EPLMRAIDAction) {
    EPLMRAIDActionUnknown,
    EPLMRAIDActionExpand,
    EPLMRAIDActionClose,
    EPLMRAIDActionResize,
    EPLMRAIDActionCreateCalendarEvent,
    EPLMRAIDActionPlayVideo,
    EPLMRAIDActionStorePicture,
    EPLMRAIDActionSetOrientationProperties,
    EPLMRAIDActionSetUseCustomClose,
    EPLMRAIDActionOpenURI,
    EPLMRAIDActionAudioVolumeChange,
    EPLMRAIDActionEnable
};

@interface EPLMRAIDUtil : NSObject

+ (BOOL)supportsSMS;
+ (BOOL)supportsTel;
+ (BOOL)supportsCalendar;
+ (BOOL)supportsInlineVideo;
+ (BOOL)supportsStorePicture;

+ (CGSize)screenSize;
+ (CGSize)maxSizeSafeArea;

+ (void)playVideoWithUri:(NSString *)uri
  fromRootViewController:(UIViewController *)rootViewController
    withCompletionTarget:(id)target
      completionSelector:(SEL)selector;
+ (void)storePictureWithUri:(NSString *)uri
       withCompletionTarget:(id)target
         completionSelector:(SEL)selector;

+ (EPLMRAIDAction)actionForCommand:(NSString *)command;
+ (EPLMRAIDCustomClosePosition)customClosePositionFromCustomClosePositionString:(NSString *)customClosePositionString;
+ (EPLMRAIDOrientation)orientationFromForceOrientationString:(NSString *)orientationString;

+ (EPLMRAIDState)stateFromString:(NSString *)string;
+ (NSString *)stateStringFromState:(EPLMRAIDState)state;

@end
