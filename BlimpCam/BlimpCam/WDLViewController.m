//
//  WDLViewController.m
//  BlimpCam
//
//  Created by William Lindmeier on 3/11/13.
//  Copyright (c) 2013 William Lindmeier. All rights reserved.
//

#import "WDLViewController.h"
#import "WDLLocationManager.h"

@interface WDLViewController ()
{
    NSTimer *_timerUpdate;
}
@end

@implementation WDLViewController

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    return toInterfaceOrientation == UIInterfaceOrientationPortrait;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"GPS";
    self.mapView.userInteractionEnabled = NO;
    self.mapView.userTrackingMode = MKUserTrackingModeFollowWithHeading;
    _timerUpdate = [NSTimer scheduledTimerWithTimeInterval:0.5
                                                    target:self
                                                  selector:@selector(updateLocation:)
                                                  userInfo:nil
                                                   repeats:YES];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    [_timerUpdate invalidate];
    _timerUpdate = nil;
}

- (void)updateLocation:(NSTimer *)t
{
    CLLocationCoordinate2D coords = [WDLLocationManager sharedManager].currentCoord;
    self.labelCoords.text = [NSString stringWithFormat:@"   %f, %f", coords.latitude, coords.longitude];
}

@end
