//
//  SCSelectionView.m
//  SCXcodeMinimap
//
//  Created by Stefan Ceriu on 4/21/13.
//  Copyright (c) 2013 Stefan Ceriu. All rights reserved.
//

#import "SCSelectionView.h"

@interface SCSelectionView ()

@property (nonatomic, retain) NSColor *selectionColor;

@end

@implementation SCSelectionView

- (void)dealloc
{
    [self.selectionColor release];
    [super dealloc];
}

- (void)drawRect:(NSRect)dirtyRect
{
    [[self selectionColor] setFill];
    NSRectFill(dirtyRect);
}

- (void)setNeedsDisplay:(BOOL)flag
{
    if(self.needsDisplay == flag) return;
    
    [self setSelectionColor:nil];
    [super setNeedsDisplay:flag];
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

- (void)setShouldInverseColors:(BOOL)shouldInverseColors
{
    if(_shouldInverseColors == shouldInverseColors) {
        return;
    }
    
    _shouldInverseColors = shouldInverseColors;
    _selectionColor = nil;
}

@end
