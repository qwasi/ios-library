//
//  QwasiError.m
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

#import "QwasiError.h"
#import "QwasiLocation.h"

NSString* const kQwasiErrorDomain = @"com.qwasi.sdk";

@implementation QwasiError

+ (NSString*)errorDomain {
    return kQwasiErrorDomain;
}

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

+ (NSError*)setMemberAuthFailed:(NSError*)reason {
    return [self errorWithCode: QwasiErrorSetMemberAuthFailed withMessage: @"Set member authentication failed." withInnerError: reason];
}

+ (NSError*)authMemberFailed:(NSError*)reason {
    return [self errorWithCode: QwasiErrorAuthMemeberFailed withMessage: @"Member authentication failed." withInnerError: reason];
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

+ (NSError*)setMemberDataForKey:(NSString*)key failed:(NSError*)reason {
    return [self errorWithCode: QwasiErrorSetMemberDataFailed
                   withMessage: [NSString stringWithFormat: @"Failed to set data for key %@.", key]
                withInnerError: reason];
}

+ (NSError*)getMemberDataForKey:(NSString*)key failed:(NSError*)reason {
    return [self errorWithCode: QwasiErrorGetMemberDataFailed
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
