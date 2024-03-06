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

#import "ANHTTPStubbingManager.h"
#import "ANHTTPStubURLProtocol.h"
#import "ANTestGlobal.h"
#import "ANSDKSettings.h"

#import "NSURLRequest+HTTPBodyTesting.h"




@interface ANHTTPStubbingManager()
@property (nonatomic) NSMutableArray *stubs;
@end




@implementation ANHTTPStubbingManager

+ (ANHTTPStubbingManager *)sharedStubbingManager {
    static dispatch_once_t sharedStubbingManagerToken;
    static ANHTTPStubbingManager *manager;
    dispatch_once(&sharedStubbingManagerToken, ^{
        manager = [[ANHTTPStubbingManager alloc] init];
    });
    return manager;
}

- (void)enable {
    [NSURLProtocol registerClass:[ANHTTPStubURLProtocol class]];
}

- (void)disable {
    [NSURLProtocol unregisterClass:[ANHTTPStubURLProtocol class]];
}

- (void)addStub:(ANURLConnectionStub *)stub {
    [self.stubs addObject:stub];
}

- (void)addStubs:(NSArray *)stubs {
    [self.stubs addObjectsFromArray:stubs];
}

- (void)removeAllStubs {
    [self.stubs removeAllObjects];
}

- (NSMutableArray *)stubs {
    @synchronized(self) {
        if (!_stubs) _stubs = [[NSMutableArray alloc] init];
        return _stubs;
    }
}

- (ANURLConnectionStub *)stubForURLString:(NSString *)URLString
{
    __block ANURLConnectionStub  *stubMatch  = nil;

    [self.stubs enumerateObjectsUsingBlock: ^(ANURLConnectionStub *stub, NSUInteger idx, BOOL *stop)
                                            {
                                                NSError *error;
                                                NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern: stub.requestURL
                                                                                                                       options: NSRegularExpressionDotMatchesLineSeparators
                                                                                                                         error: &error];
                                                if ([regex numberOfMatchesInString: URLString
                                                                           options: 0
                                                                             range: NSMakeRange(0, [URLString length])])
                                                {
                                                    stubMatch = stub;
                                                    *stop = YES;
                                                }
                                            } ];
    return  stubMatch;
}




#pragma mark - Helper class methods.

+ (NSDictionary *) jsonBodyOfURLRequestAsDictionary: (NSURLRequest *)urlRequest
{
    TESTTRACE();

    NSString      *bodyAsString  = [[NSString alloc] initWithData:[urlRequest ANHTTPStubs_HTTPBody] encoding:NSUTF8StringEncoding];
    NSData        *objectData    = [bodyAsString dataUsingEncoding:NSUTF8StringEncoding];
    NSError       *error         = nil;

    NSDictionary  *json          = [NSJSONSerialization JSONObjectWithData: objectData
                                                                   options: NSJSONReadingMutableContainers
                                                                     error: &error];
    if (error)  { return nil; }

    return  json;
}


@end
