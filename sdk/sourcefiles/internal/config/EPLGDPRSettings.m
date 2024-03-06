/*   Copyright 2018 APPNEXUS INC
 
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

#import "EPLGDPRSettings.h"
#import "EPLLogging.h"

NSString * const  EPLGDPR_ConsentString = @"EPLGDPR_ConsentString";
NSString * const  EPLGDPR_ConsentRequired = @"EPLGDPR_ConsentRequired";
NSString * const  EPLGDPR_PurposeConsents = @"EPLGDPR_PurposeConsents";

//TCF 2.0 variables
NSString * const  EPLIABTCF_ConsentString = @"IABTCF_TCString";
NSString * const  EPLIABTCF_SubjectToGDPR = @"IABTCF_gdprApplies";
NSString * const  EPLIABTCF_PurposeConsents = @"IABTCF_PurposeConsents";
// Gpp TCF 2.0 variabled
NSString * const  EPLIABGPP_TCFEU2_PurposeConsents = @"IABGPP_TCFEU2_PurposeConsents";
NSString * const  EPLIABGPP_TCFEU2_SubjectToGDPR = @"IABGPP_TCFEU2_gdprApplies";


//TCF 1.1 variables
NSString * const  EPLIABConsent_ConsentString = @"IABConsent_ConsentString";
NSString * const  EPLIABConsent_SubjectToGDPR = @"IABConsent_SubjectToGDPR";

// Google ACM consent parameter
NSString * const  EPLIABTCF_ADDTL_CONSENT = @"IABTCF_AddtlConsent";



@interface EPLGDPRSettings()

@end


@implementation EPLGDPRSettings

/**
 * Set the GDPR consent string in the SDK
 */
+ (void) setConsentString:(nonnull NSString *)consentString{
    [[NSUserDefaults standardUserDefaults] setObject:consentString forKey:EPLGDPR_ConsentString];
}

/**
 * Set the GDPR consent required in the SDK
 */
+ (void) setConsentRequired:(NSNumber *)consentRequired{
    
    [[NSUserDefaults standardUserDefaults] setValue:consentRequired forKey:EPLGDPR_ConsentRequired];
    
}

/**
 * reset the GDPR consent string and consent required in the SDK
 */
+ (void) reset{
    NSUserDefaults *defaults= [NSUserDefaults standardUserDefaults];
    if([[[defaults dictionaryRepresentation] allKeys] containsObject:EPLGDPR_ConsentString]){
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:EPLGDPR_ConsentString];
    }
    if([[[defaults dictionaryRepresentation] allKeys] containsObject:EPLGDPR_ConsentRequired]){
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:EPLGDPR_ConsentRequired];
    }
    if([[[defaults dictionaryRepresentation] allKeys] containsObject:EPLGDPR_PurposeConsents]){
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:EPLGDPR_PurposeConsents];
    }
}

/**
 * Get the GDPR consent string in the SDK.
 * Check for EPLIABTCF_ConsentString or EPLGDPR_ConsentString or EPLIABConsent_ConsentString in that order and return if present else return @""
 */
+ (nullable NSString *) getConsentString{
    NSString* consentString = [[NSUserDefaults standardUserDefaults] stringForKey:EPLIABTCF_ConsentString];
    if(consentString.length <= 0){
        consentString = [[NSUserDefaults standardUserDefaults] stringForKey:EPLGDPR_ConsentString];
        if(consentString.length <= 0){
            consentString = [[NSUserDefaults standardUserDefaults] stringForKey:EPLIABConsent_ConsentString];
        }
    }
    return consentString? consentString: @"";
}

/**
 * Get the GDPR consent required in the SDK
 * Check for EPLIABTCF_SubjectToGDPR ,  EPLGDPR_ConsentRequired ,  EPLIABConsent_SubjectToGDPR and EPLIABGPP_TCFEU2_SubjectToGDPR in that order  and return if present else return nil
 */
+ (nullable NSNumber *) getConsentRequired{
    
    NSNumber *hasConsent = [[NSUserDefaults standardUserDefaults] valueForKey:EPLIABTCF_SubjectToGDPR];
    if(hasConsent == nil){
        hasConsent = [[NSUserDefaults standardUserDefaults] valueForKey:EPLGDPR_ConsentRequired];
        if(hasConsent == nil){
            NSString *hasConsentStringValue = [[NSUserDefaults standardUserDefaults] stringForKey:EPLIABConsent_SubjectToGDPR];
            NSNumberFormatter *numberFormatter = [NSNumberFormatter new];
            hasConsent = [numberFormatter numberFromString:hasConsentStringValue];
        }
        if(hasConsent == nil){
            hasConsent = [[NSUserDefaults standardUserDefaults] valueForKey:EPLIABGPP_TCFEU2_SubjectToGDPR];
        }
    }
    return hasConsent;
}

  // pull Google Ad Tech Provider (ATP) IDs ids from the Addtional Consent(AC)string and convert them to JSONArray of integers.
  // for example if addtlConsentString = '1~7.12.35.62.66.70.89.93.108', then we need to return [7,12,35,62,66,70,89,93,108] this is the format impbus understands.
+ (nonnull NSArray *) getGoogleACMConsentArray{
    NSString* addtlConsentString = [[NSUserDefaults standardUserDefaults] stringForKey:EPLIABTCF_ADDTL_CONSENT];
    NSMutableArray *consentedATPIntegerArray = [NSMutableArray array];
    
    // Only if a valid Additional consent string is present proceed further.
    // The string has to start with 1~ (we support only version 1 of the ACM spec)
    if(addtlConsentString && addtlConsentString.length >2 && [addtlConsentString hasPrefix:@"1~"]){
        // From https://support.google.com/admanager/answer/9681920
        // An AC string contains the following three components:
        // Part 1: A specification version number, such as "1"
        // Part 2: A separator symbol "~"
        // Part 3: A dot-separated list of user-consented Google Ad Tech Provider (ATP) IDs. Example: "1.35.41.101"
        // For example, the AC string 1~1.35.41.101 means that the user has consented to ATPs with IDs 1, 35, 41 and 101, and the string is created using the format defined in the v1.0 specification.
        @try {
            NSArray *parsedACString = [addtlConsentString componentsSeparatedByString:@"~"];
            NSArray *consentedATPStringArray = [parsedACString[1] componentsSeparatedByString:@"."];
            for ( int i = 0; i < consentedATPStringArray.count; ++i ){
                [consentedATPIntegerArray addObject:[NSNumber numberWithInt:[consentedATPStringArray[i] intValue]]];
            }
        } @catch (NSException *ex) {
            EPLLogError(@"Exception while processing Google addtlConsentString");
        }
    }
    return consentedATPIntegerArray;
}

/**
* Get the GDPR device consent required in the SDK to pass IDFA & cookies
* Check for EPLIABTCF_PurposeConsents ,  EPLGDPR_PurposeConsents and EPLIABGPP_TCFEU2_PurposeConsents in that order  and return if present else return nil
*/
+ (NSString *) getDeviceAccessConsent {
    
    NSString* purposeConsents = [[NSUserDefaults standardUserDefaults] objectForKey:EPLIABTCF_PurposeConsents];
    if(purposeConsents.length <= 0){
        purposeConsents = [[NSUserDefaults standardUserDefaults] objectForKey:EPLGDPR_PurposeConsents];
    }
    if(purposeConsents.length <= 0){
        purposeConsents = [[NSUserDefaults standardUserDefaults] objectForKey:EPLIABGPP_TCFEU2_PurposeConsents];
    }
    if(purposeConsents != nil && purposeConsents.length > 0){
        return [purposeConsents substringToIndex:1];
    }
    return nil;
    
}

/**
* set the GDPR device consent required in the SDK to pass IDFA & cookies
*/
+ (void) setPurposeConsents :(nonnull NSString *) purposeConsents {
    if (purposeConsents.length > 0) {
        [[NSUserDefaults standardUserDefaults] setObject:purposeConsents forKey:EPLGDPR_PurposeConsents];
    }
}

/**
* Get the GDPR device consent as a combination of purpose 1 & consent required
*/
+ (BOOL) canAccessDeviceData {
    //fetch advertising identifier based TCF 2.0 Purpose1 value
    //truth table
    /*
                            deviceAccessConsent=true   deviceAccessConsent=false  deviceAccessConsent undefined
     consentRequired=false        Yes, read IDFA             No, don’t read IDFA           Yes, read IDFA
     consentRequired=true         Yes, read IDFA             No, don’t read IDFA           No, don’t read IDFA
     consentRequired=undefined    Yes, read IDFA             No, don’t read IDFA           Yes, read IDFA
     */
        
    if((([EPLGDPRSettings getDeviceAccessConsent] == nil) && ([EPLGDPRSettings getConsentRequired] == nil || [[EPLGDPRSettings getConsentRequired] boolValue] == NO)) || ([EPLGDPRSettings getDeviceAccessConsent] != nil && [[EPLGDPRSettings getDeviceAccessConsent] isEqualToString:@"1"])){
        return true;
    }
    
    return false;
}

@end
