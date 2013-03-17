//
//  WDLLocationManager.m
//  BlimpCam
//
//  Created by William Lindmeier on 3/17/13.
//  Copyright (c) 2013 William Lindmeier. All rights reserved.
//

#import "WDLLocationManager.h"

@implementation WDLLocationManager
{
    CLLocationManager *_locationManager;
    CLLocation *_currentLocation;
    CLLocationDirection _trueHeading;
    CLLocationCoordinate2D _currentCoord;
    BOOL _isUpdatingLocation;
}

@synthesize trueHeading = _trueHeading;
@synthesize currentCoord = _currentCoord;

- (id)init
{
    self = [super init];
    if(self){
        _locationManager = [[CLLocationManager alloc] init];
        _locationManager.delegate = self;
        _trueHeading = 0;
        _isUpdatingLocation = NO;
    }
    return self;
}

- (void)startLocationUpdates
{
    if(!_isUpdatingLocation){
        [_locationManager startUpdatingHeading];
        [_locationManager startUpdatingLocation];
        _isUpdatingLocation = YES;
    }
}

- (void)stopLocationUpdates
{
    if(_isUpdatingLocation){
        [_locationManager stopUpdatingHeading];
        [_locationManager stopUpdatingLocation];
        _isUpdatingLocation = NO;
    }
}

#pragma mark - Calc distance

- (CLLocationDistance)distanceMetersFromLocation:(CLLocationCoordinate2D)coords
{
    CLLocation *otherLoc = [[CLLocation alloc] initWithLatitude:coords.latitude longitude:coords.longitude];
    return [_currentLocation distanceFromLocation:otherLoc];
}

#pragma mark - CL Delegate

- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation
{
    _currentLocation = newLocation;
    _currentCoord = _currentLocation.coordinate;
    /*
    CLLocationDistance altitude = currentLocation.altitude;
    CLLocationAccuracy horizontalAccuracy = currentLocation.horizontalAccuracy;
    CLLocationAccuracy verticalAccuracy = currentLocation.verticalAccuracy;
    CLLocationSpeed speed = currentLocation.speed;
    */
}

- (void)locationManager:(CLLocationManager *)manager didUpdateHeading:(CLHeading *)newHeading
{
    // NOTE: This is 0-360 degrees
    // North is 0 degrees
    _trueHeading = newHeading.trueHeading;
}

#pragma mark - Singleton

+ (WDLLocationManager *)sharedManager
{
    static WDLLocationManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[WDLLocationManager alloc] init];
    });
    return sharedManager;
}

@end
