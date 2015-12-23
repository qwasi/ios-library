//
//  QwasiLocation.h
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
#import <CoreLocation/CoreLocation.h>

typedef NS_ENUM(NSInteger, QwasiLocationType) {
    QwasiLocationTypeUnknown = 0,
    QwasiLocationTypeCoordinate,
    QwasiLocationTypeGeofence,
    QwasiLocationTypeBeacon
};

typedef NS_ENUM(NSInteger, QwasiLocationState) {
    QwasiLocationStateUnknown = 0,
    QwasiLocationStateOutside,
    QwasiLocationStatePending,
    QwasiLocationStateInside,
    QwasiLocationStateDwell
};

@interface QwasiLocation : CLLocation
@property (nonatomic,readonly) QwasiLocationType type;
@property (nonatomic,readonly) QwasiLocationState state;
@property (nonatomic,readonly) CLLocationDegrees longitude;
@property (nonatomic,readonly) CLLocationDegrees latitude;
@property (nonatomic,readonly) NSString* id;
@property (nonatomic,readonly) NSString* name;
@property (nonatomic,readonly) NSString* vendor;
@property (nonatomic,readonly) CLLocationDistance geofenceRadius;
@property (nonatomic,readonly) NSDictionary* geometry;
@property (nonatomic,readonly) CLLocationDistance distance;
@property (nonatomic,readonly) NSTimeInterval dwellTime;
@property (nonatomic,readonly) NSUUID* beaconUUID;
@property (nonatomic,readonly) CLLocationDistance beaconProximity;
@property (nonatomic,readonly) CLBeaconMajorValue beaconMajorVersion;
@property (nonatomic,readonly) CLBeaconMinorValue beaconMinorVersion;
@property (nonatomic,readonly) CLRegion* region;
@property (nonatomic,readonly) CLBeacon* beacon;

- (id)initWithLocation:(CLLocation*)location;
- (id)initWithLocationData:(NSDictionary*)data;

- (void)enter;
- (void)enterWithBeacon:(CLBeacon*)beacon;
- (void)exit;
- (void)exitWithBeacon:(CLBeacon*)beacon;
@end