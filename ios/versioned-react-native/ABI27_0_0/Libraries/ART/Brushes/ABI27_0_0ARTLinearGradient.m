/**
 * Copyright (c) 2015-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "ABI27_0_0ARTLinearGradient.h"

#import <ReactABI27_0_0/ABI27_0_0RCTLog.h>

#import "ABI27_0_0RCTConvert+ART.h"

@implementation ABI27_0_0ARTLinearGradient
{
  CGGradientRef _gradient;
  CGPoint _startPoint;
  CGPoint _endPoint;
}

- (instancetype)initWithArray:(NSArray<NSNumber *> *)array
{
  if ((self = [super initWithArray:array])) {
    if (array.count < 5) {
      ABI27_0_0RCTLogError(@"-[%@ %@] expects 5 elements, received %@",
                  self.class, NSStringFromSelector(_cmd), array);
      return nil;
    }
    _startPoint = [ABI27_0_0RCTConvert CGPoint:array offset:1];
    _endPoint = [ABI27_0_0RCTConvert CGPoint:array offset:3];
    _gradient = CGGradientRetain([ABI27_0_0RCTConvert CGGradient:array offset:5]);
  }
  return self;
}

- (void)dealloc
{
  CGGradientRelease(_gradient);
}

- (void)paint:(CGContextRef)context
{
  CGGradientDrawingOptions extendOptions =
    kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation;
  CGContextDrawLinearGradient(context, _gradient, _startPoint, _endPoint, extendOptions);
}

@end
