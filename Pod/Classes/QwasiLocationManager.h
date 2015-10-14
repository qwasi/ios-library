//
//  QwasiLocationManager.h
//  Pods
//
//  Created by Robert Rodriguez on 6/5/15.
//
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import "EventEmitter.h"

#import "QwasiError.h"
#import "QwasiLocation.h"

@interface QwasiLocationManager : EventEmitter<CLLocationManagerDelegate>

@property (nonatomic,readonly) CLLocationManager* manager;
@property (nonatomic,readwrite) CLLocationDistance updateDistance;
@property (nonatomic,readwrite) NSTimeInterval updateInterval;
@property (nonatomic,readonly) QwasiLocation* lastLocation;
@property (nonatomic,readonly) NSArray* locations;

+ (instancetype)currentManager;
+ (instancetype)foregroundManager;
+ (instancetype)backgroundManager;

- (void)startLocationUpdates;
- (void)stopLocationUpdates;

- (void)startMonitoringLocation:(QwasiLocation*)location;
- (void)stopMonitoringLocation:(QwasiLocation*)location;
- (void)startMonitoringLocations;
- (void)stopMonitoringLocations;
@end
