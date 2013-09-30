//
//  SCSelectionView.m
//  SCXcodeMinimap
//
//  Created by Stefan Ceriu on 4/21/13.
//  Copyright (c) 2013 Stefan Ceriu. All rights reserved.
//

#import "SCSelectionView.h"

@implementation SCSelectionView
@synthesize selectionColor = _selectionColor;

- (void)drawRect:(NSRect)dirtyRect
{
    [[self selectionColor] setFill];
    NSRectFill(dirtyRect);
}

- (NSColor *)selectionColor
{
    if(_selectionColor == nil) {
        
        _selectionColor = [NSColor colorWithDeviceRed:0.0f green:0.0f blue:0.0f alpha:0.3f];
        
        Class DVTFontAndColorThemeClass = NSClassFromString(@"DVTFontAndColorTheme");
        
        if([DVTFontAndColorThemeClass respondsToSelector:@selector(currentTheme)]) {
            NSObject *theme = [DVTFontAndColorThemeClass performSelector:@selector(currentTheme)];
            
            if([theme respondsToSelector:@selector(sourceTextBackgroundColor)]) {
                NSColor *backgroundColor = [[theme performSelector:@selector(sourceTextBackgroundColor)] colorUsingColorSpace:[NSColorSpace deviceRGBColorSpace]];
                
                if(self.shouldInverseColors) {
                    
                    _selectionColor = [NSColor colorWithCalibratedRed:(1.0f - [backgroundColor redComponent])
                                                                green:(1.0f - [backgroundColor greenComponent])
                                                                 blue:(1.0f - [backgroundColor blueComponent])
                                                                alpha:0.3f];
                } else {
                    
                    _selectionColor = [NSColor colorWithCalibratedHue:0.0f
                                                           saturation:0.0f
                                                           brightness:(1.0f - [backgroundColor brightnessComponent])
                                                                alpha:0.3f];
                }
            }
        }
    }
    
    return _selectionColor;
}

- (void)setSelectionColor:(NSColor *)selectionColor
{
    if([_selectionColor isEqual:selectionColor]) return;
    
    _selectionColor = selectionColor;
    [self setNeedsDisplay:YES];
}

- (void)setShouldInverseColors:(BOOL)shouldInverseColors
{
    if(_shouldInverseColors == shouldInverseColors) {
        return;
    }
    
    _shouldInverseColors = shouldInverseColors;
    _selectionColor = nil;
}

@end
