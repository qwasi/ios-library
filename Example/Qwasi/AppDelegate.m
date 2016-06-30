//
// AppDelegate.m
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

#import "AppDelegate.h"
#import "Qwasi.h"
#define INTERACT            @"QWASI_INTERACTION"
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
    
    void (^myOnMessage)(QwasiMessage* message) = ^(QwasiMessage* message) {
        
        if (message.selected) {
            NSLog(@"Opened application %@ message: %@", message.application, message);
        }
        else {
            NSLog(@"Got application %@ message: %@", message.application, message);
        }
    };
    
    // Add a message handler anywhere in code
    [[Qwasi shared] on: @"message" listener: myOnMessage];
    
    [[Qwasi shared] removeListener: @"message" listener: myOnMessage];

    [[Qwasi shared] on: @"response" listener: ^(QwasiMessage *message, NSString *response){
        [message reply:response];
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
        
        /*[[Qwasi shared] zeroDataRequest:@"http://www.youtube.com" port:@"80" success:^(NSData *data) {
            NSLog(@"We win");
            [[Qwasi shared] emit:@"ZDReceive" args:@[data]];
        } failure:^(NSError *err) {
            NSLog( @"There was an error %@",err);
        }];
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
