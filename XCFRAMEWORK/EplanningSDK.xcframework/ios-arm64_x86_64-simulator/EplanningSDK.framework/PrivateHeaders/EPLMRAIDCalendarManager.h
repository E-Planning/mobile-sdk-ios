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

@protocol EPLMRAIDCalendarManagerDelegate;

@interface EPLMRAIDCalendarManager : NSObject

- (instancetype)initWithCalendarDictionary:(NSDictionary *)dict
                                  delegate:(id<EPLMRAIDCalendarManagerDelegate>)delegate;

@property (nonatomic, readwrite, weak) id<EPLMRAIDCalendarManagerDelegate> delegate;

@end

@protocol EPLMRAIDCalendarManagerDelegate <NSObject>

- (UIViewController *)rootViewControllerForPresentationForCalendarManager:(EPLMRAIDCalendarManager *)calendarManager;

@optional
- (void)willPresentCalendarEditForCalendarManager:(EPLMRAIDCalendarManager *)calendarManager;
- (void)didPresentCalendarEditForCalendarManager:(EPLMRAIDCalendarManager *)calendarManager;
- (void)willDismissCalendarEditForCalendarManager:(EPLMRAIDCalendarManager *)calendarManager;
- (void)didDismissCalendarEditForCalendarManager:(EPLMRAIDCalendarManager *)calendarManager;
- (void)calendarManager:(EPLMRAIDCalendarManager *)calendarManager calendarEditFailedWithErrorString:(NSString *)errorString;

@end
