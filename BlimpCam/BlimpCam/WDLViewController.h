//
//  WDLViewController.h
//  BlimpCam
//
//  Created by William Lindmeier on 3/11/13.
//  Copyright (c) 2013 William Lindmeier. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "WDLHeadingView.h"
#import <MapKit/MapKit.h>

@interface WDLViewController : UIViewController <MKMapViewDelegate>

@property (nonatomic, strong) IBOutlet WDLHeadingView *headingView;
@property (nonatomic, strong) IBOutlet UILabel *labelCoords;
@property (nonatomic, strong) IBOutlet MKMapView *mapView;

@end
