//
//  SCTextView.m
//  SCXcodeMinimap
//
//  Created by Jérôme ALVES on 29/04/13.
//  Copyright (c) 2013 Stefan Ceriu. All rights reserved.
//

#import "SCTextView.h"

@implementation SCTextView

- (void)mouseDown:(NSEvent *)theEvent
{
    [super mouseDown:theEvent];
    [self handleMouseEvent:theEvent];
}

- (void)mouseDragged:(NSEvent *)theEvent
{
    [super mouseDragged:theEvent];
    [self handleMouseEvent:theEvent];
}

- (void) handleMouseEvent:(NSEvent *)theEvent
{
    if ([self.delegate respondsToSelector:@selector(textView:goAtRelativePosition:)])
    {
        NSPoint locationInSelf = [self convertPoint:theEvent.locationInWindow fromView:nil];
        NSSize size = [self.layoutManager usedRectForTextContainer:self.textContainer].size;
        NSPoint point = NSMakePoint(locationInSelf.x / size.width, locationInSelf.y / size.height);

        [self.delegate textView:self goAtRelativePosition:point];
    }
}

- (void)setDelegate:(id<SCTextViewDelegate>)anObject
{
    [super setDelegate:anObject];
}

- (id<SCTextViewDelegate>)delegate
{
    return (id<SCTextViewDelegate>)[super delegate];
}

@end
