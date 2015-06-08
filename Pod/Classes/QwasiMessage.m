//
//  QwasiMessage.m
//  Pods
//
//  Created by Robert Rodriguez on 6/3/15.
//
//

#import "QwasiMessage.h"

#ifdef __IPHONE_8_0
#define GregorianCalendar NSCalendarIdentifierGregorian
#else
#define GregorianCalendar NSGregorianCalendar
#endif

@implementation QwasiMessage {
    NSString* _encodedPayload;
}

+ (instancetype)messageWithData:(NSDictionary*)data {
    return [[QwasiMessage alloc] initWithData: data];
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    if (self = [super init]) {
        _messageId = [aDecoder decodeObjectForKey: @"id"];
        _application = [aDecoder decodeObjectForKey: @"application"];
        _alert = [aDecoder decodeObjectForKey: @"text"];
        _timestamp = [[aDecoder decodeObjectForKey: @"timestamp"] doubleValue];
        _payloadType = [aDecoder decodeObjectForKey: @"payload_type"];
        _tags = [aDecoder decodeObjectForKey: @"tags"];
        _selected = [aDecoder decodeBoolForKey: @"selected"];
                     
        _encodedPayload = [aDecoder decodeObjectForKey: @"encodedPayload"];
        
        _payload = [[NSData alloc] initWithBase64EncodedString: _encodedPayload options: 0];
        
        if ([_payloadType caseInsensitiveCompare: @"application/json"] == NSOrderedSame) {
            NSError* jsonError;
            
            id payload = [NSJSONSerialization JSONObjectWithData: _payload options: 0 error: &jsonError];
            
            if (!jsonError) {
                _payload = payload;
            }
        }
        else if ([_payloadType rangeOfString: @"text"].location != NSNotFound) {
            _payload = [[NSString alloc] initWithData: _payload encoding: NSUTF8StringEncoding];
        }
    }
    return self;
}

- (id)initWithData:(NSDictionary*)data {
    
    if (self = [super init]) {
        _messageId = [data objectForKey: @"id"];
        _application = [data valueForKeyPath: @"application.id"];
        _alert = [data objectForKey: @"text"];
        
        if ([UIApplication sharedApplication].applicationState == UIApplicationStateInactive) {
            _selected = YES;
        }
        
        NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
        NSDate* timestamp;
        
        [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSSz"];
        [dateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
        [dateFormatter setCalendar:[[NSCalendar alloc] initWithCalendarIdentifier:GregorianCalendar]];
        [dateFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
        
        timestamp = [dateFormatter dateFromString: [data objectForKey: @"created_at"]];
        
        _timestamp = [timestamp timeIntervalSince1970];
        
        _payloadType = [data objectForKey: @"payload_type"];
        _tags = [data valueForKeyPath: @"context.tags"];
        _fetched = [[data valueForKeyPath: @"flags.fetched"] boolValue];
        
        // decode the payload
        _encodedPayload = [data objectForKey: @"payload"];
        
        _payload = [[NSData alloc] initWithBase64EncodedString: _encodedPayload options: 0];
        
        if ([_payloadType caseInsensitiveCompare: @"application/json"] == NSOrderedSame) {
            NSError* jsonError;
            
            id payload = [NSJSONSerialization JSONObjectWithData: _payload options: 0 error: &jsonError];
            
            if (!jsonError) {
                _payload = payload;
            }
        }
        else if ([_payloadType rangeOfString: @"text"].location != NSNotFound) {
            _payload = [[NSString alloc] initWithData: _payload encoding: NSUTF8StringEncoding];
        }
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject: _messageId forKey: @"id"];
    [aCoder encodeObject: _application forKey: @"application"];
    [aCoder encodeObject: _alert forKey: @"text"];
    [aCoder encodeObject: [NSNumber numberWithDouble: _timestamp] forKey: @"timestamp"];
    [aCoder encodeObject: _payloadType forKey: @"payload_type"];
    [aCoder encodeObject: _tags forKey: @"tags"];
    [aCoder encodeObject: _encodedPayload forKey: @"encodedPayload"];
    [aCoder encodeBool: YES forKey: @"selected"];
}

- (BOOL)silent {
    return (_alert == nil);
}
- (NSString*)description {
    
    if ([_payloadType caseInsensitiveCompare: @"application/json"] == NSOrderedSame) {
        NSError* jsonError;
        
        NSData* jsonData = [NSJSONSerialization dataWithJSONObject: _payload options: NSJSONWritingPrettyPrinted error: &jsonError];
        
        if (jsonData && !jsonError) {
            return [NSString stringWithUTF8String: [jsonData bytes]];
        }
    }

    return [_payload description];
}
@end
