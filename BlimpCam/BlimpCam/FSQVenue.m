//
//  FSQVenue.m
//  BlimpCam
//
//  Created by William Lindmeier on 3/17/13.
//  Copyright (c) 2013 William Lindmeier. All rights reserved.
//

#import "FSQVenue.h"

@implementation FSQVenue

- (id)initWithResponseData:(NSDictionary *)responseData
{
    self = [super init];
    if(self){
        self.fsqID = [responseData valueForKey:@"id"];
        self.name = [responseData valueForKey:@"name"];
        NSDictionary *loc = [responseData valueForKey:@"location"];
        double lat = [(NSString *)[loc valueForKey:@"lat"] doubleValue];
        double lng = [(NSString *)[loc valueForKey:@"lng"] doubleValue];
        self.coord = CLLocationCoordinate2DMake(lat, lng);
    }
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<FSQVenue id: %@ name: \"%@\" lat: %f lng: %f>",
            self.fsqID, self.name, self.coord.latitude, self.coord.longitude];
}

@end
