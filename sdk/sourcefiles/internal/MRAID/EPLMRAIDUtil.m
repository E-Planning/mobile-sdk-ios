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

#import "EPLMRAIDUtil.h"
#import <MessageUI/MFMessageComposeViewController.h>
#import "EPLGlobal.h"
#import "EPLLogging.h"

@protocol EPLStorePictureCallbackProtocol

- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo;

@end

@implementation EPLMRAIDUtil

+ (EPLMRAIDCustomClosePosition)customClosePositionFromCustomClosePositionString:(NSString *)customClosePositionString {
    if ([customClosePositionString isEqualToString:@"top-left"]) {
        return EPLMRAIDCustomClosePositionTopLeft;
    } else if ([customClosePositionString isEqualToString:@"top-center"]) {
        return EPLMRAIDCustomClosePositionTopCenter;
    } else if ([customClosePositionString isEqualToString:@"top-right"]) {
        return EPLMRAIDCustomClosePositionTopRight;
    } else if ([customClosePositionString isEqualToString:@"center"]) {
        return EPLMRAIDCustomClosePositionCenter;
    } else if ([customClosePositionString isEqualToString:@"bottom-left"]) {
        return EPLMRAIDCustomClosePositionBottomLeft;
    } else if ([customClosePositionString isEqualToString:@"bottom-center"]) {
        return EPLMRAIDCustomClosePositionBottomCenter;
    } else if ([customClosePositionString isEqualToString:@"bottom-right"]) {
        return EPLMRAIDCustomClosePositionBottomRight;
    }
    return EPLMRAIDCustomClosePositionUnknown;
}

+ (BOOL)supportsSMS {
    return [MFMessageComposeViewController canSendText];
}

+ (BOOL)supportsTel {
    return [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"tel://"]];
}

+ (BOOL)supportsCalendar {
    return NO;
}

+ (BOOL)supportsInlineVideo {
    return YES;
}

+ (BOOL)supportsStorePicture {
    return NO;
}

+ (EPLMRAIDAction)actionForCommand:(NSString *)command {
    if ([command isEqualToString:@"expand"]) {
        return EPLMRAIDActionExpand;
    } else if ([command isEqualToString:@"close"]) {
        return EPLMRAIDActionClose;
    } else if ([command isEqualToString:@"resize"]) {
        return EPLMRAIDActionResize;
    } else if ([command isEqualToString:@"createCalendarEvent"]) {
        return EPLMRAIDActionCreateCalendarEvent;
    } else if ([command isEqualToString:@"playVideo"]) {
        return EPLMRAIDActionPlayVideo;
    } else if ([command isEqualToString:@"storePicture"]) {
        return EPLMRAIDActionStorePicture;
    } else if ([command isEqualToString:@"setOrientationProperties"]) {
        return EPLMRAIDActionSetOrientationProperties;
    } else if ([command isEqualToString:@"setUseCustomClose"]) {
        return EPLMRAIDActionSetUseCustomClose;
    } else if ([command isEqualToString:@"open"]) {
        return EPLMRAIDActionOpenURI;
    }else if ([command isEqualToString:@"audioVolumeChange"]) {
        return EPLMRAIDActionAudioVolumeChange;
    } else if ([command isEqualToString:@"enable"]) {
        return EPLMRAIDActionEnable;
    }
    return EPLMRAIDActionUnknown;
}

+ (void)storePictureWithUri:(NSString *)uri
       withCompletionTarget:(id)target
         completionSelector:(SEL)selector {
    id<EPLStorePictureCallbackProtocol> completionTarget = (id<EPLStorePictureCallbackProtocol>)target;
    [completionTarget image:nil
   didFinishSavingWithError:[NSError errorWithDomain:NSCocoaErrorDomain
                                                code:0
                                            userInfo:@{NSLocalizedDescriptionKey:@"storePicture not supported"}]
                contextInfo:NULL];

}

+ (void)playVideoWithUri:(NSString *)uri
  fromRootViewController:(UIViewController *)rootViewController
    withCompletionTarget:(id)target
      completionSelector:(SEL)selector {
    NSURL *url = [NSURL URLWithString:uri];
    
    AVPlayerViewController *moviePlayerViewController = [[AVPlayerViewController alloc] init];
    moviePlayerViewController.player = [AVPlayer playerWithURL:url];
    moviePlayerViewController.modalPresentationStyle = UIModalPresentationOverFullScreen;
    moviePlayerViewController.view.frame = rootViewController.view.frame;
    [rootViewController presentViewController:moviePlayerViewController animated:YES completion:nil];
    [moviePlayerViewController.player play];
    
    [[NSNotificationCenter defaultCenter] addObserver:target
                                             selector:selector
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:moviePlayerViewController.player];
}

+ (EPLMRAIDOrientation)orientationFromForceOrientationString:(NSString *)orientationString {
    if ([orientationString isEqualToString:@"portrait"]) {
        return EPLMRAIDOrientationPortrait;
    } else if ([orientationString isEqualToString:@"landscape"]) {
        return EPLMRAIDOrientationLandscape;
    }
    return EPLMRAIDOrientationNone;
}

+ (CGSize)screenSize {
    BOOL orientationIsPortrait = UIInterfaceOrientationIsPortrait(EPLStatusBarOrientation());
    CGSize screenSize = EPLPortraitScreenBounds().size;
    int orientedWidth = orientationIsPortrait ? screenSize.width : screenSize.height;
    int orientedHeight = orientationIsPortrait ? screenSize.height : screenSize.width;
    return CGSizeMake(orientedWidth, orientedHeight);
}

+ (CGSize)maxSizeSafeArea {
    BOOL orientationIsPortrait = UIInterfaceOrientationIsPortrait(EPLStatusBarOrientation());
    CGSize screenSize = EPLPortraitScreenBoundsApplyingSafeAreaInsets().size;
    int orientedWidth = orientationIsPortrait ? screenSize.width : screenSize.height;
    int orientedHeight = orientationIsPortrait ? screenSize.height : screenSize.width;
    return CGSizeMake(orientedWidth, orientedHeight);
}

+ (EPLMRAIDState)stateFromString:(NSString *)stateString {
    if ([stateString isEqualToString:@"loading"]) {
        return EPLMRAIDStateLoading;
    } else if ([stateString isEqualToString:@"default"]) {
        return EPLMRAIDStateDefault;
    } else if ([stateString isEqualToString:@"expanded"]) {
        return EPLMRAIDStateExpanded;
    } else if ([stateString isEqualToString:@"hidden"]) {
        return EPLMRAIDStateHidden;
    } else if ([stateString isEqualToString:@"resized"]) {
        return EPLMRAIDStateResized;
    }
    return EPLMRAIDStateUnknown;
}

+ (NSString *)stateStringFromState:(EPLMRAIDState)state {
    switch (state) {
        case EPLMRAIDStateLoading:
            return @"loading";
        case EPLMRAIDStateDefault:
            return @"default";
        case EPLMRAIDStateExpanded:
            return @"expanded";
        case EPLMRAIDStateHidden:
            return @"hidden";
        case EPLMRAIDStateResized:
            return @"resized";
        default:
            return nil;
    }
}

@end
