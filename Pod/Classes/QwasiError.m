//
//  QwasiError.m
//  Pods
//
//  Created by Robert Rodriguez on 6/5/15.
//
//

#import "QwasiError.h"
#import "QwasiLocation.h"

NSString* const kQwasiErrorDomain = @"com.qwasi.sdk";

@implementation QwasiError

+ (NSError*)errorWithCode:(QwasiErrorCode)code withMessage:(NSString*)message {
    return [self errorWithCode: code withMessage: message withInnerError: nil];
}

+ (NSError*)errorWithCode:(QwasiErrorCode)code withMessage:(NSString*)message withInnerError:(NSError*)error {
    NSMutableDictionary* userInfo = [[NSMutableDictionary alloc] init];

    
    if (error) {
        userInfo[NSLocalizedDescriptionKey] = [NSString stringWithFormat: @"%@ reason=%@", message, error.localizedDescription];
        userInfo[NSLocalizedFailureReasonErrorKey] = error.localizedDescription;
        userInfo[@"innerError"] = error;
    }
    else {
        userInfo[NSLocalizedDescriptionKey] = message;
    }
    
    return [NSError errorWithDomain: kQwasiErrorDomain code: code userInfo: userInfo];
}

+ (NSError*)deviceRegistrationFailed:(NSError*)reason {
    return [self errorWithCode: QwasiErrorDeviceRegistrationFailed withMessage: @"Device registration failed." withInnerError: reason];
}

+ (NSError*)setUserTokenFailed:(NSError*)reason {
    return [self errorWithCode: QwasiErrorSetUserTokenFailed withMessage: @"Set usertoken failed." withInnerError: reason];
}

+ (NSError*)deviceUnregisterFailed:(NSError*)reason {
    return [self errorWithCode: QwasiErrorDeviceUnregisterFailed withMessage: @"Device unregister failed." withInnerError: reason];
}

+ (NSError*)pushRegistrationFailed:(NSError*)reason {
    return [self errorWithCode: QwasiErrorPushRegistrationFailed withMessage: @"Push registration failed." withInnerError: reason];
}

+ (NSError*)messageFetchFailed:(NSError*)reason {
    return [self errorWithCode: QwasiErrorMessageFetchFailed withMessage: @"Message fetch failed." withInnerError: reason];
}

+ (NSError*)locationFetchFailed:(NSError*)reason {
    return [self errorWithCode: QwasiErrorLocationFetchFailed withMessage: @"Location fetch failed." withInnerError: reason];
}

+ (NSError*)locationSyncFailed:(NSError*)reason {
    return [self errorWithCode: QwasiErrorLocationSyncFailed withMessage: @"Location sync failed." withInnerError: reason];
}

+ (NSError*)channel:(NSString*)channel subscribeFailed:(NSError*)reason {
    return [self errorWithCode: QwasiErrorChannelSubscribeFailed
                   withMessage: [NSString stringWithFormat: @"Channel %@ subscribe failed.", channel]
                withInnerError: reason];
}

+ (NSError*)channel:(NSString*)channel unsubscribeFailed:(NSError*)reason; {
    return [self errorWithCode: QwasiErrorChannelUnsubscribeFailed
                   withMessage: [NSString stringWithFormat: @"Channel %@ unsubscribe failed.", channel]
                withInnerError: reason];
}

+ (NSError*)location:(QwasiLocation *)location monitoringFailed:(NSError *)reason {
    return [self errorWithCode: QwasiErrorLocationMonitoringFailed
                   withMessage: [NSString stringWithFormat: @"Failed to monitor location %@ (%@).", location.id, location.name]
                withInnerError: reason];
}

+ (NSError*)location:(QwasiLocation*)location beaconRangingFailed:(NSError*)reason {
    return [self errorWithCode: QwasiErrorLocationBeaconRangingFailed
                   withMessage: [NSString stringWithFormat: @"Failed to range beacon for location %@ (%@).", location.id, location.name]
                withInnerError: reason];
}

+ (NSError*)setDeviceDataForKey:(NSString*)key failed:(NSError*)reason {
    return [self errorWithCode: QwasiErrorSetDeviceDataFailed
                   withMessage: [NSString stringWithFormat: @"Failed to set data for key %@.", key]
                withInnerError: reason];
}

+ (NSError*)getDeviceDataForKey:(NSString*)key failed:(NSError*)reason {
    return [self errorWithCode: QwasiErrorGetDeviceDataFailed
                   withMessage: [NSString stringWithFormat: @"Failed to get data for key %@.", key]
                withInnerError: reason];
}

+ (NSError*)sendMessageToUserToken:(NSString*)userToken failed:(NSError*)reason {
    return [self errorWithCode: QwasiErrorSendMessageFailed
                   withMessage: [NSString stringWithFormat: @"Failed to send message to user %@.", userToken]
                withInnerError: reason];
}

+ (NSError*)postEvent:(NSString*)event failedWithReason:(NSError*)reason {
    return [self errorWithCode: QwasiErrorPostEventFailed withMessage: [NSString stringWithFormat: @"Post event %@ failed.", event] withInnerError: reason];
}

+ (NSError*)apiError:(NSDictionary*)err {
    return [self errorWithCode: [[err valueForKeyPath: @"error.code"] integerValue] withMessage: [err valueForKeyPath: @"error.message"]];
}

+ (NSError*)deviceNotRegistered {
    return [self errorWithCode: QwasiErrorDeviceNotRegistered withMessage: @"Device has not registered with server."];
}

+ (NSError*)pushNotEnabled {
    return [self errorWithCode: QwasiErrorPushNotEnabled withMessage: @"User has disabled push notifications for the device."];
}

+ (NSError*)invalidMessage {
    return [self errorWithCode: QwasiErrorInvalidMessage withMessage: @"Invalid message identifier"];
}

+ (NSError*)locationAccessDenied {
    return [self errorWithCode: QwasiErrorLocationAccessDenied withMessage: @"Location authorization access denied."];
}

+ (NSError*)locationAccessInsufficient {
    return [self errorWithCode: QwasiErrorLocationAccessInsufficient withMessage: @"Location authorization access insufficient."];
}
@end
