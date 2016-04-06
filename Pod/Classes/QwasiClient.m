#include "QwasiClient.h"

@implementation QwasiClient

@synthesize restClient = _restClient;
@synthesize rpcClient = _rpcClient;

+ (instancetype)default{
    
    //get if our version is RESTful
    NSString* vString = [SHORT_VERSION stringByReplaceingOccurencesOfString@".%i.%i"
                                       withString:@""];
    
    NSInteger rawVersion = [vString integerValue];
    
    //repair this later
    if( rawVersion < 3){
        [self setRestful:NO];
        rpcClient = [[QwasiRPCClient alloc] default];
        restClient = nil;
    }
    else{
        [self setRestful:YES];
        restClient = [[QwasiRESTClient alloc] default];
        rpcClient = nil;
    }
    
    return self;
}

+ (instancetype)clientWithConfig:(QwasiConfig*)config{
    //get if our version is RESTful
    NSString* vString = [SHORT_VERSION stringByReplaceingOccurencesOfString@".%i.%i"
                         withString:@""];
    
    NSInteger rawVersion = [vString integerValue];
    
    if( rawVersion < 3){
        [self setRestful:NO];
        rpcClient = [QwasiRPCClient clientWithConfig: [QwasiConfig default]];
    }
    else {
        [self setRestful:YES];
        restClient = [QwasiRESTClient clientWithConfig: [QwasiConfig default]];
    }
    
    return self;
}

- (void)invokeMethod:(NSString *)method
      withParameters:(id)parameters
               retry:(BOOL)retry
             success:(void (^)(AFHTTPRequestOperation *, id))success
             failure:(void (^)(AFHTTPRequestOperation *, NSError *))failure{
    
    if( isRestful ){
        [restClient caseMethod: method withParameters: parameters];
    }
    else{
        [rpcClient caseMethod: method withParameters: parameters retry: retry];
    }
    
}

@end