//
//  WDLLocationManager.h
//  BlimpCam
//
//  Created by William Lindmeier on 3/17/13.
//  Copyright (c) 2013 William Lindmeier. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

@interface WDLLocationManager : NSObject <CLLocationManagerDelegate>

- (void)startLocationUpdates;
- (void)stopLocationUpdates;
- (CLLocationDistance)distanceMetersFromLocation:(CLLocationCoordinate2D)coords;

@property (nonatomic, readonly) CLLocationDirection trueHeading;
@property (nonatomic, readonly) CLLocationCoordinate2D currentCoord;
@property (nonatomic, readonly) CLLocation *currentLocation;

+ (WDLLocationManager *)sharedManager;

@end
