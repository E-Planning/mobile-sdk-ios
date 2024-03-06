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

#import <Foundation/Foundation.h>



#define EPL_DEBUG_MODE				1

extern NSString *const kANLoggingNotification;
extern NSString *const kANLogMessageKey;
extern NSString *const kANLogMessageLevelKey;

void notifyListener(NSString *message, NSInteger messageLevel);

#if EPL_DEBUG_MODE

void _ANLog(EPLLogLevel level, NSString *levelString, char const *logContext, NSString *format, ...)  NS_FORMAT_FUNCTION(4, 5);
#define EPLLogMark()             _ANLog(EPLLogLevelTrace, @"MARK",    __PRETTY_FUNCTION__, @"")
#define EPLLogMarkMessage(...)   _ANLog(EPLLogLevelTrace, @"MARK",    __PRETTY_FUNCTION__, __VA_ARGS__)
#define EPLLogTrace(...)         _ANLog(EPLLogLevelTrace, @"TRACE",   __PRETTY_FUNCTION__, __VA_ARGS__)
#define EPLLogDebug(...)         _ANLog(EPLLogLevelDebug, @"DEBUG",   __PRETTY_FUNCTION__, __VA_ARGS__)
#define EPLLogInfo(...)          _ANLog(EPLLogLevelInfo,  @"INFO",    __PRETTY_FUNCTION__, __VA_ARGS__)
#define EPLLogWarn(...)          _ANLog(EPLLogLevelWarn,  @"WARNING", __PRETTY_FUNCTION__, __VA_ARGS__)
#define EPLLogError(...)         _ANLog(EPLLogLevelError, @"ERROR",   __PRETTY_FUNCTION__, __VA_ARGS__)

#else

#define EPLLogMark() {}
#define EPLLogMarkMessage(...) {}
#define EPLLogTrace(...) {}
#define EPLLogDebug(...) {}
#define EPLLogInfo(...) {}
#define EPLLogWarn(...) {}
#define EPLLogError(...) {}

#endif


