//
//  QwasiTests.m
//  QwasiTests
//
//  Created by Rob Rodriguez on 06/02/2015.
//  Copyright (c) 2015 Rob Rodriguez. All rights reserved.
//

// https://github.com/Specta/Specta

#import "Specta.h"
#import "Expecta.h"
#import "Qwasi.h"

NSString* _deviceToken;

SpecBegin(InitialSpecs)

describe(@"Test Qwasi API Client", ^{
    
    it(@"Will register for a device token", ^{
        
        [Qwasi shared].config = [QwasiConfig configWithURL: [NSURL URLWithString: @"https://sandbox.qwasi.com/v1"]
                                           withApplication: @"552f5e6e3e73ca104b46191d"
                                                   withKey: @"7e459638914ae77e9ee2b0037e1f73f1"];
        
        waitUntil(^(DoneCallback done) {
            [[Qwasi shared] registerDevice: nil withName: @"Test Device" withUserToken: @"CI Tests" withUserInfo: nil success:^(NSString *deviceToken) {
               
               _deviceToken = deviceToken;
               
               done();
               
           } failure:^(NSError *err) {
               
               expect(err).to.beNil();
               
               done();
           }];
        });
    });
    
    it(@"Will unregister the device token", ^{
        waitUntil(^(DoneCallback done) {
            [[Qwasi shared] unregisterDevice: _deviceToken success:^() {
                
                done();
                
            } failure:^(NSError *err) {
                
                expect(err).to.beNil();
                
                done();
            }];
        });

    });
});

SpecEnd
