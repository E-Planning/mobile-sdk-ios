#import "EPLCarrierObserver.h"
#import <CoreTelephony/CTCarrier.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>

@interface EPLCarrierObserver()
@property (nonatomic, strong) CTTelephonyNetworkInfo *networkInfo;
@end

@interface EPLCarrierMeta()
@property (nonatomic, copy, readwrite) NSString *name;
@property (nonatomic, copy, readwrite) NSString *countryCode;
@property (nonatomic, copy, readwrite) NSString *networkCode;

- (instancetype)initWith:(NSString *)name
             countryCode:(NSString *)countryCode
             networkCode:(NSString *)networkCode;

+ (instancetype)makeWithCarrier:(CTCarrier *)carrier;
@end

@implementation EPLCarrierMeta
- (instancetype)initWith:(NSString *)name
             countryCode:(NSString *)countryCode
             networkCode:(NSString *)networkCode;
{
    if (self = [super init]) {
        self.name = name;
        self.countryCode = countryCode;
        self.networkCode = networkCode;
    }
    return self;
}

+ (instancetype)makeWithCarrier:(CTCarrier *)carrier {
    return [[EPLCarrierMeta alloc] initWith:carrier.carrierName
                               countryCode:carrier.mobileCountryCode
                               networkCode:carrier.mobileNetworkCode];
}
@end

@implementation EPLCarrierObserver
+ (instancetype)shared {
    static EPLCarrierObserver *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[EPLCarrierObserver alloc] init];
    });
    return sharedInstance;
}

- (EPLCarrierMeta *)carrierMeta
{
    CTCarrier *carrier = [self.networkInfo subscriberCellularProvider];
    return [EPLCarrierMeta makeWithCarrier:carrier];
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.networkInfo = [CTTelephonyNetworkInfo new];
    }
    return self;
}
@end
