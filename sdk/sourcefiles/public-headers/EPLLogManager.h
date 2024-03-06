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

#import <Foundation/Foundation.h>

/**
 The lower the filter level, the more logs will be shown.
 For example, `EPLLogLevelInfo` will display messages from
 `EPLLogLevelInfo,` `EPLLogLevelWarn,` and `EPLLogLevelError.`
 The default level is `EPLLogLevelWarn`
 */
typedef NS_ENUM(NSUInteger, EPLLogLevel) {
	EPLLogLevelAll		= 0,
    EPLLogLevelMark      = 9,
	EPLLogLevelTrace		= 10,
	EPLLogLevelDebug		= 20,
	EPLLogLevelInfo		= 30,
	EPLLogLevelWarn		= 40,
	EPLLogLevelError		= 50,
	EPLLogLevelOff		= 60
};

/**
 Use the `EPLLogManager` methods to set the desired level of log filter.
 */
@interface EPLLogManager : NSObject

/**
 Gets the current log filter level.
 */
+ (EPLLogLevel)getANLogLevel;

/**
 Sets the log filter level.
 */
+ (void)setANLogLevel:(EPLLogLevel)level;

/**
 Enable  to subscribe for Notifications
 */
+ (void)setNotificationsEnabled:(BOOL )enabled;

/**
  Get Notification Status
 */
+ (BOOL)isNotificationsEnabled;


@end
