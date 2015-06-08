# Qwasi

[![Build Status](https://travis-ci.org/qwasi/ios-library.svg?branch=master)](https://travis-ci.org/qwasi/ios-library)

## Usage

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Requirements

1. XCode 6.1+
2. Cocoapods

## Installation

Qwasi is available from [CocoaPods](http://cocoapods.org/). To install
it, simply add the following lines to your Podfile:

```ruby

pod "Qwasi"
```

## Author

Rob Rodriguez, rob.rodriguez@qwasi.com

## License

Qwasi is available under the MIT license. See the LICENSE file for more info.

## Pod Dependencies
```
 'CocoaLumberjack'
 'AFJSONRPCClient'
 'GBDeviceInfo', '~> 3.1.0'
 'Emitter'
 'QSwizzle', '~> 0.2.0'

```

## Device Tokens

Every device that engages with Qwasi requires a unique device token. This token is returned upon calling device register. It should be stored for future calls to device register to ensure you can properly track events for that device.

## Example Usage
```C
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
        [Qwasi shared].locationManager = [QwasiLocationManager backgroundManager];
        [Qwasi shared].locationEnabled = YES; 
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
        DDLogInfo(@"Got a message: %@", message);
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

```
