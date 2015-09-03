//
//  QwasiClient.m
//  Pods
//
//  Created by Robert Rodriguez on 6/2/15.
//
//

#import "QwasiClient.h"
#import "CocoaLumberjack.h"

#include <sys/types.h>
#include <sys/socket.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

@implementation QwasiClient {
    NSOperationQueue* _queue;
}
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
        
        // Setup the serialized queue
        _queue = [[NSOperationQueue alloc] init];
        _queue.maxConcurrentOperationCount = 1;
        _queue.suspended = YES;
        
        __weak __typeof__(_queue) __queue = _queue;
        
        [[AFNetworkReachabilityManager sharedManager] setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
            
            switch (status) {
                case AFNetworkReachabilityStatusReachableViaWiFi:
                case AFNetworkReachabilityStatusReachableViaWWAN:
                    _queue.suspended = NO;
                    break;
                    
                case AFNetworkReachabilityStatusNotReachable:
                default:
                    _queue.suspended = YES;
                    break;
            }
        }];

        [[AFNetworkReachabilityManager sharedManager] startMonitoring];
        
        if ([AFNetworkReachabilityManager sharedManager].isReachable) {
            _queue.suspended = NO;
        }
    }
    
    return self;
}

- (BOOL)connected {
    return ([AFNetworkReachabilityManager sharedManager].reachable && (_queue.suspended == NO));
}

- (void)pushOperationWithBlock:(void (^)(void))block {
    
    @synchronized(self) {
        BOOL suspended = _queue.suspended;
        
        _queue.suspended = YES;
        
        // create a new queue
        NSOperationQueue *mutatedQueue = [[NSOperationQueue alloc] init];
        
        // add the new operation at the head
        [mutatedQueue addOperationWithBlock: block];
        
        // copy in all the preexisting operations that haven't yet started
        for(NSOperation *operation in [_queue operations]) {
            if(!operation.isExecuting) {
                [mutatedQueue addOperation: operation];
            }
        }
        
        _queue = mutatedQueue;
        
        _queue.suspended = suspended;
    }
}

- (void)invokeMethod:(NSString *)method
      withParameters:(id)parameters
               retry:(BOOL)retry
             success:(void (^)(AFHTTPRequestOperation *, id))success
             failure:(void (^)(AFHTTPRequestOperation *, NSError *))failure {
    
    [self invokeMethod: method withParameters: parameters requestId: nil retry: retry success: success failure: failure];
}

- (void)invokeMethod:(NSString *)method
      withParameters:(id)parameters
           requestId:(id)requestId
             success:(void (^)(AFHTTPRequestOperation *, id))success
             failure:(void (^)(AFHTTPRequestOperation *, NSError *))failure {
    
    [self invokeMethod: method withParameters: parameters requestId: nil retry: YES success: success failure: failure];
}

- (void)invokeMethod:(NSString *)method
      withParameters:(id)parameters
           requestId:(id)requestId
               retry:(BOOL)retry
             success:(void (^)(AFHTTPRequestOperation *, id))success
             failure:(void (^)(AFHTTPRequestOperation *, NSError *))failure {
    
    @synchronized(self) {
        if ([self connected]) {
            
            DDLogVerbose(@"Invoking API method %@ with parameters %@", method, parameters);
            
            if (!requestId) {
                requestId = [[NSUUID UUID] UUIDString];
            }
            
            [super invokeMethod: method
                 withParameters: parameters
                      requestId: requestId
                        success: success
                        failure: ^(AFHTTPRequestOperation *operation, NSError *error) {
                            
                            // check for connection specific errors and handle those gracefully
                            if ([error.domain isEqualToString: NSURLErrorDomain] && retry) {
                                _queue.suspended = YES;
                                
                                DDLogDebug(@"Failed to connect to Qwasi server, retry in 3s.");
                                
                                [self pushOperationWithBlock:^{
                                    [self invokeMethod: method withParameters: parameters requestId: requestId retry: retry success: success failure: failure];
                                }];
                                
                                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                    _queue.suspended = NO;
                                });
                            }
                            else {
                            // Forward the error
                                failure(operation, error);
                            }
            }];
        }
        else {
            [_queue addOperationWithBlock:^{
                [self invokeMethod: method withParameters: parameters requestId: requestId retry: retry success: success failure: failure];
            }];
        }
    }
}
@end
