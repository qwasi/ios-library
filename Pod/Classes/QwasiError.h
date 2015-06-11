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
    QwasiErrorSetUserTokenFailed,
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
+ (NSError*)location:(QwasiLocation*)location monitoringFailed:(NSError*)reason;
+ (NSError*)location:(QwasiLocation*)location beaconRangingFailed:(NSError*)reason;
+ (NSError*)postEvent:(NSString*)event failedWithReason:(NSError*)reason;
+ (NSError*)deviceNotRegistered;
+ (NSError*)pushNotEnabled;
+ (NSError*)invalidMessage;
+ (NSError*)locationAccessDenied;
+ (NSError*)locationAccessInsufficient;
@end
