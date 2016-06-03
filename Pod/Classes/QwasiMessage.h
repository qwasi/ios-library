//
//  QwasiMessage.h
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

#import <Foundation/Foundation.h>

@interface QwasiMessage : NSObject<NSCoding>

@property (nonatomic,readonly) NSString* alert;
@property (nonatomic,readonly) NSTimeInterval timestamp;
@property (nonatomic,readonly) NSString* messageId;
@property (nonatomic,readonly) NSString* application;
@property (nonatomic,readonly) NSString* payloadType;
@property (nonatomic,readonly) NSString* payloadSHA;
@property (nonatomic,readonly) id payload;
@property (nonatomic,readonly) id context;
@property (nonatomic,readonly) NSData* rawPayload;
@property (nonatomic,readonly) NSArray* tags;
@property (nonatomic,readonly) BOOL silent;
@property (nonatomic,readonly) BOOL selected;
@property (nonatomic,readonly) BOOL background;
@property (nonatomic,readonly) BOOL fetched;
@property (nonatomic,readonly) BOOL valid;
@property (nonatomic,readonly) BOOL cached;

+ (instancetype)messageWithData:(NSDictionary*)data;

+ (instancetype)messageWithArchive:(NSData*)archive updateFlags:(BOOL)update;

- (id)initWithAlert:(NSString*)alert
        withPayload:(id)payload
    withPayloadType:(NSString*)payloadType
           withTags:(NSArray*)tags;
@end

