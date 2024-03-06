/*   Copyright 2013 APPNEXUS INC
 
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

#import "EPLInterstitialAdViewController.h"
#import "EPLGlobal.h"
#import "EPLLogging.h"
#import "UIView+EPLCategory.h"
#import "EPLMRAIDOrientationProperties.h"
#import "NSTimer+EPLCategory.h"
#import "EPLMRAIDContainerView.h"

@interface EPLInterstitialAdViewController ()
@property (nonatomic, readwrite, strong) NSTimer *progressTimer;
@property (nonatomic, readwrite, strong) NSDate *timerStartDate;
@property (nonatomic, readwrite, assign) BOOL viewed;
@property (nonatomic, readwrite, assign) BOOL originalHiddenState;
@property (nonatomic, readwrite, assign) UIInterfaceOrientation orientation;
@property (nonatomic, readwrite, assign, getter=isDismissing) BOOL dismissing;
@property (nonatomic, readwrite, assign) BOOL responsiveAd;
@end

@implementation EPLInterstitialAdViewController

- (instancetype)init {
    if (!EPLPathForANResource(NSStringFromClass([self class]), @"nib")) {
        EPLLogError(@"Could not instantiate interstitial controller because of missing NIB file");
        return nil;
    }
    self = [super initWithNibName:NSStringFromClass([self class]) bundle:EPLResourcesBundle()];
    self.originalHiddenState = NO;
    self.orientation = EPLStatusBarOrientation();
    self.needCloseButton = YES;
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    if (!self.backgroundColor) {
        self.backgroundColor = [UIColor whiteColor]; // Default white color, clear color background doesn't work with interstitial modal view
    }
    self.progressView.hidden = YES;
    self.closeButton.hidden = YES;
    if (self.contentView && !self.contentView.superview) {
        [self.view addSubview:self.contentView];
        [self.view insertSubview:self.contentView
                    belowSubview:self.progressView];
        [self.contentView an_alignToSuperviewWithXAttribute:NSLayoutAttributeCenterX
                                                 yAttribute:NSLayoutAttributeCenterY];
    }
    if(self.needCloseButton){
        [self setupCloseButtonImageWithCustomClose:self.useCustomClose];
    }
}

- (void)setupCloseButtonImageWithCustomClose:(BOOL)useCustomClose {
    if (useCustomClose) {
        [self.closeButton setImage:nil
                          forState:UIControlStateNormal];
        return;
    }
    BOOL atLeastiOS7 = [self respondsToSelector:@selector(modalPresentationCapturesStatusBarAppearance)];
    NSString *closeboxImageName = @"interstitial_flat_closebox";
    if (!atLeastiOS7) {
        closeboxImageName = @"interstitial_closebox";
    }
    UIImage *closeboxImage = [UIImage imageWithContentsOfFile:EPLPathForANResource(closeboxImageName, @"png")];
    [self.closeButton setImage:closeboxImage
                      forState:UIControlStateNormal];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.originalHiddenState = EPLStatusBarHidden();
    
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if(self.needCloseButton){
            if (!self.viewed && (([self.delegate closeDelayForController] > 0.0) || (self.autoDismissAdDelay>-1)) ) {
                [self startCountdownTimer];
                self.viewed = YES;
            } else {
                self.closeButton.hidden = NO;
                [self stopCountdownTimer];
            }
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if(self.needCloseButton){
        [self.progressTimer invalidate];
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    self.dismissing = NO;
}

- (void)startCountdownTimer {
    self.progressView.hidden = NO;
    self.closeButton.hidden = YES;
    self.timerStartDate = [NSDate date];
    self.progressTimer = [NSTimer scheduledTimerWithTimeInterval:0.01 target:self selector:@selector(progressTimerDidFire:) userInfo:nil repeats:YES];
}

- (void)stopCountdownTimer {
     self.progressView.hidden = YES;
    [self.progressTimer invalidate];
    
}



- (void)progressTimerDidFire:(NSTimer *)timer {
    
    
    NSDate *timeNow = [NSDate date];
    NSTimeInterval timeShown = [timeNow timeIntervalSinceDate:self.timerStartDate];
    NSTimeInterval closeButtonDelay = [self.delegate closeDelayForController];
    if(self.autoDismissAdDelay > -1){
       [self.progressView setProgress:(timeShown / self.autoDismissAdDelay)];
        if (timeShown >= self.autoDismissAdDelay) {
            [self dismissAd];
            [self stopCountdownTimer];
        }
        if (timeShown >= closeButtonDelay && self.closeButton.hidden == YES) {
            self.closeButton.hidden = NO;
        }
    }else{
        [self.progressView setProgress:(timeShown / closeButtonDelay)];
        if (timeShown >= closeButtonDelay && self.closeButton.hidden == YES) {
            self.closeButton.hidden = NO;
            [self stopCountdownTimer];
        }
    }
    
    
}
- (void)setContentView:(UIView *)contentView {
    if (contentView != _contentView) {
        if ([_contentView isKindOfClass:[WKWebView class]]) {
            WKWebView *webView = (WKWebView *)_contentView;
            [webView stopLoading];
            [webView setNavigationDelegate:nil];
            [webView setUIDelegate:nil];
        }
        
        [_contentView removeFromSuperview];
        _contentView = contentView;
        
        [self.view insertSubview:_contentView
                    belowSubview:self.progressView];
        _contentView.translatesAutoresizingMaskIntoConstraints = NO;
        
        if(self.needCloseButton == NO){
            self.responsiveAd = YES;
        }
        
        if ([_contentView isKindOfClass:[EPLMRAIDContainerView class]]) {
            if (((EPLMRAIDContainerView *) _contentView).isResponsiveAd) {
                self.responsiveAd = YES;
            }
        }
        
        if (self.responsiveAd) {
            [_contentView an_constrainToSizeOfSuperviewApplyingSafeAreaLayoutGuide];
            [_contentView an_alignToSuperviewApplyingSafeAreaLayoutGuideWithXAttribute:NSLayoutAttributeLeft yAttribute:NSLayoutAttributeTop offsetX:0 offsetY:0];
        } else {
            [_contentView an_constrainWithFrameSize];
            [_contentView an_alignToSuperviewApplyingSafeAreaLayoutGuideWithXAttribute:NSLayoutAttributeCenterX yAttribute:NSLayoutAttributeCenterY offsetX:0 offsetY:0];
        }
    }
}

- (void)setBackgroundColor:(UIColor *)backgroundColor {
    _backgroundColor = backgroundColor;
    self.view.backgroundColor = _backgroundColor;
}

- (void)dismissAd {
    self.dismissing = YES;
    [self.delegate interstitialAdViewControllerShouldDismiss:self];
}

- (IBAction)closeAction:(id)sender {
    [self dismissAd];
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

-(UIStatusBarAnimation) preferredStatusBarUpdateAnimation {
    return UIStatusBarAnimationNone;
}

- (BOOL)shouldAutorotate {
    return self.responsiveAd;
}

#if __IPHONE_9_0
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
#else
    - (NSUInteger)supportedInterfaceOrientations {
#endif
        if (self.orientationProperties) {
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
        
        if (self.responsiveAd) {
            return UIInterfaceOrientationMaskAll;
        }
        
        switch (self.orientation) {
            case UIInterfaceOrientationLandscapeLeft:
                return UIInterfaceOrientationMaskLandscapeLeft;
            case UIInterfaceOrientationLandscapeRight:
                return UIInterfaceOrientationMaskLandscapeRight;
            case UIInterfaceOrientationPortraitUpsideDown:
                return UIInterfaceOrientationMaskPortraitUpsideDown;
            default:
                return UIInterfaceOrientationMaskPortrait;
        }
    }
    
    - (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
        if (self.orientationProperties) {
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
                default:
                    break;
            }
        }
        return self.orientation;
    }
    
    - (void)viewWillLayoutSubviews {
        CGFloat buttonDistanceToSuperview;
        if ([self respondsToSelector:@selector(modalPresentationCapturesStatusBarAppearance)]) {
            CGSize statusBarFrameSize = EPLStatusBarFrame().size;
            buttonDistanceToSuperview = statusBarFrameSize.height;
            if (statusBarFrameSize.height > statusBarFrameSize.width) {
                buttonDistanceToSuperview = statusBarFrameSize.width;
            }
        } else {
            buttonDistanceToSuperview = 0;
        }
        
        self.buttonTopToSuperviewConstraint.constant = buttonDistanceToSuperview;
        
        if (!self.isDismissing) {
            CGRect normalizedContentViewFrame = CGRectMake(0, 0, CGRectGetWidth(self.contentView.frame), CGRectGetHeight(self.contentView.frame));
            if (!CGRectContainsRect(self.view.frame, normalizedContentViewFrame)) {
                CGRect rotatedNormalizedContentViewFrame = CGRectMake(0, 0, CGRectGetHeight(self.contentView.frame), CGRectGetWidth(self.contentView.frame));
                if (CGRectContainsRect(self.view.frame, rotatedNormalizedContentViewFrame)) {
                    [self.contentView an_constrainWithSize:CGSizeMake(CGRectGetHeight(self.contentView.frame), CGRectGetWidth(self.contentView.frame))];
                }
            }
        }
    }
    
    - (void)setUseCustomClose:(BOOL)useCustomClose {
        if (_useCustomClose != useCustomClose) {
            _useCustomClose = useCustomClose;
            [self setupCloseButtonImageWithCustomClose:useCustomClose];
        }
    }
    
    - (void)setOrientationProperties:(EPLMRAIDOrientationProperties *)orientationProperties {
        _orientationProperties = orientationProperties;
        if ([self.view an_isViewable]) {
            if (orientationProperties.allowOrientationChange && orientationProperties.forceOrientation == EPLMRAIDOrientationNone) {
                [UIViewController attemptRotationToDeviceOrientation];
            } else if (EPLStatusBarOrientation() != [self preferredInterfaceOrientationForPresentation]) {
                [self.delegate dismissAndPresentAgainForPreferredInterfaceOrientationChange];
            }
        }
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
