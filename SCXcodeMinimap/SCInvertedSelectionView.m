//
//  SCSelectionView.m
//  SCXcodeMinimap
//
//  Created by Stefan Ceriu on 4/21/13.
//  Copyright (c) 2013 Stefan Ceriu. All rights reserved.
//

#import "SCInvertedSelectionView.h"

@implementation SCInvertedSelectionView

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        
        NSObject *DVTFontAndColorTheme = [NSClassFromString(@"DVTFontAndColorTheme") performSelector:@selector(currentTheme)];
        NSColor *backgroundColor = [DVTFontAndColorTheme performSelector:@selector(sourceTextBackgroundColor)];
        
        // sets the selectionColor to the inverse of the currently selected theme's backgroundColor
        [self setSelectionColor:[NSColor colorWithCalibratedRed:(1.0f - [backgroundColor redComponent]) green:(1.0f - [backgroundColor greenComponent])  blue:(1.0f - [backgroundColor blueComponent])  alpha:0.3]];
        
    }
    return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
    [[self selectionColor] setFill];
    NSRectFill(dirtyRect);
}


@end
