/*   Copyright 2019 APPNEXUS INC

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

#import <XCTest/XCTest.h>
#import "ANUSPrivacySettings.h"

@interface ANUSPrivacySettingsTestCase : XCTestCase

@end

@implementation ANUSPrivacySettingsTestCase

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testUSPrivacyStringNotExist {
    //given
    [ANUSPrivacySettings reset];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"IABUSPrivacy_String"];
    //when
    NSString *privacyString = [ANUSPrivacySettings getUSPrivacyString];
    //then
    XCTAssertEqual(0,privacyString.length);
}

- (void)testUSPrivacyStringExist {
    //given
    [ANUSPrivacySettings setUSPrivacyString:@"1yn"];
    //when
    NSString *privacyString = [ANUSPrivacySettings getUSPrivacyString];
    //then
    XCTAssertNotEqual(0,privacyString.length);
    XCTAssertEqual(@"1yn", privacyString);
}

- (void)testUSPrivacyStringEmpty {
    //given
    [ANUSPrivacySettings setUSPrivacyString:@""];
    //when
    NSString *privacyString = [ANUSPrivacySettings getUSPrivacyString];
    //then
    XCTAssertEqual(0,privacyString.length);
    XCTAssertEqual(@"", privacyString);
}

- (void)testIABUSPrivacyStringExist {
    //given
    [ANUSPrivacySettings reset];
    [[NSUserDefaults standardUserDefaults] setObject:@"1yn" forKey:@"IABUSPrivacy_String"];
    //when
    NSString *privacyString = [ANUSPrivacySettings getUSPrivacyString];
    //then
    XCTAssertNotEqual(0,privacyString.length);
    XCTAssertEqual(@"1yn", privacyString);
}

@end
