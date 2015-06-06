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

#define USER_TOKEN @"201-867-5309"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Setup the logger so we can see what the API is doing
    [DDLog addLogger:[DDTTYLogger sharedInstance]];
    
    // Get our device token from the defaults
    NSString* deviceToken = [[NSUserDefaults standardUserDefaults] valueForKey: @"deviceToken"];
    
    // Register the device with Qwasi
    [[Qwasi shared] registerDevice: deviceToken withUserToken: USER_TOKEN success: ^(NSString *deviceToken) {
        
        // We need to store this for later as this is our unique device identifier
        [[NSUserDefaults standardUserDefaults] setValue: deviceToken forKey: @"deviceToken"];
        
        // Enable push services
        [Qwasi shared].pushEnabled = YES;
        
        // The default is for foreground location only, set the location manager to get background updates
        [Qwasi shared].locationManager = [QwasiLocationManager backgroundManager];
        [Qwasi shared].locationEnabled = YES; 
    }];
    
    [[Qwasi shared] on: @"error" listener: ^(NSError* error) {
        // Handle Errors here
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
        DDLogInfo(@"Got a message: %@", message);
    }];
    
    // Location updates
    [[Qwasi shared] on: @"location" listener: ^(QwasiLocation* location, QwasiLocationState state) {
    
        switch (location.type) {
            case QwasiLocationTypeCoordinate:
                DDLogInfo(@"Location updated: %@", location);
                break;
                
            case QwasiLocationTypeGeofence:
            case QwasiLocationTypeBeacon:
                if (state == QwasiLocationStateInside) {
                    DDLogInfo(@"Entered location %@.", location.name);
                }
                else {
                    DDLogInfo(@"Exited location %@.", location.name);
                }
                break;
                
            default:
                break;
        }

    }];
    
    return YES;
}

@end
