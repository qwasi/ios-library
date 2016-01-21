# Qwasi

[![Build Status](https://travis-ci.org/qwasi/ios-library.svg?branch=develop)](https://travis-ci.org/qwasi/ios-library)

The Qwasi `ios-library` provides a convenient method for accessing the Qwasi JSON-RPC API.

## Usage

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Requirements

1. XCode 6.1+
2. Cocoapods

## Installation

Qwasi is available from [CocoaPods](http://cocoapods.org/). To install
it, simply add the following lines to your Podfile:

```

pod 'Qwasi', '~>2.1.20'
```
## License

Qwasi is available under the MIT license. See the LICENSE file for more info.

## Pod Dependencies
```
 'AFJSONRPCClient'
 'GBDeviceInfo', '~> 3.1.0'
 'Emitter'
 'QSwizzle', '~> 0.2.0'

```

## Library Initialization `Qwasi`

### Default Shared Qwasi
There is a default singleton Qwasi object that is best for most use cases.

```objectivec
	Qwasi* qwasi = [Qwasi shared];
```

### Allocate a new Qwasi
It would typically be unecessary to create your own `Qwasi` object, but if you need to it is simple.

```objectivec
	Qwasi* qwasi = [[Qwasi alloc] init];
```

## Library Configuration `QwasiConfig`
By default any `Qwasi` instance will attempt to use the default configuration described below. You can explicitly set or change the configuration by setting the config object. Any time you change the configuration you will need to re-register the device.

```objectivec
	qwasi.config = [QwasiConfig default];
```

### Default Configuration

The default configuration file is `Qwasi.plist`. You create and add the property list to your Xcode project and include it in your bundle.

```
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>apiUrl</key>
	<string>https://sandbox.qwasi.com/v1</string>
	<key>apiKey</key>
	<string>Your Key</string>
	<key>appId</key>
	<string>Your id</string>
</dict>
</plist>
```

### Custom Configuration File
You can load a configuration from another property list by using: 

```+ (instancetype)configWithFile:(NSString*)path```

Example:

```objectivec
	QwasiConfig* config = [QwasiConfig configWithFile: @"myconfig"];
	qwasi.config = config;
```

**Note: you should not include the `.plist` extention in the path**

### Runtime Configuration
You can create a runtime configuration object on the fly using:

```objectivec
+ (instancetype)configWithURL:(NSURL*)url withApplication:(NSString*)app withKey:(NSString*)key;
```
Example:

```objectivec
	NSURL* url = [NSURL urlWithString: @"https://sandbox.qwasi.com/v1"];
	QwasiConfig* config = [QwasiConfig configWithURL: url withApplication: @"Your app" withKey: @"Your key"];
	qwasi.config = config;
```
## Event Emitters
The Qwasi libary uses nodejs like emitters to emit events. You can listen for these events by registering a listener using one of the registation methods. 

**Note: It is important that event handlers are registered before the device registration or there maybe a race condition (i.e. events are emitted before the handlers are created***

```objectivec
- (void)on:(id)event listener:(id)listener;
- (void)once:(id)event listener:(id)listener;
- (void)on:(id)event selector:(SEL)selector target:(__weak id)target;
- (void)once:(id)event selector:(SEL)selector target:(__weak id)target;
```
### Handling Incoming Messages
You receive message via the `message` event for your qwasi instance.

Example:

```objectivec
	[qwasi on: @"message" listener: ^(QwasiMessage* message) {
			// Do as you will with the message
	}];	
```
###### SDK Event - "message"
###### SDK Error - `QwasiErrorMessageFetchFailed`
###### API Method - N/A

### Error Handling `QwasiError`
Some methods will have a failure callback parameter, but all methods will emit errors via the `Qwasi` instance. You can register a default error handler on your instance and process errors as needed.

Example:

```objectivec
[qwasi on: @"error" listener: ^(NSError* error) {
        // Handle Errors here (see QwasiError.h)
        if (error.domain == kQwasiErrorDomain) {
            switch (error.code) {
                default:
                    break;
            }
        }
        
        DDLogError(@"%@", error);
    }];
```


## Device Registration
### Device Tokens
Every device that engages with Qwasi requires a unique device token. This token is returned upon calling device register. It should be stored for future calls to device register to ensure you can properly track events for that device. registerDevice only needs to be called once per application start, unless you change the configuration.

There are many `registerDevice` overloads defined in `Qwasi.h`, the simplest and most useful is:

```objectivec
- (void)registerDevice:(NSString*)deviceToken withUserToken:(NSString*)userToken success:(void(^)(NSString* deviceToken))success;
```

Example:

```objectivec
    // Get our device token from the defaults
    NSString* deviceToken = [[NSUserDefaults standardUserDefaults] valueForKey: DEVICE_TOKEN_KEY];

    [qwasi registerDevice: deviceToken withUserToken: USER_TOKEN success: ^(NSString *deviceToken) {
        // We need to store this for later as this is our unique device identifier
        [[NSUserDefaults standardUserDefaults] setValue: deviceToken forKey: DEVICE_TOKEN_KEY];
    }];
```
###### SDK Event - "register"
##### SDK Error - `QwasiErrorDeviceRegistrationFailed`
###### API Method - `device.register`

### User Tokens
User tokens are basically your vendor identifier for this device. Some developers use their customer id or loyalty id number, this allow you to address the devices with this token from the platform. These do not have to be unique and can be used to group devices under a single user token. The default is "".

You can set the user token either via the `deviceRegister` call, or later via the qwasi object.

Example:

```objectivec
	qwasi.userToken = @"My User Token";
```

If the device has not been registered the user token will be updated when registration is called, otherwise it will simply use the 	`device.set_user_token` API call.

###### SDK Event - N/A
###### SDK Error - `QwasiErrorSetUserTokenFailed`
###### API Method - `device.set_user_token`

### Unregistration
Unregistering a device results in the record being fully removed from the Qwasi databases. This is for privacy compliance, etc if the application requires it. Devices should be unregistered execept under these circumstances.

If necessary a device can be unregistered using:

```objectivec
- (void)unregisterDevice:(NSString*)deviceToke success:(void(^)())success failure:(void(^)(NSError* err))failure;
```
###### SDK Event - N/A
###### SDK Error - `QwasiErrorDeviceUnregisterFailed`
###### API Method - `device.unregister`

## Push Notifications
Qwasi supports a simplified registration for push notifications. Once the device is registered you can either set `pushEnabled` on the instance or call the method:

```objectivec
- (void)registerForNotifications:(void(^)())success failure:(void(^)(NSError* err))failure;
```

Example:

```objectivec
	qwasi.pushEnabled = YES;

	// if you want notification for when the push registration completed
	// this event can occur more than once in an app life-cycle
	[qwasi once: @"pushRegistered" listener: ^(NSString* pushToken) {
		// do with the token as you will...	
	}];

	// if you just want notification and the pushToken for youself
	// this even will only occur once per app life-cycle
	[qwasi once: @"pushToken" listener: ^(NSString* pushToken) {
		// do with the token as you will...	
	}];
```

**Note**: The `pushEnabled` flag is asynchrously set, so if you need to use the value, you must do so after you receive one of the completion events in the example, as there is race between when it is actually set internally.

###### SDK Event - "pushToken"
###### SDK Error - `QwasiErrorPushRegistrationFailed`
###### API Method - `device.set_push_token`

### APS Server Override
Development (Debug) build applications will acquire aps sandbox push tokens than only be used with Apple's sandbox push gateway. Likewise production (Release) builds will by default acquire a production push token. This behavior can be overridden the application provisioning profile with something like this in the profile:

```
<key>aps-environment</key>
<string>development</string>
```
Editing this profile is not supported and outside the scope of this document.

The Qwasi Notification Manager will attempt to detect the mode of operation based on the DEBUG preprocessor header. To override this you need to manually set this flag before the initial device register, which will force the servers used by the Qwasi platform to deliver the notifications.

```objectivec
[QwasiNotificationManager shared].sandbox = YES; // or NO to force production
```

### Background Fetch
If the user does not permit push notifications, or if the device does not have network access some notification could be missed. If your app has the backgroud fetch permission, you will still continue to get notification periodically, even if push is disabled. The library will simluate a push by fetching an unread message and creating a UILocalNotification.

### Message Polling
If your app does not support background fetch, you can periodically call:

```objectivec
- (void)fetchUnreadMessage:(void(^)(QwasiMessage* message))success failure:(void(^)(NSError* err))failure;
```
A good place to put this method is in your UIApplicationDelegate.

Example:

```objectivec
- (void)applicationDidBecomeActive:(UIApplication *)application {
	...
    [qwasi fetchUnreadMessage:^(QwasiMessage *message) {

	// If you want to pass the message to your default message handler, do this 
    	[qwasi emit: @"message", message];

    } failure:^(NSError *err) {
        // You can set this block to nil if you want the error do go to your default error listener
    }];
}
```
This method will not generate a notification.

###### SDK Event - "message" (optional)
###### SDK Error - `QwasiErrorMessageFetchFailed`
###### API Method - `message.poll`

### Tag based callbacks
The `qwasi` instance will emit special events for tags contained in a message, these can be used to filter callbacks based on special tags.

Example:

```objectivec
	// call this so messages with this tag won't get emitter to the default message
    // hander as well
	[qwasi filterTag: @"myCustomTag"];

	[qwasi on: @"tag#myCustomTag listener: ^(QwasiMessage* message) {
		// handle the message with the tag
	}];
```

## Message Channels
`Qwasi` AIM supports arbitraty message groups via channels. The API is simple.

### Subscribe to a Channel

```objectivec
- (void)subscribeToChannel:(NSString*)channel;
```

Example:

```objectivec
	[qwasi subscribeToChannel:@"baseball"];
```
###### SDK Event - N/A
###### SDK Error - `QwasiErrorChannelSubscribeFailed`
###### API Method - `channel.subscribe`

### Unsubscribe from Channel

```objectivec
- (void)unsubscribeFromChannel:(NSString*)channel;
```

Example:

```objectivec
	[qwasi unsubscribeFromChannel:@"baseball"];
```
###### SDK Event - N/A
###### SDK Error - `QwasiErrorChannelUnsubscribeFailed`
###### API Method - `channel.unsubscribe`


## Application Events
The `Qwasi` platform supports triggers on application events, but the events have to be provided. By default the library will send application state events (open, foreground, background). You can send custom events and configure your AIM to act on those as you see fit

```objectivec
- (void)postEvent:(NSString*)event withData:(id)data;
```

Example:

```objectivec
	[qwasi postEvent: @"login" withData: @{ @"username": "bobvila" }];
```

## Location
The `Qwasi` SDK can provide device location and track geofence and iBeacon events. The geofences and iBeacon must be preconfigured via the AIM or API interfaces.

### Enabling Location
Location is enabled or disabled via the qwasi instance, once the device has been registered:

```objectivec
	qwasi.locationEnabled = YES;
```

### Location Manager
There can only be one active `QwasiLocationManager`, you must set this before you enable location, the default is the foregroundManager.

```objectivec
	// Default foreground manager
	qwasi.locationManager = [QwasiLocationManager foreground];

	// Or the background manager
	qwasi.locationManager = [QwasiLocationManager background];
```

**Note: once you set a location manager for your app on the initial run, you can change it, but will require the user to access the applications Settings page. You can go from Background (permissive) to Foreground (restrictive) without changing the settings.***

###### SDK Event - N/A
###### SDK Error - `QwasiErrorLocationSyncFailed`
###### API Method - `location.fetch`

### Handling Location Events
Like messages, locations events are delivered via an emitter on your instance.

Example:

```objectivec
	[qwasi on: @"location" listener: ^(QwasiLocation* location, QwasiLocationState state) {
		switch (location.type) {
            case QwasiLocationTypeCoordinate:
                // This is a normal GPS update
                break;
                
            case QwasiLocationTypeGeofence:
                if (state == QwasiLocationStateInside) {
                   // inside a geofence
                }
                else {
                   // now outside the geofence
                }
                break;
                
            case QwasiLocationTypeBeacon:
                if (state == QwasiLocationStateInside) {
                    // hit a beacon
                }
                else {
                    // left the beacon proximty
                }
                break;
                
            default:
                break;
        }
	}];	
```
###### SDK Event - "location"
###### SDK Error - N/A
###### API Method - N/A

## Cloud Data
Qwasi supports a key value based cloud data storage system. This data stored member or device specific. The key can be a deep object path using dot-notication.

### Member Data
Every device is backed by a member record. Member records are identified by a user_token and represent an aggregate record. Data is available accross devices using the same user_token.

#### Set Member Data

```objectivec
- (void)setMemberValue:(id)value forKey:(NSString*)key
               success:(void(^)(void))success
               failure:(void(^)(NSError* err))failure;

- (void)setMemberValue:(id)value forKey:(NSString*)key;
```
###### SDK Event - N/A
###### SDK Error - `QwasiErrorSetMemberDataFailed`
###### API Method - `member.set_data`

#### Get Member Data

```objectivec
- (void)memberValueForKey:(NSString*)key
                  success:(void(^)(id value))success
                  failure:(void(^)(NSError* err))failure;
```
###### SDK Event - N/A
###### SDK Error - `QwasiErrorGetMemberDataFailed`
###### API Method - `member.get_data`

Example:

```objectivec
[qwasi setMemberValue: @"35"
			    forKey: @"age"];

[qwasi memberValueForKey: @"age" 
		              success:^(id value) {
                
				NSLog(@"%@", value);
            } 
			       failure:^(NSError *err) {
            }];				
```
### Device Data
Device data persists to the device, but is also member specific. Therefore if a user_token changes, so does the device specific data set. This allows for multiple users to share a device with their per-device data store.

#### Set Device Data

```objectivec
- (void)setDeviceValue:(id)value forKey:(NSString*)key
               success:(void(^)(void))success
               failure:(void(^)(NSError* err))failure;

- (void)setDeviceValue:(id)value forKey:(NSString*)key;
```
###### SDK Event - N/A
###### SDK Error - `QwasiErrorSetDeviceDataFailed`
###### API Method - `device.set_data`

#### Get Device Data

```objectivec
- (void)deviceValueForKey:(NSString*)key
                  success:(void(^)(id value))success
                  failure:(void(^)(NSError* err))failure;
```
###### SDK Event - N/A
###### SDK Error - `QwasiErrorGetDeviceDataFailed`
###### API Method - `device.get_data`

Example:

```objectivec
[qwasi setDeviceValue: @"hotrod99"
			    forKey: @"user.displayname"];

[qwasi deviceValueForKey: @"user.displayname" 
		              success:^(id value) {
                
				NSLog(@"%@", value);
            } 
			       failure:^(NSError *err) {
            }];				
```
## Sending Message
With the Qwasi API and SDK it is possible to send message to other users, this could facilitate a 2-way communication or chat application. Qwasi does not explictly support this functionality so much of the implementation is left to the developer. You will need to manage mapping your own userTokens to some useful data, which can be stored in the device record as described above.

```objectivec
- (void)sendMessage:(QwasiMessage*)message
        toUserToken:(NSString*)userToken
            success:(void(^)())success
            failure:(void(^)(NSError* err))failure;

- (void)sendMessage:(QwasiMessage*)message
        toUserToken:(NSString*)userToken;
```
###### SDK Event - N/A
###### SDK Error - `QwasiErrorSendMessageFailed`
###### API Method - `message.send`

Example Receiver:

```objectivec
	// filter out our chat tags
	[qwasi filterTag: @"chatMessage"];

	[qwasi on: @"tag#chatMessage" listener: ^(QwasiMessage* message) {
		// handle the message with the tag
		NSString* displayName = [message.payload: @"from"];
		NSLog(@"Got a message from %@", displayName);
	}];
```

Example Sender:

```objectivec
	QwasiMessage* welcome = [[QwasiMessage alloc] initWithAlert: @"You have a new message" 
												   withPayload: @{ @"from": @"myusername" }
											   withPayloadType: nil 
												        withTags: @[@"chatMessage"]];

	[qwasi sendMessage: message toUserToken: @"anotheruser"];
```
