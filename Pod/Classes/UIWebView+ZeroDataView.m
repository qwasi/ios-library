//
//  UIWebView+ZeroDataView.m
//  Pods
//
//  Created by Adam Turnbull on 6/9/16.
//
//

#import "UIWebView+ZeroDataView.h"

@implementation UIWebView (ZeroDataView)

-(void) loadZeroDataUrl:(NSString*) url
                   port:(NSString*) port
                success:(void(^)(NSData* data))success
                failure:(void(^)(NSError* err))failure{

    [[Qwasi shared] zeroDataRequest:url port:port success:^(NSData *data) {
        NSLog(@"Retrieved Data, attempting to load");
        
        [self loadData:data MIMEType:@"text/html" textEncodingName: @"UTF-8" baseURL: [NSURL URLWithString:url]];
        success(data);
    } failure:^(NSError *err) {
        
        NSLog(@"Failed to fetch content with error %@", err);
        failure(err);
    }];
}

@end
