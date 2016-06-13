//
//  UIWebView+ZeroDataView.h
//  Pods
//
//  Created by Adam Turnbull on 6/9/16.
//
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "Qwasi.h"

@interface UIWebView (ZeroDataView)

-(void) loadZeroDataUrl:(NSString*) url
                   port:(NSString*) port
                success:(void(^)(NSData* data))success
                failure:(void(^)(NSError* err))failure;

@end
