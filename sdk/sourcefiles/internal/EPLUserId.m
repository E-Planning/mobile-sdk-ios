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

#import "EPLUserId.h"

@implementation EPLUserId

@synthesize  source                            = __source;
@synthesize  userId                            = __userId;

- (nullable instancetype)initWithANUserIdSource:(EPLUserIdSource)source userId:(NSString *)userId{
    self = [super init];
    
    if (self != nil) {
        
        switch(source){
            case EPLUserIdSourceCriteo:
                self.source = @"criteo.com";
                break;
            case EPLUserIdSourceUID2:
                self.source =  @"uidapi.com";
                break;
            case EPLUserIdSourceNetId:
                self.source = @"netid.de";
                break;
            case EPLUserIdSourceLiveRamp:
                self.source = @"liveramp.com";
                break;
            case EPLUserIdSourceTheTradeDesk:
                self.source = @"adserver.org";
                break;
        }
        self.userId = userId;
    }
    
    return self;
}

- (nullable instancetype)initWithStringSource:(nonnull NSString *)source userId:(nonnull NSString *)userId isFirstParytId:(BOOL)firstParytId{
    self = [super init];
    
    if (self != nil) {
        self.source = source;
        self.userId = userId;
        self.isFirstParytId = firstParytId;
    }
    
    return self;
}

@end

