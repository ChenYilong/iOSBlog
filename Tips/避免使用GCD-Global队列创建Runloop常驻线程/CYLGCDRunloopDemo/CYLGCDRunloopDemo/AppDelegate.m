//
//  AppDelegate.m
//  CYLGCDRunloopDemo
//
//  Created by chenyilong on 2017/6/7.
//  Copyright © 2017年 Elon Chan. All rights reserved.
//

#import "AppDelegate.h"
#import "Foo.h"

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    
//    NSOperationQueue *asyncOperationQueue = [[NSOperationQueue alloc] init];
//    [asyncOperationQueue setMaxConcurrentOperationCount:300];
//    for (int i = 0; i < 300 ; i++) {
//        NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
//            NSString *currentThreadName = [NSString stringWithFormat:@"🔴类名与方法名：%@（在第%@行），描述：%@", @(__PRETTY_FUNCTION__), @(__LINE__), @""];
//            [[NSThread currentThread] setName:@"didFinishLaunchingWithOptions"];
////            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
////            NSLog(@"🔴类名与方法名：%@（在第%@行），描述：%@", @(__PRETTY_FUNCTION__), @(__LINE__), @"");
////            });
////NSLog(@"🔴类名与方法名：%@（在第%@行），描述：%@", @(__PRETTY_FUNCTION__), @(__LINE__), @"");
//            
//            
//            
//            
//            NSThread *networkRequestThread = [[NSThread alloc] initWithTarget:self selector:@selector(ayncThread:) object:@(i)];
//            [networkRequestThread start];
//            NSLog(@"🔴类名与方法名：%@（在第%@行），描述：%@", @(__PRETTY_FUNCTION__), @(__LINE__), @(i));
//            
//            
////            [[Foo new] test];
////            [[Foo new] begin];
//        }];
//        
//      
//
//        [asyncOperationQueue addOperation:operation];
//    }
    
    return YES;
}

//- (void)ayncThread:(id)i {
//    NSLog(@"💚类名与方法名：%@（在第%@行），描述：%@", @(__PRETTY_FUNCTION__), @(__LINE__), i);
//
//}
- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}


- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}


@end
