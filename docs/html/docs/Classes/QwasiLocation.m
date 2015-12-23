//
//  QwasiLocation.m
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

#import "QwasiLocation.h"
#import "QwasiLocationManager.h"

#import <objc/runtime.h>

@implementation QwasiLocation {
    NSTimeInterval _dwellInterval;
    NSTimeInterval _dwellStart;
    NSTimeInterval _dwellExit;
    dispatch_source_t _dwellTimer;
    
    double _dwellTic;
    
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
        
        _id = [NSString stringWithFormat: @"%lu", (unsigned long)self.hash];
        _name = [NSString stringWithFormat: @"CLLocation_%lu", (unsigned long)self.hash];
        _type = QwasiLocationTypeCoordinate;
        _region = [[CLCircularRegion alloc] initWithCenter: self.coordinate radius: 0 identifier: _id];
        _state = QwasiLocationStateUnknown;
        _exit = NO;
    }
    
    return self;
}

- (id)initWithLocationData:(NSDictionary*)data {
    
    NSDictionary* geofence = data[@"geofence"];
    NSDictionary* beacon = data[@"beacon"];
    NSDictionary* properties = data[@"properties"];
    
    NSArray* coord;
  
    if (geofence) {
            coord = [data valueForKeyPath: @"geofence.geometry.coordinates"];
    }
    else{
        // This is not a geofence so use dummy coordinates
        coord = @[[NSNumber numberWithDouble: 0], [NSNumber numberWithDouble: 0]];
    }
    
    if (self = [super initWithLatitude: [coord[1] doubleValue] longitude: [coord[0] doubleValue]]) {
        _id = data[@"id"];
        
        _name = data[@"name"];
        
        _dwellInterval = [[properties valueForKey: @"dwell_interval"] doubleValue];
        
        _dwellInterval = MAX(_dwellInterval, 60.0f);
        
        _dwellTic = 1.0;
        
        _geofenceRadius = [[geofence valueForKeyPath: @"properties.radius"] doubleValue];
        
        _geofenceRadius = MAX(3.0f, _geofenceRadius);
        
        if (beacon && ![beacon isKindOfClass: [NSNull class]]) {
            _type = QwasiLocationTypeBeacon;
            
            NSArray* _ids = [beacon valueForKey: @"id"];
            
            _vendor = [beacon valueForKey: @"type"];
            
            if ([_ids isKindOfClass:[NSArray class]] &&
                 [_vendor isEqualToString:@"ibeacon"]) {
                _beaconUUID = (_ids.count > 0) ? [[NSUUID alloc] initWithUUIDString: _ids[0]] : nil;
                _beaconMajorVersion = (_ids.count > 1) ? [_ids[1] unsignedShortValue] : -1;
                _beaconMinorVersion = (_ids.count > 2) ? [_ids[2] unsignedShortValue] : -1;
            }
            
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
    
    if (_dwell) {
        return QwasiLocationStateDwell;
    }
    else if (_inside) {
        return QwasiLocationStateInside;
    }
    else if (_exit) {
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
    NSMutableDictionary* desc = [[NSMutableDictionary alloc] init];
    
    desc[@"id"] = _id;
    desc[@"name"] = _name;
    desc[@"region"] = [super description];
    
    switch (_type) {
        case QwasiLocationTypeBeacon:
        {
            NSDictionary* beac = @{ @"vendor": _vendor,
                                    @"uuid": _beaconUUID ? _beaconUUID.UUIDString : @"unknown",
                                    @"maj_ver": [NSNumber numberWithDouble: _beaconMajorVersion],
                                    @"min_ver": [NSNumber numberWithDouble: _beaconMinorVersion],
                                    @"proximity": [NSNumber numberWithDouble: _beaconProximity] };
            desc[@"beacon"] = beac;
        }
            break;
            
        case QwasiLocationTypeGeofence:
            desc[@"type"] = @"geofence";
            break;
            
        case QwasiLocationTypeCoordinate:
            desc[@"type"] = @"coordinate";
            break;
            
        default:
            desc[@"type"] = @"unknown";
            break;
    }
    
    return [NSString stringWithFormat: @"%@", desc];
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
                
                _dwellStart = [NSDate timeIntervalSinceReferenceDate];
                
                _dwellExit = 0;
                
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
            // How often the event will be fired, up to _dwellInterval
            __block NSTimeInterval _timerInterval = MAX(_dwellInterval / 10, 10);
            
            dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
            
            _dwellExit = 0;
            
            _dwellTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
            
            dispatch_source_set_timer(_dwellTimer, dispatch_time(DISPATCH_TIME_NOW, _timerInterval * NSEC_PER_SEC), _timerInterval * NSEC_PER_SEC, (1ull * NSEC_PER_SEC) / 10);
            
            dispatch_source_set_event_handler(_dwellTimer, ^{
                @synchronized(self) {
                    if (_inside) {
                        if (_exit) {
                            _inside = NO;
                        }
                        else {
                            _dwell = YES;
                            
                            _dwellExit = 0;
                            
                            [[QwasiLocationManager currentManager] emit: @"dwell", self];
                            
                            // Back off the dwell timers
                            if (self.dwellTime > _dwellInterval * _dwellTic) {
                                
                                _timerInterval = _dwellInterval * _dwellTic++;
                                
                                dispatch_source_set_timer(_dwellTimer, dispatch_time(DISPATCH_TIME_NOW, _timerInterval * NSEC_PER_SEC), _timerInterval * NSEC_PER_SEC, (1ull * NSEC_PER_SEC) / 10);
                            }
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

- (void)exitWithBeacon:(CLBeacon*)beacon {
    _beacon = beacon;
    
    [self exit];
}

- (void)exit {
    @synchronized(self) {
        if (_inside) {
            
            _dwellExit = [NSDate timeIntervalSinceReferenceDate] - _dwellStart;
            
            _exit = YES;
        }
    }
}

- (NSTimeInterval)dwellTime {
    if (!_inside && _exit && _dwellExit) {
        return _dwellExit;
    }
    else if (_dwellStart) {
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
