//
//  AppDelegate.m
//  Qwasi
//
//  Created by CocoaPods on 06/02/2015.
//  Copyright (c) 2014 Rob Rodriguez. All rights reserved.
//

#import "AppDelegate.h"
#import "Qwasi.h"

#define USER_TOKEN          @"+14089167525"
#define DEVICE_TOKEN_KEY    @"deviceToken"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [[Qwasi shared] on: @"error" listener: ^(NSError* error) {
        // Handle Errors here (see QwasiError.h)
        if (error.domain == kQwasiErrorDomain) {
            switch (error.code) {
                default:
                    break;
            }
        }
        
        NSLog(@"%@", error);
    }];
    
    // Add a message handler anywhere in code
    [[Qwasi shared] on: @"message" listener: ^(QwasiMessage* message) {
        
        if (message.selected) {
            NSLog(@"Opened application %@ message: %@", message.application, message);
        }
        else {
            NSLog(@"Got application %@ message: %@", message.application, message);
        }
    }];
    
    // Location updates
    [[Qwasi shared] on: @"location" listener: ^(QwasiLocation* location, QwasiLocationState state) {
    
        switch (location.type) {
            case QwasiLocationTypeCoordinate:
                // NSLog(@"Location updated: %@", location);
                break;
                
            case QwasiLocationTypeGeofence:
                if (state == QwasiLocationStateInside) {
                    NSLog(@"Entered location %@.", location.name);
                }
                else if (state == QwasiLocationStateDwell) {
                    NSLog(@"Dwell location %@.", location.name);
                }
                else {
                    NSLog(@"Exited location %@.", location.name);
                }
                break;
                
            case QwasiLocationTypeBeacon:
                if (state == QwasiLocationStateInside) {
                    NSLog(@"Triggered beacon %@.", location.name);
                }
                else if (state == QwasiLocationStateDwell) {
                    NSLog(@"Dwell beacon %@.", location.name);
                }
                else {
                    NSLog(@"Cleared beacon %@.", location.name);
                }
                break;
                
            default:
                break;
        }

    }];
    
    //Example for overriding debug sandbox
    //[QwasiNotificationManager shared].sandbox = YES;
    
    // Get our device token from the defaults
    NSString* deviceToken = [[NSUserDefaults standardUserDefaults] valueForKey: DEVICE_TOKEN_KEY];
    
    // Register the device with Qwasi
    [[Qwasi shared] registerDevice: deviceToken withUserToken: USER_TOKEN success: ^(NSString *deviceToken) {
        
        // We need to store this for later as this is our unique device identifier
        [[NSUserDefaults standardUserDefaults] setValue: deviceToken forKey: DEVICE_TOKEN_KEY];
        
        // Enable push services
        [Qwasi shared].pushEnabled = YES;
        
        // The default is for foreground location only, set the location manager to get background updates
        // [Qwasi shared].locationManager = [QwasiLocationManager backgroundManager];
        [Qwasi shared].locationEnabled = YES;
        
        /*QwasiMessage* welcome = [[QwasiMessage alloc] initWithAlert: @"You have a new message" withPayload: @"Test Message" withPayloadType: @"text/plain" withTags: nil];
         
         // Send ourselves a test message
         [[Qwasi shared] sendMessage: welcome toUserToken: USER_TOKEN];
         
         [[Qwasi shared] setDeviceValue: @"rodriguise" forKey: @"user.displayname" success:^{
         [[Qwasi shared] deviceValueForKey: @"user.displayname" success:^(id value) {
         NSLog(@"%@", value);
         } failure:^(NSError *err) {
         
         }];
         } failure:^(NSError *err) {
         
         }];
         
         [[Qwasi shared] subscribeToChannel: @"SomeChannel" success:^{
         NSLog(@"Did it: %@", [Qwasi shared].channels);
         [[Qwasi shared] unsubscribeFromChannel: @"SomeChannel"];
         } failure:^(NSError *err) {
         
         }];*/
    }];

    return YES;
}

@end
