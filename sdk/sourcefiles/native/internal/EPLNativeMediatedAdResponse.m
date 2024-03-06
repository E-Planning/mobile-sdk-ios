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

#import "EPLNativeMediatedAdResponse+PrivateMethods.h"
#import "EPLNativeCustomAdapter.h"
#import "EPLLogging.h"
#import "EPLGlobal.h"
#import "UIView+EPLNativeAdCategory.h"
#import "EPLNativeAdResponse+PrivateMethods.h"
#import "EPLTrackerManager.h"
#import "EPLOMIDImplementation.h"

@interface EPLNativeMediatedAdResponse () <EPLNativeCustomAdapterAdDelegate>

@property (nonatomic, readwrite, assign) EPLNativeAdNetworkCode networkCode;
@property (nonatomic, readwrite, strong) NSArray<NSString *> *impTrackers;
@property (nonatomic, readwrite) BOOL impressionsHaveBeenTracked;

@end

@implementation EPLNativeMediatedAdResponse

@synthesize title = _title;
@synthesize body = _body;
@synthesize callToAction = _callToAction;
@synthesize rating = _rating;
@synthesize mainImage = _mainImage;
@synthesize mainImageURL = _mainImageURL;
@synthesize iconImage = _iconImage;
@synthesize iconImageURL = _iconImageURL;
@synthesize customElements = _customElements;
@synthesize expired = _expired;
@synthesize networkCode = _networkCode;
@synthesize adapter = _adapter;

- (BOOL)hasExpired {
    if (_expired == YES) {
        return YES;
    }
    
    
    if (!self.adapter || ([self.adapter respondsToSelector:@selector(hasExpired)] && [self.adapter hasExpired])) {
        
        _expired = YES;
    }
    return _expired;
}

- (nullable instancetype)initWithCustomAdapter:(nullable id<EPLNativeCustomAdapter>)adapter
                          networkCode:(EPLNativeAdNetworkCode)networkCode {
    if (!adapter) {
        return nil;
    }
    if (self = [super init]) {
        _adapter = adapter;
        _networkCode = networkCode;
        _adapter.nativeAdDelegate = self;
        _impressionsHaveBeenTracked = NO;
    }
    return self;
}

#pragma mark - Registration

- (BOOL)registerResponseInstanceWithNativeView:(EPLView *)view
                            rootViewController:(EPLViewController *)controller
                                clickableViews:(NSArray *)clickableViews
                                         error:(NSError *__autoreleasing *)error {
    return [self registerAdapterWithNativeView:view
                            rootViewController:controller
                                clickableViews:clickableViews
                                         error:error];
}

- (BOOL)registerAdapterWithNativeView:(UIView *)view
                   rootViewController:(UIViewController *)controller
                       clickableViews:(NSArray *)clickableViews
                                error:(NSError **)error {
    if ([self.adapter respondsToSelector:@selector(requestDelegate)]) {
        self.adapter.nativeAdDelegate = self;
    } else {
        EPLLogDebug(@"native_adapter_native_ad_delegate_missing");
    }
    if ([self.adapter respondsToSelector:@selector(registerViewForImpressionTrackingAndClickHandling:withRootViewController:clickableViews:)]) {
        [self.adapter registerViewForImpressionTrackingAndClickHandling:view
                                                 withRootViewController:controller
                                                         clickableViews:clickableViews];
        return YES;
    } else if ([self.adapter respondsToSelector:@selector(registerViewForImpressionTracking:)] && [self.adapter respondsToSelector:@selector(handleClickFromRootViewController:)]) {
        [self.adapter registerViewForImpressionTracking:view];
        [self attachGestureRecognizersToNativeView:view
                                withClickableViews:clickableViews];
        return YES;
    } else {
        EPLLogError(@"native_adapter_error");
        if (error) {
            *error = EPLError(@"native_adapter_error", EPLNativeAdRegisterErrorCodeBadAdapter);
        }
        return NO;
    }
}

#pragma mark - Unregistration

- (void)unregisterViewFromTracking {
    [super unregisterViewFromTracking];
    if ([self.adapter respondsToSelector:@selector(unregisterViewFromTracking)]) {
        [self.adapter unregisterViewFromTracking];
    }
}

#pragma mark - Click handling

- (void)handleClick {
    if ([self.adapter respondsToSelector:@selector(handleClickFromRootViewController:)]) {
        [self.adapter handleClickFromRootViewController:self.rootViewController];
    }
}

#pragma mark - Impression Tracking
- (void)fireImpTrackers {
    if (self.impTrackers && !self.impressionsHaveBeenTracked) {
        [EPLTrackerManager fireTrackerURLArray:self.impTrackers withBlock:^(BOOL isTrackerFired) {
            if (isTrackerFired) {
                [super adDidLogImpression];
            }
        }];
    }
    if(self.omidAdSession != nil){
        [[EPLOMIDImplementation sharedInstance] fireOMIDImpressionOccuredEvent:self.omidAdSession];
    }
    self.impressionsHaveBeenTracked = YES;
}

# pragma mark - EPLNativeCustomAdapterAdDelegate
// Only need to handling adWillLogImpression rest all is handle in the base class EPLNativeAdResponse.m
- (void)adDidLogImpression {
    [self fireImpTrackers];
}

- (void)registerAdWillExpire{
    [self registerAdAboutToExpire];
}

@end
