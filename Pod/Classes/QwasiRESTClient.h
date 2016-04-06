#import "QwasiClient.h"
#import "QwasiConfig.h"

@interface QwasiRESTClient : NSObject

@property (nonatomic, strong) QwasiConfig* RESTConfig;

+ (instancetype)default;

+ (instancetype)clientWithConfig:(QwasiConfig*)config;

@end