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

#import "EPLBannerAdView+EPLContentViewTransitions.h"
#import "EPLSDKSettings.h"


static NSString *const kANContentViewTransitionsOldContentViewTransitionKey = @"AppNexusOldContentViewTransition";
static NSString *const kANContentViewTransitionsNewContentViewTransitionKey = @"AppNexusNewContentViewTransition";

@implementation EPLBannerAdView (EPLContentViewTransitions)

// Properties are synthesized in EPLBannerAdView
@dynamic transitionInProgress;
@dynamic contentView;

- (void)performTransitionFromContentView:(UIView *)oldContentView
                           toContentView:(UIView *)newContentView {
    if (self.transitionType == EPLBannerViewAdTransitionTypeNone) {
        if (newContentView) {
            [self addSubview:newContentView];
            [self constrainContentView];
            [self an_removeSubviewsWithException:newContentView];
        } else {
            [self an_removeSubviews];
        }
        return;
    }
    
    EPLBannerViewAdTransitionType transitionType = self.transitionType;
    if ((oldContentView && !newContentView) || (newContentView && !oldContentView)) {
        transitionType = EPLBannerViewAdTransitionTypeFade;
    }
    
    EPLBannerViewAdTransitionDirection transitionDirection = self.transitionDirection;
    if (transitionDirection == EPLBannerViewAdTransitionDirectionRandom) {
        transitionDirection = arc4random_uniform(4);
    }
    
    if (transitionType != EPLBannerViewAdTransitionTypeFlip) {
        newContentView.hidden = YES;
    }
    
    if (newContentView) {
        [self addSubview:newContentView];
        [self constrainContentView];
    }
    
    self.transitionInProgress = @(YES);
    
    [UIView animateWithDuration:self.transitionDuration
                     animations:^{
                         if (transitionType == EPLBannerViewAdTransitionTypeFlip) {
                             CAKeyframeAnimation *oldContentViewAnimation = [CAKeyframeAnimation animationWithKeyPath:@"transform"];
                             oldContentViewAnimation.values = [self keyFrameValuesForOldContentViewFlipAnimationWithDirection:transitionDirection];
                             oldContentViewAnimation.duration = self.transitionDuration;
                             [oldContentView.layer addAnimation:oldContentViewAnimation
                                                         forKey:kANContentViewTransitionsOldContentViewTransitionKey];
                             
                             CAKeyframeAnimation *newContentViewAnimation = [CAKeyframeAnimation animationWithKeyPath:@"transform"];
                             newContentViewAnimation.values = [self keyFrameValuesForNewContentViewFlipAnimationWithDirection:transitionDirection];
                             newContentViewAnimation.duration = self.transitionDuration;
                             newContentViewAnimation.delegate = (id<CAAnimationDelegate>)self;
                             [newContentView.layer addAnimation:newContentViewAnimation
                                                         forKey:kANContentViewTransitionsNewContentViewTransitionKey];
                         } else {
                             CATransition *transition = [CATransition animation];
                             transition.startProgress = 0;
                             transition.endProgress = 1.0;
                             transition.type = [[self class] CATransitionTypeFromANTransitionType:transitionType];
                             transition.subtype = [[self class] CATransitionSubtypeFromANTransitionDirection:transitionDirection
                                                                                        withANTransitionType:transitionType];
                             transition.duration = self.transitionDuration;
                             transition.delegate = (id<CAAnimationDelegate>)self;
                             
                             [oldContentView.layer addAnimation:transition
                                                         forKey:kCATransition];
                             [newContentView.layer addAnimation:transition
                                                         forKey:kCATransition];
                             
                             newContentView.hidden = NO;
                             oldContentView.hidden = YES;
                         }
                     }];
}

- (void)alignContentView {
    NSLayoutAttribute xAttribute = NSLayoutAttributeCenterX;
    NSLayoutAttribute yAttribute = NSLayoutAttributeCenterY;
    switch (self.alignment) {
        case EPLBannerViewAdAlignmentTopLeft:
            yAttribute = NSLayoutAttributeTop;
            xAttribute = NSLayoutAttributeLeft;
            break;
        case EPLBannerViewAdAlignmentTopCenter:
            yAttribute = NSLayoutAttributeTop;
            xAttribute = NSLayoutAttributeCenterX;
            break;
        case EPLBannerViewAdAlignmentTopRight:
            yAttribute = NSLayoutAttributeTop;
            xAttribute = NSLayoutAttributeRight;
            break;
        case EPLBannerViewAdAlignmentCenterLeft:
            yAttribute = NSLayoutAttributeCenterY;
            xAttribute = NSLayoutAttributeLeft;
            break;
        case EPLBannerViewAdAlignmentCenterRight:
            yAttribute = NSLayoutAttributeCenterY;
            xAttribute = NSLayoutAttributeRight;
            break;
        case EPLBannerViewAdAlignmentBottomLeft:
            yAttribute = NSLayoutAttributeBottom;
            xAttribute = NSLayoutAttributeLeft;
            break;
        case EPLBannerViewAdAlignmentBottomCenter:
            yAttribute = NSLayoutAttributeBottom;
            xAttribute = NSLayoutAttributeCenterX;
            break;
        case EPLBannerViewAdAlignmentBottomRight:
            yAttribute = NSLayoutAttributeBottom;
            xAttribute = NSLayoutAttributeRight;
            break;
        default: // EPLBannerViewAdAlignmentCenter
            break;
    }
    [self.contentView an_alignToSuperviewWithXAttribute:xAttribute
                                             yAttribute:yAttribute];
}

- (void)constrainContentView {
    self.contentView.translatesAutoresizingMaskIntoConstraints = NO;
    
    BOOL shouldConstrainToSuperview = NO;
    if (EPLSDKSettings.sharedInstance.shouldConstrainToSuperview != nil) {
        shouldConstrainToSuperview = EPLSDKSettings.sharedInstance.shouldConstrainToSuperview([NSValue valueWithCGSize:self.contentView.bounds.size]);
    }

    if(CGSizeEqualToSize([self adSize], CGSizeMake(1, 1)) || shouldConstrainToSuperview){
        
        [self.contentView an_constrainToSizeOfSuperview];
        [self.contentView an_alignToSuperviewWithXAttribute:NSLayoutAttributeLeft
                                                 yAttribute:NSLayoutAttributeTop];
        
    }else {
        
        [self.contentView an_constrainWithFrameSize];
        [self alignContentView];
        
    }
}

+ (NSString *)CATransitionSubtypeFromANTransitionDirection:(EPLBannerViewAdTransitionDirection)transitionDirection
                                      withANTransitionType:(EPLBannerViewAdTransitionType)transitionType {
    if (transitionType == EPLBannerViewAdTransitionTypeFade) {
        return kCATransitionFade;
    }
    
    switch (transitionDirection) {
        case EPLBannerViewAdTransitionDirectionUp:
            return kCATransitionFromTop;
        case EPLBannerViewAdTransitionDirectionDown:
            return kCATransitionFromBottom;
        case EPLBannerViewAdTransitionDirectionLeft:
            return kCATransitionFromRight;
        case EPLBannerViewAdTransitionDirectionRight:
            return kCATransitionFromLeft;
        default:
            return kCATransitionFade;
    }
}

+ (NSString *)CATransitionTypeFromANTransitionType:(EPLBannerViewAdTransitionType)transitionType {
    switch (transitionType) {
        case EPLBannerViewAdTransitionTypeFade:
            return kCATransitionPush;
        case EPLBannerViewAdTransitionTypePush:
            return kCATransitionPush;
        case EPLBannerViewAdTransitionTypeMoveIn:
            return kCATransitionMoveIn;
        case EPLBannerViewAdTransitionTypeReveal:
            return kCATransitionReveal;
        default:
            return kCATransitionPush;
    }
}

static NSInteger const kANBannerAdViewNumberOfKeyframeValuesToGenerate = 35;
static CGFloat kANBannerAdViewPerspectiveValue = -1.0 / 750.0;

- (NSArray *)keyFrameValuesForContentViewFlipAnimationWithDirection:(EPLBannerViewAdTransitionDirection)direction
                                                  forOldContentView:(BOOL)isOldContentView {
    CGFloat angle = 0.0f;
    CGFloat x;
    CGFloat y;
    CGFloat frameFlipDimensionLength = 0.0f;
    
    switch (direction) {
        case EPLBannerViewAdTransitionDirectionUp:
            x = 1;
            y = 0;
            angle = isOldContentView ? M_PI_2 : -M_PI_2;
            frameFlipDimensionLength = CGRectGetHeight(self.frame);
            break;
        case EPLBannerViewAdTransitionDirectionDown:
            x = 1;
            y = 0;
            angle = isOldContentView ? -M_PI_2: M_PI_2;
            frameFlipDimensionLength = CGRectGetHeight(self.frame);
            break;
        case EPLBannerViewAdTransitionDirectionLeft:
            x = 0;
            y = 1;
            angle = isOldContentView ? -M_PI_2 : M_PI_2;
            frameFlipDimensionLength = CGRectGetWidth(self.frame);
            break;
        case EPLBannerViewAdTransitionDirectionRight:
            x = 0;
            y = 1;
            angle = isOldContentView ? M_PI_2 : -M_PI_2;
            frameFlipDimensionLength = CGRectGetWidth(self.frame);
            break;
        default:
            x = 1;
            y = 0;
            angle = isOldContentView ? M_PI_2 : -M_PI_2;
            frameFlipDimensionLength = CGRectGetHeight(self.frame);
            break;
    }
    
    NSMutableArray *keyframeValues = [[NSMutableArray alloc] init];
    for (NSInteger valueNumber=0; valueNumber <= kANBannerAdViewNumberOfKeyframeValuesToGenerate; valueNumber++) {
        CATransform3D transform = CATransform3DIdentity;
        transform.m34 = kANBannerAdViewPerspectiveValue;
        transform = CATransform3DTranslate(transform, 0, 0, -frameFlipDimensionLength / 2.0);
        transform = CATransform3DRotate(transform, angle * valueNumber / kANBannerAdViewNumberOfKeyframeValuesToGenerate, x, y, 0);
        transform = CATransform3DTranslate(transform, 0, 0, frameFlipDimensionLength / 2.0);
        [keyframeValues addObject:[NSValue valueWithCATransform3D:transform]];
    }
    return isOldContentView ? keyframeValues : [[keyframeValues reverseObjectEnumerator] allObjects];
}

- (NSArray *)keyFrameValuesForOldContentViewFlipAnimationWithDirection:(EPLBannerViewAdTransitionDirection)direction {
    return [self keyFrameValuesForContentViewFlipAnimationWithDirection:direction
                                                      forOldContentView:YES];
}

- (NSArray *)keyFrameValuesForNewContentViewFlipAnimationWithDirection:(EPLBannerViewAdTransitionDirection)direction {
    return [self keyFrameValuesForContentViewFlipAnimationWithDirection:direction
                                                      forOldContentView:NO];
}

- (void)animationDidStop:(CAAnimation *)anim
                finished:(BOOL)flag {
    if (![self.contentView.layer.animationKeys count]) { // No animations left
        [self an_removeSubviewsWithException:self.contentView];
        self.transitionInProgress = @(NO);
    }
}

@end
