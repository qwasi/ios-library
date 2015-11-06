//
//  QwasiNotificationManager.h
//  Pods
//
//  Created by Robert Rodriguez on 6/7/15.
//
//

#import <Foundation/Foundation.h>
#import "EventEmitter.h"

@interface QwasiNotificationManager : EventEmitter
@property (nonatomic,readonly)NSString* pushToken;

+ (instancetype)shared;

- (void)registerForRemoteNotification;
@end
