//
//  QwasiLocationManager.m
//  Pods
//
//  Created by Robert Rodriguez on 6/5/15.
//
//

#import "QwasiLocationManager.h"
#import "CocoaLumberjack.h"

QwasiLocationManager* _activeManager = nil;

@implementation QwasiLocationManager {
    CLAuthorizationStatus _authStatus;
    CLAuthorizationStatus _requiredStatus;
    BOOL _deferred;
    BOOL _started;
    
    NSMutableDictionary* _regionMap;
}

+ (instancetype)currentManager {
    return _activeManager;
}

+ (instancetype)foregroundManager {
    static dispatch_once_t once;
    static id sharedInstance = nil;
    
    if (_activeManager) {
        return _activeManager;
    }
    
    dispatch_once(&once, ^{
        sharedInstance = [[QwasiLocationManager alloc] initWithRequiredAuthorization: kCLAuthorizationStatusAuthorizedWhenInUse];
        _activeManager = sharedInstance;
    });
    
    return sharedInstance;
}

+ (instancetype)backgroundManager {
    static dispatch_once_t once;
    static id sharedInstance = nil;
    
    if (_activeManager) {
        return _activeManager;
    }
    
    dispatch_once(&once, ^{
        sharedInstance = [[QwasiLocationManager alloc] initWithRequiredAuthorization: kCLAuthorizationStatusAuthorizedAlways];
        _activeManager = sharedInstance;
    });
    
    return sharedInstance;
}

- (id)initWithRequiredAuthorization:(CLAuthorizationStatus)status {
    return [self initWithLocationManager: [[CLLocationManager alloc] init] requiredAuthorization: status];
}

- (id)initWithLocationManager:(CLLocationManager*)manager requiredAuthorization:(CLAuthorizationStatus)status {
    if (self = [super init]) {
        
        _requiredStatus = status;
        _authStatus = [CLLocationManager authorizationStatus];
        
        _updateDistance = 100;  // 100 meters
        _updateInterval = 900;  // 30 minutes
        
        _regionMap = [[NSMutableDictionary alloc] init];
        _manager = manager;
        _manager.delegate = self;
        _manager.desiredAccuracy = kCLLocationAccuracyBest;
        _manager.distanceFilter = kCLDistanceFilterNone;
        _manager.activityType = CLActivityTypeFitness;
        
#if !TARGET_IPHONE_SIMULATOR
        _manager.pausesLocationUpdatesAutomatically = NO;
#endif
        
        // Clear any existing regions
        for (CLRegion* region in _manager.monitoredRegions) {
            [_manager stopMonitoringForRegion: region];
        }
    }
    return self;
}

- (void)startLocationUpdates {
    
    switch (_authStatus) {
        case kCLAuthorizationStatusNotDetermined:
            if (![_manager respondsToSelector:@selector(requestAlwaysAuthorization)]) {
                // iOS 7, just enabled the location manager
                [_manager startUpdatingLocation];
            }
            else if (_requiredStatus == kCLAuthorizationStatusAuthorizedWhenInUse) {
                [_manager requestWhenInUseAuthorization];
            }
            else if (_requiredStatus == kCLAuthorizationStatusAuthorizedAlways) {
                [_manager requestAlwaysAuthorization];
            }
            break;
            
        case kCLAuthorizationStatusRestricted:
        case kCLAuthorizationStatusDenied:
            [self emit:@"error", [QwasiError locationAccessDenied]];
            break;
            
        case kCLAuthorizationStatusAuthorizedAlways:
        case kCLAuthorizationStatusAuthorizedWhenInUse:
            if (_authStatus > _requiredStatus) {
                [self emit:@"error", [QwasiError locationAccessInsufficient]];
            }
            else {
                [_manager startUpdatingLocation];
                
                _started = YES;
            }
            break;
            
        default:
            break;
    }
}

- (void)stopLocationUpdates {
    [_manager stopUpdatingLocation];
    
    [self stopMonitoringLocations];
    
    _started = NO;
}

- (void)startMonitoringLocation:(QwasiLocation*)location {
    
    @synchronized(self) {
        if (![_regionMap objectForKey: location.id]) {
            
            // Beacons require always authorization status to monitor
            if (location.type == QwasiLocationTypeBeacon && _authStatus != kCLAuthorizationStatusAuthorizedAlways) {
                DDLogDebug(@"Background auth required to monitor beacons, beacon %@ will not be monitored", location.name);
            }
            else {
                _regionMap[location.id] = location;
                
                [_manager startMonitoringForRegion: location.region];
                [_manager disallowDeferredLocationUpdates];
            }
        }
    }
}

- (void)stopMonitoringLocation:(QwasiLocation*)location {
    
    @synchronized(self) {
        if ([_regionMap objectForKey: location.id]) {
            [_manager stopMonitoringForRegion: location.region];
            [_regionMap removeObjectForKey: location.id];
            [location exit];
        }
    }
}

- (void)startMonitoringLocations {
    for (NSString* _id in _regionMap) {
        QwasiLocation* location = (QwasiLocation*)[_regionMap objectForKey: _id];
        
        [self startMonitoringLocation: location];
    }
}

- (void)stopMonitoringLocations {
    NSMutableDictionary* tmp;
    
    @synchronized(self) {
        tmp = _regionMap;
        _regionMap = [[NSMutableDictionary alloc] init];
    }
    
    for (NSString* _id in tmp) {
        QwasiLocation* location = (QwasiLocation*)[tmp objectForKey: _id];
        
        [_manager stopMonitoringForRegion: location.region];
        
        [location exit];
    }
    
    [tmp removeAllObjects];
}

- (NSArray*)locations {
    return [_regionMap allValues];
}

#pragma mark - CLLocationManagerDelegate
- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
    
    _lastLocation = [[QwasiLocation alloc] initWithLocation: [locations lastObject]];
    
    [self emit: @"location", _lastLocation];
    
    if (!_deferred) {
        
        [_manager allowDeferredLocationUpdatesUntilTraveled: _updateDistance timeout: _updateInterval];
        
        _deferred = YES;
    }
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    [self emit:@"error", error];
    
    _started = NO;
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    if (!_started) {
        [self startLocationUpdates];
    }
}

- (void)locationManager:(CLLocationManager *)manager didFinishDeferredUpdatesWithError:(NSError *)error {
    _deferred = NO;
}

- (void)locationManager:(CLLocationManager *)manager didStartMonitoringForRegion:(CLRegion *)region {
    QwasiLocation* location = [_regionMap objectForKey: region.identifier];
    
    if (location) {
        DDLogVerbose(@"Did start monitoring %@", location);
        
        [_manager requestStateForRegion: location.region];
    }
}

- (void)locationManager:(CLLocationManager *)manager monitoringDidFailForRegion:(CLRegion *)region withError:(NSError *)error {
    QwasiLocation* location = [_regionMap objectForKey: region.identifier];
    
    if (location) {
        if (error.domain == kCLErrorDomain) {
            switch (error.code) {
                case kCLErrorDenied:
                case kCLErrorRegionMonitoringDenied:
                    
                    DDLogVerbose(@"Failed to start monitoring %@, access denied by user.", location);
                    break;
                    
                case kCLErrorRegionMonitoringFailure:
                {
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        [_manager startMonitoringForRegion: region];
                    });
                }
                    break;
                    
                case kCLErrorRegionMonitoringResponseDelayed:
                case kCLErrorRegionMonitoringSetupDelayed:
                    return;
                    
                default:
                    break;
            }
        }
        else {
            DDLogVerbose(@"Failed to start monitoring %@, %@", location, error);
            
            [self emit: @"error", [QwasiError location: location monitoringFailed: error]];
        }
    }
}

- (void)locationManager:(CLLocationManager *)manager didEnterRegion:(CLRegion *)region {
    QwasiLocation* location = [_regionMap objectForKey: region.identifier];
    
    if (location) {
        
        if (location.type == QwasiLocationTypeBeacon) {
            [_manager startRangingBeaconsInRegion: (CLBeaconRegion*)region];
        }
        else {
            [location enter];
        }
    }
}

- (void)locationManager:(CLLocationManager *)manager didExitRegion:(CLRegion *)region {
    QwasiLocation* location = [_regionMap objectForKey: region.identifier];
    
    if (location) {
        [location exit];
    }
}

- (void)locationManager:(CLLocationManager *)manager didDetermineState:(CLRegionState)state forRegion:(CLRegion *)region {
    QwasiLocation* location = [_regionMap objectForKey: region.identifier];
    
    if (location) {
        switch (state) {
            case CLRegionStateInside:
                if (location.type == QwasiLocationTypeBeacon) {
                    [_manager startRangingBeaconsInRegion: (CLBeaconRegion*)region];
                }
                else {
                    [location enter];
                }
                break;
                
            case CLRegionStateOutside:
                [location exit];
                break;
                
            default:
                break;
        }
    }
}

- (void)locationManager:(CLLocationManager *)manager didRangeBeacons:(NSArray *)beacons inRegion:(CLBeaconRegion *)region {
    QwasiLocation* location = [_regionMap objectForKey: region.identifier];
    CLBeacon* beacon = beacons.count > 0 ? beacons[0] : nil;
    
    if (location && beacon) {
        
        if ((beacon.accuracy > 0) &&
            (beacon.accuracy <= location.beaconProximity)) {
            
            [location enterWithBeacon: beacon];
        }
        else {
            [location exitWithBeacon: beacon];
        }
    }
}

- (void)locationManager:(CLLocationManager *)manager rangingBeaconsDidFailForRegion:(CLBeaconRegion *)region withError:(NSError *)error {
    QwasiLocation* location = [_regionMap objectForKey: region.identifier];
    
    if (location) {
        DDLogVerbose(@"Failed to range %@, %@", location, error);
        
        [self emit: @"error", [QwasiError location: location beaconRangingFailed: error]];
    }
}
@end
