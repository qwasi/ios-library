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

SpecBegin(InitialSpecs)

describe(@"these will pass", ^{
    
    it(@"can do maths", ^{
        expect(1).beLessThan(23);
    });
    
    it(@"can read", ^{
        expect(@"team").toNot.contain(@"I");
    });
});

SpecEnd
