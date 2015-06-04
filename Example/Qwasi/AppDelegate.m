//
//  QAppDelegate.m
//  Qwasi
//
//  Created by CocoaPods on 06/02/2015.
//  Copyright (c) 2014 Rob Rodriguez. All rights reserved.
//

#import "AppDelegate.h"
#import "CocoaLumberjack.h"
#import "Qwasi.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Setup the logger so we can see what the API is doing
    [DDLog addLogger:[DDASLLogger sharedInstance]];
    [DDLog addLogger:[DDTTYLogger sharedInstance]];
    
    // Get our device token from the defaults
    NSString* deviceToken = [[NSUserDefaults standardUserDefaults] valueForKey: @"deviceToken"];
    
    // Register the device with Qwasi
    [[Qwasi shared] registerDevice: deviceToken withName: nil withUserToken: nil success: ^(NSString *deviceToken) {
        
        // We need to store this for later as this is our unique device identifier
        [[NSUserDefaults standardUserDefaults] setValue: deviceToken forKey: @"deviceToken"];
        
        // Register for push notifications
        [[Qwasi shared] registerForNotifications:^(NSString *pushToken) {
            
        } failure:^(NSError *err) {
            // Something bad happened, check logs
        }];
    } failure: ^(NSError *err) {
        // Something bad happened, check logs
    }];
    
    // Add a message handler
    [[Qwasi shared] on: @"message" listener: ^(QwasiMessage* message) {
        DDLogInfo(@"Got a message: %@", message);
    }];
    
    return YES;
}
@end
