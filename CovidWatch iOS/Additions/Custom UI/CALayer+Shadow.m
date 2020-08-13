//
//  CALayer+Shadow.m
//
//  Created by Christopher McGraw on 5/12/17.
//

#import "CALayer+Shadow.h"

@implementation CALayer (Shadow)

- (void)setShadowUIColor:(UIColor *)color
{
    self.shadowColor = color.CGColor;
}

- (UIColor *)shadowUIColor
{
    return [UIColor colorWithCGColor:self.shadowColor];
}

@end
