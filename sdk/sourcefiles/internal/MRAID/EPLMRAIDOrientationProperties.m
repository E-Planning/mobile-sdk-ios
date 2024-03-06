/*   Copyright 2014 APPNEXUS INC
 
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

#import "EPLMRAIDOrientationProperties.h"

@implementation EPLMRAIDOrientationProperties

+ (EPLMRAIDOrientationProperties *)orientationPropertiesFromQueryComponents:(NSDictionary *)queryComponents {
    NSString *allowOrientationChangeString = queryComponents[@"allow_orientation_change"];
    BOOL allowOrientationChange;
    if (allowOrientationChangeString) {
        allowOrientationChange = [allowOrientationChangeString boolValue];
    } else {
        allowOrientationChange = YES;
    }
    
    NSString *forceOrientationString = queryComponents[@"force_orientation"];
    EPLMRAIDOrientation forceOrientation = [EPLMRAIDUtil orientationFromForceOrientationString:forceOrientationString];
    return [[EPLMRAIDOrientationProperties alloc] initWithAllowOrientationChange:allowOrientationChange
                                                               forceOrientation:forceOrientation];
}

- (instancetype)initWithAllowOrientationChange:(BOOL)allowOrientationChange
                              forceOrientation:(EPLMRAIDOrientation)forceOrientation {
    if (self = [super init]) {
        _allowOrientationChange = allowOrientationChange;
        _forceOrientation = forceOrientation;
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"(allowOrientationChange %d, forceOrientation: %lu)", self.allowOrientationChange, (long unsigned)self.forceOrientation];
}

@end
