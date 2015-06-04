//
//  QwasiConfig.h
//  Pods
//
//  Created by Robert Rodriguez on 6/2/15.
//
//

#import <Foundation/Foundation.h>

@interface QwasiConfig : NSObject
@property (nonatomic,readonly) NSURL* url;
@property (nonatomic,readonly) NSString* application;
@property (nonatomic,readonly) NSString* key;

+ (instancetype)default;

+ (instancetype)configWithFile:(NSString*)path;

+ (instancetype)configWithURL:(NSURL*)url
              withApplication:(NSString*)app
                      withKey:(NSString*)key;
@end
