//
//  AppDelegate.m
//  Qwasi
//
//  Created by CocoaPods on 06/02/2015.
//  Copyright (c) 2014 Rob Rodriguez. All rights reserved.
//

#import "AppDelegate.h"
#import "Qwasi.h"

#define USER_TOKEN          @"201-867-5309"
#define DEVICE_TOKEN_KEY    @"deviceToken"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Setup the logger so we can see what the API is doing
    [DDLog addLogger:[DDTTYLogger sharedInstance]];
    
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
        
        QwasiMessage* welcome = [[QwasiMessage alloc] initWithAlert: @"sup foo" withPayload: @"not much" withPayloadType: @"text/plain" withTags: nil];
        
        [[Qwasi shared] sendMessage: welcome toUserToken: USER_TOKEN];
        
        [[Qwasi shared] setDeviceValue: @"rodriguise" forKey: @"user.displayname" success:^{
            [[Qwasi shared] deviceValueForKey: @"user.displayname" success:^(id value) {
                NSLog(@"%@", value);
            } failure:^(NSError *err) {
                
            }];
        } failure:^(NSError *err) {
            
        }];
    }];
    
    [[Qwasi shared] on: @"error" listener: ^(NSError* error) {
        // Handle Errors here (see QwasiError.h)
        if (error.domain == kQwasiErrorDomain) {
            switch (error.code) {
                default:
                    break;
            }
        }
        
        DDLogError(@"%@", error);
    }];
    
    // Add a message handler anywhere in code
    [[Qwasi shared] on: @"message" listener: ^(QwasiMessage* message) {
        
        if (message.selected) {
            DDLogInfo(@"Opened application %@ message: %@", message.application, message);
        }
        else {
            DDLogInfo(@"Got application %@ message: %@", message.application, message);
        }
    }];
    
    // Location updates
    [[Qwasi shared] on: @"location" listener: ^(QwasiLocation* location, QwasiLocationState state) {
    
        switch (location.type) {
            case QwasiLocationTypeCoordinate:
                DDLogInfo(@"Location updated: %@", location);
                break;
                
            case QwasiLocationTypeGeofence:
                if (state == QwasiLocationStateInside) {
                    DDLogInfo(@"Entered location %@.", location.name);
                }
                else {
                    DDLogInfo(@"Exited location %@.", location.name);
                }
                break;
                
            case QwasiLocationTypeBeacon:
                if (state == QwasiLocationStateInside) {
                    DDLogInfo(@"Triggered beacon %@.", location.name);
                }
                else {
                    DDLogInfo(@"Cleared beacon %@.", location.name);
                }
                break;
                
            default:
                break;
        }

    }];

    return YES;
}

@end
