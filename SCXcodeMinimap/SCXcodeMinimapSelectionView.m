//
//  SCXcodeMinimapSelectionView.m
//  SCXcodeMinimap
//
//  Created by Stefan Ceriu on 24/01/2015.
//  Copyright (c) 2015 Stefan Ceriu. All rights reserved.
//

#import "SCXcodeMinimapSelectionView.h"
#import "DVTFontAndColorTheme.h"

@implementation SCXcodeMinimapSelectionView
@synthesize selectionColor = _selectionColor;

- (void)drawRect:(NSRect)dirtyRect
{
	[[self selectionColor] setFill];
	NSRectFill(dirtyRect);
}

- (void)setSelectionColor:(NSColor *)selectionColor
{
	if([_selectionColor isEqual:selectionColor]) return;
	
	_selectionColor = selectionColor;
	[self setNeedsDisplay:YES];
}

@end
