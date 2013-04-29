//
//  SCSelectionView.m
//  SCXcodeMinimap
//
//  Created by Stefan Ceriu on 4/21/13.
//  Copyright (c) 2013 Stefan Ceriu. All rights reserved.
//

#import "SCSelectionView.h"

@implementation SCSelectionView

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        
        NSObject *DVTFontAndColorTheme = [NSClassFromString(@"DVTFontAndColorTheme") performSelector:@selector(currentTheme)];
        NSColor *backgroundColor = [DVTFontAndColorTheme performSelector:@selector(sourceTextBackgroundColor)];
        
        // sets the selectionColor to the inverse of the brightnessComponent of the currently selected theme's backgroundColor
        [self setSelectionColor:[NSColor colorWithCalibratedHue:0.0f saturation:0.0f brightness:(1.0f - [backgroundColor brightnessComponent]) alpha:0.25f]];
        
    }
    return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
    [[self selectionColor] setFill];
    NSRectFill(dirtyRect);
}


@end
