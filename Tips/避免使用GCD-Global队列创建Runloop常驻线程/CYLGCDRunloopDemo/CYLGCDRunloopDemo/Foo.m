
//
//  Foo.m
//  CYLGCDRunloopDemo
//
//  Created by chenyilong on 2017/6/7.
//  Copyright © 2017年 Elon Chan. All rights reserved.
//

#import "Foo.h"

@interface Foo()  {
    NSRunLoop *_runloop;
    NSTimer *_timeoutTimer;
    NSTimeInterval _timeoutInterval;
    dispatch_semaphore_t _sem;
}
@end

@implementation Foo

- (instancetype)init {
    if (!(self = [super init])) {
        return nil;
    }
    _timeoutInterval = 1 ;
    _sem = dispatch_semaphore_create(0);
    // Do any additional setup after loading the view, typically from a nib.
    return self;
}

- (id)test {
    // 第一种方式：
    // NSThread *networkRequestThread = [[NSThread alloc] initWithTarget:self selector:@selector(networkRequestThreadEntryPoint0:) object:nil];
    // [networkRequestThread start];
    //第二种方式:
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        [self networkRequestThreadEntryPoint0:nil];
    });
    dispatch_semaphore_wait(_sem, DISPATCH_TIME_FOREVER);
    NSLog(@"🔴类名与方法名：%@（在第%@行），描述：%@", @(__PRETTY_FUNCTION__), @(__LINE__), @"");
    return @(YES);
}

- (void)networkRequestThreadEntryPoint0:(id)__unused object {
    @autoreleasepool {
        NSLog(@"🔴类名与方法名：%@（在第%@行），描述：%@", @(__PRETTY_FUNCTION__), @(__LINE__), [NSThread currentThread]);
        [[NSThread currentThread] setName:@"CYLTest"];
        _runloop = [NSRunLoop currentRunLoop];
        [_runloop addPort:[NSMachPort port] forMode:NSDefaultRunLoopMode];
        
        NSLog(@"🔴类名与方法名：%@（在第%@行），描述：%@", @(__PRETTY_FUNCTION__), @(__LINE__), @"");
        _timeoutTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(stopLoop) userInfo:nil repeats:NO];
        [_runloop addTimer:_timeoutTimer forMode:NSRunLoopCommonModes];
        [_runloop run];//在实际开发中最好使用这种方式来确保能runloop退出，做双重的保障[runloop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:(timeoutInterval+5)]];
        NSLog(@"🔴类名与方法名：%@（在第%@行），描述：%@", @(__PRETTY_FUNCTION__), @(__LINE__), [NSThread currentThread]);
    }
}

- (void)stopLoop {
    NSLog(@"🔴类名与方法名：%@（在第%@行），描述：%@", @(__PRETTY_FUNCTION__), @(__LINE__), @"stop loop");
    CFRunLoopStop([_runloop getCFRunLoop]);
    dispatch_semaphore_signal(_sem);
}

- (void)dealloc {
    NSLog(@"🔴类名与方法名：%@（在第%@行），描述：%@", @(__PRETTY_FUNCTION__), @(__LINE__), @"");
}

@end
