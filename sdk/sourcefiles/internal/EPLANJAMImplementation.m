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

#import "EPLANJAMImplementation.h"

#import "EPLGlobal.h"
#import "EPLLogging.h"
#import "NSString+EPLCategory.h"

// Minimum MARID refresh interval set via EPLJAM in Seconds.
//
#define kANMinimumMRAIDRefreshFrequencyInSeconds 0.1

NSString *const kANCallMayDeepLink = @"MayDeepLink";
NSString *const kANCallDeepLink = @"DeepLink";
NSString *const kANCallExternalBrowser = @"ExternalBrowser";
NSString *const kANCallInternalBrowser = @"InternalBrowser";
NSString *const kANCallRecordEvent = @"RecordEvent";
NSString *const kANCallDispatchAppEvent = @"DispatchAppEvent";
NSString *const kANCallGetDeviceID = @"GetDeviceID";
NSString *const kANCallSetMraidRefreshFrequency = @"SetMRAIDRefreshFrequency";
NSString *const kANCallGetCustomKeywords = @"GetCustomKeywords";

NSString *const kANKeyCaller = @"caller";

@interface EPLRecordEventDelegate : NSObject <WKNavigationDelegate>
@end

@interface WKWebView (RecordEvent)
@property (nonatomic, readwrite, strong) EPLRecordEventDelegate *recordEventDelegate;
@end

@implementation EPLANJAMImplementation

+ (void)handleURL:(NSURL *)URL withWebViewController:(EPLAdWebViewController *)controller {
    NSString *call = [URL host];
    NSDictionary *queryComponents = [[URL query] an_queryComponents];
    if ([call isEqualToString:kANCallMayDeepLink]) {
        [EPLANJAMImplementation callMayDeepLink:controller query:queryComponents];
    } else if ([call isEqualToString:kANCallDeepLink]) {
        [EPLANJAMImplementation callDeepLink:controller query:queryComponents];
    } else if ([call isEqualToString:kANCallExternalBrowser]) {
        [EPLANJAMImplementation callExternalBrowser:controller query:queryComponents];
    } else if ([call isEqualToString:kANCallInternalBrowser]) {
        [EPLANJAMImplementation callInternalBrowser:controller query:queryComponents];
    } else if ([call isEqualToString:kANCallRecordEvent]) {
        [EPLANJAMImplementation callRecordEvent:controller query:queryComponents];
    } else if ([call isEqualToString:kANCallDispatchAppEvent]) {
        [EPLANJAMImplementation callDispatchAppEvent:controller query:queryComponents];
    } else if ([call isEqualToString:kANCallGetDeviceID]) {
        [EPLANJAMImplementation callGetDeviceID:controller query:queryComponents];
    } else if ([call isEqualToString:kANCallSetMraidRefreshFrequency]) {
        [EPLANJAMImplementation callSetMraidRefreshFrequency:controller query:queryComponents];
    } else if ([call isEqualToString:kANCallGetCustomKeywords]) {
        [EPLANJAMImplementation callGetCustomKeywords:controller query:queryComponents];
    }else {
        EPLLogWarn(@"EPLJAM called with unsupported function: %@", call);
    }
}

// Deep Link

+ (void)callMayDeepLink:(EPLAdWebViewController *)controller query:(NSDictionary *)query {
    NSString *cb = [query valueForKey:@"cb"];
    NSString *urlParam = [query valueForKey:@"url"];
    BOOL mayDeepLink;
    
    if ([urlParam length] < 1) {
        mayDeepLink = NO;
    } else {
        NSURL *url = [NSURL URLWithString:urlParam];
        mayDeepLink = [[UIApplication sharedApplication] canOpenURL:url];
    }
    
    NSDictionary *paramsList = @{
                                 kANKeyCaller: kANCallMayDeepLink,
                                 @"mayDeepLink": mayDeepLink ? @"true" : @"false"
                                 };
    [EPLANJAMImplementation loadResult:controller cb:cb paramsList:paramsList];
}

+ (void)callDeepLink:(EPLAdWebViewController *)controller query:(NSDictionary *)query {
    NSString *cb = [query valueForKey:@"cb"];
    NSString *urlParam = [query valueForKey:@"url"];
    
    NSURL *url = [NSURL URLWithString:urlParam];
    if ([[UIApplication sharedApplication] canOpenURL:url]
        && [[UIApplication sharedApplication] openURL:url]) {
        // success, do nothing
        return;
    } else {
        NSDictionary *paramsList = @{kANKeyCaller: kANCallDeepLink};
        [EPLANJAMImplementation loadResult:controller cb:cb paramsList:paramsList];
    }
}

// Launch Browser

+ (void)callExternalBrowser:(EPLAdWebViewController *)controller query:(NSDictionary *)query {
    NSString *urlParam = [query valueForKey:@"url"];
    
    NSURL *url = [NSURL URLWithString:urlParam];
    if (EPLHasHttpPrefix([url scheme])
        && [[UIApplication sharedApplication] canOpenURL:url]) {
        //added as the test case was failing due to unavailability of a delegate.
        [controller.adViewANJAMInternalDelegate adWillLeaveApplication];
        [EPLGlobal openURL:[url absoluteString]];
    }
}

+ (void)callInternalBrowser:(EPLAdWebViewController *)controller
                      query:(NSDictionary *)query {
    NSString *urlParam = [query valueForKey:@"url"];
    NSURL *url = [NSURL URLWithString:urlParam];
    [controller.browserDelegate openInAppBrowserWithURL:url];
}

// Record Event

+ (void)callRecordEvent:(EPLAdWebViewController *)controller query:(NSDictionary *)query {
    NSString *urlParam = [query valueForKey:@"url"];
    
    NSURL *url = [NSURL URLWithString:urlParam];
    WKWebView *recordEventWebView = [[WKWebView alloc] initWithFrame:CGRectMake(0, 0, 0, 0)];
    EPLRecordEventDelegate *recordEventDelegate = [EPLRecordEventDelegate new];
    recordEventWebView.recordEventDelegate = recordEventDelegate;
    recordEventWebView.navigationDelegate = recordEventDelegate;
    [recordEventWebView setHidden:YES];
    [recordEventWebView loadRequest:[NSURLRequest requestWithURL:url]];
    [controller.contentView addSubview:recordEventWebView];
}

// Dispatch App Event

+ (void)callDispatchAppEvent:(EPLAdWebViewController *)controller query:(NSDictionary *)query {
    NSString *event = [query valueForKey:@"event"];
    NSString *data = [query valueForKey:@"data"];
    
    [controller.adViewANJAMInternalDelegate adDidReceiveAppEvent:event withData:data];
}

// Get Device ID

+ (void)callGetDeviceID:(EPLAdWebViewController *)controller query:(NSDictionary *)query {
   
    NSString *idfa = EPLAdvertisingIdentifier();
        NSString *cb = [query valueForKey:@"cb"];
        // send idName:idfa, id: idfa value
        NSDictionary *paramsList = @{
            kANKeyCaller: kANCallGetDeviceID,
            @"idname": @"idfa",
            @"id": (idfa ? idfa : @"")
        };
        [EPLANJAMImplementation loadResult:controller cb:cb paramsList:paramsList];
}

// Get Custom Keywords

+ (void)callGetCustomKeywords:(EPLAdWebViewController *)controller query:(NSDictionary *)query {
    NSString *cb = [query valueForKey:@"cb"];
    
    NSMutableDictionary<NSString *, NSString *>  *customKeywordsAsStrings  = [EPLGlobal convertCustomKeywordsAsMapToStrings: controller.adViewANJAMInternalDelegate.customkeywordsForANJAM
                                                                                                       withSeparatorString: @"," ];
    [EPLANJAMImplementation loadResult:controller cb:cb paramsList:customKeywordsAsStrings];
}

+ (void)callSetMraidRefreshFrequency:(EPLAdWebViewController *)controller query:(NSDictionary *)query {
    NSString *milliseconds = [query valueForKey:@"ms"];
    double refreshFrequencyinSeconds = [milliseconds doubleValue] / 1000;
    if (refreshFrequencyinSeconds < kANMinimumMRAIDRefreshFrequencyInSeconds)
    {
        controller.checkViewableTimeInterval = kANMinimumMRAIDRefreshFrequencyInSeconds;
        EPLLogWarn(@"setMraidRefreshFrequency called with value %f, setMraidRefreshFrequency set to minimum allowed value %f.",
                  refreshFrequencyinSeconds, kANMinimumMRAIDRefreshFrequencyInSeconds );
    } else {
        controller.checkViewableTimeInterval = refreshFrequencyinSeconds;
    }
}

// Send the result back to JS

+ (void)loadResult:(EPLAdWebViewController *)controller cb:(NSString *)cb paramsList:(NSDictionary *)paramsList {
    __block NSString *params = [NSString stringWithFormat:@"cb=%@", cb ? cb : @"-1"];
    
    [paramsList enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
        key = EPLConvertToNSString(key);
        NSString *valueString = EPLConvertToNSString(value);
        if (([key length] > 0) && ([valueString length] > 0)) {
            params = [params stringByAppendingFormat:@"&%@=%@", key,
                      [valueString an_encodeAsURIComponent]];
        }
    }];
    
    NSString *url = [NSString stringWithFormat:@"javascript:window.sdkjs.client.result(\"%@\")", params];
    [controller fireJavaScript:url];
}

@end

@implementation EPLRecordEventDelegate

-(void) webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    EPLLogDebug(@"RecordEvent completed succesfully");
}

@end

@implementation WKWebView (RecordEvent)

EPLRecordEventDelegate *_recordEventDelegate;


- (void)setRecordEventDelegate:(EPLRecordEventDelegate *)recordEventDelegate {
    _recordEventDelegate = recordEventDelegate;
}

- (EPLRecordEventDelegate *)recordEventDelegate {
    return _recordEventDelegate;
}

@end
