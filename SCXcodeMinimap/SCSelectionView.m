//
//  SCSelectionView.m
//  SCXcodeMinimap
//
//  Created by Stefan Ceriu on 4/21/13.
//  Copyright (c) 2013 Stefan Ceriu. All rights reserved.
//

#import "SCSelectionView.h"

@implementation SCSelectionView

- (void)drawRect:(NSRect)dirtyRect
{
    [[NSColor colorWithDeviceRed:0.0f green:0.0f blue:0.0f alpha:0.3f] setFill];
    NSRectFill(dirtyRect);
}


@end
