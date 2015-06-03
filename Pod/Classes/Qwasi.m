//
//  Qwasi.m
//  Pods
//
//  Created by Robert Rodriguez on 6/2/15.
//
//

#import "Qwasi.h"

@implementation Qwasi
+ (instancetype)default {
    static dispatch_once_t once;
    static id sharedInstance = nil;
    
    dispatch_once(&once, ^{
        sharedInstance = [Qwasi qwasiWithConfig: [QwasiConfig default]];
    });
    
    return sharedInstance;
}

+ (instancetype)qwasiWithConfig:(QwasiConfig*)config {
    return [[Qwasi alloc] initWithConfig: config];
}

- (id)initWithConfig:(QwasiConfig*)config {
    if (self = [super init]) {
        
    }
    return self;
}
@end
