//
//  Qwasi.m
//  Pods
//
//  Created by Robert Rodriguez on 6/2/15.
//
//

#import "Qwasi.h"
#import "QwasiClient.h"
#import "CocoaLumberjack.h"
#import "GBDeviceInfo.h"

#import "NSObject+STSwizzle.h"

typedef void (^fetchCompletionHander)(UIBackgroundFetchResult result);

@implementation Qwasi {
    QwasiClient* _client;
}

+ (instancetype)shared {
    static dispatch_once_t once;
    static id sharedInstance = nil;
    
    dispatch_once(&once, ^{
        sharedInstance = [Qwasi qwasiWithConfig: [QwasiConfig default]];
    });
    
    return sharedInstance;
}

+ (instancetype)qwasiWithConfig:(QwasiConfig*)config {
    return [[Qwasi alloc] initWithConfig: config];
}

- (id)initWithConfig:(QwasiConfig*)config {
    if (self = [super init]) {
        
        _registered = NO;
        
        _client = [QwasiClient clientWithConfig: config];
    }
    return self;
}

- (void)setConfig:(QwasiConfig *)config {
    _client = [QwasiClient clientWithConfig: config];
    _registered = NO;
}

- (void)registerDevice:(NSString*)deviceToken
              withName: (NSString*)name
         withUserToken:(NSString*)userToken
               success:(void(^)(NSString* deviceToken))success
               failure:(void(^)(NSError* err))failure {
    
    // An empty device token tells the server to generate a new one for this device
    if (deviceToken == nil) {
        deviceToken = @"";
    }
    
    if (name == nil) {
        name = [UIDevice currentDevice].name;
    }
    
    if (userToken == nil) {
        userToken = @"";
    }

    NSDictionary* info = @{
#if DEBUG
                           @"debug": [NSNumber numberWithBool: YES],
#else   
                           @"debug": [NSNumber numberWithBool: NO],
#endif
                           @"version": [UIDevice currentDevice].systemVersion,
                           @"system": [UIDevice currentDevice].systemName,
                           @"model": [GBDeviceInfo deviceInfo].modelString,
                           @"sdkVersion": @"2.1.0" 
                           };
    
    [_client invokeMethod: @"device.register"
           withParameters: @{ @"id": deviceToken,
                              @"name": name,
                              @"user_token": userToken,
                              @"info": info }
     
                  success: ^(AFHTTPRequestOperation *operation, id responseObject) {
              
                      _registered = YES;
                      
                      _deviceToken = [responseObject valueForKey: @"id"];
                      
                      if (success) {
                          success(_deviceToken);
                      }
                      
                      DDLogInfo(@"Device %@ registered successfully.", _deviceToken);
                    
                }
                  failure: ^(AFHTTPRequestOperation *operation, NSError *error) {
                      if (failure) {
                          failure(error);
                      }
                      
                      DDLogError(@"Device registration failed %@.", error);
                }];
}

- (void)registerForNotifications:(void(^)(NSString* pushToken))success
                         failure:(void(^)(NSError* err))failure {
    if (_registered) {
        UIApplication* application = [UIApplication sharedApplication];
        NSObject* appDelegate = application.delegate;
 
        [appDelegate replaceMethodForSelector: @selector(application:didRegisterForRemoteNotificationsWithDeviceToken:) orAddWithTypes:"v@:@@" implementation:^(id _self, UIApplication* _unused, NSData* token) {
            const unsigned *tokenBytes = [token bytes];
            
            _pushToken = [NSString stringWithFormat:@"%08x%08x%08x%08x%08x%08x%08x%08x",
                                   ntohl(tokenBytes[0]), ntohl(tokenBytes[1]), ntohl(tokenBytes[2]),
                                   ntohl(tokenBytes[3]), ntohl(tokenBytes[4]), ntohl(tokenBytes[5]),
                                   ntohl(tokenBytes[6]), ntohl(tokenBytes[7])];
            
            [_client invokeMethod: @"device.set_push_token"
                   withParameters: @{ @"id": _deviceToken,
                                      @"proto": @"push.apns",
                                      @"token": _pushToken }
                          success:^(AFHTTPRequestOperation *operation, id responseObject) {
                              if (success) success(_pushToken);
                              
                              DDLogInfo(@"Push token %@ registration successful.", _pushToken);
                              
                          } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                              
                              if (failure) failure(error);
                              
                              DDLogError(@"Push registration failed: %@.", error);
                          }];
        }];
        
        [appDelegate replaceMethodForSelector: @selector(application:didFailToRegisterForRemoteNotificationsWithError:) orAddWithTypes:"v@:@@" implementation:^(id _self, UIApplication* _unused, NSError* error) {
            
            DDLogError(@"Push registration failed: %@.", error);
            
            if (failure) {
                failure(error);
            }
        }];
        
        [appDelegate replaceMethodForSelector: @selector(application:didReceiveRemoteNotification:fetchCompletionHandler:)
                               orAddWithTypes:"v@:@@@"
                               implementation: ^(id _self, UIApplication* _unused, NSDictionary* userInfo, fetchCompletionHander completionHandler)
         {
             [self fetchMessageForNotification: userInfo success:^(QwasiMessage *message) {
                 
                 [self emit: @"message", message];
                 
                 if (completionHandler) completionHandler(UIBackgroundFetchResultNewData);
                 
             } failure:^(NSError *err) {
                 
                 if (err.code == E_QWASI_INVALID_MESSAGE) {
                     [_self callOnSuper:^{
                         if ([_self respondsToSelector:@selector(application:didReceiveRemoteNotification:fetchCompletionHandler:)]) {
                             [_self application: application didReceiveRemoteNotification: userInfo fetchCompletionHandler: completionHandler];
                         }
                         else if (completionHandler) {
                             completionHandler(UIBackgroundFetchResultNoData);
                         }
                     }];
                 }
                 else if (completionHandler) {
                     completionHandler(UIBackgroundFetchResultFailed);
                 }
             }];
         }];
        
        [appDelegate replaceMethodForSelector: @selector(application:performFetchWithCompletionHandler:)
                               orAddWithTypes: "v@:@@"
                               implementation: ^(id _self, UIApplication* application, fetchCompletionHander completionHandler)
        {
            [self fetchUnreadMessage:^(QwasiMessage *message) {
                [self emit: @"message", message];
                
                [_self callOnSuper:^{
                    if ([_self respondsToSelector:@selector(application:performFetchWithCompletionHandler:)]) {
                        [_self application: application performFetchWithCompletionHandler: completionHandler];
                    }
                    else if (completionHandler) {
                        completionHandler(UIBackgroundFetchResultNewData);
                    }
                }];
            } failure:^(NSError *err) {
                NSData* errData = err.userInfo[@"com.alamofire.serialization.response.error.data"];
                NSDictionary* jsonError = nil;
                
                if (errData) {
                    NSError* parseError;
                    jsonError = [NSJSONSerialization JSONObjectWithData: errData options: kNilOptions error: &parseError];
                    
                    if (parseError) {
                        DDLogError(@"Failed to parse server error response: %@", parseError);
                    }
                }
                
                if (!jsonError || [[jsonError valueForKeyPath:@"error.code"] integerValue] != 404) {
                    DDLogError(@"Unexpected server error: %@", jsonError);
                }
                
                [_self callOnSuper:^{
                    if ([_self respondsToSelector:@selector(application:performFetchWithCompletionHandler:)]) {
                        [_self application: application performFetchWithCompletionHandler: completionHandler];
                    }
                    else if (completionHandler) {
                        completionHandler(UIBackgroundFetchResultFailed);
                    }
                }];
            }];
        }];
        
        if ([application respondsToSelector: @selector(registerUserNotificationSettings:)]) {
            // ios 8+
            [application registerUserNotificationSettings: [UIUserNotificationSettings settingsForTypes: UIUserNotificationTypeAlert categories: nil]];
            [application registerForRemoteNotifications];
        }
        else {
            // ios 7.1+
            [application registerForRemoteNotificationTypes: UIRemoteNotificationTypeAlert];
        }
        
    }
    else if (failure) {
        failure([NSError errorWithDomain: @"com.qwasi"
                                    code: E_QWASI_DEVICE_NOT_REGISTERED
                                userInfo: @{ NSLocalizedDescriptionKey: @"Device not registered." }]);
    }
}

- (void)fetchMessageForNotification:(NSDictionary*)userInfo
                            success:(void(^)(QwasiMessage* message))success
                            failure:(void(^)(NSError* err))failure {
    
    if (_registered) {
        
        NSDictionary* flags = @{ @"opened": [NSNumber numberWithBool: [UIApplication sharedApplication].applicationState == UIApplicationStateInactive] };
        NSDictionary* qwasi = userInfo[@"qwasi"];
        NSString* msgId = qwasi[@"m"];
        
        if (msgId) {
            [_client invokeMethod: @"message.fetch"
                   withParameters: @{ @"device": _deviceToken,
                                      @"id": msgId,
                                      @"flags": flags }
                          success:^(AFHTTPRequestOperation *operation, id responseObject) {
                              
                              if (success) success([QwasiMessage messageWithData: responseObject]);
                                                   
                          } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                              if (failure) failure(error);
                          }];
        }
        else if (failure) {
            failure([NSError errorWithDomain: @"com.qwasi"
                                        code: E_QWASI_INVALID_MESSAGE
                                    userInfo: @{ NSLocalizedDescriptionKey: @"Notification does not contain a valid Qwasi message id" }]);

        }
    }
    else if (failure) {
        failure([NSError errorWithDomain: @"com.qwasi"
                                    code: E_QWASI_DEVICE_NOT_REGISTERED
                                userInfo: @{ NSLocalizedDescriptionKey: @"Device not registered." }]);
    }
    
}

- (void)fetchUnreadMessage:(void(^)(QwasiMessage* message))success
                   failure:(void(^)(NSError* err))failure {
    if (_registered) {
        
        [_client invokeMethod: @"message.poll"
               withParameters: @{ @"device": _deviceToken,
                                  @"options": @{ @"fetch": [NSNumber numberWithBool: YES] } }
                      success:^(AFHTTPRequestOperation *operation, id responseObject) {
                          
                          if (success) success([QwasiMessage messageWithData: responseObject]);
                          
                      } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                          if (failure) failure(error);
                      }];

    }
    else if (failure) {
        failure([NSError errorWithDomain: @"com.qwasi"
                                    code: E_QWASI_DEVICE_NOT_REGISTERED
                                userInfo: @{ NSLocalizedDescriptionKey: @"Device not registered." }]);
    }

}
@end
