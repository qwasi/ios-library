//
//  QwasiClient.m
//  Pods
//
//  Created by Robert Rodriguez on 6/2/15.
//
//

#import "QwasiClient.h"
#import "CocoaLumberjack.h"

@implementation QwasiClient
+ (instancetype)default {
    static dispatch_once_t once;
    static id sharedInstance = nil;
    
    dispatch_once(&once, ^{
        sharedInstance = [QwasiClient clientWithConfig: [QwasiConfig default]];
    });
    
    return sharedInstance;
}


+ (instancetype)clientWithConfig:(QwasiConfig*)config {
    return [[QwasiClient alloc] initWithConfig: config];
}

- (id)initWithConfig:(QwasiConfig*)config {
    if (self = [super initWithEndpointURL: config.url]) {
        
        [self.requestSerializer setValue: config.application forHTTPHeaderField: @"X-QWASI-APP-ID"];
        [self.requestSerializer setValue: config.key forHTTPHeaderField: @"X-QWASI-API-KEY"];
    }
    
    return self;
}

- (void)invokeMethod:(NSString *)method withParameters:(id)parameters requestId:(id)requestId success:(void (^)(AFHTTPRequestOperation *, id))success failure:(void (^)(AFHTTPRequestOperation *, NSError *))failure {
    
    DDLogVerbose(@"Invoking API method %@ with parameters %@", method, parameters);
    
    [super invokeMethod: method withParameters: parameters requestId: requestId success: success failure: failure];
}
@end
