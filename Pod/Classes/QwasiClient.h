//
//  QwasiClient.h
//  Pods
//
//  Created by Robert Rodriguez on 6/2/15.
//
//

#import <Foundation/Foundation.h>
#import "QwasiConfig.h"
#import "AFJSONRPCClient.h"

@interface QwasiClient : AFJSONRPCClient

+ (instancetype)default;

+ (instancetype)clientWithConfig:(QwasiConfig*)config;

@end
