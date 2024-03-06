/*   Copyright 2020 APPNEXUS INC
 
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

#import <Foundation/Foundation.h>
#import <TrackerApp-Swift.h>
#import "BannerNativeAdViewabilityTrackerTestVC.h"
#import <AppNexusSDK/AppNexusSDK.h>
#import "ANStubManager.h"
#import "ANNativeAdView.h"
#import "SDKValidationURLProtocol.h"
#import "NSURLRequest+HTTPBodyTesting.h"
#import "ANNativeAdResponse+PrivateMethods.h"
#import "Constant.h"
#import "ANHTTPStubbingManager.h"

@interface BannerNativeAdViewabilityTrackerTestVC () <ANBannerAdViewDelegate,ANNativeAdDelegate,SDKValidationURLProtocolDelegate,ANNativeAdResponseProtocol,ANNativeAdRequestDelegate>{
    BOOL isAdVisible;
}

@property (weak, nonatomic) IBOutlet UIView *adView;

@property (nonatomic, readwrite, strong) ANBannerAdView *banner;
@property (nonatomic,readwrite,strong) ANNativeAdResponse *nativeAdResponse;
@property (nonatomic,readwrite,strong) ANNativeAdRequest *nativeAdRequest;
@property (weak, nonatomic) ANNativeAdView *nativeAdView;
// TableView is used to list all the events fired and stored in Array eventList
@property (weak, nonatomic) IBOutlet UITableView *tableView;
// To Store list of tracker URL fired by the SDK
@property (strong, nonatomic) NSMutableArray *eventList;
// Used to store the list of argument passed  by UI test ([NSProcessInfo processInfo].arguments)
@property (strong, nonatomic) NSArray *uiTestList;

@end

@implementation BannerNativeAdViewabilityTrackerTestVC

- (void)viewDidLoad
{
    
    [super viewDidLoad];
    
}
- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:true];
    
    // store the list of argument passed  by UI test by UI Test
    self.uiTestList = [NSProcessInfo processInfo].arguments;
    //  MockTestcase is enabled(set to 1) prepare stubbing with mock response else disable stubbing
    if(MockTestcase){
        [self prepareStubbing];
    }   else {
        [[ANHTTPStubbingManager sharedStubbingManager] disable];
        [[ANHTTPStubbingManager sharedStubbingManager] removeAllStubs];
        [[ANStubManager sharedInstance] enableStubbing];
        [[ANStubManager sharedInstance] disableStubbing];
    }
    //  registerEventListener is used to register for tracking the URL fired by Application(or SDK)
   [self registerEventListener];

    int adWidth  = 300;
    int adHeight = 250;
    isAdVisible = true;
    
    // We want to center our ad on the screen.
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    CGFloat originX = (screenRect.size.width / 2) - (adWidth / 2);
    CGFloat originY = (screenRect.size.height / 2) - (adHeight / 2);
    
    // Needed for when we create our ad view.
    CGRect rect = CGRectMake(originX, originY, adWidth, adHeight);
    CGSize size = CGSizeMake(adWidth, adHeight);
    
    
    if( [self.uiTestList containsObject:@"EnableOMIDOptimization"]){
        ANSDKSettings.sharedInstance.enableOMIDOptimization = true;
    }else{
        ANSDKSettings.sharedInstance.enableOMIDOptimization = false;
    }
    
    
    
    // Prepair a banner Native ad view.
    if( [self.uiTestList containsObject:BannerNativeViewabilityTrackerTest] ||  [self.uiTestList containsObject:BannerNativeRendererViewabilityTrackerTest] ){
        
        self.banner = [ANBannerAdView adViewWithFrame:rect placementId:BannerPlacementId adSize:size];
        self.banner.rootViewController = self;
        self.banner.shouldAllowNativeDemand = YES;
        self.banner.enableNativeRendering = YES;
        self.banner.shouldAllowVideoDemand = NO;
        self.banner.delegate = self;
        self.banner.clickThroughAction = ANClickThroughActionOpenSDKBrowser;
        self.banner.accessibilityIdentifier = @"bannerAdElements";
        [self.adView addSubview:self.banner];
        self.banner.shouldServePublicServiceAnnouncements = NO;
        self.banner.autoRefreshInterval = 0;
        // Set Creative Id if ForceCreative is enabled
        if(ForceCreative){
            self.banner.forceCreativeId = BannerForceCreativeId;
        }
        [self.banner loadAd];
    }
    // Prepair a Native ad view.
    else if([self.uiTestList containsObject:NativeViewabilityTrackerTest] ){
        self.nativeAdRequest= [[ANNativeAdRequest alloc] init];
        self.nativeAdRequest.placementId = NativePlacementId;
        self.nativeAdRequest.gender = ANGenderMale;
        self.nativeAdRequest.shouldLoadIconImage = YES;
        self.nativeAdRequest.shouldLoadMainImage = YES;
        // Set Creative Id if ForceCreative is enabled
        if(ForceCreative){
            self.nativeAdRequest.forceCreativeId = NativeForceCreativeId;
        }
        self.nativeAdRequest.delegate = self;
        [self.nativeAdRequest loadAd];
    }
   
    
    [SDKValidationURLProtocol setDelegate:self];
    [NSURLProtocol registerClass:[SDKValidationURLProtocol class]];
   
    self.eventList = [[NSMutableArray alloc] init];
    self.tableView.hidden = YES;
    
    
}
//  registerEventListener is used to register for tracking the URL fired by Application(or SDK)
-(void)registerEventListener{
    [NSURLProtocol registerClass:[WebKitURLProtocol class]];
    [NSURLProtocol wk_registerWithScheme:@"https"];
    [NSURLProtocol wk_registerWithScheme:@"http"];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateNetworkLog:)
                                                 name:@"didReceiveURLResponse"
                                               object:nil];
}
//  prepareStubbing if MockTestcase is enabled(set to 1) prepare stubbing with mock response else disable stubbing
-(void)prepareStubbing{
    

    self.title = self.adType;
    [[ANStubManager sharedInstance] disableStubbing];
    [[ANStubManager sharedInstance] enableStubbing];
    
    if(  [self.uiTestList containsObject:BannerNativeRendererViewabilityTrackerTest] ){
        [[ANStubManager sharedInstance] stubRequestWithResponse:@"RTBBannerNativeRendererAd"];
    }else{
        [[ANStubManager sharedInstance] stubRequestWithResponse:@"RTBBannerNativeAd"];
    }
}

- (void)adDidReceiveAd:(id)ad {
    NSLog(@"Ad did receive ad");
    
    // To Hide add after 2 second so that we can track the Viewablity zero
    [NSTimer scheduledTimerWithTimeInterval:2.0
                                     target:self
                                   selector:@selector(hideShowAdAction)
                                   userInfo:nil
                                    repeats:NO];
}

// To Hide/Show add after 2 second so that we can track the Viewablity 0% & 100%
-(void) hideShowAdAction {
    
    if( [self.uiTestList containsObject:BannerNativeViewabilityTrackerTest] ||  [self.uiTestList containsObject:NativeViewabilityTrackerTest] ){
        if(isAdVisible){
            self.nativeAdView.hidden = true;
            [NSTimer scheduledTimerWithTimeInterval:2.0
                                             target:self
                                           selector:@selector(hideShowAdAction)
                                           userInfo:nil
                                            repeats:NO];
        }else{
            self.nativeAdView.hidden = false;
            [NSTimer scheduledTimerWithTimeInterval:8.0
                                             target:self
                                           selector:@selector(removeBannerNativeAdAction)
                                           userInfo:nil
                                            repeats:NO];
        }
    }else if ( [self.uiTestList containsObject:BannerNativeRendererViewabilityTrackerTest]){
        if(isAdVisible){
            self.banner.hidden = true;
            [NSTimer scheduledTimerWithTimeInterval:2.0
                                             target:self
                                           selector:@selector(hideShowAdAction)
                                           userInfo:nil
                                            repeats:NO];
        }else{
            self.banner.hidden = false;
            [NSTimer scheduledTimerWithTimeInterval:8.0
                                             target:self
                                           selector:@selector(removeBannerNativeAdAction)
                                           userInfo:nil
                                            repeats:NO];
        }
    }
    
    isAdVisible = !isAdVisible;
}

// Remove BannerNative and Native add to call session finish
- (void)removeBannerNativeAdAction {
    
    
    if( [self.uiTestList containsObject:BannerNativeViewabilityTrackerTest] ||  [self.uiTestList containsObject:NativeViewabilityTrackerTest] ){
        
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.nativeAdView.hidden  = YES;
            self.adView.hidden = YES;
            [self.nativeAdView removeFromSuperview];
        });
        
        [self.nativeAdResponse unregisterViewFromTracking];
        self.nativeAdResponse.delegate = nil;
        self.nativeAdResponse = nil;
        self.nativeAdRequest.delegate = nil;
        self.nativeAdRequest = nil;
        
        self.nativeAdView = nil;
    }else if ( [self.uiTestList containsObject:BannerNativeRendererViewabilityTrackerTest]){
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [self.banner removeFromSuperview];
            self.banner = nil;
            });
        
    }
    
    double delayInSeconds = 2.0;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        self.tableView.hidden = NO;
        [self.tableView reloadData];
    });
    
    
}


-(void)ad:(id)ad requestFailedWithError:(NSError *)error{
    NSLog(@"Ad request Failed With Error");
}

- (void)adRequest:(ANNativeAdRequest *)request didReceiveResponse:(ANNativeAdResponse *)response {
    self.nativeAdResponse = response;
    [self renderNativeAdResponse];
}
- (void)ad:(id)loadInstance didReceiveNativeAd:(id)responseInstance{
    self.nativeAdResponse = (ANNativeAdResponse *)responseInstance;
    [self renderNativeAdResponse];
    
}

// renderNative AdResponse
-(void)renderNativeAdResponse{
    
    UINib *adNib = [UINib nibWithNibName:@"ANNativeAdView" bundle:[NSBundle mainBundle]];
    NSArray *array = [adNib instantiateWithOwner:self options:nil];
    self.nativeAdView = [array firstObject];
    self.nativeAdView.titleLabel.text = self.nativeAdResponse.title;
    self.nativeAdView.bodyLabel.text = self.nativeAdResponse.body;
    self.nativeAdView.iconImageView.image = self.nativeAdResponse.iconImage;
    self.nativeAdView.mainImageView.image = self.nativeAdResponse.mainImage;
    self.nativeAdView.sponsoredLabel.text = self.nativeAdResponse.sponsoredBy;
    
    [self.nativeAdView.callToActionButton setTitle:self.nativeAdResponse.callToAction forState:UIControlStateNormal];
    self.nativeAdResponse.delegate = self;
    self.nativeAdResponse.clickThroughAction = ANClickThroughActionOpenSDKBrowser;
    
    [self.adView addSubview:self.nativeAdView];
    
    [self.nativeAdResponse registerViewForTracking:self.nativeAdView
                            withRootViewController:self
                                    clickableViews:@[self.nativeAdView.callToActionButton,self.nativeAdView.mainImageView]
                                             error:nil];
    
    if(ANSDKSettings.sharedInstance.enableOMIDOptimization){
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (5 * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void) {
         
            _nativeAdView.frame = CGRectMake(-600, -600, _nativeAdView.frame.size.width, _nativeAdView.frame.size.height);
            
        });
    }
    else{
        [NSTimer scheduledTimerWithTimeInterval:2.0
                                         target:self
                                       selector:@selector(hideShowAdAction)
                                       userInfo:nil
                                        repeats:NO];
    }

}

- (void)adRequest:(nonnull ANNativeAdRequest *)request didFailToLoadWithError:(nonnull NSError *)error withAdResponseInfo:(nullable ANAdResponseInfo *)adResponseInfo {
    NSLog(@"Ad request Failed With Error");
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


# pragma mark - Ad Server Response Stubbing
// updateNetworkLog: Will return event in fire of URL from Application(or SDK)
- (void) updateNetworkLog:(NSNotification *) notification
{
    NSDictionary *userInfo = notification.userInfo;
    NSURLResponse *response = [userInfo objectForKey:@"response"];
    NSString *absoluteURLText = [response.URL.absoluteURL absoluteString];
    NSLog(@"absoluteURLText -> %@",absoluteURLText);
    
}

# pragma mark - Intercept HTTP Request Callback
// didReceiveIABResponse : Will record and return the events fire by SDK
- (void)didReceiveIABResponse:(NSString *)response {
    NSLog(@"OMID response %@",response);
    
    if([response containsString:@"OmidSupported%5Btrue%5D%22"]){
        if([self.uiTestList containsObject:@"OmidSupported"]){
            [self.eventList addObject:@"OmidSupported=true"];
        }
        
        
    }else if([response containsString:@"sessionStart"]){
        if([self.uiTestList containsObject:@"SessionStart"]){
            [self.eventList addObject:@"sessionStart"];
            if([response containsString:@"limited"]){
                //accessMode%22%3A%22
                [self.eventList addObject:@"accessMode=limited"];
            }
            if([response containsString:@"mediaType"]){
                //%22%3A%22display
                [self.eventList addObject:@"mediaType=display"];
            }
//            partnerName%22%3A%22Appnexus
            if([response containsString:@"Appnexus"]){
                [self.eventList addObject:@"partnerName=Appnexus"];
            }
            //creativeType%22%3A%22nativeDisplay
            if([response containsString:@"nativeDisplay"]){
                [self.eventList addObject:@"creativeType=nativeDisplay"];
            }
 
        }
    }
    
//    else if ([response containsString:@"type%22%3A%22loaded%22%2C%22data%22%3A%7B%22impressionType%22%3A%22viewable%22%2C%22mediaType%22%3A%22display%22%2C%22creativeType%22%3A%22nativeDisplay%22%7D%7D"]){
        else if ([response containsString:@"viewable"]){
        if([self.uiTestList containsObject:@"TypeLoaded"]){
            [self.eventList addObject:@"type=loaded"];
            [self.eventList addObject:@"impressionType=viewable"];
            [self.eventList addObject:@"mediaType=display"];
            [self.eventList addObject:@"creativeType=nativeDisplay"];
        }
        
    }
    else if([response containsString:@"percentageInView%22%3A0"]){
        
        if([self.uiTestList containsObject:@"OmidPercentageInView0"]){
            
            [self.eventList addObject:@"percentageInView=0"];
        }
    }
    
    
    else if([response containsString:@"percentageInView%22%3A1"] || [response containsString:@"percentageInView%22%3A2"] || [response containsString:@"percentageInView%22%3A3"] || [response containsString:@"percentageInView%22%3A4"] ||[response containsString:@"percentageInView%22%3A5"] || [response containsString:@"percentageInView%22%3A6"] || [response containsString:@"percentageInView%22%3A7"] ||[response containsString:@"percentageInView%22%3A8"] || [response containsString:@"percentageInView%22%3A9"]){
        if([self.uiTestList containsObject:@"OmidPercentageInView100"]){
            [self.eventList addObject:@"percentageInView=MoreThan0"];
        }
    }
    
    
    else if([response containsString:@"type%22%3A%22sessionFinish%22%7D"]){
        if(ANSDKSettings.sharedInstance.enableOMIDOptimization && [self.uiTestList containsObject:@"SessionFinish"]){
            [self.eventList addObject:@"EnableOMIDOptimization"];
            [self.eventList addObject:@"type=sessionFinish"];
            self.tableView.hidden = NO;
            [self.tableView reloadData];
        }
        if([self.uiTestList containsObject:@"SessionFinish"]){
            [self.eventList addObject:@"type=sessionFinish"];
        }
    }
    
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.eventList.count;
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier  forIndexPath:indexPath] ;
    NSString *value = [self.eventList objectAtIndex:indexPath.row];
    cell.textLabel.text = value;
    return cell;
}
@end
