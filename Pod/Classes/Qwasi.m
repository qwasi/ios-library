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

#define LOCATION_EVENT_FILTER 50.0f
#define LOCATION_UPDATE_FILTER 10.0f
#define LOCATION_SYNC_FILTER 100.0f

NSString* const kEventApplicationState = @"com.qwasi.event.application.state";
NSString* const kEventLocationUpdate = @"com.qwasi.event.location.update";
NSString* const kEventLocationEnter = @"com.qwasi.event.location.enter";
NSString* const kEventLocationExit = @"com.qwasi.event.location.exit";

typedef void (^fetchCompletionHander)(UIBackgroundFetchResult result);

@implementation Qwasi {
    CLLocation* _lastLocationEvent;
    CLLocation* _lastLocationUpdate;
    CLLocation* _lastLocationSync;
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
        
        _locationUpdateFilter = LOCATION_UPDATE_FILTER;
        _locationEventFilter = LOCATION_EVENT_FILTER;
        _locationSyncFilter = LOCATION_SYNC_FILTER;
    }
    return self;
}

- (void)setConfig:(QwasiConfig *)config {
    _client = [QwasiClient clientWithConfig: config];
    _registered = NO;
}

- (void)setPushEnabled:(BOOL)pushEnabled {
    
    _pushEnabled = pushEnabled;
    
    if (_pushEnabled) {
        [self registerForNotifications: nil failure: nil];
    }
}

- (void)setLocationEnabled:(BOOL)locationEnabled {
    _locationEnabled = locationEnabled;
    
    if (_locationEnabled) {
        if (!_locationManager) {
            _locationManager = [QwasiLocationManager foregroundManager];
        }
        
        [_locationManager removeAllListeners];
        
        [_locationManager on: @"location" listener: ^(QwasiLocation* location) {
            @synchronized(self) {
                if (!_lastLocationEvent || [location distanceFromLocation: _lastLocationEvent] > MAX(LOCATION_EVENT_FILTER, _locationEventFilter)) {
                    
                    [self postEvent: kEventLocationUpdate withData:@{ @"lat": [NSNumber numberWithFloat: location.coordinate.latitude],
                                                                      @"lng": [NSNumber numberWithFloat: location.coordinate.longitude] }];
                    
                    _lastLocationEvent = location;
                }
                
                if (!_lastLocationUpdate || [location distanceFromLocation: _lastLocationUpdate] > _locationUpdateFilter) {
                    
                    [self emit: @"location", location];
                    
                    _lastLocationUpdate = location;
                }
                
                if (!_lastLocationSync || [location distanceFromLocation: _lastLocationSync] > MAX(LOCATION_SYNC_FILTER, _locationSyncFilter)) {

                    [self fetchLocationsNear: location success:^(NSArray* locations){
                        [_locationManager stopMonitoringAllLocations];
                        
                        for (QwasiLocation* location in locations) {
                            [_locationManager startMonitoringLocation: location];
                        }
                    } failure:^(NSError *err) {
                        err = [QwasiError locationSyncFailed: err];
                        
                        [self emit: @"error", err];
                    }];
                    
                    _lastLocationSync = location;
                }
                
                _lastLocation = [[QwasiLocation alloc] initWithLocation: location];
            }
        }];
        
        [_locationManager on: @"enter" listener: ^(QwasiLocation* location) {
            NSMutableDictionary* data = [[NSMutableDictionary alloc] init];
            
            data[@"id"] = location.id;
            data[@"name"] = location.name;
            data[@"lng"] = [NSNumber numberWithDouble: _lastLocation.longitude];
            data[@"lat"] = [NSNumber numberWithDouble: _lastLocation.latitude];
            
            if (location.type == QwasiLocationTypeBeacon) {
                data[@"distance"] = [NSNumber numberWithDouble: location.beacon.accuracy];
                data[@"beacon"] = @{ @"id": location.beaconUUID.UUIDString,
                                     @"maj_ver": [NSNumber numberWithDouble: location.beaconMajorVersion],
                                     @"min_ver": [NSNumber numberWithDouble: location.beaconMinorVersion] };
            }
            else {
                data[@"distance"] = [NSNumber numberWithDouble: [_lastLocation distanceFromLocation: location]];
            }
            
            [self postEvent: kEventLocationEnter withData: data];
            
            [self emit:@"location", location, QwasiLocationStateInside];
        }];
        
        [_locationManager on: @"exit" listener: ^(QwasiLocation* location) {
            NSMutableDictionary* data = [[NSMutableDictionary alloc] init];
            
            data[@"id"] = location.id;
            data[@"name"] = location.name;
            data[@"lng"] = [NSNumber numberWithDouble: _lastLocation.longitude];
            data[@"lat"] = [NSNumber numberWithDouble: _lastLocation.latitude];
            
            
            if (location.type == QwasiLocationTypeBeacon) {
                data[@"distance"] = [NSNumber numberWithDouble: location.beacon.accuracy];
                data[@"beacon"] = @{ @"id": location.beaconUUID.UUIDString,
                                     @"maj_ver": [NSNumber numberWithDouble: location.beaconMajorVersion],
                                     @"min_ver": [NSNumber numberWithDouble: location.beaconMinorVersion] };
            }
            else {
                data[@"distance"] = [NSNumber numberWithDouble: [_lastLocation distanceFromLocation: location]];
            }
            
            [self postEvent: kEventLocationExit withData: data];
            
            [self emit:@"location", location, QwasiLocationStateOutside];
        }];
        
        [_locationManager on: @"error" listener: ^(NSError* error) {
            [self emit: @"error", error];
        }];
        
        [_locationManager startLocationUpdates];
    }
    else if (_locationManager) {
        [_locationManager stopLocationUpdates];
    }
}

- (void)registerDevice:(NSString*)deviceToken
              withName:(NSString*)name
         withUserToken:(NSString*)userToken
               success:(void(^)(NSString* deviceToken))success {
    [self registerDevice: deviceToken withName: name withUserToken: userToken success: success failure: nil];
}

- (void)registerDevice:(NSString*)deviceToken
         withUserToken:(NSString*)userToken
               success:(void(^)(NSString* deviceToken))success {
    
    [self registerDevice: deviceToken withName: nil withUserToken: userToken success: success failure: nil];
}

- (void)registerDevice:(NSString*)deviceToken
               success:(void(^)(NSString* deviceToken))success {
    [self registerDevice: deviceToken withName: nil withUserToken: nil success: success failure: nil];
}

- (void)registerDevice:(NSString*)deviceToken
         withUserToken:(NSString*)userToken {
    [self registerDevice: deviceToken withName: nil withUserToken: userToken success: nil failure: nil];
}

- (void)registerDevice:(NSString*)deviceToken {
    [self registerDevice: deviceToken withName: nil withUserToken: nil success: nil failure: nil];
}

- (void)registerDevice:(NSString*)deviceToken
              withName: (NSString*)name
         withUserToken:(NSString*)userToken
               success:(void(^)(NSString* deviceToken))success
               failure:(void(^)(NSError* err))failure {
    
    UIApplication* application = [UIApplication sharedApplication];
    NSObject* appDelegate = application.delegate;
    
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
    
    // Add hooks to send application state events
    [appDelegate replaceMethodForSelector: @selector(applicationWillEnterForeground:) orAddWithTypes: "v@:@" implementation: ^(id _self, UIApplication* _unused) {

        [self postEvent: kEventApplicationState withData: @{ @"state": @"foreground" } success: nil failure: nil];
                                                             
        [_self callOnSuper:^{
            if ([_self respondsToSelector:@selector(applicationWillEnterForeground:)]) {
                [_self applicationWillEnterForeground: application];
            }
        }];
    }];
    
    [appDelegate replaceMethodForSelector: @selector(applicationDidEnterBackground:) orAddWithTypes: "v@:@" implementation: ^(id _self, UIApplication* _unused) {
        
        [self postEvent: kEventApplicationState withData: @{ @"state": @"background" } success: nil failure: nil];
        
        [_self callOnSuper:^{
            if ([_self respondsToSelector:@selector(applicationDidEnterBackground:)]) {
                [_self applicationDidEnterBackground: application];
            }
        }];
    }];

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
                      
                      [self emit: @"registered", _deviceToken];
                    
                }
                  failure: ^(AFHTTPRequestOperation *operation, NSError *error) {
                      error = [QwasiError deviceRegistrationFailed: error];
                      
                      if (failure) {
                          failure(error);
                      }
                      
                      [self emit: @"error", error];
                      
                      DDLogError(@"Device registration failed %@.", error);
                }];
}

- (void)registerForNotifications:(void(^)(NSString* pushToken))success
                         failure:(void(^)(NSError* err))failure {
    if (_registered) {
        UIApplication* application = [UIApplication sharedApplication];
        NSObject* appDelegate = application.delegate;
 
        // Add hooks for push notifications
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
                              
                              DDLogInfo(@"Push token %@ set successfully.", _pushToken);
                              
                              [self emit: @"pushToken", _pushToken];
                              
                          } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                              
                              error = [QwasiError pushRegistrationFailed: error];
                              
                              if (failure) failure(error);
                              
                              DDLogError(@"Push registration failed: %@.", error);
                          }];
        }];
        
        [appDelegate replaceMethodForSelector: @selector(application:didFailToRegisterForRemoteNotificationsWithError:) orAddWithTypes:"v@:@@" implementation:^(id _self, UIApplication* _unused, NSError* error) {
            
            DDLogError(@"Push registration failed: %@.", error);
            
            [_self callOnSuper:^{
                if ([_self respondsToSelector:@selector(application:didFailToRegisterForRemoteNotificationsWithError:)]) {
                    [_self application: application didFailToRegisterForRemoteNotificationsWithError: error];
                }
            }];
            
            error = [QwasiError pushRegistrationFailed: error];
            
            if (failure) {
                failure(error);
            }
            
            [self emit: @"error", error];
        }];
        
        [appDelegate replaceMethodForSelector: @selector(application:didReceiveRemoteNotification:fetchCompletionHandler:)
                               orAddWithTypes:"v@:@@@"
                               implementation: ^(id _self, UIApplication* _unused, NSDictionary* userInfo, fetchCompletionHander completionHandler)
         {
             [self fetchMessageForNotification: userInfo success:^(QwasiMessage *message) {
                 
                 [self emit: @"message", message];
                 
                 if (completionHandler) completionHandler(UIBackgroundFetchResultNewData);
                 
             } failure:^(NSError *err) {
                 
                 if (err.code == QwasiErrorInvalidMessage) {
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
            
                if (errData) {
                    NSError* parseError;
                    NSDictionary* jsonError = [NSJSONSerialization JSONObjectWithData: errData options: kNilOptions error: &parseError];
                    
                    if (parseError) {
                        DDLogError(@"Failed to parse server error response: %@", parseError);
                        
                        [self emit: @"error", parseError];
                    }
                    else {
                        err = [QwasiError apiError: jsonError];
                    }
                }
                
                
                if (err.code != QwasiErrorMessageNotFound) {
                    
                    DDLogError(@"Unexpected server error: %@", err);
                    
                    [self emit: @"error", err];
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
    else {
        NSError* error = [QwasiError pushRegistrationFailed: [QwasiError deviceNotRegistered]];
        
        if (failure) {
            failure(error);
        }
        
        [self emit: @"error", error];
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
        else {
            NSError* error = [QwasiError invalidMessage];
            
            if (failure) {
                failure(error);
            }
            
            [self emit: @"error", error];
        }
    }
    else {
        NSError* error = [QwasiError messageFetchFailed: [QwasiError deviceNotRegistered]];
        
        if (failure) {
            failure(error);
        }
        
        [self emit: @"error", error];
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
    else {
        NSError* error = [QwasiError messageFetchFailed: [QwasiError deviceNotRegistered]];
        
        if (failure) {
            failure(error);
        }
        
        [self emit: @"error", error];
    }
}

- (void)postEvent:(NSString*)event
         withData:(id)data {
    [self postEvent: event withData: data success: nil failure: nil];
}

- (void)postEvent:(NSString*)event
         withData:(id)data
          success:(void(^)(void))success
          failure:(void(^)(NSError* err))failure {
    if (_registered) {
        
        [_client invokeMethod: @"event.post"
               withParameters: @{ @"device": _deviceToken,
                                  @"type": event,
                                  @"data": data }
                      success:^(AFHTTPRequestOperation *operation, id responseObject) {
                          
                          if (success) success();
                          
                      } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                          if (failure) failure(error);
                      }];
        
    }
    else {
        NSError* error = [QwasiError postEvent: event failedWithReason: [QwasiError deviceNotRegistered]];
        
        if (failure) {
            failure(error);
        }
        
        [self emit: @"error", error];
    }
}

- (void)fetchLocationsNear:(CLLocation*)location
                   success:(void(^)(NSArray* locations))success
                   failure:(void(^)(NSError* err))failure {
    if (_registered) {
        
        [_client invokeMethod: @"location.fetch"
               withParameters: @{ @"near": @{ @"lng": [NSNumber numberWithDouble: location.coordinate.longitude],
                                              @"lat": [NSNumber numberWithDouble: location.coordinate.latitude],
                                              @"radius": [NSNumber numberWithDouble: _locationSyncFilter * 20] },
                                  @"options": @{ @"schema": @"2.0" } }
                      success:^(AFHTTPRequestOperation *operation, id responseObject) {
                          
                          if (success) {
                              NSMutableArray* locations = [[NSMutableArray alloc] init];
                              
                              for (NSDictionary* data in responseObject) {
                                  [locations addObject: [[QwasiLocation alloc] initWithLocationData: data]];
                              }
                          
                              success(locations);
                          }
                          
                      } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                          if (failure) failure(error);
                      }];
        
    }
    else {
        NSError* error = [QwasiError locationFetchFailed: [QwasiError deviceNotRegistered]];
        
        if (failure) {
            failure(error);
        }
        
        [self emit: @"error", error];
    }

}
@end
