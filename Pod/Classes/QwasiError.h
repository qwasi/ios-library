//
//  QwasiError.h
//  Pods
//
//  Created by Robert Rodriguez on 6/5/15.
//
//

#import <Foundation/Foundation.h>

extern NSString* const kQwasiErrorDomain;

typedef NS_ENUM(NSInteger, QwasiErrorCode) {
    QwasiErrorNone = 0,
    QwasiErrorDeviceNotRegistered = 9000,
    QwasiErrorDeviceRegistrationFailed,
    QwasiErrorDeviceUnregisterFailed,
    QwasiErrorPushRegistrationFailed,
    QwasiErrorPushNotEnabled,
    QwasiErrorMessageFetchFailed,
    QwasiErrorLocationFetchFailed,
    QwasiErrorLocationSyncFailed,
    QwasiErrorLocationMonitoringFailed,
    QwasiErrorLocationBeaconRangingFailed,
    QwasiErrorPostEventFailed,
    QwasiErrorChannelSubscribeFailed,
    QwasiErrorChannelUnsubscribeFailed,
    QwasiErrorSetUserTokenFailed,
    QwasiErrorSetDeviceDataFailed,
    QwasiErrorGetDeviceDataFailed,
    QwasiErrorSendMessageFailed,
    QwasiErrorInvalidMessage,
    QwasiErrorLocationAccessDenied,
    QwasiErrorLocationAccessInsufficient,
    QwasiErrorMessageNotFound = 404
};

@class QwasiLocation;

@interface QwasiError : NSObject
+ (NSError*)apiError:(NSDictionary*)err;
+ (NSError*)deviceRegistrationFailed:(NSError*)reason;
+ (NSError*)deviceUnregisterFailed:(NSError*)reason;
+ (NSError*)pushRegistrationFailed:(NSError*)reason;
+ (NSError*)messageFetchFailed:(NSError*)reason;
+ (NSError*)locationFetchFailed:(NSError*)reason;
+ (NSError*)locationSyncFailed:(NSError*)reason;
+ (NSError*)setUserTokenFailed:(NSError*)reason;
+ (NSError*)setDeviceDataForKey:(NSString*)key failed:(NSError*)reason;
+ (NSError*)getDeviceDataForKey:(NSString*)key failed:(NSError*)reason;
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
@end
