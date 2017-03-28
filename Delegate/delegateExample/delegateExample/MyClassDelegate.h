//
//  MyClassDelegate.h
//  delegateExample
//
//  Created by Kian Davoudi-Rad on 2017-03-16.
//  Copyright © 2017 Kian Davoudi-Rad. All rights reserved.
//
#import <Foundation/Foundation.h>
#include "MyClassDelegateProtocol.h"

@interface MyClassDelegate : NSObject
{
    //Local Vars
    id <MyClassDelegateProtocol> delegate;
}
// Autosynthesize the member, It Actually provides getter and setter.
@property (nonatomic, assign) id <MyClassDelegateProtocol> delegate;
@end

@implementation MyClassDelegate



-(void) appDidLoadImage:(NSString*)confirmationMessage{
    NSLog(@"Success!");
    NSLog(@"%@",confirmationMessage);
}
@end
