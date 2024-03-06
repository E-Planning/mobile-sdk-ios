/*   Copyright 2016 APPNEXUS INC
 
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

#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

#import "EPLAdConstants.h"
@import OMSDK_Microsoft;

#import "EPLAdResponseInfo.h"



typedef NS_ENUM(NSUInteger, EPLVideoAdPlayerTracker) {
    EPLVideoAdPlayerTrackerFirstQuartile,
    EPLVideoAdPlayerTrackerMidQuartile,
    EPLVideoAdPlayerTrackerThirdQuartile,
    EPLVideoAdPlayerTrackerFourthQuartile

};

typedef NS_ENUM(NSUInteger, EPLVideoAdPlayerEvent) {
    EPLVideoAdPlayerEventPlay,
    EPLVideoAdPlayerEventSkip,
    EPLVideoAdPlayerEventMuteOff,
    EPLVideoAdPlayerEventMuteOn
};



@class  EPLVideoAdPlayer;


@protocol EPLVideoAdPlayerDelegate <NSObject>

-(void) videoAdReady;
-(void) videoAdLoadFailed:(nonnull NSError *)error withAdResponseInfo:(nullable EPLAdResponseInfo *)adResponseInfo;

@optional

- (void) videoAdError:(nonnull NSError *)error;
- (void) videoAdWillPresent: (nonnull EPLVideoAdPlayer *)videoAd;
- (void) videoAdDidPresent:  (nonnull EPLVideoAdPlayer *)videoAd;
- (void) videoAdWillClose:   (nonnull EPLVideoAdPlayer *)videoAd;
- (void) videoAdDidClose:    (nonnull EPLVideoAdPlayer *)videoAd;

- (void) videoAdWillLeaveApplication: (nonnull EPLVideoAdPlayer *)videoAd;

- (void) videoAdImpressionListeners:(EPLVideoAdPlayerTracker) tracker;
- (void) videoAdEventListeners:(EPLVideoAdPlayerEvent) eventTrackers;
- (void) videoAdWasClicked;
- (void) videoAdWasClickedWithURL:(nonnull NSString *)urlString;

- (EPLClickThroughAction) videoAdPlayerClickThroughAction;
- (BOOL) videoAdPlayerLandingPageLoadsInBackground;

- (void) videoAdPlayerFullScreenEntered: (nonnull EPLVideoAdPlayer *)videoAd;
- (void) videoAdPlayerFullScreenExited: (nonnull EPLVideoAdPlayer *)videoAd;


@end




@interface EPLVideoAdPlayer : UIView<WKScriptMessageHandler,WKNavigationDelegate, WKUIDelegate>

@property (strong, nonatomic, nullable) id <EPLVideoAdPlayerDelegate> delegate;
@property (nonatomic, readwrite, strong, nullable) OMIDMicrosoftAdSession * omidAdSession;

-(void) loadAdWithVastContent:(nonnull NSString *) vastContent;
-(void) loadAdWithVastUrl:(nonnull NSString *) vastUrl;
-(void) loadAdWithJSONContent:(nonnull NSString *) jsonContent;

-(void)playAdWithContainer:(nonnull UIView *) containerView;
-(void) pauseAdVideo;
-(void) resumeAdVideo;
-(void) removePlayer;

- (NSUInteger) getAdDuration;
- (nullable NSString *) getCreativeURL;
- (nullable NSString *) getVASTURL;
- (nullable NSString *) getVASTXML;
- (NSUInteger) getAdPlayElapsedTime;
/**
 * Get the Orientation of the Video rendered using the BannerAdView
 *
 * @return Default VideoOrientation value EPLUnknown, which indicates that aspectRatio can't be retrieved for the video.
 */
- (EPLVideoOrientation) getVideoOrientation;

- (NSInteger) getVideoWidth;

- (NSInteger) getVideoHeight;

@end

