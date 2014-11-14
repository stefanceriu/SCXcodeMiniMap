//
//  SCMiniMapView.m
//  SCXcodeMinimap
//
//  Created by Jérôme ALVES on 30/04/13.
//  Copyright (c) 2013 Stefan Ceriu. All rights reserved.
//

#import "SCMiniMapView.h"
#import "SCXcodeMinimap.h"

const CGFloat kDefaultZoomLevel = 0.1f;
static const CGFloat kDefaultShadowLevel = 0.1f;

static NSString * const DVTFontAndColorSourceTextSettingsChangedNotification = @"DVTFontAndColorSourceTextSettingsChangedNotification";

@interface SCMiniMapView () <NSLayoutManagerDelegate>

@property (nonatomic, strong) NSColor *backgroundColor;
@property (nonatomic, strong) NSFont *font;
@property (nonatomic, assign) NSInteger numberOfLines;

@end

@implementation SCMiniMapView
@synthesize backgroundColor = _backgroundColor;

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (id)initWithFrame:(NSRect)frame
{
    if (self = [super initWithFrame:frame])
    {
        /* Configure ScrollView */
        [self setWantsLayer:YES];
        [self setAutoresizingMask: NSViewMinXMargin | NSViewHeightSizable];
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
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(updateTheme)
                                                     name:DVTFontAndColorSourceTextSettingsChangedNotification
                                                   object:nil];
    }
    return self;
}

#pragma mark - Lazy Initialization

- (NSTextView *)textView
{
    if (_textView == nil) {
        _textView = [[NSClassFromString(@"DVTSourceTextView") alloc] initWithFrame:self.bounds];
        
        [_textView setBackgroundColor:[NSColor clearColor]];
        
        [_textView.textContainer setLineFragmentPadding:0.0f];
        
        [_textView setAllowsUndo:NO];
        [_textView setAllowsImageEditing:NO];
        [_textView setAutomaticDashSubstitutionEnabled:NO];
        [_textView setAutomaticDataDetectionEnabled:NO];
        [_textView setAutomaticLinkDetectionEnabled:NO];
        [_textView setAutomaticQuoteSubstitutionEnabled:NO];
        [_textView setAutomaticSpellingCorrectionEnabled:NO];
        [_textView setAutomaticTextReplacementEnabled:NO];
        [_textView setContinuousSpellCheckingEnabled:NO];
        [_textView setDisplaysLinkToolTips:NO];
        [_textView setEditable:NO];
        [_textView setRichText:YES];
        [_textView setSelectable:NO];
        
        [self setDocumentView:_textView];
        
        [self updateTheme];
        
        [[NSNotificationCenter defaultCenter] removeObserver:_textView name:DVTFontAndColorSourceTextSettingsChangedNotification object:nil];
    }
    
    [_textView.layoutManager setDelegate:self];
    
    return _textView;
}

- (SCSelectionView *)selectionView
{
    if (_selectionView == nil) {
        _selectionView = [[SCSelectionView alloc] init];
        //[_selectionView setShouldInverseColors:YES];
        [self.textView addSubview:_selectionView];
    }
    
    return _selectionView;
}

- (NSFont *)font
{
    if(_font == nil) {
        _font = [NSFont fontWithName:@"Menlo" size:11 * kDefaultZoomLevel];
        
        Class DVTFontAndColorThemeClass = NSClassFromString(@"DVTFontAndColorTheme");
        if([DVTFontAndColorThemeClass respondsToSelector:@selector(currentTheme)]) {
            
            NSObject *theme = [DVTFontAndColorThemeClass performSelector:@selector(currentTheme)];
            if([theme respondsToSelector:@selector(sourcePlainTextFont)]) {
                NSFont *themeFont = [theme performSelector:@selector(sourcePlainTextFont)];
                self.font = [NSFont fontWithName:themeFont.familyName size:themeFont.pointSize * kDefaultZoomLevel];
            }
        }
    }
    
    return _font;
}

- (NSColor *)backgroundColor
{
    if(_backgroundColor == nil) {
        _backgroundColor = [[NSColor clearColor] shadowWithLevel:kDefaultShadowLevel];
        
        Class DVTFontAndColorThemeClass = NSClassFromString(@"DVTFontAndColorTheme");
        if([DVTFontAndColorThemeClass respondsToSelector:@selector(currentTheme)]) {
            
            NSObject *theme = [DVTFontAndColorThemeClass performSelector:@selector(currentTheme)];
            if([theme respondsToSelector:@selector(sourceTextBackgroundColor)]) {
                NSColor *themeBackgroundColor = [theme performSelector:@selector(sourceTextBackgroundColor)];
                self.backgroundColor = [themeBackgroundColor shadowWithLevel:kDefaultShadowLevel];
            }
        }
    }
    
    return _backgroundColor;
}

#pragma mark - Show/Hide

- (void)show
{
    self.hidden = NO;
    
    NSRect editorTextViewFrame = self.editorScrollView.frame;
    editorTextViewFrame.size.width = self.editorScrollView.superview.frame.size.width - self.bounds.size.width;
    self.editorScrollView.frame = editorTextViewFrame;
    
    [self updateTextView];
    [self updateSelectionView];
}

- (void)hide
{
    self.hidden = YES;
    
    NSRect editorTextViewFrame = self.editorScrollView.frame;
    editorTextViewFrame.size.width = self.editorScrollView.superview.frame.size.width;
    self.editorScrollView.frame = editorTextViewFrame;
}

#pragma mark - Updating

- (void)updateTheme
{
    [self setFont:nil];
    
    [self setBackgroundColor:nil];
    [self.selectionView setSelectionColor:nil];
    [self.textView setBackgroundColor:self.backgroundColor];
}

- (void)updateTextView
{
    if ([self isHidden]) {
        return;
    }
    
    typeof(self) __weak weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        NSMutableAttributedString *mutableAttributedString = [self.editorTextView.textStorage mutableCopy];
        
        if(mutableAttributedString.length == 0) {
            //Nothing to do here.
            weakSelf.numberOfLines = 0;
            return;
        }
        
        __block NSMutableParagraphStyle *style;
        
        [mutableAttributedString enumerateAttribute:NSParagraphStyleAttributeName
                                            inRange:NSMakeRange(0, mutableAttributedString.length)
                                            options:0
                                         usingBlock:^(id value, NSRange range, BOOL *stop) {
                                             style = [value mutableCopy];
                                             *stop = YES;
                                         }];
        
        
        [style setTabStops:@[]];
        [style setDefaultTabInterval:style.defaultTabInterval * kDefaultZoomLevel];
        
        [mutableAttributedString setAttributes:@{NSFontAttributeName: weakSelf.font, NSParagraphStyleAttributeName : style} range:NSMakeRange(0, mutableAttributedString.length)];
        
        //Send the text storage update off to the main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.textView.textStorage setAttributedString:mutableAttributedString];
            [weakSelf updateSelectionView];
        });
        
        //Calculate the total number of lines
        [weakSelf calculateLinesFromString:[mutableAttributedString string]];
    });
}

- (void)calculateLinesFromString:(NSString *)string
{
    NSInteger count = 0;
    for (NSInteger index = 0;  index < [string length]; count++) {
        index = NSMaxRange([string lineRangeForRange:NSMakeRange(index, 0)]);
    }
    
    //Cache the last calculated lines so we can figure out how long we should take to render this minimap.
    self.numberOfLines = count;
}

- (void)resizeWithOldSuperviewSize:(NSSize)oldSize
{
    [super resizeWithOldSuperviewSize:oldSize];
    [self updateSelectionView];
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
    
    [self.selectionView setFrame:selectionViewFrame];
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
    return [self.editorTextView.layoutManager.delegate layoutManager:layoutManager
                                        shouldUseTemporaryAttributes:attrs
                                                  forDrawingToScreen:toScreen
                                                    atCharacterIndex:charIndex
                                                      effectiveRange:effectiveCharRange];
}

#pragma mark - Navigation

- (void)mouseUp:(NSEvent *)theEvent
{
    [super mouseUp:theEvent];
    [self handleMouseEvent:theEvent];
}

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
    static BOOL isDragging;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        isDragging = NO;
    });
    
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
    
    BOOL justStartDragging = NO;
    if (theEvent.type == NSLeftMouseUp) {
        isDragging = NO;
    }
    else {
        justStartDragging = !isDragging;
        isDragging = YES;
    }
    
    [self goAtRelativePosition:point justStartDragging:justStartDragging];
}

- (void)goAtRelativePosition:(NSPoint)position justStartDragging:(BOOL)justStartDragging
{
    static CGFloat mouseDownOffset;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mouseDownOffset = 0;
    });
    
    CGFloat documentHeight = [self.editorScrollView.documentView frame].size.height;
    CGSize boundsSize = self.editorScrollView.bounds.size;
    CGFloat maxOffset = documentHeight - boundsSize.height;
    CGFloat locationInDocumentY = documentHeight * position.y;
    
    if (justStartDragging) {
        mouseDownOffset = locationInDocumentY -
        (self.editorScrollView.contentView.documentVisibleRect.origin.y + boundsSize.height/2.0);
    }
    
    CGFloat offset;
    if (fabs(mouseDownOffset) <= boundsSize.height/2.0) {
        offset = floor(locationInDocumentY - boundsSize.height/2 - mouseDownOffset);
    }
    else {
        offset = floor(locationInDocumentY - boundsSize.height/2);
    }
    offset = MIN(MAX(0, offset), maxOffset);
    
    [self.editorTextView scrollRectToVisible:NSMakeRect(0, offset, boundsSize.width, boundsSize.height)];
}

@end
