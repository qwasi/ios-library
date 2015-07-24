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
#import "QwasiAppManager.h"

#define LOCATION_EVENT_FILTER 50.0f
#define LOCATION_UPDATE_FILTER 100.0f
#define LOCATION_SYNC_FILTER 200.0f
#define PED_FILTER 10.0f

#define UPDATE_FILTER(speed, filter) (speed / PED_FILTER) * filter

NSString* const kEventApplicationState = @"com.qwasi.event.application.state";
NSString* const kEventLocationUpdate = @"com.qwasi.event.location.update";
NSString* const kEventLocationEnter = @"com.qwasi.event.location.enter";
NSString* const kEventLocationDwell= @"com.qwasi.event.location.dwell";
NSString* const kEventLocationExit = @"com.qwasi.event.location.exit";

typedef void (^fetchCompletionHander)(UIBackgroundFetchResult result);

@implementation Qwasi {
    CLLocation* _lastLocationEvent;
    CLLocation* _lastLocationUpdate;
    CLLocation* _lastLocationSync;
    
    NSCache* _messageCache;
    NSArray* _locations;
    NSMutableArray* _filteredTags;
    
    dispatch_once_t _locationOnce;
    dispatch_once_t _pushOnce;
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
        
        self.config = config;
        
        _locationUpdateFilter = LOCATION_UPDATE_FILTER;
        _locationEventFilter = LOCATION_EVENT_FILTER;
        _locationSyncFilter = LOCATION_SYNC_FILTER;
        
        _useLocalNotifications = YES;
        
        _messageCache = [[NSCache alloc] init];
        
        _userToken = @"";
        
        _filteredTags = [[NSMutableArray alloc] init];
        
        [[QwasiAppManager shared] on: @"willEnterForeground" listener: ^() {
            [self postEvent: kEventApplicationState withData: @{ @"state": @"foreground" } success: nil failure: nil];
        }];
        
        [[QwasiAppManager shared] on: @"didEnterBackground" listener: ^() {
            [self postEvent: kEventApplicationState withData: @{ @"state": @"background" } success: nil failure: nil];
        }];
    }
    return self;
}

- (void)setConfig:(QwasiConfig *)config {
    _config = config;
    _client = [QwasiClient clientWithConfig: config];
    _registered = NO;
}

- (void)setPushEnabled:(BOOL)pushEnabled {
    
    if (pushEnabled) {
        [self registerForNotifications: nil failure: nil];
    }
    else {
        [self unregisterForNotifications: nil failure: nil];
    }
}

- (void)setLocationEnabled:(BOOL)locationEnabled {
    _locationEnabled = locationEnabled;
    
    if (_locationEnabled) {
        
        if (!_locationManager) {
            _locationManager = [QwasiLocationManager foregroundManager];
        }
        
        dispatch_once(&_locationOnce, ^{
            [_locationManager on: @"location" listener: ^(QwasiLocation* location) {
                @synchronized(self) {
                    CLLocationSpeed speed = location.speed;
                    
                    _lastLocation = [[QwasiLocation alloc] initWithLocation: location];
                    
                    
                    if (!_lastLocationEvent || [location distanceFromLocation: _lastLocationEvent] > MAX(LOCATION_EVENT_FILTER, UPDATE_FILTER(speed, _locationEventFilter))) {
                        
                        [self postEvent: kEventLocationUpdate withData:@{ @"lat": [NSNumber numberWithFloat: location.coordinate.latitude],
                                                                          @"lng": [NSNumber numberWithFloat: location.coordinate.longitude] }];
                        
                        _lastLocationEvent = location;
                    }
                    
                    if (!_lastLocationUpdate || [location distanceFromLocation: _lastLocationUpdate] > UPDATE_FILTER(speed, _locationUpdateFilter)) {
                        
                        [self emit: @"location", location];
                        
                        _lastLocationUpdate = location;
                    }
                    
                    if (!_lastLocationSync || [location distanceFromLocation: _lastLocationSync] > MAX(LOCATION_SYNC_FILTER, UPDATE_FILTER(speed, _locationSyncFilter))) {

                        [self fetchLocationsNear: location success:^(NSArray* locations){
                            
                            for (QwasiLocation* location in _locations) {
                                [_locationManager stopMonitoringLocation: location];
                            }
                            
                            _locations = locations;
                            
                            for (QwasiLocation* location in locations) {
                                [_locationManager startMonitoringLocation: location];
                            }
                        } failure:^(NSError *err) {
                            err = [QwasiError locationSyncFailed: err];
                            
                            [self emit: @"error", err];
                        }];
                        
                        _lastLocationSync = location;
                    }
                    
                }
            }];
            
            [_locationManager on: @"enter" listener: ^(QwasiLocation* location) {
                NSMutableDictionary* data = [[NSMutableDictionary alloc] init];
                
                data[@"id"] = location.id;
                data[@"name"] = location.name;
                data[@"lng"] = [NSNumber numberWithDouble: _lastLocation.longitude];
                data[@"lat"] = [NSNumber numberWithDouble: _lastLocation.latitude];
                data[@"dwellTime"] = [NSNumber numberWithDouble: location.dwellTime];
                
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
            
            [_locationManager on: @"dwell" listener: ^(QwasiLocation* location) {
                NSMutableDictionary* data = [[NSMutableDictionary alloc] init];
                
                data[@"id"] = location.id;
                data[@"name"] = location.name;
                data[@"lng"] = [NSNumber numberWithDouble: _lastLocation.longitude];
                data[@"lat"] = [NSNumber numberWithDouble: _lastLocation.latitude];
                data[@"dwellTime"] = [NSNumber numberWithDouble: location.dwellTime];
                
                if (location.type == QwasiLocationTypeBeacon) {
                    data[@"distance"] = [NSNumber numberWithDouble: location.beacon.accuracy];
                    data[@"beacon"] = @{ @"id": location.beaconUUID.UUIDString,
                                         @"maj_ver": [NSNumber numberWithDouble: location.beaconMajorVersion],
                                         @"min_ver": [NSNumber numberWithDouble: location.beaconMinorVersion] };
                }
                else {
                    data[@"distance"] = [NSNumber numberWithDouble: [_lastLocation distanceFromLocation: location]];
                }
                
                [self postEvent: kEventLocationDwell withData: data];
                
                [self emit:@"location", location, QwasiLocationStateDwell];
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
        });
    }
    else if (_locationManager) {
        [_locationManager stopLocationUpdates];
    }
}

- (void)registerDevice:(NSString*)deviceToken
              withName:(NSString*)name
         withUserToken:(NSString*)userToken
               success:(void(^)(NSString* deviceToken))success {
    [self registerDevice: deviceToken withName: name withUserToken: userToken withUserInfo: nil success: success failure: nil];
}

- (void)registerDevice:(NSString*)deviceToken
              withName:(NSString*)name
         withUserToken:(NSString*)userToken
          withUserInfo:(NSDictionary*)userInfo
               success:(void(^)(NSString* deviceToken))success {
    [self registerDevice: deviceToken withName: name withUserToken: userToken withUserInfo: userInfo success: success failure: nil];
}

- (void)registerDevice:(NSString*)deviceToken
         withUserToken:(NSString*)userToken
               success:(void(^)(NSString* deviceToken))success {
    
    [self registerDevice: deviceToken withName: nil withUserToken: userToken withUserInfo: nil success: success failure: nil];
}

- (void)registerDevice:(NSString*)deviceToken
               success:(void(^)(NSString* deviceToken))success {
    [self registerDevice: deviceToken withName: nil withUserToken: nil withUserInfo: nil success: success failure: nil];
}

- (void)registerDevice:(NSString*)deviceToken
         withUserToken:(NSString*)userToken {
    [self registerDevice: deviceToken withName: nil withUserToken: userToken withUserInfo: nil success: nil failure: nil];
}

- (void)registerDevice:(NSString*)deviceToken {
    [self registerDevice: deviceToken withName: nil withUserToken: nil withUserInfo: nil success: nil failure: nil];
}

- (void)registerDevice:(NSString*)deviceToken
         withUserToken:(NSString*)userToken
          withUserInfo:(NSDictionary*)userInfo
               success:(void(^)(NSString* deviceToken))success {
    [self registerDevice: deviceToken withName: nil withUserToken: userToken withUserInfo: userInfo success: success failure: nil];
}

- (void)registerDevice:(NSString*)deviceToken
              withName: (NSString*)name
         withUserToken:(NSString*)userToken
          withUserInfo:(NSDictionary *)userInfo
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
        userToken = _userToken;
    }
    
    NSMutableDictionary* info = [[NSMutableDictionary alloc] init];
    
    NSDictionary* deviceInfo = @{
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
    
    if (userInfo) {
        [info addEntriesFromDictionary: userInfo];
    }
    
    [info addEntriesFromDictionary: deviceInfo];
    
    [_client invokeMethod: @"device.register"
           withParameters: @{ @"id": deviceToken,
                              @"name": name,
                              @"user_token": userToken,
                              @"info": info }
     
                  success: ^(AFHTTPRequestOperation *operation, id responseObject) {
                      
                      _registered = YES;
                      
                      _deviceToken = [responseObject valueForKey: @"id"];
                      
                      _applicationName = [responseObject valueForKeyPath: @"application.name"];
                      
                      if (success) {
                          success(_deviceToken);
                      }
                      
                      DDLogInfo(@"Device %@ registered successfully for application %@.", _deviceToken, _applicationName);
                      
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

- (void)setUserToken:(NSString *)userToken {
    _userToken = userToken;
    
    if (_registered) {
        [_client invokeMethod: @"device.set_user_token" withParameters: @{@"id": _deviceToken,
                                                                          @"user_token": _userToken }
                                                                          success:^(AFHTTPRequestOperation *operation, id responseObject)
        {
            
            DDLogVerbose(@"Set usertoken for application %@ succeed.", _applicationName);
            
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            error = [QwasiError setUserTokenFailed: error];
            
            [self emit: @"error", error];
            
            DDLogError(@"Set usertoken failed %@.", error);
        }];
    }
}

- (void)unregisterDevice:(NSString*)deviceToken success:(void(^)())success failure:(void(^)(NSError* err))failure {
    if (_registered) {
        
        [_client invokeMethod: @"device.unregister"
               withParameters: @{ @"id": _deviceToken }
                      success:^(AFHTTPRequestOperation *operation, id responseObject) {
                          
                          _registered = NO;
                          _deviceToken = nil;
                          
                          if (success) success();
                          
                      } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                          
                          error = [QwasiError deviceUnregisterFailed: error];
                          
                          if (failure) failure(error);
                      }];
        
    }
    else {
        NSError* error = [QwasiError deviceUnregisterFailed: [QwasiError deviceNotRegistered]];
        
        if (failure) {
            failure(error);
        }
        
        [self emit: @"error", error];
    }
}

- (void)registerForNotifications:(void(^)(NSString* pushToken))success
                         failure:(void(^)(NSError* err))failure {
    if (_registered) {
        
        dispatch_once(&_pushOnce, ^{
            [[QwasiNotificationManager shared] once: @"pushToken" listener: ^(NSString* pushToken) {
                [_client invokeMethod: @"device.set_push_token"
                       withParameters: @{ @"id": _deviceToken,
                                          @"proto": @"push.apns",
                                          @"token": pushToken }
                              success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                  
                                  _pushEnabled = YES;
                                  
                                  if (success) success(pushToken);
                                  
                                  DDLogInfo(@"Device %@ push token %@ set successfully.", _deviceToken, pushToken);
                                  
                              } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                  
                                  _pushEnabled = NO;
                                  
                                  error = [QwasiError pushRegistrationFailed: error];
                                  
                                  if (failure) failure(error);
                                  
                                  DDLogError(@"Push registration failed: %@.", error);
                              }];
            }];
            
            [[QwasiNotificationManager shared] once: @"error" listener: ^(NSError* error) {
                
                if (error.code == QwasiErrorPushNotEnabled) {
                    _pushEnabled = NO;
                    
                    DDLogWarn(@"Remote notifications disabled for device, poll will still work.");
                }
                else {
                    [self emit: @"error", error];
                }
                
            }];
            
            [[QwasiNotificationManager shared] on: @"notification" listener: ^(NSDictionary* userInfo) {
                [self fetchMessageForNotification: userInfo success:^(QwasiMessage *message) {
                    
                    [[QwasiNotificationManager shared] emit: @"message", message, self];
                    
                } failure:^(NSError *err) {
                    
                    err = [QwasiError messageFetchFailed: err];
                    
                    [self emit: @"error", err];
                }];
            }];
            
            [[QwasiNotificationManager shared] on: @"message" listener: ^(QwasiMessage* message, BOOL _self) {
                
                if ([message.application isEqualToString: _config.application]) {
                    BOOL filter = NO;
                    
                    for (NSString* tag in message.tags) {
                        
                        if ([_filteredTags indexOfObject: tag] != NSNotFound) {
                            
                            [self emit: [NSString stringWithFormat: @"tag#%@", tag], message];
                        
                            filter = YES;
                        }
                    }
                    
                    if (!filter) {
                        [self emit: @"message", message];
                    }
                }
            }];
            
            [[QwasiAppManager shared] on: @"backgroundFetch" listener: ^() {
                
                [self fetchUnreadMessage:^(QwasiMessage *message) {
                    
                    if (_useLocalNotifications && [UIApplication sharedApplication].applicationState != UIApplicationStateActive ) {
                        UILocalNotification* localNotification = [[UILocalNotification alloc] init];
                        
                        localNotification.fireDate = [NSDate dateWithTimeIntervalSinceNow: 0];
                        localNotification.alertBody = message.alert;
                        localNotification.userInfo = @{ @"qwasi": [NSKeyedArchiver archivedDataWithRootObject: message] };
                        
                        [[UIApplication sharedApplication] scheduleLocalNotification:localNotification];
                    }
                    
                    [self emit: @"message", message];
                    
                } failure:^(NSError *err) {
                    if (err.code != QwasiErrorMessageNotFound) {
                        
                        DDLogError(@"Unexpected server error: %@", err);
                        
                        [self emit: @"error", err];
                    }
                }];
            }];
            
            [[QwasiNotificationManager shared] registerForRemoteNotification];
        });
    }
    else {
        NSError* error = [QwasiError pushRegistrationFailed: [QwasiError deviceNotRegistered]];
        
        if (failure) {
            failure(error);
        }
        
        [self emit: @"error", error];
    }
}

- (void)unregisterForNotifications:(void(^)())success
                           failure:(void(^)(NSError* err))failure {
    if (_registered) {
        
        [_client invokeMethod: @"device.set_push_token"
               withParameters: @{ @"id": _deviceToken,
                                  @"proto": @"push.poll",
                                  @"token": @"" }
                      success:^(AFHTTPRequestOperation *operation, id responseObject)
        {
                          
          _pushEnabled = NO;
          
          if (success) success();
          
          DDLogInfo(@"Device unregistered for remote notifications.");
          
      } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
          
          error = [QwasiError pushRegistrationFailed: error];
          
          if (failure) failure(error);
          
          DDLogError(@"Push registration failed: %@.", error);
      }];
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
        NSString* appId = qwasi[@"a"];
        
        if (msgId && appId) {
            if ([appId isEqualToString: _config.application]) {
                
                NSData* cachedMessage = [_messageCache objectForKey: msgId];
                
                if (!cachedMessage) {
                    [_client invokeMethod: @"message.fetch"
                           withParameters: @{ @"device": _deviceToken,
                                              @"id": msgId,
                                              @"flags": flags }
                                  success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                      QwasiMessage* message = [QwasiMessage messageWithData: responseObject];
                                      
                                      [_messageCache setObject: [NSKeyedArchiver archivedDataWithRootObject: message] forKey: message.messageId];
                                    
                                      if (success) success(message);
                                                           
                                  } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                      
                                      NSData* errData = error.userInfo[@"com.alamofire.serialization.response.error.data"];
                                      
                                      if (errData) {
                                          NSError* parseError;
                                          NSDictionary* jsonError = [NSJSONSerialization JSONObjectWithData: errData options: kNilOptions error: &parseError];
                                          
                                          if (parseError) {
                                              DDLogError(@"Failed to parse server error response: %@", parseError);
                                              
                                              [self emit: @"error", parseError];
                                          }
                                          else {
                                              error = [QwasiError apiError: jsonError];
                                          }
                                      }
                                      else {
                                          error = [QwasiError messageFetchFailed: error];
                                      }
                                      
                                      if (failure) failure(error);

                                  }];
                }
                else {
                    QwasiMessage* message = [NSKeyedUnarchiver unarchiveObjectWithData: cachedMessage];
                    
                    if (success && message) success(message);
                }
            }
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
                          
                          QwasiMessage* message = [QwasiMessage messageWithData: responseObject];
                          
                          [_messageCache setObject: [NSKeyedArchiver archivedDataWithRootObject: message] forKey: message.messageId];
                          
                          if (success) success(message);
                          
                      } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                          
                          NSData* errData = error.userInfo[@"com.alamofire.serialization.response.error.data"];
                          
                          if (errData) {
                              NSError* parseError;
                              NSDictionary* jsonError = [NSJSONSerialization JSONObjectWithData: errData options: kNilOptions error: &parseError];
                              
                              if (parseError) {
                                  DDLogError(@"Failed to parse server error response: %@", parseError);
                                  
                                  [self emit: @"error", parseError];
                              }
                              else {
                                  error = [QwasiError apiError: jsonError];
                              }
                          }
                          else {
                              error = [QwasiError messageFetchFailed: error];
                          }
                          
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

- (void)filterTag:(NSString *)tag {
    [_filteredTags addObject: tag];
}

- (void)unfilterTag:(NSString*)tag {
    [_filteredTags removeObject: tag];
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
                          
                          error = [QwasiError postEvent: event failedWithReason: error];
                          
                          if (failure) failure(error);
                          
                          [self emit: @"error", error];
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
                                              @"radius": [NSNumber numberWithDouble: _locationSyncFilter * 10] },
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
                          
                          error = [QwasiError locationFetchFailed: error];
                          
                          if (failure) failure(error);
                          
                          [self emit: @"error", error];
                          
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

- (void)subscribeToChannel:(NSString*)channel {
    [self subscribeToChannel: channel success: nil failure: nil];
}

- (void)subscribeToChannel:(NSString*)channel
                   success:(void(^)(void))success
                   failure:(void(^)(NSError* err))failure {
    if (_registered) {
        
        [_client invokeMethod: @"channel.subscribe"
               withParameters: @{ @"device": _deviceToken,
                                  @"channel": channel }
                      success:^(AFHTTPRequestOperation *operation, id responseObject) {
                          
                          DDLogVerbose(@"Subscribed to channel %@ for application %@.", channel, _applicationName);
                          
                          if (success) {
                              success();
                          }
                          
                      } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                          
                          error = [QwasiError channel: channel subscribeFailed: error];
                          
                          if (failure) failure(error);
                          
                          [self emit: @"error", error];
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

- (void)unsubscribeFromChannel:(NSString*)channel {
    [self unsubscribeFromChannel: channel success: nil failure: nil];
}

- (void)unsubscribeFromChannel:(NSString*)channel
                       success:(void(^)(void))success
                       failure:(void(^)(NSError* err))failure {
    if (_registered) {
        
        [_client invokeMethod: @"channel.unsubscribe"
               withParameters: @{ @"device": _deviceToken,
                                  @"channel": channel }
                      success:^(AFHTTPRequestOperation *operation, id responseObject) {
                          
                          DDLogVerbose(@"Unsubscribed to channel %@ for application %@.", channel, _applicationName);
                          
                          if (success) {
                              success();
                          }
                          
                      } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                          
                          error = [QwasiError channel: channel subscribeFailed: error];
                          
                          if (failure) failure(error);
                          
                          [self emit: @"error", error];
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

- (void)setDeviceValue:(id)value forKey:(NSString*)key
               success:(void(^)(void))success
               failure:(void(^)(NSError* err))failure {
    if (_registered) {
        
        [_client invokeMethod: @"device.set_data"
               withParameters: @{ @"id": _deviceToken,
                                  @"key": key,
                                  @"value": value }
                      success:^(AFHTTPRequestOperation *operation, id responseObject) {
                          
                          if (success) {
                              success();
                          }
                          
                      } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                          
                          error = [QwasiError setDeviceDataForKey: key failed: error];
                          
                          if (failure) failure(error);
                          
                          [self emit: @"error", error];
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

- (void)setDeviceValue:(id)value forKey:(NSString*)key {
    [self setDeviceValue: value forKey: key success: nil failure: nil];
}

- (void)deviceValueForKey:(NSString*)key
                  success:(void(^)(id value))success
                  failure:(void(^)(NSError* err))failure {
    if (_registered) {
        
        [_client invokeMethod: @"device.get_data"
               withParameters: @{ @"id": _deviceToken,
                                  @"key": key }
                      success:^(AFHTTPRequestOperation *operation, id responseObject) {
                          
                          if (success) {
                              success(responseObject);
                          }
                          
                      } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                          
                          error = [QwasiError getDeviceDataForKey: key failed: error];
                          
                          if (failure) failure(error);
                          
                          [self emit: @"error", error];
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

- (void)sendMessage:(QwasiMessage*)message
        toUserToken:(NSString*)userToken
            success:(void(^)())success
            failure:(void(^)(NSError* err))failure {
    if (_registered) {
        
        id payload = message.payload;
        
        if (payload) {
            
            if ([NSJSONSerialization isValidJSONObject: payload]) {
                NSError* jsonError;
                
                NSData* jsonData = [NSJSONSerialization dataWithJSONObject: message.payload options: 0 error: &jsonError];
                
                if (!jsonData || jsonError) {
                    
                    jsonError = [QwasiError sendMessageToUserToken: userToken failed: jsonError];
                    
                    if (failure) failure(jsonError);
                    
                    [self emit: @"error", jsonError];
                    
                    return;
                }
                
                payload = [jsonData base64EncodedStringWithOptions:0];
                
            }
            else if ([payload isKindOfClass: [NSString class]]) {
                NSData* jsonData = [payload dataUsingEncoding: NSUTF8StringEncoding];
                payload = [jsonData base64EncodedStringWithOptions: 0];
            }
            else {
                payload = nil;
            }
        }
        
        [_client invokeMethod: @"message.send"
               withParameters: @{ @"audience": @{ @"user_tokens": @[userToken] },
                                  @"notification": message.alert,
                                  @"payload": payload,
                                  @"payload_type": message.payloadType,
                                  @"tags": message.tags }
                      success:^(AFHTTPRequestOperation *operation, id responseObject) {
                          
                          if (success) {
                              success(responseObject);
                          }
                          
                      } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                          
                          error = [QwasiError sendMessageToUserToken: userToken failed: error];
                          
                          if (failure) failure(error);
                          
                          [self emit: @"error", error];
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

- (void)sendMessage:(QwasiMessage*)message
        toUserToken:(NSString*)userToken {
    [self sendMessage: message toUserToken: userToken success: nil failure: nil];
}
@end
