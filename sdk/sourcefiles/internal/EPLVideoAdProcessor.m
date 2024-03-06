/*   Copyright 2017 APPNEXUS INC
 
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

#import "EPLVideoAdProcessor.h"
#import "NSDictionary+EPLCategory.h"
#import "EPLRTBVideoAd.h"
#import "EPLAdConstants.h"
#import "EPLAdResponseCode.h"

@interface EPLVideoAdProcessor()
    @property (nonatomic, readwrite, strong) id<EPLVideoAdProcessorDelegate> delegate;
    @property (nonatomic, strong)   NSString        *csmJsonContent;
    @property (nonatomic, strong)   NSString        *videoXmlContent;
    @property (nonatomic, strong)   NSString        *videoURLString;
    @property  (nonatomic, strong)  EPLVideoAdPlayer *adPlayer;
@end

@implementation EPLVideoAdProcessor

- (nonnull instancetype)initWithDelegate:(nonnull id<EPLVideoAdProcessorDelegate>)delegate withAdVideoContent:(nonnull id) videoAdContent{
    
    
    if (self = [self init]) {
        self.delegate = delegate;
        
        if([videoAdContent isKindOfClass:[EPLCSMVideoAd class]]){
        
           EPLCSMVideoAd *csmVideoAd = (EPLCSMVideoAd *)videoAdContent;
           self.csmJsonContent = [csmVideoAd.adDictionary an_jsonStringWithPrettyPrint:YES];
        
        }else if ([videoAdContent isKindOfClass:[EPLRTBVideoAd class]]){
        
            EPLRTBVideoAd *rtbVideo = (EPLRTBVideoAd *) videoAdContent;
            if(rtbVideo.content.length >0){
                self.videoXmlContent = rtbVideo.content;
            }else if(rtbVideo.content.length >0){
                self.videoURLString = rtbVideo.assetURL;
            }else{
                EPLLogError(@"RTBVideo content & url are empty");
            }
        }
        
        [self processAdVideoContent];
    }
    return self;
}

-(void) processAdVideoContent{
    
    self.adPlayer = [[EPLVideoAdPlayer alloc] init];
    if(self.adPlayer != nil){
        self.adPlayer.delegate = self;
        if(self.videoURLString){
            [self.adPlayer loadAdWithVastUrl:self.videoURLString];
        }else if(self.videoXmlContent){
            [self.adPlayer loadAdWithVastContent:self.videoXmlContent];
        }else if(self.csmJsonContent){
            [self.adPlayer loadAdWithJSONContent:self.csmJsonContent];
        }else {
            EPLLogError(@"no csm or rtb object content available to process");
        }
    } else {
        EPLLogError(@"AdPlayer creation failed");
    }
    
}


#pragma mark EPLVideoAdPlayerDelegate methods

-(void) videoAdReady {
    
    [self.adPlayer setDelegate:nil];
    
    if([self.delegate respondsToSelector:@selector(videoAdProcessor:didFinishVideoProcessing:)]){
        [self.delegate videoAdProcessor:self didFinishVideoProcessing:self.adPlayer];
    }else {
        EPLLogError(@"no delegate subscription found");
    }
    
    
}
-(void) videoAdLoadFailed:(nonnull NSError *)error withAdResponseInfo:(nullable EPLAdResponseInfo *)adResponseInfo
{
    [self.adPlayer setDelegate:nil];
    
    if([self.delegate respondsToSelector:@selector(videoAdProcessor:didFailVideoProcessing:)]){
        NSError *error = EPLError(@"Error parsing video tag", EPLAdResponseCode.INTERNAL_ERROR.code);
        [self.delegate videoAdProcessor:self didFailVideoProcessing:error];
    }else {
        EPLLogError(@"no delegate subscription found");
    }
    
}



@end
