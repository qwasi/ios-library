//
//  Qwasi.h
//  Pods
//
//  Created by Robert Rodriguez on 6/2/15.
//
//

#import <Foundation/Foundation.h>

#pragma mark - Qwasi Import Headers

#import <Qwasi/QwasiConfig.h>
#import <Qwasi/QwasiClient.h>

#pragma mark - Qwasi Interface
@interface Qwasi : NSObject

+ (instancetype)default;
+ (instancetype)qwasiWithConfig:(QwasiConfig*)config;

@end
