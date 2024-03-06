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

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

#import "EPLAdView.h"
#import "EPLAdProtocol.h"




//---------------------------------------------------------- -o--
typedef NS_ENUM(NSInteger, EPLInstreamVideoPlaybackStateType)
{
    EPLInstreamVideoPlaybackStateError           = -1,
    EPLInstreamVideoPlaybackStateCompleted       = 0,
    EPLInstreamVideoPlaybackStateSkipped         = 1
};


//---------------------------------------------------------- -o--
@class  EPLInstreamVideoAd;


@protocol  EPLInstreamVideoAdLoadDelegate <NSObject>

    @required
    - (void)adDidReceiveAd:(nonnull id)ad;

    @optional
    - (void)ad:(nonnull id)ad requestFailedWithError:(nonnull NSError *)error;

@end


@protocol  EPLInstreamVideoAdPlayDelegate <NSObject>

    @required

    - (void) adDidComplete:  (nonnull id<EPLAdProtocol>)ad
                 withState:  (EPLInstreamVideoPlaybackStateType)state;

    @optional
    - (void) adCompletedFirstQuartile:  (nonnull id<EPLAdProtocol>)ad;
    - (void) adCompletedMidQuartile:    (nonnull id<EPLAdProtocol>)ad;
    - (void) adCompletedThirdQuartile:  (nonnull id<EPLAdProtocol>)ad;


    - (void) adMute: (nonnull id<EPLAdProtocol>)ad
         withStatus: (BOOL)muteStatus;

    - (void)adWasClicked:(nonnull id<EPLAdProtocol>)ad;
    - (void)adWasClicked:(nonnull id<EPLAdProtocol>)ad withURL:(nonnull NSString *)urlString;

    - (void)adWillClose:(nonnull id<EPLAdProtocol>)ad;
    - (void)adDidClose:(nonnull id<EPLAdProtocol>)ad;

    - (void)adWillPresent:(nonnull id<EPLAdProtocol>)ad;
    - (void)adDidPresent:(nonnull id<EPLAdProtocol>)ad;

    - (void)adWillLeaveApplication:(nonnull id<EPLAdProtocol>)ad;

    - (void) adPlayStarted:(nonnull id<EPLAdProtocol>)ad;

@end




//---------------------------------------------------------- -o--
@interface EPLInstreamVideoAd : EPLAdView <EPLVideoAdProtocol>

    // Public properties.
    //
    @property  (weak, nonatomic, readwrite, nullable)  id<EPLInstreamVideoAdLoadDelegate>  loadDelegate;
    @property  (weak, nonatomic, readonly, nullable)  id<EPLInstreamVideoAdPlayDelegate>  playDelegate;

    //
    @property (strong, nonatomic, readonly, nullable)  NSString  *descriptionOfFailure;
    @property (strong, nonatomic, readonly, nullable)  NSError   *failureNSError;

    @property (nonatomic, readonly)  BOOL  didUserSkipAd;
    @property (nonatomic, readonly)  BOOL  didUserClickAd;
    @property (nonatomic, readonly)  BOOL  isAdMuted;
    @property (nonatomic, readonly)  BOOL  isVideoTagReady;
    @property (nonatomic, readonly)  BOOL  didVideoTagFail;


    // Lifecycle methods.
    //
    - (nonnull instancetype) initWithPlacementId: (nonnull NSString *)placementId;
    - (nonnull instancetype) initWithMemberId:(NSInteger)memberId inventoryCode:(nonnull NSString *)inventoryCode;

    - (BOOL) loadAdWithDelegate: (nullable id<EPLInstreamVideoAdLoadDelegate>)loadDelegate;

    - (void) playAdWithContainer: (nonnull UIView *)adContainer
                    withDelegate: (nullable id<EPLInstreamVideoAdPlayDelegate>)playDelegate;
    
    - (void) pauseAd;
    
    - (void) resumeAd;

    - (void) removeAd;

    - (NSUInteger) getAdDuration;
    - (nullable NSString *) getCreativeURL;
    - (nullable NSString *) getVastURL;
    - (nullable NSString *) getVastXML;

    - (NSUInteger) getAdPlayElapsedTime;

@end


