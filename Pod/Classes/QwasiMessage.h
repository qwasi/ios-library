//
//  QwasiMessage.h
//  Pods
//
//  Created by Robert Rodriguez on 6/3/15.
//
//

#import <Foundation/Foundation.h>

@interface QwasiMessage : NSObject<NSCoding>

@property (nonatomic,readonly) NSString* alert;
@property (nonatomic,readonly) NSTimeInterval timestamp;
@property (nonatomic,readonly) NSString* messageId;
@property (nonatomic,readonly) NSString* application;
@property (nonatomic,readonly) NSString* payloadType;
@property (nonatomic,readonly) NSString* payloadSHA;
@property (nonatomic,readonly) id payload;
@property (nonatomic,readonly) NSData* rawPayload;
@property (nonatomic,readonly) NSArray* tags;
@property (nonatomic,readonly) BOOL silent;
@property (nonatomic,readonly) BOOL selected;
@property (nonatomic,readonly) BOOL fetched;
@property (nonatomic,readonly) BOOL valid;
@property (nonatomic,readonly) BOOL cached;

+ (instancetype)messageWithData:(NSDictionary*)data;

- (id)initWithAlert:(NSString*)alert
        withPayload:(id)payload
    withPayloadType:(NSString*)payloadType
           withTags:(NSArray*)tags;
@end

