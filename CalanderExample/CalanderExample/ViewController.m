//
//  ViewController.m
//  CalanderExample
//
//  Created by Kian Davoudi-Rad on 2017-03-28.
//  Copyright © 2017 Kian Davoudi-Rad. All rights reserved.
//

#import "ViewController.h"
#import <EventKit/EventKit.h>

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    // Functio Description:
    // Get all events in for a certain day.

//    EKEventStore *eventStore = [[EKEventStore alloc] init];
    EKEventStore *store = [[EKEventStore alloc] init];
    EKEventStore *store = [[EKEventStore alloc] initWithAccessToEntityTypes:EKEntityMaskEvent];

//    NSCalendar *calendar = [NSCalendar currentCalendar];
//
//    // Create the start date components
//    NSDateComponents *oneDayAgoComponents = [[NSDateComponents alloc] init];
//    oneDayAgoComponents.day = -1;
//    NSDate *oneDayAgo = [calendar dateByAddingComponents:oneDayAgoComponents
//                                                  toDate:[NSDate date]
//                                                 options:0];
//
//    // Create the end date components
//    NSDateComponents *oneYearFromNowComponents = [[NSDateComponents alloc] init];
//    oneYearFromNowComponents.year = 1;
//    NSDate *oneYearFromNow = [calendar dateByAddingComponents:oneYearFromNowComponents
//                                                       toDate:[NSDate date]
//                                                      options:0];
//
//    // Create the predicate from the event store's instance method
//    NSPredicate *predicate = [store predicateForEventsWithStartDate:oneDayAgo
//                                                            endDate:oneYearFromNow
//                                                          calendars:nil];
//
//    // Fetch all events that match the predicate
//    NSArray *events = [store eventsMatchingPredicate:predicate];



}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
