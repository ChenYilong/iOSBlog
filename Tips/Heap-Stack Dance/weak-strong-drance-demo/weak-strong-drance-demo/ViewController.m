//
//  ViewController.m
//  weak-strong-drance-demo
//
//  Created by 陈宜龙 on 12/21/16.
//  Copyright © 2016 ElonChan. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    __autoreleasing Foo *foo = [Foo new];
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
