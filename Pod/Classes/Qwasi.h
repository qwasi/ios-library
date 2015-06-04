//
//  Qwasi.h
//  Pods
//
//  Created by Robert Rodriguez on 6/2/15.
//
//

#import <Foundation/Foundation.h>

#import "QwasiConfig.h"
#import "QwasiMessage.h"
#import "Emitter.h"

@interface Qwasi : NSObject

#define E_QWASI_DEVICE_NOT_REGISTERED   -1000
#define E_QWASI_INVALID_MESSAGE         -1001

@property (nonatomic,readonly) BOOL registered;
@property (nonatomic,readwrite) QwasiConfig* config;
@property (nonatomic,readonly) NSString* pushToken;
@property (nonatomic,readonly) NSString* deviceToken;

+ (instancetype)shared;

- (void)registerDevice:(NSString*)deviceToken
              withName:(NSString*)name
         withUserToken:(NSString*)userToken
               success:(void(^)(NSString* deviceToken))success
               failure:(void(^)(NSError* err))failure;

- (void)registerForNotifications:(void(^)(NSString* pushToken))success
                         failure:(void(^)(NSError* err))failure;

- (void)fetchMessageForNotification:(NSDictionary*)userInfo
                            success:(void(^)(QwasiMessage* message))success
                            failure:(void(^)(NSError* err))failure;

- (void)fetchUnreadMessage:(void(^)(QwasiMessage* message))success
                   failure:(void(^)(NSError* err))failure;

- (void)postEvent:(NSString*)event
         withData:(NSDictionary*)data
          success:(void(^)(void))success
          failure:(void(^)(NSError* err))failure;

@end
