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

#import "EPLBannerAdView.h"
#import "UIView+EPLCategory.h"

@interface EPLBannerAdView (EPLContentViewTransitions)

@property (nonatomic, readonly, strong) UIView *contentView; // Only need readonly access in this category
@property (nonatomic, readwrite, strong) NSNumber *transitionInProgress;

- (void)performTransitionFromContentView:(UIView *)oldContentView
                           toContentView:(UIView *)newContentView;
- (void)alignContentView;
- (void)constrainContentView;

@end