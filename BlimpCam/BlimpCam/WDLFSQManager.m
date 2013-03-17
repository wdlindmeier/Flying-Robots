//
//  WDLFSQManager.m
//  BlimpCam
//
//  Created by William Lindmeier on 3/17/13.
//  Copyright (c) 2013 William Lindmeier. All rights reserved.
//

#import "WDLFSQManager.h"
#import "FSQJSONObjectViewController.h"
#import "FSQAppCredentials.h"
#import "WDLLocationManager.h"
#import "FSQVenue.h"

@interface WDLFSQManager()

@property(nonatomic,strong) BZFoursquareRequest *request;
@property(nonatomic,copy) NSDictionary *meta;
@property(nonatomic,copy) NSArray *notifications;
@property(nonatomic,copy) NSDictionary *response;

@end

@implementation WDLFSQManager
{
    FSQErrorBlock _errorCallback;
    FSQSuccessBlock _successCallback;
}

- (id)init
{
    self = [super init];
    if(self){
        self.foursquare = [[BZFoursquare alloc] initWithClientID:FHClientID
                                                     callbackURL:FHCallbackURL];
        _foursquare.version = @"20111119";
        _foursquare.locale = [[NSLocale currentLocale] objectForKey:NSLocaleLanguageCode];
        _foursquare.sessionDelegate = self;
    }
    return self;
}

- (void)dealloc {
    _foursquare.sessionDelegate = nil;
    [self cancelRequest];
}

#pragma mark - FSQ Requests

#pragma mark -
#pragma mark BZFoursquareRequestDelegate

- (void)requestDidFinishLoading:(BZFoursquareRequest *)request
{
    self.meta = request.meta;
    self.notifications = request.notifications;
    self.response = request.response;
    self.request = nil;
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    NSLog(@"requestDidFinishLoading. Calling success block: %@", _successCallback);
    _successCallback();
}

- (void)request:(BZFoursquareRequest *)request didFailWithError:(NSError *)error
{
    NSLog(@"%s: %@", __PRETTY_FUNCTION__, error);
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:nil
                                                        message:[[error userInfo] objectForKey:@"errorDetail"]
                                                       delegate:nil
                                              cancelButtonTitle:NSLocalizedString(@"OK", @"")
                                              otherButtonTitles:nil];
    [alertView show];
    self.meta = request.meta;
    self.notifications = request.notifications;
    self.response = request.response;
    self.request = nil;
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    _errorCallback([error userInfo]);
}

#pragma mark -
#pragma mark BZFoursquareSessionDelegate

- (void)foursquareDidAuthorize:(BZFoursquare *)foursquare
{
    NSLog(@"foursquareDidAuthorize");
    _successCallback();
}

- (void)foursquareDidNotAuthorize:(BZFoursquare *)foursquare error:(NSDictionary *)errorInfo {
    NSLog(@"%s: %@", __PRETTY_FUNCTION__, errorInfo);
    _errorCallback(errorInfo);
}

- (void)cancelRequest
{
    if (_request) {
        _request.delegate = nil;
        [_request cancel];
        self.request = nil;
        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    }
}

- (void)prepareForRequest
{
    [self cancelRequest];
    self.meta = nil;
    self.notifications = nil;
    self.response = nil;
}

/*
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
*/

#pragma mark - Authentication

- (BOOL)isAuthenticated
{
    return [_foursquare isSessionValid];
}

- (void)authenticateWithSuccess:(void (^)(void))successCallback
                          error:(FSQErrorBlock)errorCallback
{
    _successCallback = successCallback;
    _errorCallback = errorCallback;
    [_foursquare startAuthorization];
}

- (void)logout
{
    [_foursquare invalidateSession];
}

#pragma mark - Specific Requests

- (void)searchForNearbyVenuesWithSuccess:(void (^)(NSArray * results))successCallback
                                   error:(FSQErrorBlock)errorCallback
{
    NSLog(@"Searching for venues");
    WDLFSQManager __weak *weakSelf = self;
    _successCallback = ^{
        // NSLog(@"self.response: %@", weakSelf.response);
        NSArray *venueData = [(NSDictionary *)weakSelf.response valueForKey:@"venues"];
        NSMutableArray *venues = [NSMutableArray arrayWithCapacity:venueData.count];
        for(NSDictionary *vinfo in venueData){
            FSQVenue *v = [[FSQVenue alloc] initWithResponseData:vinfo];
            [venues addObject:v];
        }
        successCallback([NSArray arrayWithArray:venues]);
    };
    _errorCallback = errorCallback;

    [self prepareForRequest];
    
    CLLocationCoordinate2D coord = [[WDLLocationManager sharedManager] currentCoord];
    
    NSString *query = [NSString stringWithFormat:@"%f,%f", coord.latitude, coord.longitude];
    NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:query, @"ll", nil];
    self.request = [_foursquare requestWithPath:@"venues/search"
                                     HTTPMethod:@"GET"
                                     parameters:parameters
                                       delegate:self];
    [_request start];
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
}

#pragma mark - Singleton
    
+ (WDLFSQManager *)sharedManager
{
    static WDLFSQManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[WDLFSQManager alloc] init];
    });
    return sharedManager;
}

@end
