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
#import <ImageIO/ImageIO.h>
#import <MobileCoreServices/MobileCoreServices.h>

static WDLViewController *MainViewController = nil;

static NSString *FSQVenueIDFoodHogHQ = @"51462719e4b076f4b0a75dc1"; // Food Hog HQ
static NSString *FSQVenueIDIppudo = @"4a5403b8f964a520f3b21fe3"; // Ippudo
static NSString *FSQVenueIDPaulieGees = @"4b9709fcf964a520c4f434e3"; // Paulie Gees
static NSString *FSQVenueIDITP = @"408da280f964a520d8f21ee3"; // ITP
static NSString *RequestCheckinFlag = @"REQUEST_CHECKIN";

typedef enum AlertViewContexts {
    AlertViewContextNone = 0,
    AlertViewContextEnteredTargetRange
} AlertViewContext;

static const float ThresholdMetersInRangeOfTarget = 100.0;

@interface WDLViewController ()
{
    NSTimer *_timerUpdate;
    int _targetSelection;
    FSQVenue *_targetVenue;
    NSArray *_targets;
    BOOL _isShowingPickerView;
    AlertViewContext _alertViewContext;
    AVCamCaptureManager *_captureManager;
    NSString *_serverAddress;
    int _frameNum;
}

@property (atomic, assign) BOOL isRecording;
@property (atomic, assign) BOOL isCheckingIn;
@property (atomic, assign) BOOL didCheckIn;
@property (atomic, assign) BOOL isInRangeOfTarget;
@property (atomic, strong) NSDictionary *uploadParams;
@property (atomic, strong) UIImage *checkinPhoto;

@end

@implementation WDLViewController

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    return toInterfaceOrientation == UIInterfaceOrientationPortrait;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.isCheckingIn = NO;
    
    _serverAddress = @"10.0.1.19:8000";
    self.textFieldServerIP.text = _serverAddress;
    
    self.isRecording = NO;
    
    _isShowingPickerView = NO;
    self.isInRangeOfTarget = NO;
    _alertViewContext = AlertViewContextNone;
    
    _frameNum = 0;
    
    self.title = @"Food Hog";
    
    self.mapView.userInteractionEnabled = NO;
    self.mapView.userTrackingMode = MKUserTrackingModeFollowWithHeading;
    
    _timerUpdate = [NSTimer scheduledTimerWithTimeInterval:0.5
                                                    target:self
                                                  selector:@selector(updateLocation:)
                                                  userInfo:nil
                                                   repeats:YES];
    
    FSQVenue*venueHQ = [[FSQVenue alloc] init];
    venueHQ.name = @"Food Hog HQ";
    venueHQ.fsqID = FSQVenueIDFoodHogHQ;
    CLLocationCoordinate2D hqLL;
    hqLL.latitude = 40.716766;
    hqLL.longitude = -73.946428;
    venueHQ.coord = hqLL;
    
    FSQVenue*venuePaulieGees = [[FSQVenue alloc] init];
    venuePaulieGees.name = @"Paulie Gee's";
    venuePaulieGees.fsqID = FSQVenueIDPaulieGees;
    hqLL.latitude = 40.729568;
    hqLL.longitude = -73.958545;
    venuePaulieGees.coord = hqLL;
    
    FSQVenue*venueIppudo = [[FSQVenue alloc] init];
    venueIppudo.name = @"Ippudo";
    venueIppudo.fsqID = FSQVenueIDIppudo;
    hqLL.latitude = 40.731049;
    hqLL.longitude = -73.990263;
    venueIppudo.coord = hqLL;
    
    FSQVenue*venueITP = [[FSQVenue alloc] init];
    venueITP.name = @"ITP";
    venueITP.fsqID = FSQVenueIDITP;
    hqLL.latitude = 40.729064;
    hqLL.longitude = -73.993692;
    venueITP.coord = hqLL;
    
    _targetVenue = venueHQ;
    _targets = @[venueHQ, venuePaulieGees, venueIppudo, venueITP];
    
    //[self selectTarget:_venueCheckin];
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Target"
                                                                              style:UIBarButtonItemStylePlain
                                                                             target:self
                                                                             action:@selector(pickTarget:)];

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"FSQ"
                                                                             style:UIBarButtonItemStylePlain
                                                                            target:self
                                                                            action:@selector(foursquarePressed:)];

}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    MainViewController = self;
    [self fsqAuthenticate];
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

#pragma mark - IBOutlets

- (IBAction)buttonCameraPressed:(id)sender
{
    self.isRecording = !self.isRecording;
    
    if(self.isRecording){
        
        _serverAddress = self.textFieldServerIP.text;
        self.textFieldServerIP.enabled = NO;
        
        [self.buttonCamera setTitle:@"🎥"
                           forState:UIControlStateNormal];
        [self.buttonCamera setBackgroundColor:[UIColor redColor]];
        CABasicAnimation *pulseAnim = [CABasicAnimation animationWithKeyPath:@"opacity"];
        pulseAnim.fromValue = @(1.0);
        pulseAnim.toValue = @(0.3);
        pulseAnim.repeatCount = HUGE_VALF;
        pulseAnim.autoreverses = YES;
        pulseAnim.duration = 1.0f;
        [self.buttonCamera.layer addAnimation:pulseAnim forKey:@"pulse"];
        
        [self spinUpCameraForStreaming];
                
    }else{
        
        self.textFieldServerIP.enabled = YES;
        
        [self.buttonCamera setTitle:@"🔴"
                           forState:UIControlStateNormal];
        [self.buttonCamera.layer removeAnimationForKey:@"pulse"];
        [self.buttonCamera setBackgroundColor:[UIColor whiteColor]];
        
        [self tearDownCamera];
    }
}

#pragma mark - Streaming

- (void)streamNextImage
{
    if(self.isRecording){
        
        [_captureManager captureImageData:^(NSData *jpegData) {
            
            _frameNum = (_frameNum + 1) % 100;
            [self uploadImageData:jpegData frameNum:_frameNum];
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                [self streamNextImage];
            });
        }];
    }
}

NSData * JPEGDataWithCGImage(CGImageRef cgImage, UIImageOrientation orientation, CGFloat compressionQuality)
{
    NSData *      jpegData = nil;
    
    CFMutableDataRef      data = CFDataCreateMutable(NULL, 0);
    CGImageDestinationRef idst = CGImageDestinationCreateWithData(data, kUTTypeJPEG, 1, NULL);
    if (idst) {
        NSInteger   exif;
        switch (orientation) {
            case UIImageOrientationUp:            exif = 1; break;
            case UIImageOrientationDown:          exif = 3; break;
            case UIImageOrientationLeft:          exif = 8; break;
            case UIImageOrientationRight:         exif = 6; break;
            case UIImageOrientationUpMirrored:    exif = 2; break;
            case UIImageOrientationDownMirrored:  exif = 4; break;
            case UIImageOrientationLeftMirrored:  exif = 5; break;
            case UIImageOrientationRightMirrored: exif = 7; break;
        }
        NSDictionary *      props = [[NSDictionary alloc] initWithObjectsAndKeys:[NSNumber numberWithFloat:compressionQuality], kCGImageDestinationLossyCompressionQuality, [NSNumber numberWithInteger:exif], kCGImagePropertyOrientation, nil];
        
        CGImageDestinationAddImage(idst, cgImage, (__bridge CFDictionaryRef)props);
        if (CGImageDestinationFinalize(idst)) {
            jpegData = [NSData dataWithData:(__bridge NSData *)data];
        }
        CFRelease(idst);
    }
    
    CFRelease(data);
    
    return jpegData;
}

UIImageOrientation ImageOrientationFromCurrentDeviceOrientation()
{
    UIDeviceOrientation curDeviceOrientation = [[UIDevice currentDevice] orientation];
    UIImageOrientation imageOrientation;
    switch (curDeviceOrientation) {
        case UIDeviceOrientationLandscapeLeft:
            imageOrientation = UIImageOrientationRight;
            break;
        case UIDeviceOrientationLandscapeRight:
            imageOrientation = UIImageOrientationLeft;
            break;
        case UIDeviceOrientationPortraitUpsideDown:
            imageOrientation = UIImageOrientationDown;
            break;
        default:
            imageOrientation = UIImageOrientationUp;
            break;
    }
    return imageOrientation;
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    //NSLog(@"dropped frame");
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    //NSLog(@"Captured output");
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);

    int height = CVPixelBufferGetHeight(pixelBuffer);
    int width = CVPixelBufferGetWidth(pixelBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer);
    // Get the number of bytes per row for the pixel buffer
	UInt8 * frameData = CVPixelBufferGetBaseAddress(pixelBuffer);
    
    // Process pixel buffer bytes here
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef newContext = CGBitmapContextCreate(frameData,
                                                    width, height, 8,
                                                    bytesPerRow,
                                                    colorSpace,
                                                    kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    CGImageRef frame = CGBitmapContextCreateImage(newContext);

    UIImageOrientation imgOrient = ImageOrientationFromCurrentDeviceOrientation();
    NSData *jpegData = JPEGDataWithCGImage(frame, imgOrient, 0.5f);

    _frameNum = (_frameNum + 1) % 100;
    [self uploadImageData:jpegData frameNum:_frameNum];

    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    CGContextRelease(newContext);
    CGColorSpaceRelease(colorSpace);
    CGImageRelease(frame);
}

static NSString const *UploadBoundary = @"FlYiNgRoBoTsPyOnFoOd";
static NSString const *FileParamName = @"image";

- (void)uploadImageData:(NSData *)jpegData frameNum:(int)frameNum
{
    // create request
    
    NSURL *requestURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/upload",
                                              _serverAddress]];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
    [request setHTTPShouldHandleCookies:NO];
    [request setTimeoutInterval:10];
    [request setHTTPMethod:@"POST"];
    
    // set Content-Type in HTTP header
    NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", UploadBoundary];
    [request setValue:contentType forHTTPHeaderField: @"Content-Type"];
    
    // post body
    NSMutableData *body = [NSMutableData data];
    
    if(self.didCheckIn){
        NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:self.uploadParams];
        params[@"checked_in"] = [@(YES) stringValue];
        self.uploadParams = params;
        NSLog(@"NOTE: Sent did check in params: %@", self.uploadParams);
        self.didCheckIn = NO;
    }
    
    // add params (all params are strings)
    for(NSString *param in self.uploadParams) {
        [body appendData:[[NSString stringWithFormat:@"--%@\r\n", UploadBoundary] dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n\r\n", param] dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[[NSString stringWithFormat:@"%@\r\n", [self.uploadParams objectForKey:param]] dataUsingEncoding:NSUTF8StringEncoding]];
    }    
    
    // add image data
    [body appendData:[[NSString stringWithFormat:@"--%@\r\n", UploadBoundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"; filename=\"image%i.jpg\"\r\n",
                       FileParamName, frameNum] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[@"Content-Type: image/jpeg\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:jpegData];
    [body appendData:[[NSString stringWithFormat:@"\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
    
    [body appendData:[[NSString stringWithFormat:@"--%@--\r\n", UploadBoundary] dataUsingEncoding:NSUTF8StringEncoding]];
    
    // setting the body of the post to the reqeust
    [request setHTTPBody:body];
    
    // set the content-length
    NSString *postLength = [NSString stringWithFormat:@"%d", [body length]];
    [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
    
    // set URL
    [request setURL:requestURL];
    
    NSURLResponse* response;
    NSError* error = nil;
    
    NSData *respData = [NSURLConnection sendSynchronousRequest:request
                                             returningResponse:&response
                                                         error:&error];
    NSString *respString = [[NSString alloc] initWithData:respData encoding:NSUTF8StringEncoding];
    if([respString isEqualToString:RequestCheckinFlag]){
        UIImage *checkinImage = [UIImage imageWithData:jpegData];
        NSLog(@"ALERT: Request to checkin via FQS");
        dispatch_async(dispatch_get_main_queue(), ^{
            // Save the photo
            [MainViewController setCheckinPhoto:checkinImage];
            // Checkin
            [MainViewController fsqCheckinToVenue:_targetVenue];
        });
    }
    //NSLog(@"Uploaded photo %i", frameNum);
    // NSLog(@"Response: %@", );
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
            if([fsq isAuthenticated] && _targetVenue){
                [self fsqCheckinToVenue:_targetVenue];
            }else{
                if(![fsq isAuthenticated]){
                    [[[UIAlertView alloc] initWithTitle:nil
                                                message:@"You are not logged into FourSquare"
                                               delegate:nil
                                      cancelButtonTitle:@"OK"
                                      otherButtonTitles:nil] show];
                }else if(!_targetVenue){
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

- (void)spinUpCameraForStreaming
{
    if(!_captureManager){
        
        NSLog(@"Spinning up camera for streaming");
        
        _captureManager = [[AVCamCaptureManager alloc] init];
        
        [_captureManager setDelegate:self];
        
        if ([_captureManager setupSession:AVCaptureSessionPresetLow
                                flashMode:AVCaptureFlashModeOff
                           outputDelegate:self]) {
            // Start the session. This is done asychronously since -startRunning doesn't return until the session is running.
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                NSLog(@"startRunning");
                [[_captureManager session] startRunning];
            });
            
        }
    }
}

- (void)spinUpCamera
{
    if(!_captureManager){
        
        NSLog(@"Spinning up camera");
        
        _captureManager = [[AVCamCaptureManager alloc] init];
        
        [_captureManager setDelegate:self];
        
        if ([_captureManager setupSession:AVCaptureSessionPresetMedium
                                flashMode:AVCaptureFlashModeAuto
                           outputDelegate:nil]) {
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
            if(_targetVenue){
                [self fsqUploadPhoto:camImage toVenue:_targetVenue];
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
    // [self spinUpCamera];
    // [self fsqSearchNearby];
}

- (void)targetSpotted
{
    if(_targetVenue){
        _alertViewContext = AlertViewContextEnteredTargetRange;
        NSString *msg = [NSString stringWithFormat:@"You have entered the range of your target: %@", _targetVenue.name];
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
}

- (void)updateLocation:(NSTimer *)t
{
    CLLocationAccuracy hAccuracy = [WDLLocationManager sharedManager].currentLocation.horizontalAccuracy;

    // Toss out anything that's inaccurate
    if(hAccuracy > 0.0 && hAccuracy < 100.0){

        CLLocationCoordinate2D coords = [WDLLocationManager sharedManager].currentCoord;
        CLLocationDistance distMeters = [[WDLLocationManager sharedManager] distanceMetersFromLocation:_targetVenue.coord];

        NSString *rangeIndicator = self.isInRangeOfTarget ? @"*" : @"";
        self.labelCoords.text = [NSString stringWithFormat:@"   %f, %f, Δ %0.2fm %@",
                                 coords.latitude, coords.longitude, distMeters, rangeIndicator];
        
        if(!self.isInRangeOfTarget && distMeters < ThresholdMetersInRangeOfTarget){
            self.isInRangeOfTarget = YES;
            [self enteredRangeOfTarget];
        }else if(self.isInRangeOfTarget && distMeters > ThresholdMetersInRangeOfTarget){
            self.isInRangeOfTarget = NO;
            [self exitedRangeOfTarget];
        }
        
        self.uploadParams = @{@"lat" : [@(coords.latitude) stringValue],
                              @"lng" : [@(coords.longitude) stringValue],
                              @"dist" : [@(distMeters) stringValue],
                              @"in_range" : [@(self.isInRangeOfTarget) stringValue],
                              @"target_name" : _targetVenue.name,
                              };
    }
}

#pragma mark - Text Field

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return NO;
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
            NSLog(@"Found %i nearby venues", results.count);
            for(FSQVenue *v in results){
                //...
            }
        } error:^(NSDictionary *errorInfo) {
            NSLog(@"ERROR searching for venues: %@", errorInfo);
        }];
    }
}

- (void)fsqCheckinToVenue:(FSQVenue *)venue
{
    WDLFSQManager *fsq = [WDLFSQManager sharedManager];
    if([fsq isAuthenticated] && !self.isCheckingIn){
        self.isCheckingIn = YES;
        [fsq checkinToVenue:venue
                    success:^(NSDictionary *response) {
                        NSLog(@"SUCCESS: %@", response);
                        self.didCheckIn = YES;
                        self.isCheckingIn = NO;
                        if(self.checkinPhoto){
                            NSLog(@"We have a checkin photo. Uploading now.");
                            [self fsqUploadPhoto:self.checkinPhoto
                                         toVenue:venue];
                            [MainViewController setCheckinPhoto:nil];
                        }
                    } error:^(NSDictionary *errorInfo) {
                        NSLog(@"ERROR checking in: %@", errorInfo);
                        [MainViewController setCheckinPhoto:nil] ;
                        self.didCheckIn = NO;
                        self.isCheckingIn = NO;
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
    //[self fsqAuthenticate];
    [self fsqCheckinToVenue:_targetVenue];
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
    return _targets.count;
}

// tell the picker how many components it will have
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return 1;
}

// tell the picker the title for a given component
- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    return ((FSQVenue *)_targets[row]).name;
}

#pragma mark - UIPickerViewDelegate

- (void)pickerView:(UIPickerView *)pickerView didSelectRow: (NSInteger)row inComponent:(NSInteger)component
{
    _targetVenue = _targets[row];
    [self setPickerViewIsVisible:NO];
}

- (void)setTargetSelection
{
    [self.pickerViewTarget selectRow:[_targets indexOfObject:_targetVenue]
                         inComponent:0
                            animated:YES];
}

@end
