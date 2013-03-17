//
//  FSQVenue.h
//  BlimpCam
//
//  Created by William Lindmeier on 3/17/13.
//  Copyright (c) 2013 William Lindmeier. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

@interface FSQVenue : NSObject

- (id)initWithResponseData:(NSDictionary *)responseData;

@property (nonatomic, strong) NSString *fsqID;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, assign) CLLocationCoordinate2D coord;

@end
