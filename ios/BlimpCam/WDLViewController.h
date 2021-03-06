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
#import "AVCamCaptureManager.h"

@interface WDLViewController : UIViewController <
MKMapViewDelegate,
UIPickerViewDataSource,
UIPickerViewDelegate,
UIAlertViewDelegate,
AVCamCaptureManagerDelegate,
AVCaptureVideoDataOutputSampleBufferDelegate,
UITextFieldDelegate>

@property (nonatomic, strong) IBOutlet WDLHeadingView *headingView;
@property (nonatomic, strong) IBOutlet UILabel *labelCoords;
@property (nonatomic, strong) IBOutlet MKMapView *mapView;
@property (nonatomic, strong) IBOutlet UIPickerView *pickerViewTarget;
@property (nonatomic, strong) IBOutlet UIButton *buttonCamera;
@property (nonatomic, strong) IBOutlet UITextField *textFieldServerIP;

- (IBAction)buttonCameraPressed:(id)sender;

@end
