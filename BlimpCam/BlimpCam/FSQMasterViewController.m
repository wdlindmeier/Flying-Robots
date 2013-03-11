/*
 * Copyright (C) 2011 Ba-Z Communication Inc. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

// https://github.com/baztokyo/foursquare-ios-api

#import "FSQJSONObjectViewController.h"
#import "FSQMasterViewController.h"
#import "FHAppCredentials.h"
#import "AVCamCaptureManager.h"
#import <AVFoundation/AVFoundation.h>

@interface FSQMasterViewController ()
@property(nonatomic,readwrite,strong) BZFoursquare *foursquare;
@property(nonatomic,strong) BZFoursquareRequest *request;
@property(nonatomic,copy) NSDictionary *meta;
@property(nonatomic,copy) NSArray *notifications;
@property(nonatomic,copy) NSDictionary *response;
- (void)updateView;
- (void)cancelRequest;
- (void)prepareForRequest;
- (void)searchVenues;
- (void)checkin;
- (void)addPhoto;
@end

enum {
    kAuthenticationSection = 0,
    kEndpointsSection,
    kResponsesSection,
    kPhotoSection,
    kSectionCount
};

enum {
    kAccessTokenRow = 0,
    kAuthenticationRowCount
};

enum {
    kSearchVenuesRow = 0,
    kCheckInRow,
    kAddPhotoRow,
    kEndpointsRowCount
};

enum {
    kMetaRow = 0,
    kNotificationsRow,
    kResponseRow,
    kResponsesRowCount
};

enum {
    kTakePhoto = 0,
    kPhotoRowCount
};

@implementation FSQMasterViewController

@synthesize foursquare = _foursquare;
@synthesize request = _request;
@synthesize meta = _meta;
@synthesize notifications = _notifications;
@synthesize response = _response;


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if(self){
        [self initFSQController];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self initFSQController];
    }
    return self;
}

- (void)initFSQController
{
    self.foursquare = [[BZFoursquare alloc] initWithClientID:FHClientID
                                                 callbackURL:FHCallbackURL];
    _foursquare.version = @"20111119";
    _foursquare.locale = [[NSLocale currentLocale] objectForKey:NSLocaleLanguageCode];
    _foursquare.sessionDelegate = self;

    _captureManager = [[AVCamCaptureManager alloc] init];
    
    [_captureManager setDelegate:self];
    
    if ([_captureManager setupSession]) {

        // Create video preview layer and add it to the UI
        /*
        AVCaptureVideoPreviewLayer *newCaptureVideoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:[_captureManager session]];
        UIView *view = [self videoPreviewView];
        CALayer *viewLayer = [view layer];
        [viewLayer setMasksToBounds:YES];
        
        CGRect bounds = [view bounds];
        [newCaptureVideoPreviewLayer setFrame:bounds];
        
        if ([newCaptureVideoPreviewLayer isOrientationSupported]) {
            [newCaptureVideoPreviewLayer setOrientation:AVCaptureVideoOrientationPortrait];
        }
        
        [newCaptureVideoPreviewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
        
        [viewLayer insertSublayer:newCaptureVideoPreviewLayer below:[[viewLayer sublayers] objectAtIndex:0]];
        
        [self setCaptureVideoPreviewLayer:newCaptureVideoPreviewLayer];
         */
        
        // Start the session. This is done asychronously since -startRunning doesn't return until the session is running.
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [[_captureManager session] startRunning];
        });
        
    }

}

- (void)dealloc {
    _foursquare.sessionDelegate = nil;
    [self cancelRequest];
    [[NSNotificationCenter defaultCenter] removeObserver:self];

}

#pragma mark -
#pragma mark View lifecycle

#pragma mark -
#pragma mark UITableViewDataSource

- (int)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case kAuthenticationSection:
            return kAuthenticationRowCount;
            break;
        case kResponsesSection:
            return kResponsesRowCount;
            break;
        case kEndpointsSection:
            return kEndpointsRowCount;
            break;
        case kPhotoSection:
            return kPhotoRowCount;
            break;
    }
    return 0;
}

- (int)numberOfSectionsInTableView:(UITableView *)tableView
{
    return kSectionCount;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    switch (section) {
        case kAuthenticationSection:
            return @"Authentication";
            break;
        case kResponsesSection:
            return @"Response";
            break;
        case kEndpointsSection:
            return @"Endpoints";
            break;
        case kPhotoSection:
            return @"Camera";
            break;
    }
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
    if(!cell){
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                      reuseIdentifier:@"Cell"];
    }
    switch (indexPath.section) {
        case kAuthenticationSection:
            if (![_foursquare isSessionValid]) {
                cell.textLabel.text = NSLocalizedString(@"Obtain Access Token", @"");
            } else {
                cell.textLabel.text = NSLocalizedString(@"Forget Access Token", @"");
            }
            break;
        case kResponsesSection:
        {
            switch (indexPath.row) {
                case kMetaRow:
                    cell.textLabel.text = @"Meta";
                    break;
                case kNotificationsRow:
                    cell.textLabel.text = @"Notifications";
                    break;
                case kResponseRow:
                    cell.textLabel.text = @"Response";
                    break;
            }
        }
            break;
        case kEndpointsSection:
            switch (indexPath.row) {
                case kSearchVenuesRow:
                    cell.textLabel.text = @"Search Venues";
                    break;
                case kCheckInRow:
                    cell.textLabel.text = @"Check In";
                    break;
                case kAddPhotoRow:
                    cell.textLabel.text = @"Add a Photo";
                    break;
            }
            break;
        case kPhotoSection:
            cell.textLabel.text = @"Trigger Photo";
            break;
    }
    return cell;
}

#pragma mark -
#pragma mark UITableViewDelegate

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (indexPath.section) {
    case kAuthenticationSection:
        if (![_foursquare isSessionValid]) {
            cell.textLabel.text = NSLocalizedString(@"Obtain Access Token", @"");
        } else {
            cell.textLabel.text = NSLocalizedString(@"Forget Access Token", @"");
        }
        break;
    case kResponsesSection:
        {
            id collection = nil;
            switch (indexPath.row) {
            case kMetaRow:
                collection = _meta;
                break;
            case kNotificationsRow:
                collection = _notifications;
                break;
            case kResponseRow:
                collection = _response;
                break;
            }
            if (!collection) {
                cell.textLabel.enabled = NO;
                cell.detailTextLabel.text = nil;
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
            } else {
                cell.textLabel.enabled = YES;
                NSUInteger count = [collection count];
                NSString *format = (count == 1) ? NSLocalizedString(@"(%lu item)", @"") : NSLocalizedString(@"(%lu items)", @"");
                cell.detailTextLabel.text = [NSString stringWithFormat:format, count];
                cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            }
        }
        break;
    }
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    if (cell.selectionStyle == UITableViewCellSelectionStyleNone) {
        return nil;
    } else {
        return indexPath;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (indexPath.section) {
    case kAuthenticationSection:
        if (![_foursquare isSessionValid]) {
            [_foursquare startAuthorization];
        } else {
            [_foursquare invalidateSession];
            NSArray *indexPaths = [NSArray arrayWithObject:indexPath];
            [tableView reloadRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationNone];
            [tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
        }
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        break;
    case kEndpointsSection:
        switch (indexPath.row) {
        case kSearchVenuesRow:
            [self searchVenues];
            break;
        case kCheckInRow:
            [self checkin];
            break;
        case kAddPhotoRow:
            [self addPhoto];
            break;
        }
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        break;
    case kResponsesSection:
        {
            id JSONObject = nil;
            switch (indexPath.row) {
            case kMetaRow:
                JSONObject = _meta;
                break;
            case kNotificationsRow:
                JSONObject = _notifications;
                break;
            case kResponseRow:
                JSONObject = _response;
                break;
            }
            FSQJSONObjectViewController *JSONObjectViewController = [[FSQJSONObjectViewController alloc] initWithJSONObject:JSONObject];
            UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
            JSONObjectViewController.title = cell.textLabel.text;
            [self.navigationController pushViewController:JSONObjectViewController animated:YES];
        }
        break;
        case kPhotoSection:
        {
            [self initCameraPhoto];
        }
        break;
    }
}

#pragma mark - Image Picker

- (void)initCameraPhoto
{
    [_captureManager captureStillImage];
    
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
}

/*
- (void)dismissCamera
{
    if(_imgPickerController){
        UIImagePickerController *ip = _imgPickerController;
        [ip dismissViewControllerAnimated:NO
                               completion:^{
                                   _imgPickerController = nil;
                               }];
    }
}


- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    UIImage *img = [info valueForKey:UIImagePickerControllerOriginalImage];
    UIImageWriteToSavedPhotosAlbum(img, self, @selector(image:didFinishSavingWithError:contextInfo:), NULL);
}

- (void)imgePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [self dismissCamera];
}

- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *) error contextInfo:(void *)contextInfo
{
    if(error){
        NSLog(@"ERROR: Could not write image to library: %@", error);
    }
    [self dismissCamera];
}

- (void)cameraIsReady:(NSNotification *)note
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [_imgPickerController takePicture];
    });
}*/

#pragma mark - AVCamCaptureManagerDelegate

- (void)captureManager:(AVCamCaptureManager *)captureManager didFailWithError:(NSError *)error
{
    CFRunLoopPerformBlock(CFRunLoopGetMain(), kCFRunLoopCommonModes, ^(void) {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[error localizedDescription]
                                                            message:[error localizedFailureReason]
                                                           delegate:nil
                                                  cancelButtonTitle:NSLocalizedString(@"OK", @"OK button title")
                                                  otherButtonTitles:nil];
        [alertView show];
    });
}

- (void)captureManagerRecordingBegan:(AVCamCaptureManager *)captureManager
{
    //..
}

- (void)captureManagerRecordingFinished:(AVCamCaptureManager *)captureManager
{
    //..
}

- (void)captureManagerStillImageCaptured:(AVCamCaptureManager *)captureManager
{
    // Cool man. Should be in the lib.
    NSLog(@"CAPTURED STILL IMAGE");
}

- (void)captureManagerDeviceConfigurationChanged:(AVCamCaptureManager *)captureManager
{
    //...
}


#pragma mark -
#pragma mark BZFoursquareRequestDelegate

- (void)requestDidFinishLoading:(BZFoursquareRequest *)request
{
    self.meta = request.meta;
    self.notifications = request.notifications;
    self.response = request.response;
    self.request = nil;
    [self updateView];
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
}

- (void)request:(BZFoursquareRequest *)request didFailWithError:(NSError *)error {
    NSLog(@"%s: %@", __PRETTY_FUNCTION__, error);
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:nil message:[[error userInfo] objectForKey:@"errorDetail"] delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", @"") otherButtonTitles:nil];
    [alertView show];
    self.meta = request.meta;
    self.notifications = request.notifications;
    self.response = request.response;
    self.request = nil;
    [self updateView];
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
}

#pragma mark -
#pragma mark BZFoursquareSessionDelegate

- (void)foursquareDidAuthorize:(BZFoursquare *)foursquare {
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:kAccessTokenRow inSection:kAuthenticationSection];
    NSArray *indexPaths = [NSArray arrayWithObject:indexPath];
    [self.tableView reloadRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationNone];
}

- (void)foursquareDidNotAuthorize:(BZFoursquare *)foursquare error:(NSDictionary *)errorInfo {
    NSLog(@"%s: %@", __PRETTY_FUNCTION__, errorInfo);
}

#pragma mark -
#pragma mark Anonymous category

- (void)updateView {
    if ([self isViewLoaded]) {
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        [self.tableView reloadData];
        if (indexPath) {
            [self.tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
        }
    }
}

- (void)cancelRequest {
    if (_request) {
        _request.delegate = nil;
        [_request cancel];
        self.request = nil;
        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    }
}

- (void)prepareForRequest {
    [self cancelRequest];
    self.meta = nil;
    self.notifications = nil;
    self.response = nil;
}

- (void)searchVenues {
    [self prepareForRequest];
    NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:@"40.7,-74", @"ll", nil];
    self.request = [_foursquare requestWithPath:@"venues/search" HTTPMethod:@"GET" parameters:parameters delegate:self];
    [_request start];
    [self updateView];
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
}

- (void)checkin {
    [self prepareForRequest];
    NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:@"4d341a00306160fcf0fc6a88", @"venueId", @"public", @"broadcast", nil];
    self.request = [_foursquare requestWithPath:@"checkins/add" HTTPMethod:@"POST" parameters:parameters delegate:self];
    [_request start];
    [self updateView];
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
}

- (void)addPhoto {
    [self prepareForRequest];
    NSURL *photoURL = [[NSBundle mainBundle] URLForResource:@"TokyoBa-Z" withExtension:@"jpg"];
    NSData *photoData = [NSData dataWithContentsOfURL:photoURL];
    NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:photoData, @"photo.jpg", @"4d341a00306160fcf0fc6a88", @"venueId", nil];
    self.request = [_foursquare requestWithPath:@"photos/add" HTTPMethod:@"POST" parameters:parameters delegate:self];
    [_request start];
    [self updateView];
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
}

@end
