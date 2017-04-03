//
//  ViewController.m
//  EventProtocol
//
//  Created by Kian Davoudi-Rad on 2017-04-03.
//  Copyright © 2017 Kian Davoudi-Rad. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    _calServices = [[ICalServices alloc]init];
    [_calServices loadCalanderServices];
    [_calServices checkEventStoreAccessForCalendar];
//    NSMutableArray *test = [_calServices fetchEvents];
//    NSLog(@"OK,%@",test);
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
