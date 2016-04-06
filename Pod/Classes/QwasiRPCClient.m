//
// QwasiRPCClient.m
//
// Copyright (c) 2015-2016, Qwasi Inc (http://www.qwasi.com/)
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//    * Redistributions of source code must retain the above copyright
//      notice, this list of conditions and the following disclaimer.
//    * Redistributions in binary form must reproduce the above copyright
//      notice, this list of conditions and the following disclaimer in the
//      documentation and/or other materials provided with the distribution.
//    * Neither the name of Qwasi nor the
//      names of its contributors may be used to endorse or promote products
//      derived from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
// ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL QWASI BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
// ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#import "QwasiRPCClient.h"

#include <sys/types.h>
#include <sys/socket.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

@implementation QwasiRPCClient {
    NSOperationQueue* _queue;
}
+ (instancetype)default {
    static dispatch_once_t once;
    static id sharedInstance = nil;
    
    dispatch_once(&once, ^{
        sharedInstance = [QwasiRPCClient clientWithConfig: [QwasiConfig default]];
    });
    
    return sharedInstance;
}

+ (instancetype)clientWithConfig:(QwasiConfig*)config {
    return [[QwasiRPCClient alloc] initWithConfig: config];
}

- (id)initWithConfig:(QwasiConfig*)config {
    if (self = [super initWithEndpointURL: config.url]) {
        
        [self.requestSerializer setValue: config.application forHTTPHeaderField: @"X-QWASI-APP-ID"];
        [self.requestSerializer setValue: config.key forHTTPHeaderField: @"X-QWASI-API-KEY"];
        [self.requestSerializer setValue: @"2.1.0" forHTTPHeaderField: @"Accept-Version"];
        
        // Setup the serialized queue
        _queue = [[NSOperationQueue alloc] init];
        _queue.maxConcurrentOperationCount = 1;
        _queue.suspended = YES;
        
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
            
            NSLog(@"Invoking API method %@ with parameters %@", method, parameters);
            
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
                                
                                NSLog(@"Failed to connect to Qwasi server, retry in 3s.");
                                
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
