//
//  WDLViewController.m
//  BlimpCam
//
//  Created by William Lindmeier on 3/11/13.
//  Copyright (c) 2013 William Lindmeier. All rights reserved.
//

#import "WDLViewController.h"
#import "WDLLocationManager.h"
#import "WDLFSQManager.h"

enum Targets {
    Target368Manhattan = 0,
    Target116Noble = 1,
    TargetIppudo = 2,
    NumTargets
};

typedef enum AlertViewContexts {
    AlertViewContextNone = 0,
    AlertViewContextEnteredTargetRange
} AlertViewContext;

static const float ThresholdMetersInRangeOfTarget = 100.0;

@interface WDLViewController ()
{
    NSTimer *_timerUpdate;
    int _targetSelection;
    CLLocationCoordinate2D _coords116Noble;
    CLLocationCoordinate2D _coords368Manhattan;
    CLLocationCoordinate2D _coordsIppudo;
    CLLocationCoordinate2D _coordsTarget;
    BOOL _isShowingPickerView;
    BOOL _isInRangeOfTarget;
    AlertViewContext _alertViewContext;
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
    
    _isShowingPickerView = NO;
    _isInRangeOfTarget = NO;
    _alertViewContext = AlertViewContextNone;
    
    self.title = @"GPS";
    
    self.mapView.userInteractionEnabled = NO;
    self.mapView.userTrackingMode = MKUserTrackingModeFollowWithHeading;
    
    _timerUpdate = [NSTimer scheduledTimerWithTimeInterval:0.5
                                                    target:self
                                                  selector:@selector(updateLocation:)
                                                  userInfo:nil
                                                   repeats:YES];
    
    _coords116Noble.latitude = 40.728598;
    _coords116Noble.longitude = -73.955955;
    
    _coords368Manhattan.latitude = 40.716766;
    _coords368Manhattan.longitude = -73.946428;
    
    _coordsIppudo.latitude = 40.731049;
    _coordsIppudo.longitude = -73.990263;
    
    [self selectTarget:TargetIppudo];
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Target"
                                                                              style:UIBarButtonItemStylePlain
                                                                             target:self
                                                                             action:@selector(pickTarget:)];

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"FSQ"
                                                                             style:UIBarButtonItemStylePlain
                                                                            target:self
                                                                            action:@selector(foursquarePressed:)];

}

- (void)viewDidUnload
{
    [super viewDidUnload];
    [_timerUpdate invalidate];
    _timerUpdate = nil;
}

#pragma mark - UIAlertView delegate

static NSString *AlertButtonTitleTakePhoto = @"Take Photo";
static NSString *AlertButtonTitleCheckIn = @"Check In";

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if(_alertViewContext == AlertViewContextEnteredTargetRange && buttonIndex != alertView.cancelButtonIndex){
        NSString *title = [alertView buttonTitleAtIndex:buttonIndex];
        if([title isEqualToString:AlertButtonTitleTakePhoto]){
            // TODO: Take a photo
            NSLog(@"TODO: Take a photo");
        }else if([title isEqualToString:AlertButtonTitleCheckIn]){
            // TODO: Check in
            NSLog(@"TODO: Check in");
        }
    }
    _alertViewContext = AlertViewContextNone;
}

#pragma mark - Location

- (void)enteredRangeOfTarget
{
    _alertViewContext = AlertViewContextEnteredTargetRange;
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil
                                                    message:@"You have entered the range of your target"
                                                   delegate:self
                                          cancelButtonTitle:@"Dismiss"
                                          otherButtonTitles:AlertButtonTitleTakePhoto,
                                                            AlertButtonTitleCheckIn, nil];
    [alert show];
}

- (void)exitedRangeOfTarget
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil
                                                    message:@"You have left the range of your target"
                                                   delegate:nil
                                          cancelButtonTitle:@"Dismiss"
                                          otherButtonTitles:nil];
    [alert show];
}

- (void)updateLocation:(NSTimer *)t
{
    CLLocationAccuracy hAccuracy = [WDLLocationManager sharedManager].currentLocation.horizontalAccuracy;

    // Toss out anything that's inaccurate
    if(hAccuracy > 0.0 && hAccuracy < 100.0){

        CLLocationCoordinate2D coords = [WDLLocationManager sharedManager].currentCoord;
        CLLocationDistance distMeters = [[WDLLocationManager sharedManager] distanceMetersFromLocation:_coordsTarget];

        NSString *rangeIndicator = _isInRangeOfTarget ? @"*" : @"";
        self.labelCoords.text = [NSString stringWithFormat:@"   %f, %f, Δ %0.2fm %@",
                                 coords.latitude, coords.longitude, distMeters, rangeIndicator];
        
        if(!_isInRangeOfTarget && distMeters < ThresholdMetersInRangeOfTarget){
            _isInRangeOfTarget = YES;
            [self enteredRangeOfTarget];
        }else if(_isInRangeOfTarget && distMeters > ThresholdMetersInRangeOfTarget){
            _isInRangeOfTarget = NO;
            [self exitedRangeOfTarget];
        }
        
    }
}

#pragma mark - Foursquare

- (void)foursquarePressed:(id)sender
{
    WDLFSQManager *fsq = [WDLFSQManager sharedManager];
    if([fsq isAuthenticated]){
        [fsq searchForNearbyVenuesWithSuccess:^(NSArray *results) {
            NSLog(@"Found nearby venues:\n%@", results);
        } error:^(NSDictionary *errorInfo) {
            NSLog(@"ERROR searching for venues: %@", errorInfo);
        }];
    }else{
        [fsq authenticateWithSuccess:^{
            NSLog(@"SUCCCESS authenticating");
        } error:^(NSDictionary *errorInfo) {
            NSLog(@"ERROR authenticating: %@", errorInfo);
        }];
    }
}

#pragma mark - Picker View

- (void)pickTarget:(id)sender
{
    if(!_isShowingPickerView){
        [self setPickerViewIsVisible:YES];
    }else{
        [self setPickerViewIsVisible:NO];
    }
}

- (void)setPickerViewIsVisible:(BOOL)visible
{
    if(!_isShowingPickerView){
        [self.pickerViewTarget reloadAllComponents];
        [self setTargetSelection];
    }
    _isShowingPickerView = visible;
    [self.view addSubview:self.pickerViewTarget];
    CGSize sizePicker = self.pickerViewTarget.frame.size;
    CGSize sizeView = self.view.frame.size;
    CGRect rectFrom = CGRectMake(0, sizeView.height, sizeView.width, sizePicker.height);
    CGRect rectTo = rectFrom;
    rectTo.origin.y = rectFrom.origin.y - sizePicker.height;

    if(!_isShowingPickerView){
        CGRect rectSwap = rectTo;
        rectTo = rectFrom;
        rectFrom = rectSwap;
    }
    
    self.pickerViewTarget.frame = rectFrom;
    [UIView animateWithDuration:0.35
                     animations:^{
                         self.pickerViewTarget.frame = rectTo;
                     } completion:^(BOOL finished) {
                         if(!_isShowingPickerView){
                             [self.pickerViewTarget removeFromSuperview];
                         }
                     }];
}

#pragma mark - UIPickerViewDataSource

// tell the picker how many rows are available for a given component
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    return NumTargets;
}

// tell the picker how many components it will have
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return 1;
}

// tell the picker the title for a given component
- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    NSString *title = nil;
    switch (row) {
        case Target368Manhattan:
            title = @"368 Manhattan";
            break;
        case Target116Noble:
            title = @"116 Noble";
            break;
        case TargetIppudo:
            title = @"Ippudo";
            break;
    }
    return title;
}

#pragma mark - UIPickerViewDelegate

- (void)pickerView:(UIPickerView *)pickerView didSelectRow: (NSInteger)row inComponent:(NSInteger)component
{
    [self selectTarget:row];
    [self setPickerViewIsVisible:NO];
}

- (void)selectTarget:(int)targetNum
{
    _targetSelection = targetNum;
    _isInRangeOfTarget = NO;
    switch (targetNum) {
        case Target368Manhattan:
            _coordsTarget = _coords368Manhattan;
            break;
        case Target116Noble:
            _coordsTarget = _coords116Noble;
            break;
        case TargetIppudo:
            _coordsTarget = _coordsIppudo;
            break;
    }
}

- (void)setTargetSelection
{
    [self.pickerViewTarget selectRow:_targetSelection
                         inComponent:0
                            animated:YES];
}

@end
