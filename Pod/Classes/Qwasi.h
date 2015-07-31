//
//  Qwasi.h
//  Pods
//
//  Created by Robert Rodriguez on 6/2/15.
//
//

#import <Foundation/Foundation.h>

#import "QwasiError.h"
#import "QwasiConfig.h"
#import "QwasiClient.h"
#import "QwasiMessage.h"
#import "QwasiNotificationManager.h"
#import "QwasiLocationManager.h"
#import <CocoaLumberjack/CocoaLumberjack.h>
#import <Emitter/Emitter.h>

extern NSString* const kEventApplicationState;
extern NSString* const kEventLocationUpdate;
extern NSString* const kEventLocationEnter;
extern NSString* const kEventLocationExit;

@interface Qwasi : NSObject

@property (nonatomic,readonly) BOOL registered;
@property (nonatomic,readwrite) QwasiConfig* config;
@property (nonatomic,readonly) QwasiClient* client;
@property (nonatomic,readwrite) QwasiLocationManager* locationManager;
@property (nonatomic,readonly) NSString* applicationName;
@property (nonatomic,readonly) NSString* deviceToken;
@property (nonatomic,readonly) NSArray* channels;
@property (nonatomic,readwrite) NSString* userToken;
@property (nonatomic,readwrite) BOOL pushEnabled;
@property (nonatomic,readwrite) BOOL locationEnabled;
@property (nonatomic,readwrite) BOOL useLocalNotifications;
@property (nonatomic,readwrite) CLLocationDistance locationUpdateFilter;
@property (nonatomic,readwrite) CLLocationDistance locationEventFilter;
@property (nonatomic,readwrite) CLLocationDistance locationSyncFilter;
@property (nonatomic,readonly) QwasiLocation* lastLocation;

+ (instancetype)shared;

+ (NSString*)version;

- (id)initWithConfig:(QwasiConfig*)config;

- (void)registerDevice:(NSString*)deviceToken
              withName:(NSString*)name
         withUserToken:(NSString*)userToken
          withUserInfo:(NSDictionary*)userInfo
               success:(void(^)(NSString* deviceToken))success
               failure:(void(^)(NSError* err))failure;

- (void)registerDevice:(NSString*)deviceToken
              withName:(NSString*)name
         withUserToken:(NSString*)userToken
          withUserInfo:(NSDictionary*)userInfo
               success:(void(^)(NSString* deviceToken))success;

- (void)registerDevice:(NSString*)deviceToken
              withName:(NSString*)name
         withUserToken:(NSString*)userToken
               success:(void(^)(NSString* deviceToken))success;

- (void)registerDevice:(NSString*)deviceToken
         withUserToken:(NSString*)userToken
               success:(void(^)(NSString* deviceToken))success;

- (void)registerDevice:(NSString*)deviceToken
         withUserToken:(NSString*)userToken
          withUserInfo:(NSDictionary*)userInfo
               success:(void(^)(NSString* deviceToken))success;

- (void)registerDevice:(NSString*)deviceToken
               success:(void(^)(NSString* deviceToken))success;

- (void)registerDevice:(NSString*)deviceToken
         withUserToken:(NSString*)userToken;

- (void)registerDevice:(NSString*)deviceToken;

- (void)unregisterDevice:(NSString*)deviceToken
                 success:(void(^)())success
                 failure:(void(^)(NSError* err))failure;

- (void)registerForNotifications:(void(^)(NSString* pushToken))success
                         failure:(void(^)(NSError* err))failure;

- (void)unregisterForNotifications:(void(^)())success
                           failure:(void(^)(NSError* err))failure;

- (void)fetchMessageForNotification:(NSDictionary*)userInfo
                            success:(void(^)(QwasiMessage* message))success
                            failure:(void(^)(NSError* err))failure;

- (void)fetchUnreadMessage:(void(^)(QwasiMessage* message))success
                   failure:(void(^)(NSError* err))failure;

- (void)postEvent:(NSString*)event
         withData:(id)data
          success:(void(^)(void))success
          failure:(void(^)(NSError* err))failure;

- (void)postEvent:(NSString*)event
         withData:(id)data;

- (void)fetchLocationsNear:(CLLocation*)location
                   success:(void(^)(NSArray* locations))success
                   failure:(void(^)(NSError* err))failure;

- (void)subscribeToChannel:(NSString*)channel;

- (void)subscribeToChannel:(NSString*)channel
                   success:(void(^)(void))success
                   failure:(void(^)(NSError* err))failure;

- (void)unsubscribeFromChannel:(NSString*)channel;

- (void)unsubscribeFromChannel:(NSString*)channel
                       success:(void(^)(void))success
                       failure:(void(^)(NSError* err))failure;

- (void)setDeviceValue:(id)value forKey:(NSString*)key
               success:(void(^)(void))success
               failure:(void(^)(NSError* err))failure;

- (void)setDeviceValue:(id)value forKey:(NSString*)key;

- (void)deviceValueForKey:(NSString*)key
                  success:(void(^)(id value))success
                  failure:(void(^)(NSError* err))failure;

- (void)filterTag:(NSString*)tag;
- (void)unfilterTag:(NSString*)tag;

- (void)sendMessage:(QwasiMessage*)message
        toUserToken:(NSString*)userToken
            success:(void(^)())success
            failure:(void(^)(NSError* err))failure;

- (void)sendMessage:(QwasiMessage*)message
        toUserToken:(NSString*)userToken;

@end
