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

#import "EPLMRAIDExpandViewController.h"
#import "EPLMRAIDExpandProperties.h"
#import "EPLMRAIDOrientationProperties.h"
#import "EPLGlobal.h"
#import "EPLLogging.h"

#import "UIView+EPLCategory.h"

@interface EPLMRAIDExpandViewController ()

@property (nonatomic, readwrite, assign) BOOL originalStatusBarHiddenState;

@property (nonatomic, readwrite, strong) UIView *contentView;
@property (nonatomic, readwrite, strong) EPLMRAIDExpandProperties *expandProperties;

@property (nonatomic, readwrite, weak) UIButton *closeButton;

@end

@implementation EPLMRAIDExpandViewController

- (instancetype)initWithContentView:(UIView *)contentView
                   expandProperties:(EPLMRAIDExpandProperties *)expandProperties {
    if (self = [super init]) {
        _contentView = contentView;
        _expandProperties = expandProperties;
        _orientationProperties = [[EPLMRAIDOrientationProperties alloc] initWithAllowOrientationChange:YES
                                                                                     forceOrientation:EPLMRAIDOrientationNone];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    [self createCloseButton];
    [self attachContentView];
}

- (void)createCloseButton {
    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    closeButton.translatesAutoresizingMaskIntoConstraints = NO;
    [closeButton addTarget:self
                    action:@selector(closeButtonWasTapped)
          forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:closeButton];
    [closeButton an_constrainWithSize:CGSizeMake(kANMRAIDExpandViewControllerCloseRegionWidth, kANMRAIDExpandViewControllerCloseRegionHeight)];
    [closeButton an_alignToSuperviewApplyingSafeAreaLayoutGuideWithXAttribute:NSLayoutAttributeRight yAttribute:NSLayoutAttributeTop offsetX:0 offsetY:0];
    if (!self.expandProperties.useCustomClose) {
        BOOL atLeastiOS7 = [self respondsToSelector:@selector(modalPresentationCapturesStatusBarAppearance)];
        NSString *closeboxImageName = @"interstitial_flat_closebox";
        if (!atLeastiOS7) {
            closeboxImageName = @"interstitial_closebox";
        }
        UIImage *closeboxImage = [UIImage imageWithContentsOfFile:EPLPathForANResource(closeboxImageName, @"png")];
        [closeButton setImage:closeboxImage
                     forState:UIControlStateNormal];
    }
    self.closeButton = closeButton;
}

- (void)closeButtonWasTapped {
    [self.delegate closeButtonWasTappedOnExpandViewController:self];
}

- (void)attachContentView {
    self.contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView removeConstraints:self.contentView.constraints];
    [self.contentView an_removeSizeConstraintToSuperview];
    [self.contentView an_removeAlignmentConstraintsToSuperview];
    
    [self.view insertSubview:self.contentView
                belowSubview:self.closeButton];
    if (self.expandProperties.width == -1 && self.expandProperties.height == -1) {
        [self.contentView an_constrainToSizeOfSuperview];
    } else {
        CGRect orientedScreenBounds = EPLAdjustAbsoluteRectInWindowCoordinatesForOrientationGivenRect(EPLPortraitScreenBounds());
        CGFloat expandedWidth = self.expandProperties.width;
        CGFloat expandedHeight = self.expandProperties.height;
        
        if (expandedWidth == -1) {
            expandedWidth = orientedScreenBounds.size.width;
        }
        if (expandedHeight == -1) {
            expandedHeight = orientedScreenBounds.size.height;
        }
        [self.contentView an_constrainWithSize:CGSizeMake(expandedWidth, expandedHeight)];
    }
    [self.contentView an_alignToSuperviewApplyingSafeAreaLayoutGuideWithXAttribute:NSLayoutAttributeLeft yAttribute:NSLayoutAttributeTop offsetX:0 offsetY:0];
}

- (UIView *)detachContentView {
    UIView *contentView = self.contentView;
    [contentView removeConstraints:contentView.constraints];
    [contentView an_removeSizeConstraintToSuperview];
    [contentView an_removeAlignmentConstraintsToSuperview];
    [contentView removeFromSuperview];
    self.contentView = nil;
    return contentView;
}

- (void)setOrientationProperties:(EPLMRAIDOrientationProperties *)orientationProperties {
    _orientationProperties = orientationProperties;
    if ([self.view an_isViewable]) {
        if (orientationProperties.allowOrientationChange && orientationProperties.forceOrientation == EPLMRAIDOrientationNone) {
            [UIViewController attemptRotationToDeviceOrientation];
        } else {
            [self.delegate dismissAndPresentAgainForPreferredInterfaceOrientationChange];
        }
    }
}

#if __IPHONE_9_0
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
#else
- (NSUInteger)supportedInterfaceOrientations {
#endif
    if (self.orientationProperties.allowOrientationChange) {
        return UIInterfaceOrientationMaskAll;
    } else {
        switch (self.orientationProperties.forceOrientation) {
            case EPLMRAIDOrientationPortrait:
                return UIInterfaceOrientationMaskPortrait;
            case EPLMRAIDOrientationLandscape:
                return UIInterfaceOrientationMaskLandscape;
            default:
                return UIInterfaceOrientationMaskAll;
        }
    }
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    switch (self.orientationProperties.forceOrientation) {
        case EPLMRAIDOrientationPortrait:
            if (EPLStatusBarOrientation() == UIInterfaceOrientationPortraitUpsideDown) {
                return UIInterfaceOrientationPortraitUpsideDown;
            }
            return UIInterfaceOrientationPortrait;
        case EPLMRAIDOrientationLandscape:
            if (EPLStatusBarOrientation() == UIInterfaceOrientationLandscapeRight) {
                return UIInterfaceOrientationLandscapeRight;
            }
            return UIInterfaceOrientationLandscapeLeft;
        default: {
            UIInterfaceOrientation currentOrientation = EPLStatusBarOrientation();
            return currentOrientation;
        }
    }   
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (![self respondsToSelector:@selector(setNeedsStatusBarAppearanceUpdate)]) {
        self.originalStatusBarHiddenState = EPLStatusBarHidden();
        
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (self.orientationProperties.allowOrientationChange) {
        _orientationProperties = [[EPLMRAIDOrientationProperties alloc] initWithAllowOrientationChange:YES
                                                                                     forceOrientation:EPLMRAIDOrientationNone];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
   
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}
    
// Allow WKWebView to present WKActionSheet
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (self.presentedViewController) {
        [self.presentedViewController presentViewController:viewControllerToPresent
                                                   animated:flag
                                                 completion:completion];
    } else {
        [super presentViewController:viewControllerToPresent
                            animated:flag
                          completion:completion];
    }
}

@end
