//
//  Foo.m
//  weak-strong-drance-demo
//
//  Created by 陈宜龙 on 12/21/16.
//  Copyright © 2016 ElonChan. All rights reserved.
//

#import "Foo.h"

typedef void (^Completion)(Foo *foo);

@interface Foo ()

@property (nonatomic, copy) Completion completion1;
@property (nonatomic, copy) Completion completion2;

@end

@implementation Foo

- (instancetype)init {
    if (!(self = [super init])) {
        return nil;
    }
    __weak typeof(self) weakSelf = self;
    self.completion1 = ^(Foo *foo) {
        NSLog(@"completion1");
    };
    self.completion2 = ^(Foo *foo) {
        __strong typeof(self) strongSelf = weakSelf;
        NSLog(@"completion2");
        NSUInteger delaySeconds = 2;
        dispatch_time_t when = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delaySeconds * NSEC_PER_SEC));
        dispatch_after(when, dispatch_get_main_queue(), ^{
            NSLog(@"两秒钟后");
            foo.completion1(foo);//foo等价于strongSelf
        });
    };
    self.completion2(self);
    return self;
}

- (void)dealloc {
    NSLog(@"dealloc");
}

@end
