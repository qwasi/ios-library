//
//  QwasiNotificationManager.h
//  Pods
//
//  Created by Robert Rodriguez on 6/7/15.
//
//

#import <Foundation/Foundation.h>

@interface QwasiNotificationManager : NSObject
@property (nonatomic,readonly)NSString* pushToken;

+ (instancetype)shared;

- (void)registerForRemoteNotification;
@end
