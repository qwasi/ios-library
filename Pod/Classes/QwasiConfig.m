//
//  QwasiConfig.m
//  Pods
//
//  Created by Robert Rodriguez on 6/2/15.
//
//

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
@end
