/*   Copyright 2016 APPNEXUS INC
 
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

#import "EPLSDKSettings.h"
#import "EPLGlobal.h"
#import "EPLLogManager.h"
#import "EPLCarrierObserver.h"
#import "EPLReachability.h"
#import "EPLBaseUrlConfig.h"
#import "EPLWebView.h"
#import "EPLLogging.h"
#import "EPLGDPRSettings.h"
#import "EPLAdConstants.h"


@interface EPLBaseUrlConfig : NSObject
//EMPTY
@end


@implementation EPLBaseUrlConfig

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    static EPLBaseUrlConfig *config;
    dispatch_once(&onceToken, ^{
        config = [[EPLBaseUrlConfig alloc] init];
    });
    return config;
}

- (NSString *)webViewBaseUrl {
    if( EPLGDPRSettings.canAccessDeviceData == NO || EPLSDKSettings.sharedInstance.doNotTrack == YES){
        return @"https://ib.adnxs-simple.com/";
    }
    return @"https://mediation.adnxs.com/";
}

-(NSString *) utAdRequestBaseUrl {
    if(EPLGDPRSettings.canAccessDeviceData == NO || EPLSDKSettings.sharedInstance.doNotTrack == YES){
        return @"https://dibu-m1ny231s8-fndigrazias-projects.vercel.app/mob/3";
    }
    return @"https://dibu-m1ny231s8-fndigrazias-projects.vercel.app/mob/3";
}

- (NSURL *) videoWebViewUrl
{
    return  [self urlForResourceWithBasename:@"vastVideo" andExtension:@"html"];
}

- (NSURL *) nativeRenderingUrl
{
    return  [self urlForResourceWithBasename:@"nativeRenderer" andExtension:@"html"];
}


#pragma mark - Helper methods.

- (NSURL *) urlForResourceWithBasename:(NSString *)basename andExtension:(NSString *)extension
{
    if (EPLLogManager.getANLogLevel > EPLLogLevelDebug)
    {
        return [EPLResourcesBundle() URLForResource:basename withExtension:extension];
        
    } else {
        NSURL       *url                        = [EPLResourcesBundle() URLForResource:basename withExtension:extension];
        NSString    *URLString                  = [url absoluteString];
        NSString    *debugQueryString           = @"?ast_debug=true";
        NSString    *URLwithDebugQueryString    = [URLString stringByAppendingString: debugQueryString];
        NSURL       *debugURL                   = [NSURL URLWithString:URLwithDebugQueryString];
        
        return debugURL;
    }
}
@end




@interface EPLSDKSettings()

@property (nonatomic) EPLBaseUrlConfig *baseUrlConfig;
@property (nonatomic, readwrite, strong, nonnull) NSString *sdkVersion;
@end


@implementation EPLSDKSettings

@synthesize nativeAdAboutToExpireInterval = __nativeAdAboutToExpireInterval;

+ (id)sharedInstance {
    static dispatch_once_t sdkSettingsToken;
    static EPLSDKSettings *sdkSettings;
    dispatch_once(&sdkSettingsToken, ^{
        sdkSettings = [[EPLSDKSettings alloc] init];
        sdkSettings.locationEnabledForCreative =  YES;
        sdkSettings.enableOpenMeasurement = YES;
        sdkSettings.enableTestMode = NO;
        sdkSettings.disableIDFAUsage = NO;
        sdkSettings.disableIDFVUsage = NO;
        sdkSettings.doNotTrack = NO;
        sdkSettings.auctionTimeout = 0;
        sdkSettings.nativeAdAboutToExpireInterval = kAppNexusNativeAdAboutToExpireInterval;
        sdkSettings.enableOMIDOptimization = NO;
        sdkSettings.enableContinuousTracking = NO;
    });
    return sdkSettings;
}

- (NSString *)sdkVersion{
    return EPL_SDK_VERSION;
}

- (EPLBaseUrlConfig *)baseUrlConfig {
    if (!_baseUrlConfig) {
        return [EPLBaseUrlConfig sharedInstance];
        
    } else {
        return _baseUrlConfig;
    }
}

// In general, MobileSDK does not require initialization.
// However, MobileSDK does maintain state, some of which can be initialized early in the app lifecycle in order to save cycles later.
//
// Optionally call this method early in the app lifecycle.  For example in [AppDelegate application:didFinishLaunchingWithOptions:].

- (void) optionalSDKInitialization:(sdkInitCompletion _Nullable)success
{
    [[EPLReachability sharedReachabilityForInternetConnection] start];
    [EPLGlobal adServerRequestURL];
    
    //    App should be able to handle changes to the user’s cellular service provider. For example, the user could swap the device’s SIM card with one from another provider while app is running. Not applicable for macOS to know more click link https://developer.apple.com/documentation/coretelephony/cttelephonynetworkinfo
#if !APPNEXUS_NATIVE_MACOS_SDK
    [EPLCarrierObserver shared];
    [EPLWebView prepareWebView];
#endif
    
    if(success != nil){
        if ([EPLGlobal userAgent] == nil) {
            NSOperationQueue *queue = [[NSOperationQueue alloc]init];
            
            [[NSNotificationCenter defaultCenter] addObserverForName:@"kUserAgentDidChangeNotification"
                                                              object:nil
                                                               queue:queue
                                                          usingBlock:^(NSNotification *notification) {
                success(YES);
                [[NSNotificationCenter defaultCenter] removeObserver:@"kUserAgentDidChangeNotification"];
                [[NSNotificationCenter defaultCenter] removeObserver:@"kUserAgentFailedToChangeNotification"];
            }];
            
            [[NSNotificationCenter defaultCenter] addObserverForName:@"kUserAgentFailedToChangeNotification"
                                                              object:nil
                                                               queue:queue
                                                          usingBlock:^(NSNotification *notification) {
                success(NO);
                [[NSNotificationCenter defaultCenter] removeObserver:@"kUserAgentDidChangeNotification"];
                [[NSNotificationCenter defaultCenter] removeObserver:@"kUserAgentFailedToChangeNotification"];
            }];
        } else {
            success(YES);
        }
    }
}

-(void)setNativeAdAboutToExpireInterval:(NSInteger)nativeAdAboutToExpireInterval{
    if(nativeAdAboutToExpireInterval <= 0 ){
        __nativeAdAboutToExpireInterval = kAppNexusNativeAdAboutToExpireInterval;
        EPLLogError(@"nativeAdAboutToExpireInterval can not be set less than or equal to zero");
        return;
    }
    __nativeAdAboutToExpireInterval = nativeAdAboutToExpireInterval;
}

@end
