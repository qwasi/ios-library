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
#import "Qwasi.h"
#import "NSObject+STSwizzle.h"

typedef void (^fetchCompletionHander)(UIBackgroundFetchResult result);
typedef void (^responseCompletionHandler)(void);
@implementation QwasiNotificationManager {
    BOOL _registering;
    NSDictionary* _launchNotification;
    
}
+ (void)load {
    [QwasiNotificationManager shared];
    
    [[NSNotificationCenter defaultCenter] addObserver: [QwasiNotificationManager shared]
                                            selector :@selector(processLaunchNotification:)
                                                 name: UIApplicationDidFinishLaunchingNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver: [QwasiNotificationManager shared]
                                            selector :@selector(checkNotificationStatus:)
                                                 name: UIApplicationWillEnterForegroundNotification object:nil];
    
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
        
        _pushEnabled = NO;
        
        _customButtons = [NSMutableArray array];
    }
    return self;
}

- (void)processLaunchNotification:(NSNotification*)note {
    
    NSDictionary* userInfo = [note userInfo];
    
    _launchNotification = userInfo[UIApplicationLaunchOptionsRemoteNotificationKey];
}

- (void)checkNotificationStatus:(NSNotification*)note {
    UIApplication* application = [UIApplication sharedApplication];
    
    UIUserNotificationSettings* settings = application.currentUserNotificationSettings;
    
    if (settings.types & UIUserNotificationTypeAlert) {
        if (!_pushEnabled && _pushToken == nil) {
            [application registerForRemoteNotifications];
        } else {
            _pushEnabled = YES;
            [self emit: @"pushToken", _pushToken, nil];
        }
    } else if (_pushEnabled) {
        _pushEnabled = NO;
        [self emit: @"pushToken", _pushToken, [QwasiError pushNotEnabled]];
    }
}

- (NSDictionary*)launchNotification {
    NSDictionary* note = _launchNotification;
    _launchNotification = nil;
    return note;
}

- (void)registerForRemoteNotifications {
    
    if (_pushToken) {
        [self emit: @"pushToken", _pushToken, nil];
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
                 
                 if (!_pushEnabled) {
                     _pushEnabled = YES;
                 
                     [self emit: @"pushToken", _pushToken, nil];
                 }
                 
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
                     _pushEnabled = NO;
                     
                     [self emit: @"pushToken", _pushToken, [QwasiError pushNotEnabled]];
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
                 
                 _pushEnabled = NO;
                 
                 [self emit: @"pushToken", _pushToken, error];
                 
                 [self emit: @"error", [QwasiError pushRegistrationFailed: error]];
                 
                 [_self callOnSuper:^{
                     if ([_self respondsToSelector:@selector(application:didFailToRegisterForRemoteNotificationsWithError:)]) {
                         [_self application: application didFailToRegisterForRemoteNotificationsWithError: error];
                     }
                 }];
             }];
            
            [[Qwasi shared] filterTag: @"QWASI_INTERACTION_SETUP"];
            
            [[Qwasi shared] on: @"tag#QWASI_INTERACTION_SETUP" listener: ^(QwasiMessage* message) {
                
                
                [_customButtons addObjectsFromArray:message.context[@"buttons"]];
                NSMutableArray *customActions = [[NSMutableArray alloc] init];
                
                for ( NSString* button in _customButtons){
                    UIMutableUserNotificationAction *qwasiCustom = [[UIMutableUserNotificationAction alloc] init];
                    qwasiCustom.identifier = button;
                    qwasiCustom.title = button;
                    qwasiCustom.activationMode = UIUserNotificationActivationModeBackground;
                    qwasiCustom.destructive = NO;
                    qwasiCustom.authenticationRequired = NO;
                    [qwasiCustom setBehavior:UIUserNotificationActionBehaviorDefault];
                    
                    [customActions addObject:qwasiCustom];
                }

                
                UIMutableUserNotificationCategory *QwasiInteractionCustomCat = [[UIMutableUserNotificationCategory alloc] init];
                QwasiInteractionCustomCat.identifier = [NSString stringWithString: message.context[@"category"]];
                [QwasiInteractionCustomCat setActions:[customActions subarrayWithRange:NSMakeRange(0, 2)] forContext:UIUserNotificationActionContextMinimal];
                [QwasiInteractionCustomCat setActions:customActions forContext:UIUserNotificationActionContextDefault];
                    
                NSSet *categories = [NSSet setWithObjects:QwasiInteractionCustomCat, application.currentUserNotificationSettings.categories, nil];
                UIUserNotificationType types = (UIUserNotificationType) (UIUserNotificationTypeAlert|
                                                                             UIUserNotificationTypeSound|
                                                                             UIUserNotificationTypeBadge);
                    
                UIUserNotificationSettings *settings;
                settings = [UIUserNotificationSettings settingsForTypes:types
                                                                 categories:categories];
                    
                [application registerUserNotificationSettings:settings];
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
                     QwasiMessage* message = [NSKeyedUnarchiver unarchiveObjectWithData: notification.userInfo[@"qwasi"]];
                     
                     [self emit: @"message", message];
                 }
                 
                 [_self callOnSuper:^{
                     if ([_self respondsToSelector:@selector(application:didReceiveLocalNotification:)]) {
                         [_self application: application didReceiveLocalNotification: notification];
                     }
                 }];
             }];
            
            [appDelegate replaceMethodForSelector:@selector(application:
                                             handleActionWithIdentifier:
                                                  forRemoteNotification:
                                                       withResponseInfo:
                                                      completionHandler:)
                                   orAddWithTypes:"v@:@@"
                                   implementation:^(id _self, UIApplication* _unused, NSString* identifier, NSDictionary* userInfo, NSDictionary* responseInfo, responseCompletionHandler completionHandler){
                 if( [identifier isEqualToString:@"REPLY_IDENT"] ){
                     
                     NSLog( @"Received response - %@", responseInfo[@"UIUserNotificationActionResponseTypedTextKey"]);
                     
                     [[Qwasi shared] fetchMessageForNotification:userInfo success:^(QwasiMessage *message) {
                     
                         [self emit:@"response", message, responseInfo[@"UIUserNotificationActionResponseTypedTextKey"]];
                     
                     } failure:^(NSError *err) {
                     
                         NSLog(@"Failed to refetch message");
                     
                     }];
                 }
                 [_self callOnSuper:^{
                    
                     if ([_self respondsToSelector:@selector(application:handleActionWithIdentifier:forRemoteNotification:withResponseInfo:completionHandler:)]) {
                      
                         [_self application:_unused handleActionWithIdentifier:identifier forRemoteNotification:userInfo withResponseInfo:responseInfo completionHandler:completionHandler];
                    
                     }
                 }];
                 completionHandler();

            }];
            
            [appDelegate replaceMethodForSelector:@selector(application:
                                                            handleActionWithIdentifier:
                                                            forRemoteNotification:
                                                            completionHandler:)
                                   orAddWithTypes:"v@:@@"
                                   implementation:^(id _self, UIApplication* _unused, NSString* identifier, NSDictionary* userInfo, responseCompletionHandler completionHandler){
                                       
                                       if( [identifier isEqualToString:[_customButtons objectAtIndex:0]] ){
                                           
                                           [[Qwasi shared] postEvent:@"com.qwasi.event.message.mo" withData:@{@"selected" : [_customButtons objectAtIndex:0],
                                                                                                              @"message" : userInfo}];                                       }
                                       
                                       if ( [identifier isEqualToString:[_customButtons objectAtIndex:1]] && [_customButtons count] > 1){
                                          
                                           [[Qwasi shared] postEvent:@"com.qwasi.event.message.mo" withData:@{@"selected" : [_customButtons objectAtIndex:1],
                                                                                                              @"message" : userInfo}];
                                           
                                       }
                                       
                                       if ( [identifier isEqualToString:[_customButtons objectAtIndex:2]]&& [_customButtons count] > 2){
                                       
                                           [[Qwasi shared] postEvent:@"com.qwasi.event.message.mo" withData:@{@"selected" : [_customButtons objectAtIndex:2],
                                                                                                              @"message" : userInfo}];
                                           
                                       }
                                       
                                       if ( [identifier isEqualToString:[_customButtons objectAtIndex:3]]&& [_customButtons count] > 3){
                                       
                                           [[Qwasi shared] postEvent:@"com.qwasi.event.message.mo" withData:@{@"selected" : [_customButtons objectAtIndex:3],
                                                                                                              @"message" : userInfo}];
                                           
                                       }
                                       [_self callOnSuper:^{
                                           if ([_self respondsToSelector:@selector(application:handleActionWithIdentifier:forRemoteNotification:withResponseInfo:completionHandler:)]) {
                                               [_self application:_unused handleActionWithIdentifier:identifier forRemoteNotification:userInfo completionHandler:completionHandler];
                                           }
                                       }];
                                       completionHandler();
                                       
                                   }];
        });
        
        if ([application respondsToSelector: @selector(registerUserNotificationSettings:)]) {
            // ios 8+
            UIMutableUserNotificationAction *qwasiMsgReply = [[UIMutableUserNotificationAction alloc] init];
            qwasiMsgReply.identifier = @"REPLY_IDENT";
            qwasiMsgReply.title = @"Reply";
            qwasiMsgReply.activationMode = UIUserNotificationActivationModeBackground;
            qwasiMsgReply.destructive = NO;
            qwasiMsgReply.authenticationRequired = NO;
            [qwasiMsgReply setBehavior:UIUserNotificationActionBehaviorTextInput];
            
            
            UIMutableUserNotificationCategory *QwasiInteractionCat = [[UIMutableUserNotificationCategory alloc] init];
            QwasiInteractionCat.identifier = @"QWASI_INTERACTION_TEXT";
            [QwasiInteractionCat setActions:@[qwasiMsgReply] forContext:UIUserNotificationActionContextMinimal];
            [QwasiInteractionCat setActions:@[qwasiMsgReply] forContext:UIUserNotificationActionContextDefault];
            
            //NSSet *actions = [NSSet setWithObjects:[QwasiInteractionCat actionsForContext:UIUserNotificationActionContextMinimal], nil];
            
            NSSet *categories = [NSSet setWithObject:QwasiInteractionCat];
            UIUserNotificationType types = (UIUserNotificationType) (UIUserNotificationTypeAlert|
                                                                     UIUserNotificationTypeSound|
                                                                     UIUserNotificationTypeBadge);
            
            UIUserNotificationSettings *settings;
            settings = [UIUserNotificationSettings settingsForTypes:types
                                                         categories:categories];
            
            [application registerUserNotificationSettings:settings];

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
