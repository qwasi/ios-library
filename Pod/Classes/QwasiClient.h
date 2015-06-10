//
//  QwasiClient.h
//  Pods
//
//  Created by Robert Rodriguez on 6/2/15.
//
//

#import <Foundation/Foundation.h>
#import "AFJSONRPCClient.h"
#import "QwasiConfig.h" 

@interface QwasiClient : AFJSONRPCClient

+ (instancetype)default;

+ (instancetype)clientWithConfig:(QwasiConfig*)config;

@end
