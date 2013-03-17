//
//  WDLFSQManager.h
//  BlimpCam
//
//  Created by William Lindmeier on 3/17/13.
//  Copyright (c) 2013 William Lindmeier. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BZFoursquare.h"
#import "FSQVenue.h"

typedef void(^FSQSuccessBlock)(void);
typedef void(^FSQErrorBlock)(NSDictionary *errorInfo);

@interface WDLFSQManager : NSObject <
BZFoursquareRequestDelegate,
BZFoursquareSessionDelegate>

@property(nonatomic,readwrite,strong) BZFoursquare *foursquare;

- (void)searchForNearbyVenuesWithSuccess:(void (^)(NSArray * results))successCallback
                                   error:(FSQErrorBlock)errorCallback;
- (void)checkinToVenue:(FSQVenue *)venue
               success:(void (^)(NSDictionary *response))successCallback
                 error:(FSQErrorBlock)errorCallback;
- (BOOL)isAuthenticated;
- (void)authenticateWithSuccess:(void (^)(void))successCallback
                          error:(FSQErrorBlock)errorCallback;
- (void)logout;

+ (WDLFSQManager *)sharedManager;

@end
