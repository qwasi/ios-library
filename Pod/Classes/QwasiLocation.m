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
    NSTimeInterval _dwellInterval;
    NSTimeInterval _dwellStart;
    NSTimeInterval _exitDelay;
    
    BOOL _dwell;
    BOOL _inside;
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

        NSDictionary* geofence = data[@"geofence"];
        NSDictionary* beacon = data[@"beacon"];
        NSDictionary* properties = data[@"properties"];
        
        _id = data[@"id"];
        _name = data[@"name"];
        
        _dwellInterval = [[properties valueForKey: @"dwell_interval"] doubleValue];
        _geofenceRadius = [[geofence valueForKeyPath: @"properties.radius"] doubleValue];
        
        if (beacon) {
            
            _type = QwasiLocationTypeBeacon;
            _beaconUUID = [[NSUUID alloc] initWithUUIDString: [beacon valueForKey: @"id"]];
            _beaconMajorVersion = [[beacon valueForKey: @"maj_ver"] unsignedShortValue];
            _beaconMinorVersion = [[beacon valueForKey: @"min_ver"] unsignedShortValue];
        
            if (_beaconMajorVersion == UINT16_MAX) {
                _region = [[CLBeaconRegion alloc] initWithProximityUUID: _beaconUUID identifier: _id];
            }
            else if (_beaconMinorVersion == UINT16_MAX) {
                _region = [[CLBeaconRegion alloc] initWithProximityUUID: _beaconUUID major: _beaconMajorVersion identifier: _id];
            }
            else {
                _region = [[CLBeaconRegion alloc] initWithProximityUUID: _beaconUUID major: _beaconMajorVersion minor: _beaconMinorVersion identifier: _id];
            }
        
            _beaconProximity = [[beacon valueForKey: @"proximity"] doubleValue];
            _dwellInterval = 1.0f;
            _exitDelay = 1.0f;
        }
        else {
            
            _type = QwasiLocationTypeGeofence;
            _region = [[CLCircularRegion alloc] initWithCenter: self.coordinate radius: _geofenceRadius identifier: _id];
            _exitDelay = 15.0f;
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
            return [NSString stringWithFormat: @"%@ %@ %@ (%u,%u) %ldm %@", _name, _id, _beaconUUID.UUIDString, _beaconMajorVersion, _beaconMinorVersion, (long)_beaconProximity, [super description]];
            
        case QwasiLocationTypeCoordinate:
        default:
            return [super description];
    }
}

- (void)enter {
    
    @synchronized(self) {
        if (!_dwell) {
            
            _dwellStart = [NSDate timeIntervalSinceReferenceDate];

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(_dwellInterval * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                
                @synchronized(self) {
                    if (_dwell && !_inside && [QwasiLocationManager currentManager]) {
                        _inside = YES;
                        [[QwasiLocationManager currentManager] emit: @"enter", self];
                    }
                }
            });
            
            _dwell = YES;
        }
    }
}

- (void)enterWithBeacon:(CLBeacon*)beacon {
    _beacon = beacon;
    
    [self enter];
}

- (void)exit {
    
    @synchronized(self) {
        if (_dwell) {
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(_dwellInterval * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                
                @synchronized(self) {
                    if (!_dwell && _inside && [QwasiLocationManager currentManager]) {
                        _inside = NO;
                        _beacon = nil;
                        [[QwasiLocationManager currentManager] emit: @"exit", self];
                    }
                }
            });
            
            _dwell = NO;
        }
    }
}

- (NSTimeInterval)dwellTime {

    if (_dwell) {
        return [NSDate timeIntervalSinceReferenceDate] - _dwellStart;
    }
    
    return 0;
}
@end
