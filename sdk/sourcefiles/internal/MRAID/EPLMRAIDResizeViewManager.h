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

#import <UIKit/UIKit.h>
#import "EPLMRAIDResizeProperties.h"
#import "EPLMRAIDResizeView.h"

@class EPLMRAIDResizeView;
@protocol EPLMRAIDResizeViewManagerDelegate;

@interface EPLMRAIDResizeViewManager : NSObject

@property (nonatomic, readonly, strong) EPLMRAIDResizeView *resizeView;
@property (nonatomic, readwrite, weak) id<EPLMRAIDResizeViewManagerDelegate> delegate;
@property (nonatomic, readonly, assign, getter=isResized) BOOL resized;

- (instancetype)initWithContentView:(UIView *)contentView
                         anchorView:(UIView *)anchorView;

- (BOOL)attemptResizeWithResizeProperties:(EPLMRAIDResizeProperties *)properties
                              errorString:(NSString *__autoreleasing*)errorString;
- (void)detachResizeView;

- (void)didMoveAnchorViewToWindow;

@end

@protocol EPLMRAIDResizeViewManagerDelegate <NSObject>

- (void)resizeViewClosedByResizeViewManager:(EPLMRAIDResizeViewManager *)manager;

@end
