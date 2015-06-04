//
//  QwasiMessage.m
//  Pods
//
//  Created by Robert Rodriguez on 6/3/15.
//
//

#import "QwasiMessage.h"

@implementation QwasiMessage

+ (instancetype)messageWithData:(NSDictionary*)data {
    return [[QwasiMessage alloc] initWithData: data];
}

- (id)initWithData:(NSDictionary*)data {
    
    if (self = [super init]) {
        _messageId = [data objectForKey: @"id"];
        _alert = [data objectForKey: @"notification"];
        _timestamp = [[data objectForKey: @"created"] doubleValue] / 1000.0f;
        _payloadType = [data objectForKey: @"payload_type"];
        _tags = [data objectForKey: @"tags"];
        
        // decode the payload
        NSString* encodedPayload = [data objectForKey: @"payload"];
        
        _payload = [[NSData alloc] initWithBase64EncodedString: encodedPayload options: 0];
    }
    
    return self;
}

- (NSString*)description {
    if ([_payloadType rangeOfString: @"text"].location != NSNotFound) {
        return [[NSString alloc] initWithData: _payload encoding: NSUTF8StringEncoding];
    }
    else {
        return [super description];
    }
}
@end
