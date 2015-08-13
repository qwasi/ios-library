//
//  QViewController.m
//  Qwasi
//
//  Created by Rob Rodriguez on 06/02/2015.
//  Copyright (c) 2014 Rob Rodriguez. All rights reserved.
//

#import "ViewController.h"
#import "Qwasi.h"

@interface ViewController ()
{
    NSMutableString* _messages;
}
@end

@implementation ViewController

- (id)initWithCoder:(NSCoder *)aDecoder {
    if (self = [super initWithCoder:aDecoder]) {
        
        _messages = [[NSMutableString alloc] init];
        
        // Add a new message handler for the view
        [[Qwasi shared] on: @"message" listener: ^(QwasiMessage* message) {
            [_messages appendFormat: @"<hr><b>Alert:</b> %@<br/><b>Message:</b>%@</br></br>",
             message.alert,
             message.payload];
            
            [self reloadMessages];
        }];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (void)reloadMessages {
    if (_webView) {
        [_webView loadHTMLString: _messages baseURL: nil];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [self reloadMessages];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
