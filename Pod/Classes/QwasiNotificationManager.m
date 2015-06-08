//
//  QwasiNotificationManager.m
//  Pods
//
//  Created by Robert Rodriguez on 6/7/15.
//
//

#import "QwasiNotificationManager.h"
#import "QwasiError.h"
#import "QwasiMessage.h"
#import "Emitter.h"
#import "CocoaLumberjack.h"
#import "NSObject+STSwizzle.h"

typedef void (^fetchCompletionHander)(UIBackgroundFetchResult result);

@implementation QwasiNotificationManager {
    BOOL _registering;
}
+ (void)load {
    [QwasiNotificationManager shared];
}

+ (instancetype)shared {
    static dispatch_once_t once;
    static id sharedInstance = nil;
    
    dispatch_once(&once, ^{
        sharedInstance = [[QwasiNotificationManager alloc] init];
    });
    
    return sharedInstance;
}

- (id)init {
    if (self = [super init]) {
        
    }
    return self;
}

- (void)registerForRemoteNotification {
    
    if (_pushToken) {
        [self emit: @"pushToken", _pushToken];
    }
    else {
        
        @synchronized(self) {
            if (_registering) {
                return;
            }
            _registering = YES;
        }
        
        static dispatch_once_t once;
        UIApplication* application = [UIApplication sharedApplication];
        NSObject* appDelegate = application.delegate;
        
        dispatch_once(&once, ^{
            // Add hooks for push notifications
            [appDelegate replaceMethodForSelector: @selector(application:didRegisterForRemoteNotificationsWithDeviceToken:)
                                   orAddWithTypes:"v@:@@"
                                   implementation:^(id _self, UIApplication* _unused, NSData* token)
             {
                 const unsigned *tokenBytes = [token bytes];
                 
                 _pushToken = [NSString stringWithFormat:@"%08x%08x%08x%08x%08x%08x%08x%08x",
                               ntohl(tokenBytes[0]), ntohl(tokenBytes[1]), ntohl(tokenBytes[2]),
                               ntohl(tokenBytes[3]), ntohl(tokenBytes[4]), ntohl(tokenBytes[5]),
                               ntohl(tokenBytes[6]), ntohl(tokenBytes[7])];
                 
                 [self emit: @"pushToken", _pushToken];
                 
                 [_self callOnSuper:^{
                     if ([_self respondsToSelector:@selector(application:didRegisterForRemoteNotificationsWithDeviceToken:)]) {
                         [_self application: application didRegisterForRemoteNotificationsWithDeviceToken: token];
                     }
                 }];
             }];
            
            // Add hooks for push notifications
            [appDelegate replaceMethodForSelector: @selector(application:didRegisterUserNotificationSettings:)
                                   orAddWithTypes:"v@:@@"
                                   implementation:^(id _self, UIApplication* _unused, UIUserNotificationSettings* settings)
             {
                 if (settings.types & UIUserNotificationTypeAlert) {
                     [application registerForRemoteNotifications];
                 }
                 else {
                     [self emit: @"error", [QwasiError pushNotEnabled]];
                 }
                 
                 [_self callOnSuper:^{
                     if ([_self respondsToSelector:@selector(application:didRegisterUserNotificationSettings:)]) {
                         [_self application: application didRegisterUserNotificationSettings: settings];
                     }
                 }];
             }];
            
            [appDelegate replaceMethodForSelector: @selector(application:didFailToRegisterForRemoteNotificationsWithError:)
                                   orAddWithTypes:"v@:@@"
                                   implementation:^(id _self, UIApplication* _unused, NSError* error)
             {
                 DDLogError(@"Push registration failed: %@.", error);
                 
                 [self emit: @"error", [QwasiError pushRegistrationFailed: error]];
                 
                 [_self callOnSuper:^{
                     if ([_self respondsToSelector:@selector(application:didFailToRegisterForRemoteNotificationsWithError:)]) {
                         [_self application: application didFailToRegisterForRemoteNotificationsWithError: error];
                     }
                 }];
             }];
            
            [appDelegate replaceMethodForSelector: @selector(application:didReceiveRemoteNotification:fetchCompletionHandler:)
                                   orAddWithTypes:"v@:@@@"
                                   implementation: ^(id _self, UIApplication* _unused, NSDictionary* userInfo, fetchCompletionHander completionHandler)
             {
                 [self emit: @"notification", userInfo];
                 
                 [_self callOnSuper:^{
                     if ([_self respondsToSelector:@selector(application:didReceiveRemoteNotification:fetchCompletionHandler:)]) {
                         [_self application: application didReceiveRemoteNotification: userInfo fetchCompletionHandler: completionHandler];
                     }
                     else if (completionHandler) {
                         completionHandler(UIBackgroundFetchResultNewData);
                     }
                 }];
             }];
            
            [appDelegate replaceMethodForSelector: @selector(application:didReceiveLocalNotification:)
                                   orAddWithTypes:"v@:@@@"
                                   implementation: ^(id _self, UIApplication* _unused, UILocalNotification* notification)
             {
                 if (notification.userInfo && notification.userInfo[@"qwasi"]) {
                     QwasiMessage* mesage = [NSKeyedUnarchiver unarchiveObjectWithData: notification.userInfo[@"qwasi"]];
                     
                     [self emit: @"message", mesage];
                 }
                 
                 [_self callOnSuper:^{
                     if ([_self respondsToSelector:@selector(application:didReceiveLocalNotification:)]) {
                         [_self application: application didReceiveLocalNotification: notification];
                     }
                 }];
             }];
        });
        
        if ([application respondsToSelector: @selector(registerUserNotificationSettings:)]) {
            // ios 8+
            
            [application registerUserNotificationSettings: [UIUserNotificationSettings settingsForTypes: UIUserNotificationTypeAlert categories: nil]];
        }
#if __IPHONE_OS_VERSION_MAX_ALLOWED < 80000
        else {
            // ios 7.1+
            [application registerForRemoteNotificationTypes: UIRemoteNotificationTypeAlert];
        }
#endif
    }
}
@end
