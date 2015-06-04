//
//  QwasiMessage.h
//  Pods
//
//  Created by Robert Rodriguez on 6/3/15.
//
//

#import <Foundation/Foundation.h>

@interface QwasiMessage : NSObject

@property (nonatomic,readonly) NSString* alert;
@property (nonatomic,readonly) NSTimeInterval timestamp;
@property (nonatomic,readonly) NSString* messageId;
@property (nonatomic,readonly) NSString* payloadType;
@property (nonatomic,readonly) NSData* payload;
@property (nonatomic,readonly) NSArray* tags;

+ (instancetype)messageWithData:(NSDictionary*)data;
@end

