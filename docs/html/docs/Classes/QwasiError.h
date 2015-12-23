//
//  QwasiError.h
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

#import <Foundation/Foundation.h>

extern NSString* const kQwasiErrorDomain;

/** `QwasiError` Codes */
typedef NS_ENUM(NSInteger, QwasiErrorCode) {
    /** No error. */
    QwasiErrorNone = 0,
    /** Device has not been registered yet. */
    QwasiErrorDeviceNotRegistered = 9000,
    /** Device registration failed. */
    QwasiErrorDeviceRegistrationFailed,
    /** Device de-registration failed. */
    QwasiErrorDeviceUnregisterFailed,
    /** Failed to set push token on server. */
    QwasiErrorPushRegistrationFailed,
    /** Push is not enabled. */
    QwasiErrorPushNotEnabled,
    /** Message fetch failed. */
    QwasiErrorMessageFetchFailed,
    /** Failed to fetch locations for the application. */
    QwasiErrorLocationFetchFailed,
    /** Could not synchronize location objects with remote. */
    QwasiErrorLocationSyncFailed,
    /** Location monitoring could not be enabled, likely due to permissions. */
    QwasiErrorLocationMonitoringFailed,
    /** Could not range beacons, likely due to permissions. */
    QwasiErrorLocationBeaconRangingFailed,
    /** Post event failed. */
    QwasiErrorPostEventFailed,
    /** Channel subscribe failed. */
    QwasiErrorChannelSubscribeFailed,
    /** Channel unsubscribe failed. */
    QwasiErrorChannelUnsubscribeFailed,
    /** Set user token failed. */
    QwasiErrorSetUserTokenFailed,
    /** Set Device data failed. */
    QwasiErrorSetDeviceDataFailed,
    /** Get Device data failed. */
    QwasiErrorGetDeviceDataFailed,
    /** Set Member data failed. */
    QwasiErrorSetMemberDataFailed,
    /** Get Member data failed. */
    QwasiErrorGetMemberDataFailed,
    /** Send Message failed. */
    QwasiErrorSendMessageFailed,
    /** Invalid message data received. */
    QwasiErrorInvalidMessage,
    /** Location access denied by user. */
    QwasiErrorLocationAccessDenied,
    /** Location access insufficient. */
    QwasiErrorLocationAccessInsufficient,
    /** Message does not exist or inbox empty. */
    QwasiErrorMessageNotFound = 404,
    /** Set Member authentication failed */
    QwasiErrorSetMemberAuthFailed,
    /** Member authentication failed */
    QwasiErrorAuthMemeberFailed = 401
};

@class QwasiLocation;

/**
 The `QwasiError` class wraps is a subclass of the `NSError` providing conveinice methods for common API errors.
 */
@interface QwasiError : NSObject
/** General API Error 
 @param err NSDictionary with error details */
+ (NSError*)apiError:(NSDictionary*)err;
/** Device registration failed error. 
 @param reason Underlying error data. */
+ (NSError*)deviceRegistrationFailed:(NSError*)reason;
/** Device unregistration failed error.
  @param reason Underlying error data. */
+ (NSError*)deviceUnregisterFailed:(NSError*)reason;
/** Push registration failed error.
  @param reason Underlying error data. */
+ (NSError*)pushRegistrationFailed:(NSError*)reason;
/** Message fetch failed error.
  @param reason Underlying error data. */
+ (NSError*)messageFetchFailed:(NSError*)reason;
/** Location fetch failed error.
 @param reason Underlying error data. */
+ (NSError*)locationFetchFailed:(NSError*)reason;
/** Location sync failed error.
 @param reason Underlying error data. */
+ (NSError*)locationSyncFailed:(NSError*)reason;
/** Set user token failed error.
 @param reason Underlying error data. */
+ (NSError*)setUserTokenFailed:(NSError*)reason;
/** Set member auth failed.
 @param reason Underlying error data. */
+ (NSError*)setMemberAuthFailed:(NSError*)reason;
/** Auth member failed.
 @param reason Underlying error data. */
+ (NSError*)authMemberFailed:(NSError*)reason;
/** Set device data for key failed.
 @param key The key that failed to be set.
 @param reason Underlying error data. */
+ (NSError*)setDeviceDataForKey:(NSString*)key failed:(NSError*)reason;
/** Get device data for key failed.
 @param key The key that failed to be retrieved.
 @param reason Underlying error data. */
+ (NSError*)getDeviceDataForKey:(NSString*)key failed:(NSError*)reason;
/** Set member data for key failed.
 @param key The key that failed to be set.
 @param reason Underlying error data. */
+ (NSError*)setMemberDataForKey:(NSString*)key failed:(NSError*)reason;
/** Get member data for key failed.
 @param key The key that failed to be retrieved.
 @param reason Underlying error data. */
+ (NSError*)getMemberDataForKey:(NSString*)key failed:(NSError*)reason;
/** Send message failed.
 @param userToken the usertoken the message could not be delivered to.
 @param reason Underlying error data. */
+ (NSError*)sendMessageToUserToken:(NSString*)userToken failed:(NSError*)reason;
+ (NSError*)channel:(NSString*)channel subscribeFailed:(NSError*)reason;
+ (NSError*)channel:(NSString*)channel unsubscribeFailed:(NSError*)reason;
+ (NSError*)location:(QwasiLocation*)location monitoringFailed:(NSError*)reason;
+ (NSError*)location:(QwasiLocation*)location beaconRangingFailed:(NSError*)reason;
+ (NSError*)postEvent:(NSString*)event failedWithReason:(NSError*)reason;
+ (NSError*)deviceNotRegistered;
+ (NSError*)pushNotEnabled;
+ (NSError*)invalidMessage;
+ (NSError*)locationAccessDenied;
+ (NSError*)locationAccessInsufficient;

/** 
 Convenience pointer to kQwasiErrorDomain constant, @"com.qwasi.sdk"
 
    // Check if the error is a Qwasi generated error
    if (err.domain == QwasiError.domain) {
 
    }
 */
+ (NSString*)errorDomain;
@end
