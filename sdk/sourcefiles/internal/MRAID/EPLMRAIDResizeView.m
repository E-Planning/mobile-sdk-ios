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

#import "EPLMRAIDResizeView.h"
#import "EPLLogging.h"
#import "UIView+EPLCategory.h"
#import "EPLGlobal.h"

@interface EPLMRAIDResizeView ()

@property (nonatomic, readwrite, weak) UIView *contentView;

@property (nonatomic, readwrite, strong) UIButton *closeRegion;
@property (nonatomic, readwrite, strong) UIButton *supplementaryCloseRegion;
@property (nonatomic, readwrite, strong) UIImage *closeRegionDefaultImage;

@end

@implementation EPLMRAIDResizeView

#pragma mark - EPLResizeView Implementation

- (instancetype)init {
    if (self = [super init]) {
        self.backgroundColor = [UIColor clearColor];
        [self setupCloseRegion];
        [self setupSupplementaryCloseRegion];
    }
    return self;
}

#pragma mark - Close Region

- (void)setClosePosition:(EPLMRAIDCustomClosePosition)closePosition {
    _closePosition = closePosition;
    [self setupCloseRegionConstraintsWithClosePosition:_closePosition];
}

- (void)setupCloseRegion {
    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [closeButton addTarget:self
                    action:@selector(closeRegionSelectedOnResizeView)
          forControlEvents:UIControlEventTouchUpInside];
    _closeRegion = closeButton;
    [self addSubview:_closeRegion];
}

- (void)setupSupplementaryCloseRegion {
    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [closeButton addTarget:self
                    action:@selector(closeRegionSelectedOnResizeView)
          forControlEvents:UIControlEventTouchUpInside];
    [closeButton setImage:self.closeRegionDefaultImage
                 forState:UIControlStateNormal];
    closeButton.hidden = YES;
    closeButton.translatesAutoresizingMaskIntoConstraints = NO;
    [closeButton an_constrainWithSize:CGSizeMake(kANResizeViewCloseRegionWidth, kANResizeViewCloseRegionHeight)];
    _supplementaryCloseRegion = closeButton;
    [self addSubview:_supplementaryCloseRegion];
}

- (void)setupCloseRegionConstraintsWithClosePosition:(EPLMRAIDCustomClosePosition)position {
    [self.closeRegion removeConstraints:self.closeRegion.constraints];
    self.closeRegion.translatesAutoresizingMaskIntoConstraints = NO;
    NSLayoutAttribute xAttribute;
    NSLayoutAttribute yAttribute;
    
    switch (position) {
        case EPLMRAIDCustomClosePositionTopLeft:
            yAttribute = NSLayoutAttributeTop;
            xAttribute = NSLayoutAttributeLeft;
            break;
        case EPLMRAIDCustomClosePositionTopCenter:
            yAttribute = NSLayoutAttributeTop;
            xAttribute = NSLayoutAttributeCenterX;
            break;
        case EPLMRAIDCustomClosePositionTopRight:
            yAttribute = NSLayoutAttributeTop;
            xAttribute = NSLayoutAttributeRight;
            break;
        case EPLMRAIDCustomClosePositionCenter:
            yAttribute = NSLayoutAttributeCenterY;
            xAttribute = NSLayoutAttributeCenterX;
            break;
        case EPLMRAIDCustomClosePositionBottomLeft:
            yAttribute = NSLayoutAttributeBottom;
            xAttribute = NSLayoutAttributeLeft;
            break;
        case EPLMRAIDCustomClosePositionBottomCenter:
            yAttribute = NSLayoutAttributeBottom;
            xAttribute = NSLayoutAttributeCenterX;
            break;
        case EPLMRAIDCustomClosePositionBottomRight:
            yAttribute = NSLayoutAttributeBottom;
            xAttribute = NSLayoutAttributeRight;
            break;
        default:
            EPLLogDebug(@"Invalid custom close position for MRAID resize event");
            yAttribute = NSLayoutAttributeTop;
            xAttribute = NSLayoutAttributeRight;
            break;
    }
    
    [self.closeRegion an_constrainWithSize:CGSizeMake(kANResizeViewCloseRegionWidth, kANResizeViewCloseRegionHeight)];
    [self.closeRegion an_alignToSuperviewWithXAttribute:xAttribute
                                             yAttribute:yAttribute];
}

#pragma mark - Content View

- (void)attachContentView:(UIView *)contentView {
    if (contentView != self.contentView) {
        if (self.contentView) {
            EPLLogError(@"Error: Attempt to attach a second content view to a resize view.");
            return;
        }
        self.contentView = contentView;
        [self.contentView removeFromSuperview];
        [self insertSubview:self.contentView
               belowSubview:self.closeRegion];
        [self setupContentViewConstraints];
    }
}

- (UIView *)detachContentView {
    UIView *contentView = self.contentView;
    self.contentView = nil;
    if (contentView.superview == self) {
        [contentView removeFromSuperview];
        [contentView removeConstraints:contentView.constraints];
        return contentView;
    }
    if (contentView) {
        EPLLogError(@"Error: Attempted to detach a content view from a resize view which has already been added to another hierarchy");
    }
    return nil;
}

- (void)setupContentViewConstraints {
    [self.contentView removeConstraints:self.contentView.constraints];
    self.contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView an_constrainToSizeOfSuperview];
    [self.contentView an_alignToSuperviewWithXAttribute:NSLayoutAttributeLeft
                                             yAttribute:NSLayoutAttributeTop];
}

#pragma mark - EPLResizeViewDelegate

- (void)closeRegionSelectedOnResizeView {
    [self.delegate closeRegionSelectedOnResizeView:self];
}

#pragma mark - Layout

+ (BOOL)requiresConstraintBasedLayout {
    return YES;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self enableSupplementaryCloseRegionIfNecessary];
}

- (void)enableSupplementaryCloseRegionIfNecessary {
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    CGRect closeRegionBoundsInWindowCoordinates = [self.closeRegion convertRect:self.closeRegion.bounds
                                                                         toView:nil];
    if (CGRectContainsRect(screenBounds, closeRegionBoundsInWindowCoordinates)) {
        self.supplementaryCloseRegion.hidden = YES;
    } else {
        self.supplementaryCloseRegion.hidden = NO;

        CGRect selfBoundsInWindowCoordinates = [self convertRect:self.bounds
                                                          toView:nil];
        CGRect intersection = CGRectIntersection(screenBounds, selfBoundsInWindowCoordinates);
        CGRect intersectionFrameInCloseRegionCoordinates = [self convertRect:intersection
                                                                    fromView:nil];
        CGFloat updatedCloseRegionOriginX = intersectionFrameInCloseRegionCoordinates.origin.x + intersectionFrameInCloseRegionCoordinates.size.width - self.supplementaryCloseRegion.frame.size.width;
        CGFloat updatedCloseRegionOriginY = intersectionFrameInCloseRegionCoordinates.origin.y;
        
        CGRect updatedCloseRegionFrame = CGRectMake(updatedCloseRegionOriginX, updatedCloseRegionOriginY, self.supplementaryCloseRegion.frame.size.width, self.supplementaryCloseRegion.frame.size.height);
        
        [self.supplementaryCloseRegion setFrame:updatedCloseRegionFrame];
    }
}

- (UIImage *)closeRegionDefaultImage {
    if (!_closeRegionDefaultImage) {
        BOOL atLeastiOS7 = [self respondsToSelector:@selector(tintColorDidChange)];
        NSString *closeboxImageName = @"interstitial_flat_closebox";
        if (!atLeastiOS7) {
            closeboxImageName = @"interstitial_closebox";
        }
        _closeRegionDefaultImage = [UIImage imageWithContentsOfFile:EPLPathForANResource(closeboxImageName, @"png")];
    }
    return _closeRegionDefaultImage;
}

@end
