//
//  ViewController.m
//  delegateExample
//
//  Created by Kian Davoudi-Rad on 2017-03-16.
//  Copyright © 2017 Kian Davoudi-Rad. All rights reserved.
//

#import "ViewController.h"
#import "MyClassDelegate.h"
@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    MyClassDelegate *myclass = [[MyClassDelegate alloc]init];
    [myclass appDidLoadImage:@"This Is from Caller to Delegate methos"];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
