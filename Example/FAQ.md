## Qwasi Development Best Practices

The following are some best practices that we have implemented in our reference and example applications. It is recommended that developers follow these practices when implementing applications that use the Qwasi SDKs and libraries.

### Notifications
It is important to understand that push notifications are not guaranteed by the push providers. However, by following these best practices you can ensure your application will recieve the message and rich content even when provider issues arise. Qwasi stores messages temporarily in a device inbox before sending a push notification, so message can be retrieved through other means as described below. Most customers use our AIM platform, this the typical message flow.


AIM --> message.send --> [device inbox] --> notification sent --> notification received <-- message.fetch --> [application]


#### Conditions that may prevent a push from being recieved

**Client Side**

1. The user has disabled push notifications (did not allow, set do not disturb, etc)
2. Network connectivity is not avaiable for the device
3. The device was powered off
4. The application is not running
5. Improper configuration of Qwasi libary

**Server Side**

1. The provider services ([Apple](https://developer.apple.com/system-status/), Google, etc) are not available
2. Certificates have expired or are missing
3. The Qwasi messaging queues are full and causing delays


#### Recommendations

These are some tips to ensure you recieve messages pushed through the Qwasi platform.

##### APNS (iOS Push)

These suggestions are specific to the iOS platform.

###### 1. Enable background notifications

In XCode in your target capabilities, under Background Modes, select "Remote Notifications".

This will allow the operating system to "wakeup" the app in the background to processing an incoming notification.

###### 2. Enable background app refresh

In XCode in your target capabilities, under Background Modes, select "Background fetch".

This will cause the operating system to periodically "wakeup" your application to fetch a missed notification. This is not guaranteed by the OS and will be limited by things like battery life and network connectivity.

##### All platforms

1. Periodically poll of notifications.

[iOS] (https://github.com/qwasi/ios-library/tree/develop#message-polling) allows you to perform actions when the application becomes active in the foreground, you can use this to poll for messages that may have been missed due to the issues describe above.

```objectivec

- (void)myMessagePoller {
	[qwasi fetchUnreadMessage:^(QwasiMessage *message) {
		// Pass the message to your default message handler
		[qwasi emit: @"message", message];

		// keep calling until we have no more unread messages
		[self myMessagePoller];

    } failure:^(NSError *err) {
        // You can set this block to nil if you want the error do go to your default error listener
        // The error is typically no more messages
    }];

}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    ...
	[self myMessagePoller];
   }
```

[Android](https://github.com/qwasi/android-sdk#message-polling) provides a simular callback onStart.

```java

private void myPoller() {
	qwasi.fetchUnreadMessage(new QwasiInterface(){
    	@Override
    	public void onSuccess(Object QwasiMessage){
       		 //push message to screen
			myPoller();
        	}
    	public void onFailure(QwasiError Error){
       	 //error handling
        }
    });
}

protected void onStart(){
    ...
	myPoller();
 }
```

#### Troubleshooting
##### 1. Why am I not getting background push?

###### iOS
If the application is in the force-closed state, it will not be woken up to process the push notification, which is required to fetch the rich content, unless the user taps the notificaton in the Notification center.

###### Android
If the application is terminated, its push listener is not running, so not push will be recieved by the application. 

##### 2. Why is my app not getting startup messages?

This is really only an iOS issue, if the user selects a notification from the iOS Notification Center and the app is NOT executing (force closed, etc), it is likely there is a race condition. Please see the [Example] (https://github.com/qwasi/ios-library/blob/develop/Example/Qwasi/AppDelegate.m). Not that event emitters need to be register prior to the **registerDevice** call, in order to ensure any event that occur during registration or recieved. 


### Channels

Qwasi recommends always subscribing your members to a channel as the most effective means to communicating with groups. Creating a default channel like *ALL_MEMBERS* would allow for a simple method of sending a blast to everyone.

[iOS](https://github.com/qwasi/ios-library/tree/develop#message-channels)

```objectivec
 [qwasi subscribeToChannel:@"ALL_MEMBERS"];
```

[Android] (https://github.com/qwasi/android-sdk#message-channels)

```java
   qwasi.subscribeToChannel("ALL_MEMBERS");
```








