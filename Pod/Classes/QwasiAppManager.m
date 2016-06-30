//
// QwasiAppManager.m
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
