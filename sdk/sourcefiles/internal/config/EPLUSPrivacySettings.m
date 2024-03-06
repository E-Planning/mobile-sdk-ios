/*   Copyright 2019 APPNEXUS INC

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

#import "EPLUSPrivacySettings.h"

NSString * const  EPL_USPrivacy_String = @"EPLUSPrivacy_String";
NSString * const  EPL_IAB_USPrivacy_String = @"IABUSPrivacy_String";

@implementation EPLUSPrivacySettings

/**
 * Set the IAB US Privacy String in the SDK
 */
+ (void) setUSPrivacyString:(nonnull NSString *)privacyString{
    [[NSUserDefaults standardUserDefaults] setObject:privacyString forKey:EPL_USPrivacy_String];
}

/**
 * Reset the value of IAB US Privacy String that was previously set using setUSPrivacyString
*/
+ (void) reset{
    NSUserDefaults *defaults= [NSUserDefaults standardUserDefaults];
    if([[[defaults dictionaryRepresentation] allKeys] containsObject:EPL_USPrivacy_String]){
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:EPL_USPrivacy_String];
    }
}

/**
 * Get the IAB US Privacy String in the SDK.
 * Check for EPL_USPrivacy_String And IAB_USPrivacy_String and return if present else return @""
 */
+ (nonnull NSString *) getUSPrivacyString{
    NSString* privacyString = [[NSUserDefaults standardUserDefaults] objectForKey:EPL_USPrivacy_String];
    if(privacyString == nil){
        privacyString = [[NSUserDefaults standardUserDefaults] objectForKey:EPL_IAB_USPrivacy_String];
    }
    return privacyString? privacyString: @"";
}
@end
