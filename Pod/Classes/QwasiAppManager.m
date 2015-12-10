//
//  QwasiAppManager.m
//  Pods
//
//  Created by Robert Rodriguez on 6/8/15.
//
//

#import "QwasiAppManager.h"
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
        
        [[NSNotificationCenter defaultCenter] addObserver: sharedInstance
                                                 selector: @selector(didFinishLaunching:)
                                                     name: UIApplicationDidFinishLaunchingNotification object:nil];
    });
    
    return sharedInstance;
}

- (id)init {
    if (self = [super init]) {
        
    }
    return self;
}

- (void)registerApplicationEventHooks {
    
    UIApplication* application = [UIApplication sharedApplication];
    NSObject* appDelegate = application.delegate;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willTerminate:) name:UIApplicationWillTerminateNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterForegroundNotification:) name:UIApplicationWillEnterForegroundNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didEnterBackgroundNotification:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    
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

- (void)didFinishLaunching:(NSNotification*)note {
    [self emit: @"didFinishLaunching"];
}

- (void)willTerminate:(NSNotification*)note {
    [self emit: @"willTerminate"];
}

- (void)willEnterForegroundNotification:(NSNotification*)note {
    [self emit: @"willEnterForeground"];
}

- (void)didEnterBackgroundNotification:(NSNotification*)note {
    [self emit: @"didEnterBackground"];
}
@end
