/*   Copyright 2014 APPNEXUS INC
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import "ANHTTPStubURLProtocol.h"
#import "ANHTTPStubbingManager.h"



static NSString *const  kANTestHTTPStubURLProtocolExceptionKey              = @"kANTestHTTPStubURLProtocolExceptionKey";
NSString *const         kANHTTPStubURLProtocolRequestDidLoadNotification    = @"kANHTTPStubURLProtocolRequestDidLoadNotification";
NSString *const         kANHTTPStubURLProtocolRequest                       = @"kANHTTPStubURLProtocolRequest";



@implementation ANHTTPStubURLProtocol

+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
    BOOL broadcastRequests = [ANHTTPStubbingManager sharedStubbingManager].broadcastRequests;

    if (broadcastRequests && request) {
        [[NSNotificationCenter defaultCenter] postNotificationName:kANHTTPStubURLProtocolRequestDidLoadNotification
                                                            object:nil
                                                          userInfo:@{kANHTTPStubURLProtocolRequest:request}];
    }

    BOOL isHttpOrHttps = [request.URL.scheme isEqualToString:@"http"] || [request.URL.scheme isEqualToString:@"https"];
    if (!isHttpOrHttps) {
        return NO;
    }

    BOOL ignoreUnstubbedRequests = [ANHTTPStubbingManager sharedStubbingManager].ignoreUnstubbedRequests;
    if (ignoreUnstubbedRequests) {
        ANURLConnectionStub *stub = [[ANHTTPStubbingManager sharedStubbingManager] stubForURLString:request.URL.absoluteString];
        return (stub != nil);
    } else {
        return YES;
    }
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
}

+ (BOOL)requestIsCacheEquivalent:(NSURLRequest *)a toRequest:(NSURLRequest *)b {
    return NO;
}

- (void)startLoading {
    id<NSURLProtocolClient>   client    = self.client;
    ANURLConnectionStub      *stub      = [self stubForRequest];
    
    if (stub) {
        NSURLResponse *response = [self buildResponseForRequestUsingStub:stub];
        [client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];

        NSData *responseData = [self buildDataForRequestUsingStub:stub];
        [client URLProtocol:self didLoadData:responseData];

        [client URLProtocolDidFinishLoading:self];
        NSLog(@"Successfully loaded request from stub: %@", [self request]);
        
    } else {
        NSLog(@"Could not load request successfully: %@", [self request]);
        NSLog(@"This can happen if the request was not stubbed, or if the stubs were removed before this request was completed (due to asynchronous request loading).");
        [client URLProtocol: self
           didFailWithError: [NSError errorWithDomain: kANTestHTTPStubURLProtocolExceptionKey
                                                 code: 1
                                             userInfo: nil ]
         ];
    }
}

- (void)stopLoading {
    // Do nothing, but method is required.
}




#pragma mark - Stubbing

- (ANURLConnectionStub *)stubForRequest {
    return [[ANHTTPStubbingManager sharedStubbingManager] stubForURLString:self.request.URL.absoluteString];
}


- (NSURLResponse *)buildResponseForRequestUsingStub:(ANURLConnectionStub *)stub {
    NSHTTPURLResponse *httpResponse = [[NSHTTPURLResponse alloc] initWithURL:[[self request] URL]
                                                                  statusCode:stub.responseCode
                                                                 HTTPVersion:@"HTTP/1.1"
                                                                headerFields:@{}];
    return httpResponse;
}

- (NSData *)buildDataForRequestUsingStub:(ANURLConnectionStub *)stub {
    if ([stub.responseBody isKindOfClass:[NSString class]]) {
        return [stub.responseBody dataUsingEncoding:NSUTF8StringEncoding];
    } else if ([stub.responseBody isKindOfClass:[NSData class]]) {
        return stub.responseBody;
    }
    return nil;
}

@end
