//
//  ViewController.m
//  CYLGCDRunloopDemo
//
//  Created by chenyilong on 2017/6/7.
//  Copyright © 2017年 Elon Chan. All rights reserved.
//

#import "ViewController.h"
#import "Foo.h"

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    //    NSOperationQueue *asyncOperationQueue = [[NSOperationQueue alloc] init];
    //    [asyncOperationQueue setMaxConcurrentOperationCount:300];
    //    for (int i = 0; i < 300 ; i++) {
    //        NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
    //            NSString *currentThreadName = [NSString stringWithFormat:@"🔴类名与方法名：%@（在第%@行），描述：%@", @(__PRETTY_FUNCTION__), @(__LINE__), @""];
    //            [[NSThread currentThread] setName:@"didFinishLaunchingWithOptions"];
    //             [[Foo new] test];
    //        }];
    //        [asyncOperationQueue addOperation:operation];
    //    }
    for (int i = 0; i < 300 ; i++) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
            [[Foo new] test];
            NSLog(@"🔴类名与方法名：%@（在第%@行），描述：%@", @(__PRETTY_FUNCTION__), @(__LINE__), @"");
        });
    }
}
@end
