/*   Copyright 2022 APPNEXUS INC
 
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

#import "EPLAd.h"
#import "EPLGlobal.h"
#import "EPLHTTPNetworkSession.h"
#import "EPLLogging.h"
#import "EPLSDKSettings.h"


NSString * const  VIEWABLE_IMP_CONFIG_URL = @"https://acdn.adnxs.com/mobile/viewableimpression/member_list_array.json";


#pragma mark -

@interface EPLAd()


@property (nonatomic, readwrite, assign)  NSInteger memberId;
@property (nonatomic, readwrite, strong) NSMutableArray *viewableImpsMemberIdsArray;
@property (nonatomic,readwrite) BOOL isHttpTaskSuccess;
@property (nonatomic,readwrite) BOOL isOptinalSDKInitSuccess;
@end



@implementation EPLAd


+ (id)sharedInstance {
    static dispatch_once_t xandrAdSDKToken;
    static EPLAd *xandrAdSDK;
    dispatch_once(&xandrAdSDKToken, ^{
        xandrAdSDK = [[EPLAd alloc] init];
        xandrAdSDK.memberId = -1;
        xandrAdSDK.isHttpTaskSuccess = NO;
        xandrAdSDK.isOptinalSDKInitSuccess = NO;
    });
    return xandrAdSDK;
}


- (void)initWithMemberID:(NSInteger)memberId preCacheRequestObjects:(BOOL)preCacheRequestObjects completionHandler:(EPLAdInitCompletion)completionHandler{
    
    EPLLogDebug(@"EPLAd init");
    self.memberId = memberId;
    self.isHttpTaskSuccess = NO;
    self.isOptinalSDKInitSuccess = NO;
    

    
    dispatch_queue_t  backgroundQueue  = dispatch_queue_create(__PRETTY_FUNCTION__, DISPATCH_QUEUE_SERIAL);

    dispatch_async(backgroundQueue,
    ^{
        //
        dispatch_semaphore_t  semaphoreMemberIdHttpTask  = nil;
        dispatch_semaphore_t  semaphoreOptionalSDKInititalization  = nil;

        
        if (!self.viewableImpsMemberIdsArray)
        {
            semaphoreMemberIdHttpTask = [self fetchMemberIdList];
        }else{
            self.isHttpTaskSuccess = YES;
        }

        if (preCacheRequestObjects)
        {
            semaphoreOptionalSDKInititalization = [self performOptionalSDKInitialization];
        }else{
            self.isOptinalSDKInitSuccess = YES;
        }

        if (semaphoreMemberIdHttpTask)  {
            dispatch_semaphore_wait(semaphoreMemberIdHttpTask, DISPATCH_TIME_FOREVER);
        }

        if (preCacheRequestObjects)  {
            dispatch_semaphore_wait(semaphoreOptionalSDKInititalization, DISPATCH_TIME_FOREVER);
        }
        if(completionHandler != nil){
            dispatch_async(dispatch_get_main_queue(), ^{
                
                if(self.isOptinalSDKInitSuccess && self.isHttpTaskSuccess){
                    completionHandler(YES);
                }else{
                    completionHandler(NO);
                }
            });
        }
    });
}


- (dispatch_semaphore_t) fetchMemberIdList
{
    //
    dispatch_semaphore_t  semaphore  = dispatch_semaphore_create(0);
            EPLLogDebug(@"EPLAd init: Fetching Viewable Impression Member Id's");
            NSURLRequest *request     = EPLBasicRequestWithURL([NSURL URLWithString:VIEWABLE_IMP_CONFIG_URL]);
    
            [EPLHTTPNetworkSession startTaskWithHttpRequest:request responseHandler:^(NSData * _Nonnull data, NSHTTPURLResponse * _Nonnull response) {
    
                if (!data) {
                    EPLLogError(@"EPLAd Init - Fetching Viewable Impression Member Id's Failed");
                }
                NSError *e = nil;
                self.viewableImpsMemberIdsArray = [NSJSONSerialization JSONObjectWithData: data options: NSJSONReadingMutableContainers error: &e];
                if (!self.viewableImpsMemberIdsArray) {
                  EPLLogError(@"EPLAd Init - Error parsing Viewable Impression Member List JSON: %@", e);
                    self.isHttpTaskSuccess = NO;
                }
                self.isHttpTaskSuccess = YES;
                dispatch_semaphore_signal(semaphore);
            } errorHandler:^(NSError * _Nonnull error) {
                EPLLogError(@"EPLAd Init - Fetching Viewable Impression Member Id's Failed");
                self.isHttpTaskSuccess = NO;
                dispatch_semaphore_signal(semaphore);
            }];
    
    return  semaphore;
}

- (dispatch_semaphore_t) performOptionalSDKInitialization
{
    //
    dispatch_semaphore_t  semaphore  = dispatch_semaphore_create(0);
    [[EPLSDKSettings sharedInstance] optionalSDKInitialization:^(BOOL success){
                self.isOptinalSDKInitSuccess = success;
                dispatch_semaphore_signal(semaphore);
    }];
    return  semaphore;
}


-(BOOL) doesContainMemberId:(NSInteger)buyerMemberId{
    return ([self.viewableImpsMemberIdsArray containsObject:[NSNumber numberWithInteger:buyerMemberId]]);
}


- (BOOL)isEligibleForViewableImpression:(NSInteger)buyerMemberId{
    return ([self doesContainMemberId:buyerMemberId ] || buyerMemberId == self.memberId);
}


- (BOOL)isInitialised{
    return self.memberId != -1;
}




@end
