//
//  QwasiNotificationManager.m
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

#import "QwasiNotificationManager.h"
#import "QwasiError.h"
#import "QwasiMessage.h"
#import "NSObject+STSwizzle.h"

typedef void (^fetchCompletionHander)(UIBackgroundFetchResult result);

@implementation QwasiNotificationManager {
    BOOL _registering;
    NSDictionary* _launchNotification;
}
+ (void)load {
    [QwasiNotificationManager shared];
    
    [[NSNotificationCenter defaultCenter] addObserver: [QwasiNotificationManager shared]
                                             selector :@selector(processLaunchNotification:)
                                                 name: UIApplicationDidFinishLaunchingNotification object:nil];
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
#if DEBUG
        _sandbox = YES;
#else
        _sandbox = NO;
#endif
        _pushToken = nil;
    }
    return self;
}

- (void)processLaunchNotification:(NSNotification*)note {
    
    NSDictionary* userInfo = [note userInfo];
    
    _launchNotification = userInfo[UIApplicationLaunchOptionsRemoteNotificationKey];
}

- (void)registerForRemoteNotifications {
    
    // Emit the launch notification if we have one
    if (_launchNotification) {
        [self emit: @"notification", _launchNotification];
        _launchNotification = nil;
    }
    
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
                 NSLog(@"Push registration failed: %@.", error);
                 
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
            UIUserNotificationType types = (UIUserNotificationTypeAlert | UIUserNotificationTypeBadge | UIUserNotificationTypeSound);
            
            [application registerUserNotificationSettings: [UIUserNotificationSettings settingsForTypes: types categories: nil]];
        }
#if __IPHONE_OS_VERSION_MAX_ALLOWED < 80000
        else {
            // ios 7.1+
            [application registerForRemoteNotificationTypes: UIRemoteNotificationTypeAlert | UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound];
        }
#endif
    }
}
@end
