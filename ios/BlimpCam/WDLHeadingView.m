//
//  WDLHeadingView.m
//  BlimpCam
//
//  Created by William Lindmeier on 3/17/13.
//  Copyright (c) 2013 William Lindmeier. All rights reserved.
//

#import "WDLHeadingView.h"
#import "WDLLocationManager.h"
#import "CGGeometry.h"
#import <QuartzCore/QuartzCore.h>

@implementation WDLHeadingView
{
    CADisplayLink *_displayLink;
    UIImageView *_imgViewRose;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if(self){
        [self initWDLHeadingView];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self initWDLHeadingView];
    }
    return self;
}

- (void)initWDLHeadingView
{
    UIImage *imgRose = [UIImage imageNamed:@"compass_rose"];
    _imgViewRose = [[UIImageView alloc] initWithImage:imgRose];
    _imgViewRose.backgroundColor = [UIColor clearColor];
    self.backgroundColor = [UIColor clearColor];
    [self addSubview:_imgViewRose];
    [self startAnimation];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGSize sizeView = self.frame.size;
    _imgViewRose.center = CGPointMake(sizeView.width * 0.5, sizeView.height * 0.5);
}

- (void)removeFromSuperview
{
    [super removeFromSuperview];
    [self stopAnimation];
}

- (void)stopAnimation
{
    if(_displayLink){
        [_displayLink removeFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        [_displayLink invalidate];
        _displayLink = nil;
    }
}

- (void)startAnimation
{
    if(!_displayLink){
        _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateHeading)];
        [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    }
}

- (void)updateHeading
{
    CLLocationDirection direction = [[WDLLocationManager sharedManager] trueHeading];
    float rotRads = DegreesToRadians(direction);
    self.layer.transform = CATransform3DMakeRotation(rotRads, 0, 0, -1);
}

@end
