//
//  QwasiMessage.m
//
// Copyright (c) 2015-2016, Qwasi Inc (http://www.qwasi.com/)
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//    * Redistributions of source code must retain the above copyright
//      notice, this list of conditions and the following disclaimer.
//    * Redistributions in binary form must reproduce the above copyright
//      notice, this list of conditions and the following disclaimer in the
//      documentation and/or other materials provided with the distribution.
//    * Neither the name of Qwasi nor the
//      names of its contributors may be used to endorse or promote products
//      derived from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
// ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL QWASI BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
// ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#import "QwasiMessage.h"
#import <CommonCrypto/CommonDigest.h>

#ifdef __IPHONE_8_0
#define GregorianCalendar NSCalendarIdentifierGregorian
#else
#define GregorianCalendar NSGregorianCalendar
#endif

@interface QwasiMessage (Private)
@property (nonatomic,readwrite) BOOL selected;
@property (nonatomic,readwrite) BOOL background;
@end

@implementation QwasiMessage {
    NSString* _encodedPayload;
}

+ (instancetype)messageWithData:(NSDictionary*)data {
    return [[QwasiMessage alloc] initWithData: data];
}

+ (instancetype)messageWithArchive:(NSData*)archive updateFlags:(BOOL)update {
    QwasiMessage* msg = [NSKeyedUnarchiver unarchiveObjectWithData: archive];
    
    if (update) {
        [msg updateStateFlags];
    }
    
    return msg;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    if (self = [super init]) {
        _cached = YES;
        _messageId = [aDecoder decodeObjectForKey: @"id"];
        _application = [aDecoder decodeObjectForKey: @"application"];
        _alert = [aDecoder decodeObjectForKey: @"text"];
        _timestamp = [[aDecoder decodeObjectForKey: @"timestamp"] doubleValue];
        _payloadType = [aDecoder decodeObjectForKey: @"payload_type"];
        _payloadSHA =[aDecoder decodeObjectForKey: @"payload_sha"];
        _tags = [aDecoder decodeObjectForKey: @"tags"];
        _selected = [aDecoder decodeBoolForKey: @"selected"];
        _background = [aDecoder decodeBoolForKey: @"background"];
        _fetched = [aDecoder decodeBoolForKey: @"fetched"];
        _context = [aDecoder decodeObjectForKey: @"context"];
        
        _encodedPayload = [aDecoder decodeObjectForKey: @"encodedPayload"];
        
        if (_encodedPayload) {
            _payload = [QwasiMessage decodePayload: _encodedPayload withSHA: _payloadSHA withType: _payloadType];
        }
    }
    return self;
}

- (id)initWithData:(NSDictionary*)data {
    
    if (self = [super init]) {
        _cached = NO;
        _messageId = [data objectForKey: @"id"];
        _application = [data valueForKeyPath: @"application"];
        _alert = [data objectForKey: @"text"];
        
        if ([UIApplication sharedApplication].applicationState == UIApplicationStateInactive) {
            _selected = YES;
        }
        
        if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive) {
            _background = YES;
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
        _payloadSHA = [data objectForKey: @"payload_sha"];
        _tags = [data valueForKeyPath: @"tags"];
        _fetched = [[data valueForKeyPath: @"flags.fetched"] boolValue];
        _context = [aDecoder decodeObjectForKey: @"context"];
        
        // decode the payload
        _encodedPayload = [data objectForKey: @"payload"];
        
        if (_encodedPayload) {
            _payload = [QwasiMessage decodePayload: _encodedPayload withSHA: _payloadSHA withType: _payloadType];
        }
    }
    
    return self;
}

- (id)initWithAlert:(NSString*)alert
        withPayload:(id)payload
    withPayloadType:(NSString*)payloadType
           withTags:(NSArray*)tags {
    
    if (self = [super init]) {
        _alert = alert;
        _payload = payload;
        _payloadType = payloadType;
        _tags = [[NSArray alloc] initWithArray: tags];
        _timestamp = [[NSDate dateWithTimeIntervalSince1970:0] timeIntervalSince1970];
        _context = @{};
        
        if ([UIApplication sharedApplication].applicationState == UIApplicationStateInactive) {
            _selected = YES;
        }
        
        if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive) {
            _background = YES;
        }

        if (_payloadType == nil) {
            if ([NSJSONSerialization isValidJSONObject: _payload]) {
                _payloadType = @"application/json";
            }
            else if ([_payload isKindOfClass: [NSString class]]) {
                _payloadType = @"text/plain";
            }
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
    [aCoder encodeObject: _payloadSHA forKey: @"payload_sha"];
    [aCoder encodeObject: _tags forKey: @"tags"];
    [aCoder encodeObject: _context forKey: @"context"];
    [aCoder encodeObject: _encodedPayload forKey: @"encodedPayload"];
    [aCoder encodeBool: _fetched forKey: @"fetched"];
    [aCoder encodeBool: _selected forKey: @"selected"];
    [aCoder encodeBool: _background forKey: @"background"];
    
}

- (BOOL)silent {
    return (_alert == nil);
}

- (void)updateStateFlags {

    if ([UIApplication sharedApplication].applicationState == UIApplicationStateInactive) {
        _selected = YES;
    }
    
    if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive) {
        _background = YES;
    }
}

- (NSString*)description {
    
    if ([_payloadType caseInsensitiveCompare: @"application/json"] == NSOrderedSame) {
        NSError* jsonError;
        
        NSData* jsonData = [NSJSONSerialization dataWithJSONObject: _payload options: 0 error: &jsonError];
        
        if (jsonData && !jsonError) {
            return [[NSString alloc] initWithData: jsonData encoding: NSUTF8StringEncoding];
        }
    }

    return [_payload description];
}

+ (NSString*)hashPayload:(NSData*)payload {
    
    unsigned int outputLength = CC_SHA1_DIGEST_LENGTH;
    unsigned char output[outputLength];
    
    CC_SHA1(payload.bytes, (unsigned int) payload.length, output);

    NSMutableString* hash = [NSMutableString stringWithCapacity:outputLength * 2];
    
    for (unsigned int i = 0; i < outputLength; i++) {
        [hash appendFormat:@"%02x", output[i]];
        output[i] = 0;
    }
    
    return hash;
}

+ (id)decodePayload:(NSString*)encodedPayload withSHA:(NSString*)sha withType:(NSString*)type {
    
    NSData* payloadData = [[NSData alloc] initWithBase64EncodedString: encodedPayload options: 0];
    
    id rval = nil;
    
    if (!payloadData) {
        return nil;
    }
    
    if (sha && ![sha isEqualToString: [self hashPayload: payloadData]]) {
        return nil;
    }
    
    if ([type caseInsensitiveCompare: @"application/vnd.qwasi.aim+json"] == NSOrderedSame) {
        NSError* jsonError;
        
        id _payload = [NSJSONSerialization JSONObjectWithData: payloadData options: 0 error: &jsonError];
        
        if (!jsonError) {
            if ([_payload isKindOfClass:[NSDictionary class]]) {
                rval = [[NSMutableDictionary alloc] init];
                
                for (NSString* key in _payload) {
                    id sub = [_payload objectForKey: key];
                    
                    rval[key] = [self decodePayload: sub[@"payload"] withSHA: nil withType: sub[@"payload_type"]];
                }
            }
            else if ([_payload isKindOfClass: [NSArray class]]) {
                rval = [[NSMutableArray alloc] init];
                
                for (NSDictionary* sub in _payload) {
                    [rval addObject: [self decodePayload: sub[@"payload"] withSHA: nil withType: sub[@"payload_type"]]];
                }
            }
            else {
                rval = _payload;
            }
        }

    }
    else if ([type caseInsensitiveCompare: @"application/json"] == NSOrderedSame) {
        NSError* jsonError;
        
        id _payload = [NSJSONSerialization JSONObjectWithData: payloadData options: 0 error: &jsonError];
        
        if (!jsonError) {
            rval = _payload;
        }
    }
    else if ([type rangeOfString: @"image/"].location != NSNotFound) {
        rval = [[UIImage alloc] initWithData: payloadData];
        
        if (!rval) {
            rval = payloadData;
        }
    }
    else if ([type rangeOfString: @"text/"].location != NSNotFound) {
        rval = [[NSString alloc] initWithData: payloadData encoding: NSUTF8StringEncoding];
    }
    else {
        rval = payloadData;
    }
    
    return rval;
}

- (BOOL)valid {
    return YES;
}
@end
