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

#import "EPLLogManager.h"

static EPLLogLevel  EPLLOG_LEVEL  = EPLLogLevelWarn;   //EPLLogLevelAll

static BOOL notificationsEnabled = NO;


@implementation EPLLogManager

+ (EPLLogLevel)getANLogLevel {
	return EPLLOG_LEVEL;
}

+ (void)setANLogLevel:(EPLLogLevel)level {
    EPLLOG_LEVEL = level;
}

+ (void)setNotificationsEnabled:(BOOL )enabled{
    notificationsEnabled = enabled;
}

+ (BOOL)isNotificationsEnabled{
    return notificationsEnabled;
}

@end
