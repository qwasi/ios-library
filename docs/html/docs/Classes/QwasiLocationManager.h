//
//  QwasiLocationManager.h
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
