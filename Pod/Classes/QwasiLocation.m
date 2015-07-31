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
    dispatch_source_t _dwellTimer;
    
    BOOL _dwell;
    BOOL _inside;
    BOOL _exit;
    
    QwasiLocationState _state;
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
        _state = QwasiLocationStateUnknown;
        _exit = NO;
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
        }
        else {
            
            _type = QwasiLocationTypeGeofence;
            _region = [[CLCircularRegion alloc] initWithCenter: self.coordinate radius: _geofenceRadius identifier: _id];
        }
    }
    
    return self;
}

- (QwasiLocationState)state {
    
    if (_inside) {
        return QwasiLocationStateInside;
    }
    else if (_dwell) {
        return QwasiLocationStatePending;
    }
    else if (_type == QwasiLocationTypeBeacon) {
        return QwasiLocationStateOutside;
    }
    else {
        return QwasiLocationStateUnknown;
    }
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

- (void)enterWithBeacon:(CLBeacon*)beacon {
    _beacon = beacon;
    
    [self enter];
}

- (void)enter {
    
    @synchronized(self) {
        if (!_inside) {
            
            _inside = YES;
            
            if (!_dwell) {
                [[QwasiLocationManager currentManager] emit: @"enter", self];
            }
            
            [self dwell];
        }
        
        _exit = NO;
    }
}

- (void)dwell {
    
    @synchronized(self) {
        if (_inside && !_dwellTimer) {
            dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
            
            _dwellStart = [NSDate timeIntervalSinceReferenceDate];
            
            _dwellTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
            
            dispatch_source_set_timer(_dwellTimer, dispatch_time(DISPATCH_TIME_NOW, _dwellInterval * NSEC_PER_SEC), _dwellInterval * NSEC_PER_SEC, (1ull * NSEC_PER_SEC) / 10);
            
            dispatch_source_set_event_handler(_dwellTimer, ^{
                @synchronized(self) {
                    if (_inside) {
                        if (_exit) {
                            _inside = NO;
                        }
                        else {
                            _dwell = YES;
                            
                            [[QwasiLocationManager currentManager] emit: @"dwell", self];
                        }
                    }
                    else {
                        dispatch_source_cancel(_dwellTimer);
                        
                        _dwell = NO;
                        
                        _dwellTimer = nil;
                        
                        [[QwasiLocationManager currentManager] emit: @"exit", self];
                    }
                }
            });
            
            dispatch_resume(_dwellTimer);
        }
    }
}

- (void)exit {
    
    @synchronized(self) {
        if (_inside) {
            _exit = YES;
        }
    }
}

- (NSTimeInterval)dwellTime {
    
    if (_dwell) {
        return [NSDate timeIntervalSinceReferenceDate] - _dwellStart;
    }
    
    return 0;
}

- (CLLocationDistance)distance {
    if (_beacon) {
        return _beacon.accuracy;
    }
    else if ([QwasiLocationManager currentManager]) {
        return [[QwasiLocationManager currentManager].lastLocation distanceFromLocation: self];
    }
    return 0;
}

@end
