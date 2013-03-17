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
#import "FSQVenue.h"
#import <AVFoundation/AVFoundation.h>

static NSString *FSQVenueIDFoodHogHQ = @"51462719e4b076f4b0a75dc1"; // Food Hog HQ
static NSString *FSQVenueIDIppudo = @"4a5403b8f964a520f3b21fe3"; // Ippudo
static NSString *FSQVenueIDPaulieGees = @"4b9709fcf964a520c4f434e3"; // Paulie Gees

enum Targets {
    TargetFoodHogHQ = 0,
    TargetPaulieGees = 1,
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
    CLLocationCoordinate2D _coordsFoodHogHQ;
    CLLocationCoordinate2D _coordsPaulieGees;
    CLLocationCoordinate2D _coordsIppudo;
    CLLocationCoordinate2D _coordsTarget;
    BOOL _isShowingPickerView;
    BOOL _isInRangeOfTarget;
    AlertViewContext _alertViewContext;
    AVCamCaptureManager *_captureManager;
    FSQVenue *_venueCheckin;
    NSArray *_venueIDsOfInterest;
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
    _venueCheckin = nil;
    _venueIDsOfInterest = @[FSQVenueIDFoodHogHQ, FSQVenueIDIppudo, FSQVenueIDPaulieGees];
    
    self.title = @"Food Hog";
    
    self.mapView.userInteractionEnabled = NO;
    self.mapView.userTrackingMode = MKUserTrackingModeFollowWithHeading;
    
    _timerUpdate = [NSTimer scheduledTimerWithTimeInterval:0.5
                                                    target:self
                                                  selector:@selector(updateLocation:)
                                                  userInfo:nil
                                                   repeats:YES];
    
    _coordsFoodHogHQ.latitude = 40.716766;
    _coordsFoodHogHQ.longitude = -73.946428;
    
    _coordsPaulieGees.latitude = 40.697488;
    _coordsPaulieGees.longitude = -73.979681;
    
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
    [self tearDownCamera];
}

- (void)dealloc
{
    [self tearDownCamera];
}

#pragma mark - UIAlertView delegate

static NSString *AlertButtonTitleTakePhoto = @"Take Photo";
static NSString *AlertButtonTitleCheckIn = @"Check In";

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if(_alertViewContext == AlertViewContextEnteredTargetRange && buttonIndex != alertView.cancelButtonIndex){
        NSString *title = [alertView buttonTitleAtIndex:buttonIndex];
        if([title isEqualToString:AlertButtonTitleTakePhoto]){
            [self capturePhoto];
        }else if([title isEqualToString:AlertButtonTitleCheckIn]){
            WDLFSQManager *fsq = [WDLFSQManager sharedManager];
            if([fsq isAuthenticated] && _venueCheckin){
                [self fsqCheckinToVenue:_venueCheckin];
            }else{
                if(![fsq isAuthenticated]){
                    [[[UIAlertView alloc] initWithTitle:nil
                                                message:@"You are not logged into FourSquare"
                                               delegate:nil
                                      cancelButtonTitle:@"OK"
                                      otherButtonTitles:nil] show];
                }else if(!_venueCheckin){
                    [[[UIAlertView alloc] initWithTitle:nil
                                                message:@"Could not find a venue to check into"
                                               delegate:nil
                                      cancelButtonTitle:@"OK"
                                      otherButtonTitles:nil] show];
                }
            }
        }
    }
    _alertViewContext = AlertViewContextNone;
}

#pragma mark - AV

- (void)spinUpCamera
{
    if(!_captureManager){
        
        NSLog(@"Spinning up camera");
        
        _captureManager = [[AVCamCaptureManager alloc] init];
        
        [_captureManager setDelegate:self];
        
        if ([_captureManager setupSession]) {
            // Start the session. This is done asychronously since -startRunning doesn't return until the session is running.
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [[_captureManager session] startRunning];
            });
            
        }
    }
}

- (void)tearDownCamera
{
    if(_captureManager){
        
        NSLog(@"Tearing down camera");
        
        _captureManager.delegate = nil;
        [_captureManager stopRecording];
        [[_captureManager session] stopRunning];
        _captureManager = nil;
    }
}

- (void)capturePhoto
{
    if(_captureManager){
        
        [_captureManager captureStillImage:^(UIImage *camImage) {
            // Upload that baby to fsq
            if(_venueCheckin){
                [self fsqUploadPhoto:camImage toVenue:_venueCheckin];
            }
        }];
        
        // Flash the screen white and fade it out to give UI feedback that a still image was taken
        UIView *flashView = [[UIView alloc] initWithFrame:self.view.bounds];
        [flashView setBackgroundColor:[UIColor whiteColor]];
        [[[self view] window] addSubview:flashView];
        
        [UIView animateWithDuration:.4f
                         animations:^{
                             [flashView setAlpha:0.f];
                         }
                         completion:^(BOOL finished){
                             [flashView removeFromSuperview];
                         }
         ];
    }else{
        NSLog(@"ERROR: _captureManager is nil");
    }
}

#pragma mark - Location

- (void)enteredRangeOfTarget
{
    NSLog(@"enteredRangeOfTarget");
    // Spin up an AV session
    [self spinUpCamera];
    [self fsqSearchNearby];
}

- (void)targetSpotted
{
    if(_venueCheckin){
        _alertViewContext = AlertViewContextEnteredTargetRange;
        NSString *msg = [NSString stringWithFormat:@"You have entered the range of your target: %@", _venueCheckin.name];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Target Spotted!"
                                                        message:msg
                                                       delegate:self
                                              cancelButtonTitle:@"Dismiss"
                                              otherButtonTitles:AlertButtonTitleTakePhoto,
                                                                AlertButtonTitleCheckIn,
                              nil];
        [alert show];
    }
}

- (void)exitedRangeOfTarget
{
    NSLog(@"exitedRangeOfTarget");
    
    // Wind down AV session
    [self tearDownCamera];
    
    _venueCheckin = nil;
    
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

- (void)fsqAuthenticate
{
    WDLFSQManager *fsq = [WDLFSQManager sharedManager];
    if(![fsq isAuthenticated]){
        [fsq authenticateWithSuccess:^{
            NSLog(@"SUCCCESS authenticating");
        } error:^(NSDictionary *errorInfo) {
            NSLog(@"ERROR authenticating: %@", errorInfo);
        }];
    }else{
        NSLog(@"User is already authenticated");
    }
}

- (void)fsqSearchNearby
{
    WDLFSQManager *fsq = [WDLFSQManager sharedManager];
    if([fsq isAuthenticated]){
        [fsq searchForNearbyVenuesWithSuccess:^(NSArray *results) {
            _venueCheckin = nil;
            NSLog(@"Found %i nearby venues", results.count);
            for(FSQVenue *v in results){
                // Just a simple loop over the known venues.
                // We'll pick the first one.
                for(NSString *venueID in _venueIDsOfInterest){
                    if([v.fsqID isEqualToString:venueID]){
                        _venueCheckin = v;
                        break;
                    }
                }
                if(_venueCheckin) break;
            }
            if(_venueCheckin){
                [self targetSpotted];
            }
        } error:^(NSDictionary *errorInfo) {
            NSLog(@"ERROR searching for venues: %@", errorInfo);
        }];
    }
}

- (void)fsqCheckinToVenue:(FSQVenue *)venue
{
    WDLFSQManager *fsq = [WDLFSQManager sharedManager];
    if([fsq isAuthenticated]){
        [fsq checkinToVenue:venue
                    success:^(NSDictionary *response) {
                        NSLog(@"SUCCESS: %@", response);
                    } error:^(NSDictionary *errorInfo) {
                        NSLog(@"ERROR checking in: %@", errorInfo);
                    }];
    }
}

- (void)fsqUploadPhoto:(UIImage *)img toVenue:(FSQVenue *)venue
{
    WDLFSQManager *fsq = [WDLFSQManager sharedManager];
    if([fsq isAuthenticated]){
        [fsq uploadPhoto:img
                 toVenue:venue
                 success:^(NSDictionary *response) {
                     NSLog(@"Photo Upload SUCCESS: %@", response);
                 } error:^(NSDictionary *errorInfo) {
                     NSLog(@"ERROR uploading photo: %@", errorInfo);
                 }];
    }    
}

- (void)foursquarePressed:(id)sender
{
    [self fsqAuthenticate];
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
        case TargetFoodHogHQ:
            title = @"Food Hog HQ";
            break;
        case TargetPaulieGees:
            title = @"Paulie Gees";
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
    switch (targetNum) {
        case TargetFoodHogHQ:
            _coordsTarget = _coordsFoodHogHQ;
            break;
        case TargetPaulieGees:
            _coordsTarget = _coordsPaulieGees;
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
