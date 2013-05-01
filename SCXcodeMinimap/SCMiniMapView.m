//
//  SCMiniMapView.m
//  SCXcodeMinimap
//
//  Created by Jérôme ALVES on 30/04/13.
//  Copyright (c) 2013 Stefan Ceriu. All rights reserved.
//

#import "SCMiniMapView.h"
#import "SCXcodeMinimap.h"

@implementation SCMiniMapView

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        /* Configure ScrollView */
        [self setWantsLayer:YES];
        [self setAutoresizingMask: NSViewMinXMargin | NSViewWidthSizable | NSViewHeightSizable];
        [self setDrawsBackground:NO];
        [self setHorizontalScrollElasticity:NSScrollElasticityNone];
        [self setVerticalScrollElasticity:NSScrollElasticityNone];

        /* Subscribe to show/hide notifications */
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(show)
                                                     name:SCXodeMinimapWantsToBeShownNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(hide)
                                                     name:SCXodeMinimapWantsToBeHiddenNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [_selectionView release];
    [_textView release];
    [super dealloc];
}

#pragma mark - Lazy Initialization

- (NSTextView *)textView
{
    if (_textView == nil) {
        _textView = [[NSTextView alloc] initWithFrame:self.bounds];
        [_textView setAutoresizingMask: NSViewMinXMargin | NSViewMaxXMargin | NSViewWidthSizable | NSViewHeightSizable];
        [_textView.textContainer setLineFragmentPadding:0.0f];
        [_textView setSelectable:NO];
        [_textView.layoutManager setDelegate:self];
        
        [self setDocumentView:_textView];
        
        NSColor *miniMapBackgroundColor = [NSColor clearColor];
        Class DVTFontAndColorThemeClass = NSClassFromString(@"DVTFontAndColorTheme");
        
        if([DVTFontAndColorThemeClass respondsToSelector:@selector(currentTheme)]) {
            
            NSObject *theme = [DVTFontAndColorThemeClass performSelector:@selector(currentTheme)];
            if([theme respondsToSelector:@selector(sourceTextBackgroundColor)]) {
                miniMapBackgroundColor = [theme performSelector:@selector(sourceTextBackgroundColor)];
            }
        }
        
        [_textView setBackgroundColor:[miniMapBackgroundColor shadowWithLevel:kDefaultShadowLevel]];
    }
    
    return _textView;
}

- (SCSelectionView *)selectionView
{
    if (_selectionView == nil) {
        _selectionView = [[SCSelectionView alloc] init];
        [_selectionView setAutoresizingMask: NSViewMinXMargin | NSViewMaxXMargin | NSViewWidthSizable | NSViewHeightSizable | NSViewMinYMargin | NSViewMaxYMargin];
        //[_selectionView setShouldInverseColors:YES];
        [self.textView addSubview:_selectionView];
    }
    
    return _selectionView;
}

#pragma mark - Show/Hide

- (void)show
{
    self.hidden = NO;

    NSRect editorTextViewFrame = self.editorTextView.frame;
    editorTextViewFrame.size.width = self.editorTextView.superview.frame.size.width - self.bounds.size.width - kRightSidePadding;
    self.editorTextView.frame = editorTextViewFrame;
    
    [self updateTextView];
    [self updateSelectionView];
}

- (void)hide
{
    self.hidden = YES;

    NSRect editorTextViewFrame = self.editorTextView.frame;
    editorTextViewFrame.size.width = self.editorTextView.superview.frame.size.width;
    self.editorTextView.frame = editorTextViewFrame;
}

#pragma mark - Updating

- (void)updateTextView
{
    if ([self isHidden]) {
        return;
    }
     
    NSMutableAttributedString *mutableAttributedString = [self.editorTextView.textStorage mutableCopy];

    if(mutableAttributedString == nil) {
        return;
    }

    [mutableAttributedString enumerateAttributesInRange:NSMakeRange(0, mutableAttributedString.length) options:NSAttributedStringEnumerationReverse usingBlock:
     ^(NSDictionary *attributes, NSRange range, BOOL *stop) {

         NSFont *font = [attributes objectForKey:NSFontAttributeName];
         NSFont *newFont = [NSFont fontWithName:font.familyName size:font.pointSize * kDefaultZoomLevel];

         NSMutableDictionary *mutableAttributes = [NSMutableDictionary dictionaryWithDictionary:attributes];
         [mutableAttributes setObject:newFont forKey:NSFontAttributeName];
         [mutableAttributedString setAttributes:mutableAttributes range:range];
     }];

    [self.textView.textStorage setAttributedString:mutableAttributedString];
    [mutableAttributedString release];
}

- (void)updateSelectionView
{
    if ([self isHidden]) {
        return;
    }

    NSRect selectionViewFrame = NSMakeRect(0,
                                           0,
                                           self.bounds.size.width,
                                           self.editorScrollView.visibleRect.size.height * kDefaultZoomLevel);


    CGFloat editorContentHeight = [self.editorScrollView.documentView frame].size.height - self.editorScrollView.bounds.size.height;

    if(editorContentHeight == 0) {
        selectionViewFrame.origin.y = 0;
    }
    else {
        CGFloat ratio = ([self.documentView frame].size.height - self.bounds.size.height) / editorContentHeight;
        [self.contentView scrollToPoint:NSMakePoint(0, floorf(self.editorScrollView.contentView.bounds.origin.y * ratio))];

        CGFloat textHeight = [self.textView.layoutManager usedRectForTextContainer:self.textView.textContainer].size.height;
        ratio = (textHeight - self.selectionView.bounds.size.height) / editorContentHeight;
        selectionViewFrame.origin.y = self.editorScrollView.contentView.bounds.origin.y * ratio;
    }

    self.selectionView.frame = selectionViewFrame;
}

#pragma mark - NSLayoutManagerDelegate

- (void)layoutManager:(NSLayoutManager *)layoutManager didCompleteLayoutForTextContainer:(NSTextContainer *)textContainer atEnd:(BOOL)layoutFinished
{
    if(layoutFinished) {
        [self updateSelectionView];
    }
}

- (NSDictionary *)layoutManager:(NSLayoutManager *)layoutManager shouldUseTemporaryAttributes:(NSDictionary *)attrs forDrawingToScreen:(BOOL)toScreen atCharacterIndex:(NSUInteger)charIndex effectiveRange:(NSRangePointer)effectiveCharRange
{
    return [(id<NSLayoutManagerDelegate>)self.editorTextView layoutManager:layoutManager
                                              shouldUseTemporaryAttributes:attrs
                                                        forDrawingToScreen:toScreen
                                                          atCharacterIndex:charIndex
                                                            effectiveRange:effectiveCharRange];
}

#pragma mark - Navigation

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
    NSPoint locationInSelf = [self convertPoint:theEvent.locationInWindow fromView:nil];
    
    NSSize textSize = [self.textView.layoutManager usedRectForTextContainer:self.textView.textContainer].size;
    NSSize frameSize = self.frame.size;
    
    NSPoint point;
    if (textSize.height < frameSize.height) {
        point = NSMakePoint(locationInSelf.x / textSize.width, locationInSelf.y / textSize.height);
    }
    else {
        point = NSMakePoint(locationInSelf.x / textSize.width, locationInSelf.y / frameSize.height);
    }
    
    [self goAtRelativePosition:point];
}

- (void)goAtRelativePosition:(NSPoint)position
{
    CGFloat documentHeight = [self.editorScrollView.documentView frame].size.height;
    CGSize boundsSize = self.editorScrollView.bounds.size;
    CGFloat maxOffset = documentHeight - boundsSize.height;

    CGFloat offset =  floor(documentHeight * position.y - boundsSize.height/2);

    offset = MIN(MAX(0, offset), maxOffset);

    [self.editorTextView scrollRectToVisible:NSMakeRect(0, offset, boundsSize.width, boundsSize.height)];
}

@end
