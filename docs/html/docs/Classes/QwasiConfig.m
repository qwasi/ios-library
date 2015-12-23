//
//  QwasiConfig.m
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

#import "QwasiConfig.h"

@implementation QwasiConfig

+ (instancetype)default {
    static dispatch_once_t once;
    static id sharedInstance = nil;
    
    dispatch_once(&once, ^{
        sharedInstance = [QwasiConfig configWithFile: [[NSBundle mainBundle] pathForResource: @"Qwasi"
                                                                                      ofType: @"plist"]];
    });
    
    return sharedInstance;
}

+ (instancetype)configWithFile:(NSString*)path {
    
    NSDictionary* config = [NSDictionary dictionaryWithContentsOfFile: path];
    NSURL* url = [NSURL URLWithString: config[@"apiUrl"]];
    NSString* app = config[@"appId"];
    NSString* key = config[@"apiKey"];
    
    return [QwasiConfig configWithURL: url withApplication: app withKey: key];
}

+ (instancetype)configWithURL:(NSURL*)url withApplication:(NSString*)app withKey:(NSString*)key {
    return [[QwasiConfig alloc] initWithURL: url withApplication: app withKey: key];
}

- (id)initWithURL:(NSURL*)url withApplication:(NSString*)app withKey:(NSString*)key {
    if (self = [super init]) {
        _url = url ? url : [NSURL URLWithString: @"https://api.qwasi.com/v1"];
        _application = app ? app : @"INVALID_APP_ID";
        _key = key ? key : @"INVALID_API_KEY";
    }
    
    return self;
}

- (BOOL)isValid {
    if (!_url) {
        return NO;
    }
    if (!_application) {
        return NO;
    }
    if (!_key) {
        return NO;
    }
    return YES;
}
@end
