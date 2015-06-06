//
//  QwasiLocation.h
//  Pods
//
//  Created by Robert Rodriguez on 6/5/15.
//
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

typedef NS_ENUM(NSInteger, QwasiLocationType) {
    QwasiLocationTypeUnknown = 0,
    QwasiLocationTypeCoordinate,
    QwasiLocationTypeGeofence,
    QwasiLocationTypeBeacon
};

typedef NS_ENUM(NSInteger, QwasiLocationState) {
    QwasiLocationStateUnknown = 0,
    QwasiLocationStateInside,
    QwasiLocationStateOutside
};

@interface QwasiLocation : CLLocation
@property (nonatomic,readonly) QwasiLocationType type;
@property (nonatomic,readonly) QwasiLocationState state;
@property (nonatomic,readonly) CLLocationDegrees longitude;
@property (nonatomic,readonly) CLLocationDegrees latitude;
@property (nonatomic,readonly) NSString* id;
@property (nonatomic,readonly) NSString* name;
@property (nonatomic,readonly) CLLocationDistance geofenceRadius;
@property (nonatomic,readonly) NSTimeInterval dwellTime;
@property (nonatomic,readonly) NSUUID* beaconUUID;
@property (nonatomic,readonly) CLProximity beaconProximity;
@property (nonatomic,readonly) CLBeaconMajorValue beaconMajorVersion;
@property (nonatomic,readonly) CLBeaconMinorValue beaconMinorVersion;
@property (nonatomic,readonly) CLRegion* region;

- (id)initWithLocation:(CLLocation*)location;
- (id)initWithLocationData:(NSDictionary*)data;

- (void)enter;
- (void)exit;
@end