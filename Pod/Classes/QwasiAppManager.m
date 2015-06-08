//
//  QwasiAppManager.m
//  Pods
//
//  Created by Robert Rodriguez on 6/8/15.
//
//

#import "QwasiAppManager.h"

#import "Emitter.h"
#import "NSObject+STSwizzle.h"

typedef void (^fetchCompletionHander)(UIBackgroundFetchResult result);

@implementation UIApplication (QwasiAppManager)
+ (void)load {
    [self swizzleSelector: @selector(setDelegate:) toSelector: @selector(_setDelegate:) forClass: [self class]];
}

- (void)_setDelegate:(id)delegate {
    if ([self respondsToSelector: @selector(setDelegate:)]) {
        [self performSelector:@selector(_setDelegate:) withObject: delegate];
    }
    [QwasiAppManager shared];
}
@end

@implementation QwasiAppManager
+ (instancetype)shared {
    static dispatch_once_t once;
    static id sharedInstance = nil;
    
    dispatch_once(&once, ^{
        sharedInstance = [[QwasiAppManager alloc] init];
    });
    
    return sharedInstance;
}

- (id)init {
    if (self = [super init]) {
        
        UIApplication* application = [UIApplication sharedApplication];
        NSObject* appDelegate = application.delegate;
        
        // Add hooks to send application state events
        [appDelegate replaceMethodForSelector: @selector(applicationWillEnterForeground:) orAddWithTypes: "v@:@" implementation: ^(id _self, UIApplication* _unused) {
            
            [self emit: @"willEnterForeground"];
            
            [_self callOnSuper:^{
                if ([_self respondsToSelector:@selector(applicationWillEnterForeground:)]) {
                    [_self applicationWillEnterForeground: application];
                }
            }];
        }];
        
        [appDelegate replaceMethodForSelector: @selector(applicationDidEnterBackground:) orAddWithTypes: "v@:@" implementation: ^(id _self, UIApplication* _unused) {
            
            [self emit: @"didEnterBackground"];
            
            [_self callOnSuper:^{
                if ([_self respondsToSelector:@selector(applicationDidEnterBackground:)]) {
                    [_self applicationDidEnterBackground: application];
                }
            }];
        }];
        
        [appDelegate replaceMethodForSelector: @selector(application:performFetchWithCompletionHandler:)
                               orAddWithTypes: "v@:@@"
                               implementation: ^(id _self, UIApplication* application, fetchCompletionHander completionHandler)
         {
             [self emit: @"backgroundFetch"];
             
             [_self callOnSuper:^{
                 if ([_self respondsToSelector:@selector(application:performFetchWithCompletionHandler:)]) {
                     [_self application: application performFetchWithCompletionHandler: completionHandler];
                 }
                 else if (completionHandler) {
                     completionHandler(UIBackgroundFetchResultNewData);
                 }
             }];
         }];
    }
    return self;
}
@end
