//
// Qwasi.m
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

#import "Qwasi.h"
#import "QwasiClient.h"
#import "GBDeviceInfo.h"
#import "NSObject+STSwizzle.h"
#import "QwasiAppManager.h"
#import "Version.h"

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
    
    NSMutableArray* _channels;
    
    BOOL _terminated;
    BOOL _pushRegistered;
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

+ (NSString*)version {
    return VERSION_STRING;
}

- (id)initWithConfig:(QwasiConfig*)config {
    if (self = [super init]) {
        
        _registered = NO;
        
        _pushRegistered = NO;
        
        self.config = config;
        
        _locationUpdateFilter = LOCATION_UPDATE_FILTER;
        _locationEventFilter = LOCATION_EVENT_FILTER;
        _locationSyncFilter = LOCATION_SYNC_FILTER;
        
        _useLocalNotifications = YES;
        
        _messageCache = [[NSCache alloc] init];
        
        _userToken = @"";
        
        _terminated = NO;
        
        _filteredTags = [[NSMutableArray alloc] init];
        
        [[QwasiAppManager shared] on: @"didFinishLaunching" listener: ^() {
            [self tryPostEvent: kEventApplicationState withData: @{ @"state": @"open" }];
        }];
        
        [[QwasiAppManager shared] on: @"willTerminate" listener: ^() {
            
            [self tryPostEvent: kEventApplicationState withData: @{ @"state": @"exit" }];
            
            [NSThread sleepForTimeInterval:.5];
        }];
        
        [[QwasiAppManager shared] on: @"willEnterForeground" listener: ^() {
            [self tryPostEvent: kEventApplicationState withData: @{ @"state": @"foreground" }];
        }];
        
        [[QwasiAppManager shared] on: @"didEnterBackground" listener: ^() {
            [self tryPostEvent: kEventApplicationState withData: @{ @"state": @"background" }];
        }];
    }
    return self;
}

- (void)setConfig:(QwasiConfig *)config {
    _config = config;
    _client = [QwasiClient clientWithConfig: config];
    _registered = NO;
}

- (BOOL) pushEnabled {
    return _pushRegistered && [QwasiNotificationManager shared].pushEnabled;
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
                        
                        [self tryPostEvent: kEventLocationUpdate withData:@{ @"lat": [NSNumber numberWithFloat: location.coordinate.latitude],
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
                
                [self tryPostEvent: kEventLocationEnter withData: data];
                
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
                
                [self tryPostEvent: kEventLocationDwell withData: data];
                
                [self emit: @"location", location, QwasiLocationStateDwell];
            }];
            
            [_locationManager on: @"exit" listener: ^(QwasiLocation* location) {
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
                
                [self tryPostEvent: kEventLocationExit withData: data];
                
                [self emit:@"location", location, QwasiLocationStateOutside];
            }];
            
            [_locationManager on: @"error" listener: ^(NSError* error) {
                [self emit: @"error", error];
            }];
        });
        
        [_locationManager startLocationUpdates];
    }
    else if (_locationManager) {
        
        [_locationManager stopLocationUpdates];
        
        _lastLocation = nil;
        _lastLocationSync = nil;
        _lastLocationEvent = nil;
        _lastLocationUpdate = nil;
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
                                 @"debug": [NSNumber numberWithBool: [QwasiNotificationManager shared].sandbox],
                                 @"version": [UIDevice currentDevice].systemVersion,
                                 @"system": [UIDevice currentDevice].systemName,
                                 @"model": [GBDeviceInfo deviceInfo].modelString,
                                 @"sdkVersion": [Qwasi version]
                                 };
    
    [info addEntriesFromDictionary: deviceInfo];
    
    if (userInfo) {
        [info addEntriesFromDictionary: userInfo];
    }
    
    [_client invokeMethod: @"device.register"
           withParameters: @{ @"id": deviceToken,
                              @"name": name,
                              @"user_token": userToken,
                              @"info": info }
     
                  success: ^(AFHTTPRequestOperation *operation, id responseObject) {
                      
                      _registered = YES;
                      
                      _deviceToken = [responseObject valueForKey: @"id"];
                      
                      _channels = [NSMutableArray arrayWithArray: [responseObject valueForKey: @"channels"]];
                      
                      _applicationName = [responseObject valueForKeyPath: @"application.name"];
                      
                      if (success) {
                          success(_deviceToken);
                      }
                      
                      NSLog(@"Device %@ registered successfully for application %@.", _deviceToken, _applicationName);
                      
                      [self emit: @"registered", _deviceToken];
                      
                      [[QwasiAppManager shared] registerApplicationEventHooks];
                      
                      // check for launch notification
                      NSDictionary* note = [QwasiNotificationManager shared].launchNotification;
                      if (note != nil) {
                          [[QwasiNotificationManager shared] emit: @"notification", note];
                      }
                      
                  }
                  failure: ^(AFHTTPRequestOperation *operation, NSError *error) {
                      error = [QwasiError deviceRegistrationFailed: error];
                      
                      if (failure) {
                          failure(error);
                      }
                      
                      [self emit: @"error", error];
                      
                      NSLog(@"Device registration failed %@.", error);
                  }];
}

- (void)setUserToken:(NSString *)userToken {
    _userToken = userToken;
    
    if (_registered) {
        [_client invokeMethod: @"device.register" withParameters: @{@"id": _deviceToken,
                                                                    @"user_token": _userToken }
                      success: ^(AFHTTPRequestOperation *operation, id responseObject)
         {
             
             NSLog(@"Set usertoken for application %@ succeed.", _applicationName);
             
         } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
             error = [QwasiError setUserTokenFailed: error];
             
             [self emit: @"error", error];
             
             NSLog(@"Set usertoken failed %@.", error);
         }];
    }
}

- (void)unregisterDevice:(NSString*)deviceToken success:(void(^)())success failure:(void(^)(NSError* err))failure {
    if (_registered) {
        
        [_client invokeMethod: @"device.unregister"
               withParameters: @{ @"id": _deviceToken }
                      success: ^(AFHTTPRequestOperation *operation, id responseObject) {
                          
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

- (void)setPushToken:(NSString*)pushToken
             success:(void(^)(void))success
             failure:(void(^)(NSError* err))failure {
    
    NSString* proto = @"push.apns";
    
    if (pushToken == nil) {
        pushToken = @"";
    }
    
    if ([pushToken isEqualToString:@""] ||
        ![QwasiNotificationManager shared].pushEnabled) {
        proto = @"push.poll";
    }
    
    if (_registered) {
        [_client invokeMethod: @"device.register"
               withParameters: @{ @"id": _deviceToken,
                                  @"push": @{ @"proto": proto,
                                              @"addr": pushToken } }
                      success:^(AFHTTPRequestOperation *operation, id responseObject) {
                          
                          _pushRegistered = YES;
                          
                          if (success) success();
                          
                          NSLog(@"Device %@ push token %@ set successfully.", _deviceToken, pushToken);
                          
                          [self emit:@"pushRegistered", pushToken];
                          
                      } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                          
                          _pushRegistered = NO;
                          
                          error = [QwasiError pushRegistrationFailed: error];
                          
                          if (failure) failure(error);
                          
                          NSLog(@"Push registration failed: %@.", error);
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

- (void)registerForNotifications:(void(^)(NSString* pushToken))success
                         failure:(void(^)(NSError* err))failure {
    if (_registered) {
        // Handle the case where notification manager has already registered for a push token
        if ([QwasiNotificationManager shared].pushToken != nil) {
            NSString* pushToken = [QwasiNotificationManager shared].pushToken;
            
            [self setPushToken: pushToken success:^{
                if (success) success(pushToken);
            } failure:^(NSError *err) {
                if (failure) failure(err);
            }];
        }
        dispatch_once(&_pushOnce, ^{
            static bool done = false;
            
            [[QwasiNotificationManager shared] on: @"pushToken" listener: ^(NSString* pushToken, NSError* err) {
                if (err != nil) {
                    if (err.code == QwasiErrorPushNotEnabled) {
                        NSLog(@"Remote notifications disabled for device, poll will still work.");
                    } else {
                        if (!done && failure) failure(err);
                    }   
                }
                [self setPushToken: pushToken success:^{
                    if (!done && success) success(pushToken);
                } failure:^(NSError *err) {
                    if (!done && failure) failure(err);
                }];
                
                done = true;
            }];
            
            
            [[QwasiNotificationManager shared] on: @"notification" listener: ^(NSDictionary* userInfo) {
                
                NSArray* qwasi = userInfo[@"qwasi"];
                
                if (qwasi && qwasi.count == 3) {
                    NSString* appId = qwasi[2];
                    
                    if (appId && [appId isEqualToString: _config.application]) {
                        
                        [self fetchMessageForNotification: userInfo success:^(QwasiMessage *message) {
                            
                            BOOL filtered = NO;
                            
                            filtered = [self checkMessageTags: message];
                            
                            if (!filtered) {
                                [self emit: @"message", message];
                                
                                [[QwasiNotificationManager shared] emit: @"message", message, self];
                            }
                            
                        } failure:^(NSError *err) {
                            
                            err = [QwasiError messageFetchFailed: err];
                            
                            [self emit: @"error", err];
                            
                        }];
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
                    
                    [[QwasiNotificationManager shared] emit: @"message", message, self];
                    
                } failure:^(NSError *err) {
                    if (err.code != QwasiErrorMessageNotFound) {
                        
                        NSLog(@"Unexpected server error: %@", err);
                        
                        [self emit: @"error", err];
                    }
                }];
            }];
            
            [[QwasiNotificationManager shared] registerForRemoteNotifications];
            
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
        
        [self setPushToken: nil success:^{
            
            _pushRegistered = NO;
            
            if (success) success();
            
            NSLog(@"Device unregistered for remote notifications.");
            
        } failure:^(NSError *error) {
            
            error = [QwasiError pushRegistrationFailed: error];
            
            if (failure) failure(error);
            
            NSLog(@"Push registration failed: %@.", error);
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
        
        NSArray* qwasi = userInfo[@"qwasi"];
        NSString* appId = qwasi[2];
        NSString* msgId = qwasi[0];
        
        
        if (msgId && appId) {
            if ([appId isEqualToString: _config.application]) {
                
                NSData* cachedMessage = [_messageCache objectForKey: msgId];
                
                if (!cachedMessage) {
                    
                    UIBackgroundTaskIdentifier bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler: nil];
                    
                    [_client invokeMethod: @"message.fetch"
                           withParameters: @{ @"device": _deviceToken,
                                              @"id": msgId,
                                              @"flags": flags }
                                  success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                      QwasiMessage* message = [QwasiMessage messageWithData: responseObject];
                                      
                                      [_messageCache setObject: [NSKeyedArchiver archivedDataWithRootObject: message] forKey: message.messageId];
                                      
                                      if (success) success(message);
                                      
                                      if (bgTask != UIBackgroundTaskInvalid) {
                                          [[UIApplication sharedApplication] endBackgroundTask:bgTask];
                                      }
                                      
                                  } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                      
                                      NSData* errData = error.userInfo[@"com.alamofire.serialization.response.error.data"];
                                      
                                      if (errData) {
                                          NSError* parseError;
                                          NSDictionary* jsonError = [NSJSONSerialization JSONObjectWithData: errData options: kNilOptions error: &parseError];
                                          
                                          if (parseError) {
                                              NSLog(@"Failed to parse server error response: %@", parseError);
                                              
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
                                      
                                      if (bgTask != UIBackgroundTaskInvalid) {
                                          [[UIApplication sharedApplication] endBackgroundTask:bgTask];
                                      }
                                      
                                  }];
                }
                else {
                    QwasiMessage* message = [QwasiMessage messageWithArchive: cachedMessage updateFlags: YES];
                    
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

- (void)tryFetchUnreadMessages {
    
    if (_registered) {
        [self fetchUnreadMessage:^(QwasiMessage *message) {
            
            BOOL filtered = NO;
            
            filtered = [self checkMessageTags: message];
            
            if( !filtered){
                
                [self emit: @"message", message];
                
                [[QwasiNotificationManager shared] emit: @"message", message, self];
            }
            
            [self tryFetchUnreadMessages];
            
        } failure:^(NSError *err) {
            
        }];
    }
}

- (void)fetchUnreadMessage:(void(^)(QwasiMessage* message))success
                   failure:(void(^)(NSError* err))failure {
    if (_registered) {
        
        UIBackgroundTaskIdentifier bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler: nil];
        
        [_client invokeMethod: @"message.poll"
               withParameters: @{ @"device": _deviceToken,
                                  @"options": @{ @"fetch": [NSNumber numberWithBool: YES] } }
                      success:^(AFHTTPRequestOperation *operation, id responseObject) {
                          
                          QwasiMessage* message = [QwasiMessage messageWithData: responseObject];
                          
                          [_messageCache setObject: [NSKeyedArchiver archivedDataWithRootObject: message] forKey: message.messageId];
                          
                          if (success) success(message);
                          
                          if (bgTask != UIBackgroundTaskInvalid) {
                              [[UIApplication sharedApplication] endBackgroundTask:bgTask];
                          }
                          
                      } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                          
                          NSData* errData = error.userInfo[@"com.alamofire.serialization.response.error.data"];
                          
                          if (errData) {
                              NSError* parseError;
                              NSDictionary* jsonError = [NSJSONSerialization JSONObjectWithData: errData options: kNilOptions error: &parseError];
                              
                              if (parseError) {
                                  NSLog(@"Failed to parse server error response: %@", parseError);
                                  
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
                          
                          if (bgTask != UIBackgroundTaskInvalid) {
                              [[UIApplication sharedApplication] endBackgroundTask:bgTask];
                          }
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
    [self postEvent: event withData: data retry: YES success: nil failure: nil];
}

- (void)tryPostEvent:(NSString *)event withData:(id)data {
    [self postEvent: event withData: data retry: NO success: nil failure: nil];
}

- (void)filterTag:(NSString *)tag {
    [_filteredTags addObject: tag];
}

- (void)unfilterTag:(NSString*)tag {
    [_filteredTags removeObject: tag];
}

- (BOOL)checkMessageTags:(QwasiMessage*)message{
    
    BOOL filtered = NO;
    
    for (NSString* tag in message.tags) {
        
        if ([_filteredTags indexOfObject: tag] != NSNotFound) {
            
            [self emit: [NSString stringWithFormat: @"tag#%@", tag], message];
            
            filtered = YES;
        }
    }
    
    return filtered;
}

- (void)postEvent:(NSString*)event
         withData:(id)data
          success:(void(^)(void))success
          failure:(void(^)(NSError* err))failure {
    [self postEvent: event withData: data retry: YES success: success failure: failure];
}

- (void)postEvent:(NSString*)event
         withData:(id)data
            retry:(BOOL)retry
          success:(void(^)(void))success
          failure:(void(^)(NSError* err))failure {
    
    static int backlog = 0;
    
    if (data == nil) {
        data = @{};
    }
    
    if (_registered) {
        
        UIBackgroundTaskIdentifier bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler: nil];
        
        [_client invokeMethod: @"event.post"
               withParameters: @{ @"device": _deviceToken,
                                  @"type": event,
                                  @"data": data }
                        retry: retry
                      success:^(AFHTTPRequestOperation *operation, id responseObject) {
                          
                          if (success) success();
                          
                          if (bgTask != UIBackgroundTaskInvalid) {
                              [[UIApplication sharedApplication] endBackgroundTask:bgTask];
                          }
                          
                      } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                          
                          error = [QwasiError postEvent: event failedWithReason: error];
                          
                          if (failure) failure(error);
                          
                          [self emit: @"error", error];
                          
                          if (bgTask != UIBackgroundTaskInvalid) {
                              [[UIApplication sharedApplication] endBackgroundTask:bgTask];
                          }
                      }];
        
    }
    else {
        backlog++;
        
        if (backlog > 10) {
            NSError* error = [QwasiError postEvent: event failedWithReason: [QwasiError deviceNotRegistered]];
            
            if (failure) {
                failure(error);
            }
            
            [self emit: @"error", error];
        }
        else {
            [self once: @"registered" listener: ^(NSString *deviceToken) {
                
                backlog--;
                
                [self postEvent: event withData: data retry: retry success: success failure: failure];
            }];
        }
    }
}

- (void)postDLR:(NSString*)msgId
       withType:(NSString*)dlrType
    withContext:(id)context {
    
    [self postEvent: @"com.qwasi.message.dlr"
           withData: @{ @"type" : dlrType,
                        @"to" : [self deviceToken],
                        @"user_token" : [self userToken],
                        @"context" : context,
                        @"proto" : @"push.apns",
                        @"addr" : [[QwasiNotificationManager shared] pushToken],
                        @"message" : msgId}
     ];
    
}

- (void)acknowledge:(NSString*)msgId
        withContext:(id)context{
    [self postDLR: msgId withType: @"ack" withContext: context];
}

- (void)fetchLocationsNear:(CLLocation*)location
                   success:(void(^)(NSArray* locations))success
                   failure:(void(^)(NSError* err))failure {
    if (_registered) {
        
        UIBackgroundTaskIdentifier bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler: nil];
        
        [_client invokeMethod: @"location.fetch"
               withParameters: @{ @"near": @{ @"lng": [NSNumber numberWithDouble: location.coordinate.longitude],
                                              @"lat": [NSNumber numberWithDouble: location.coordinate.latitude],
                                              @"radius": [NSNumber numberWithDouble: _locationSyncFilter * 10] },
                                  @"options": @{ @"schema": @"2.0" },
                                  @"limit": [NSNumber numberWithInt: 20] }
                      success:^(AFHTTPRequestOperation *operation, id responseObject) {
                          
                          if (success) {
                              NSArray* response = (NSArray*)responseObject;
                              NSInteger count = [[response valueForKey: @"length"] integerValue];
                              NSDictionary* values = [response valueForKey: @"value"];
                              NSMutableArray* locations = [[NSMutableArray alloc] init];
                              
                              NSLog(@"Fetched %lu locations from server.", (unsigned long)count);
                              
                              for (NSDictionary* data in values) {
                                  QwasiLocation* _loc = [[QwasiLocation alloc] initWithLocationData: data];
                                  
                                  if ((_loc.type != QwasiLocationTypeBeacon) ||
                                      [_loc.vendor isEqualToString: @"ibeacon"]) {
                                      
                                      [locations addObject: _loc];
                                  }
                                  else {
                                      NSLog(@"Ignoring unsupported location %@", _loc);
                                  }
                              }
                              
                              success(locations);
                          }
                          
                          if (bgTask != UIBackgroundTaskInvalid) {
                              [[UIApplication sharedApplication] endBackgroundTask:bgTask];
                          }
                          
                      } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                          
                          error = [QwasiError locationFetchFailed: error];
                          
                          if (failure) failure(error);
                          
                          [self emit: @"error", error];
                          
                          if (bgTask != UIBackgroundTaskInvalid) {
                              [[UIApplication sharedApplication] endBackgroundTask:bgTask];
                          }
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
                          
                          NSLog(@"Subscribed to channel %@ for application %@.", channel, _applicationName);
                          
                          if (![_channels containsObject: channel]) {
                              [_channels addObject: channel];
                          }
                          
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
        NSError* error = [QwasiError channel: channel subscribeFailed: [QwasiError deviceNotRegistered]];
        
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
                          
                          NSLog(@"Unsubscribed to channel %@ for application %@.", channel, _applicationName);
                          
                          if ([_channels containsObject: channel]) {
                              [_channels removeObject: channel];
                          }
                          
                          if (success) {
                              success();
                          }
                          
                      } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                          
                          error = [QwasiError channel: channel unsubscribeFailed: error];
                          
                          if (failure) failure(error);
                          
                          [self emit: @"error", error];
                      }];
        
    }
    else {
        NSError* error = [QwasiError channel: channel unsubscribeFailed: [QwasiError deviceNotRegistered]];
        
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
        NSError* error = [QwasiError setDeviceDataForKey: key failed: [QwasiError deviceNotRegistered]];
        
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
        NSError* error = [QwasiError getDeviceDataForKey: key failed: [QwasiError deviceNotRegistered]];
        
        if (failure) {
            failure(error);
        }
        
        [self emit: @"error", error];
    }
}

- (void)setMemberValue:(id)value forKey:(NSString*)key
               success:(void(^)(void))success
               failure:(void(^)(NSError* err))failure {
    if (_registered) {
        
        [_client invokeMethod: @"member.set"
               withParameters: @{ @"id": _userToken,
                                  @"key": key,
                                  @"value": value }
                      success:^(AFHTTPRequestOperation *operation, id responseObject) {
                          
                          if (success) {
                              success();
                          }
                          
                      } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                          
                          error = [QwasiError setMemberDataForKey: key failed: error];
                          
                          if (failure) failure(error);
                          
                          [self emit: @"error", error];
                      }];
        
    }
    else {
        NSError* error = [QwasiError setMemberDataForKey: key failed: [QwasiError deviceNotRegistered]];
        
        if (failure) {
            failure(error);
        }
        
        [self emit: @"error", error];
    }
}

- (void)setMemberValue:(id)value forKey:(NSString*)key {
    [self setMemberValue: value forKey: key success: nil failure: nil];
}

- (void)memberValueForKey:(NSString*)key
                  success:(void(^)(id value))success
                  failure:(void(^)(NSError* err))failure {
    if (_registered) {
        
        [_client invokeMethod: @"member.get"
               withParameters: @{ @"id": _userToken,
                                  @"key": key }
                      success:^(AFHTTPRequestOperation *operation, id responseObject) {
                          
                          if (success) {
                              success(responseObject);
                          }
                          
                      } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                          
                          error = [QwasiError getMemberDataForKey: key failed: error];
                          
                          if (failure) failure(error);
                          
                          [self emit: @"error", error];
                      }];
        
    }
    else {
        NSError* error = [QwasiError getMemberDataForKey: key failed: [QwasiError deviceNotRegistered]];
        
        if (failure) {
            failure(error);
        }
        
        [self emit: @"error", error];
    }
}

- (void)memberSetUserName:(NSString*)username
             withPassword:(NSString*)password
      withCurrentPassword:(NSString*)currentPassword
                  success:(void(^)(void))success
                  failure:(void(^)(NSError* err))failure
{
    if (_registered) {
        
        [_client invokeMethod: @"member.set_auth"
               withParameters: @{ @"id": _userToken,
                                  @"username": username,
                                  @"password": password,
                                  @"current": currentPassword }
                      success:^(AFHTTPRequestOperation *operation, id responseObject) {
                          
                          if (success) {
                              success();
                          }
                          
                      } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                          
                          error = [QwasiError setMemberAuthFailed: error];
                          
                          if (failure) failure(error);
                          
                          [self emit: @"error", error];
                      }];
        
    }
    else {
        NSError* error = [QwasiError setMemberAuthFailed: [QwasiError deviceNotRegistered]];
        
        if (failure) {
            failure(error);
        }
        
        [self emit: @"error", error];
    }
}

- (void)memberAuthUser:(NSString*)username
          withPassword:(NSString*)password
               success:(void(^)(void))success
               failure:(void(^)(NSError* err))failure {
    if (_registered) {
        
        [_client invokeMethod: @"member.auth"
               withParameters: @{ @"id": _userToken,
                                  @"username": username,
                                  @"password": password
                                  }
                      success:^(AFHTTPRequestOperation *operation, id responseObject) {
                          
                          if (success) {
                              success();
                          }
                          
                      } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                          
                          error = [QwasiError authMemberFailed: error];
                          
                          if (failure) failure(error);
                          
                          [self emit: @"error", error];
                      }];
        
    }
    else {
        NSError* error = [QwasiError authMemberFailed: [QwasiError deviceNotRegistered]];
        
        if (failure) {
            failure(error);
        }
        
        [self emit: @"error", error];
    }
    
}

- (void)zeroDataRequest:(NSString*)url
                   port:(NSString*)port
                success:(void(^)(NSData* data))success
                failure:(void(^)(NSError* err))failure {
    
    NSString* path = [[NSBundle mainBundle] pathForResource:@"Qwasi" ofType:@"plist"];
    NSDictionary *rawProxyInfo = [NSDictionary dictionaryWithContentsOfFile: path];
    
    if(rawProxyInfo[@"zeroDataProxy"]){
        
        NSURLSessionConfiguration *customConf = [NSURLSessionConfiguration ephemeralSessionConfiguration];
        
        NSDictionary *refinedProxy = @{
                                     (NSString*) kCFNetworkProxiesHTTPEnable: (NSNumber*)@1,
                                     (NSString*) kCFNetworkProxiesHTTPProxy: rawProxyInfo[@"zeroDataProxy"],
                                     (NSString*) kCFNetworkProxiesHTTPPort: [NSNumber numberWithInteger: [rawProxyInfo[@"zeroDataProxyPort"] integerValue]],
                                     };
        
        NSString* authString = [NSString stringWithFormat: @"%@:%@",rawProxyInfo[@"appId"], rawProxyInfo[@"apiKey"]];
        NSData* authData = [authString dataUsingEncoding:NSUTF8StringEncoding];
        NSData* encodedCred = [authData base64EncodedDataWithOptions:nil];
        NSString* completedAuth = [NSString stringWithFormat:@"Basic %@",encodedCred];
        

        customConf.connectionProxyDictionary = refinedProxy;
        customConf.HTTPAdditionalHeaders = @{ @"Authorization" : completedAuth};
        
        NSURLSession* ZDSession = [NSURLSession sessionWithConfiguration: customConf];
        
        //Check if they have not given us a port to connect to specifically, if not remove the port from the string
        NSURLRequest* ZDRequest = port ? [NSURLRequest requestWithURL: [NSURL URLWithString: [NSString stringWithFormat: @"%@:%@", url, port]]] : [NSURLRequest requestWithURL: [NSURL URLWithString: [NSString stringWithFormat: @"%@", url]]];
        
        NSURLSessionDataTask* ZDSessionTask = [ZDSession dataTaskWithRequest:ZDRequest completionHandler:
                                               ^(NSData * data, NSURLResponse * response, NSError * error) {
                                                   
                                                   NSLog(@"Completed session with response: %@ ", response);
                                                   
                                                   error ? failure(error) : NSLog(@"Completed with no errors");
                                                   
                                                   data ? success(data) : NSLog( @"Retrieved no data" );
                                               }];
        [ZDSessionTask resume];
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

- (NSArray*)channels {
    return [NSArray arrayWithArray: _channels];
}

- (void)sendMessage:(QwasiMessage*)message
        toUserToken:(NSString*)userToken {
    [self sendMessage: message toUserToken: userToken success: nil failure: nil];
}
@end
