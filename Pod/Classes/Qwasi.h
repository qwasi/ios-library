//
// Qwasi.h
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

#import <Foundation/Foundation.h>

#import "QwasiError.h"
#import "QwasiConfig.h"
#import "QwasiClient.h"
#import "QwasiMessage.h"
#import "QwasiNotificationManager.h"
#import "QwasiLocationManager.h"
#import "EventEmitter.h"

extern NSString* const kEventApplicationState;
extern NSString* const kEventLocationUpdate;
extern NSString* const kEventLocationEnter;
extern NSString* const kEventLocationExit;

/** 
 The `Qwasi` class is the primary class used to interact with the `Qwasi` framework
 
 */
@interface Qwasi : EventEmitter

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

/** Returns a shared Qwasi instance */
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

- (void)tryFetchUnreadMessages;

- (void)postEvent:(NSString*)event
         withData:(id)data
          success:(void(^)(void))success
          failure:(void(^)(NSError* err))failure;

- (void)postEvent:(NSString*)event
         withData:(id)data
            retry:(BOOL)retry
          success:(void(^)(void))success
          failure:(void(^)(NSError* err))failure;

- (void)postEvent:(NSString*)event
         withData:(id)data;

- (void)tryPostEvent:(NSString*)event
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

- (void)setMemberValue:(id)value forKey:(NSString*)key
               success:(void(^)(void))success
               failure:(void(^)(NSError* err))failure;

- (void)setMemberValue:(id)value forKey:(NSString*)key;

- (void)memberValueForKey:(NSString*)key
                  success:(void(^)(id value))success
                  failure:(void(^)(NSError* err))failure;

- (void)memberSetUserName:(NSString*)username
             withPassword:(NSString*)password
      withCurrentPassword:(NSString*)currentPassword
                  success:(void(^)(void))success
                  failure:(void(^)(NSError* err))failure;

- (void)memberAuthUser:(NSString*)username
          withPassword:(NSString*)password
               success:(void(^)(void))success
               failure:(void(^)(NSError* err))failure;

- (void)filterTag:(NSString*)tag;
- (void)unfilterTag:(NSString*)tag;

- (BOOL)checkMessageTags:(QwasiMessage*)message;

- (void)sendMessage:(QwasiMessage*)message
        toUserToken:(NSString*)userToken
            success:(void(^)())success
            failure:(void(^)(NSError* err))failure;

- (void)sendMessage:(QwasiMessage*)message
        toUserToken:(NSString*)userToken;

@end
