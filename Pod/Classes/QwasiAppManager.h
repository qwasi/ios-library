//
//  QwasiAppManager.h
//  Pods
//
//  Created by Robert Rodriguez on 6/8/15.
//
//

#import <Foundation/Foundation.h>
#import "EventEmitter.h"

@interface QwasiAppManager : EventEmitter
+ (instancetype)shared;
- (void)registerApplicationEventHooks;
@end
