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
    CAShapeLayer *_shapeLayer;
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
    _shapeLayer = [[CAShapeLayer alloc] init];
    _shapeLayer.fillColor = NULL;
    _shapeLayer.strokeColor = [UIColor blackColor].CGColor;
    _shapeLayer.lineWidth = 10.0f;
    [self.layer addSublayer:_shapeLayer];
    self.backgroundColor = [UIColor clearColor];
    [self startAnimation];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    // Add the arc shape
    _shapeLayer.frame = self.bounds;
    _shapeLayer.anchorPoint = CGPointMake(0.5, 0.5);
    double startAngle = 265.0;
    double endAngle = 275.0;
    CGMutablePathRef path = CGPathCreateMutable();
    CGSize mySize = self.frame.size;
    CGPathAddArc(path,
                 NULL,
                 mySize.width * 0.5,
                 mySize.height * 0.5,
                 mySize.width * 0.5,
                 DegreesToRadians(startAngle),
                 DegreesToRadians(endAngle),
                 YES);
    _shapeLayer.path = path;
    CGPathRelease(path);
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
