//
//  QwasiLocation.m
//  Pods
//
//  Created by Robert Rodriguez on 6/5/15.
//
//

#import "QwasiLocation.h"
#import "QwasiLocationManager.h"

#import <objc/runtime.h>

@implementation QwasiLocation {
    NSDictionary* _geometry;
    NSTimeInterval _dwellInterval;
    BOOL _dwell;
}

- (id)initWithLocation:(CLLocation *)location {
    if (self = [super initWithCoordinate: location.coordinate
                                altitude: location.altitude
                      horizontalAccuracy: location.horizontalAccuracy
                        verticalAccuracy: location.verticalAccuracy
                                  course: location.course
                                   speed: location.speed
                               timestamp: location.timestamp]) {
        
        _type = QwasiLocationTypeCoordinate;
        _region = [[CLCircularRegion alloc] initWithCenter: self.coordinate radius: 0 identifier: _id];
    }
    
    return self;
}

- (id)initWithLocationData:(NSDictionary*)data {
    
    NSArray* coord = [data valueForKeyPath: @"geofence.geometry.coordinates"];
    
    if (self = [super initWithLatitude: [coord[1] doubleValue] longitude: [coord[0] doubleValue]]) {
        _id = data[@"id"];
        _name = data[@"name"];
        _geometry = [data valueForKeyPath: @"geofence.geometry"];
        _dwellInterval = [[data valueForKeyPath: @"properties.dwell_interval"] doubleValue];
        _geofenceRadius = [[data valueForKeyPath: @"geofence.properties.radius"] doubleValue];
        
        if (data[@"beacon"]) {
            NSString* beaconProximity = [data valueForKeyPath: @"beacon.proximity"];
            
            _type = QwasiLocationTypeBeacon;
            _beaconUUID = [[NSUUID alloc] initWithUUIDString: [data valueForKeyPath: @"beacon.id"]];
            _beaconMajorVersion = [[data valueForKeyPath: @"beacon.maj_ver"] unsignedShortValue];
            _beaconMinorVersion = [[data valueForKeyPath: @"beacon.min_ver"] unsignedShortValue];
        
            if (_beaconMajorVersion == UINT16_MAX) {
                _region = [[CLBeaconRegion alloc] initWithProximityUUID: _beaconUUID identifier: _id];
            }
            else if (_beaconMinorVersion == UINT16_MAX) {
                _region = [[CLBeaconRegion alloc] initWithProximityUUID: _beaconUUID major: _beaconMajorVersion identifier: _id];
            }
            else {
                _region = [[CLBeaconRegion alloc] initWithProximityUUID: _beaconUUID major: _beaconMajorVersion minor: _beaconMinorVersion identifier: _id];
            }
            
            if ([beaconProximity isEqualToString: @"far"]) {
                _beaconProximity = CLProximityFar;
            }
            else if ([beaconProximity isEqualToString: @"immediate"]) {
                _beaconProximity = CLProximityImmediate;
            }
            else {
                _beaconProximity = CLProximityNear;
            }
        }
        else {
            _type = QwasiLocationTypeGeofence;
            _region = [[CLCircularRegion alloc] initWithCenter: self.coordinate radius: _geofenceRadius identifier: _id];
        }
    }
    
    return self;
}

- (QwasiLocationState)state {
    
    QwasiLocationManager* currentManager = [QwasiLocationManager currentManager];
    
    if (currentManager && currentManager.lastLocation) {
        CLCircularRegion* tmp = [[CLCircularRegion alloc] initWithCenter: self.coordinate radius: _geofenceRadius identifier: _id];
        
        if ([tmp containsCoordinate: currentManager.lastLocation.coordinate]) {
            return QwasiLocationStateInside;
        }
        
        return QwasiLocationStateOutside;
    }

    return QwasiLocationStateUnknown;
}

- (CLLocationDegrees)longitude {
    return self.coordinate.longitude;
}

- (CLLocationDegrees)latitude {
    return self.coordinate.latitude;
}

- (NSString*)description {
    switch (_type) {
        case QwasiLocationTypeGeofence:
            return [NSString stringWithFormat: @"%@ %@ %@", _name, _id, [super description]];
            
        case QwasiLocationTypeBeacon:
            return [NSString stringWithFormat: @"%@ %@ %@ (%u,%u) %@", _name, _id, _beaconUUID.UUIDString, _beaconMajorVersion, _beaconMinorVersion, [super description]];
            
        case QwasiLocationTypeCoordinate:
        default:
            return [super description];
    }
}

- (void)enter {
    
    if (!_dwell) {
        if (_type == QwasiLocationTypeGeofence) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(_dwellInterval * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if (_dwell && [QwasiLocationManager currentManager]) {
                    [[QwasiLocationManager currentManager] emit: @"enter", self];
                }
            });
        }
        else {
            [[QwasiLocationManager currentManager] emit: @"enter", self];
        }
        
        _dwell = YES;
    }
}

- (void)exit {
    
    if (_dwell) {
        _dwell = NO;

        [[QwasiLocationManager currentManager] emit: @"exit", self];
    }
}
@end
