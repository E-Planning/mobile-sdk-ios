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
#import <Foundation/Foundation.h>
#import "EPLAdConstants.h"

#import "EPLNativeAdResponse.h"
#if !APPNEXUS_NATIVE_MACOS_SDK
        #if __has_include(<OMSDK_Microsoft/OMIDImports.h>)
            #import <OMSDK_Microsoft/OMIDImports.h>
        #else
            #import <OMIDImports.h>
        #endif
    #import "EPLVerificationScriptResource.h"
#else
    #import <AppKit/AppKit.h>
    #import "EPLNativeAdView.h"
#endif
#import "EPLView.h"
#import "EPLViewController.h"


@interface EPLNativeAdResponse (PrivateMethods)
#if !APPNEXUS_NATIVE_MACOS_SDK

@property (nonatomic, readonly, weak) UIViewController *rootViewController;
@property (nonatomic, readonly, weak) UIView *viewForTracking;
@property (nonatomic, readonly, strong) OMIDMicrosoftAdSession *omidAdSession;
@property (nonatomic, readwrite, strong) EPLVerificationScriptResource *verificationScriptResource;
#else
@property (nonatomic, readonly, weak) NSView *viewForTracking;
#endif

@property (nonatomic, readonly, strong) NSString *nativeRenderingUrl;
@property (nonatomic, readonly, strong) NSString *nativeRenderingObject;


#pragma mark - Registration

- (BOOL)registerResponseInstanceWithNativeView:(EPLView *)view
                            rootViewController:(EPLViewController *)controller
                                clickableViews:(NSArray *)clickableViews
                                         error:(NSError *__autoreleasing*)error;
#if APPNEXUS_NATIVE_MACOS_SDK
-(void)attachClickGestureRecognizerToView:(EPLNativeAdView *)view;
#endif

#pragma mark - Unregistration

- (void)unregisterViewFromTracking;


#pragma mark - Click handling

- (void)attachGestureRecognizersToNativeView:(EPLView *)nativeView
                          withClickableViews:(NSArray *)clickableViews;




- (void)handleClick;

-(void)registerOMID;
#pragma mark - EPLNativeAdDelegate / EPLNativeCustomAdapterAdDelegate

- (void)adWasClicked;
- (void)adWasClickedWithURL:(NSString *)clickURLString fallbackURL:(NSString *)clickFallbackURLString;
- (void)willPresentAd;
- (void)didPresentAd;
- (void)willCloseAd;
- (void)didCloseAd;
- (void)willLeaveApplication;
- (void)adDidLogImpression;
- (void)registerAdWillExpire;

// EPLNativeAdRequest to EPLNativeStandardAdResponse/EPLNativeMediatedAdResponse/EPLCSRNativeAdResponse
- (void)registerAdAboutToExpire;

@end
