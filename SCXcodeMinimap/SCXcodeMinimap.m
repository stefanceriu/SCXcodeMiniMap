//
//  SCXcodeMinimap.m
//  SCXcodeMinimap
//
//  Created by Stefan Ceriu on 3/30/13.
//  Copyright (c) 2013 Stefan Ceriu. All rights reserved
//

#import "SCXcodeMinimap.h"
#import "SCSelectionView.h"
#import <objc/runtime.h>

static char kKeyMiniMapScrollView;
static char kKeyMiniMapSelectionView;
static char kKeyMiniMapTextView;

static char kKeyEditorScrollView;
static char kKeyEditorTextView;

static NSString * const IDESourceCodeEditorDidFinishSetupNotification = @"IDESourceCodeEditorDidFinishSetup";
static NSString * const IDEEditorDocumentDidChangeNotification = @"IDEEditorDocumentDidChangeNotification";
static NSString * const IDESourceCodeEditorTextViewBoundsDidChangeNotification = @"IDESourceCodeEditorTextViewBoundsDidChangeNotification";
static NSString * const DVTFontAndColorSourceTextSettingsChangedNotification = @"DVTFontAndColorSourceTextSettingsChangedNotification";//Unused

#define kDefaultZoomLevel 0.1f
#define kRightSidePadding 10.0f
#define kDefaultShadowLevel 0.1f

@implementation SCXcodeMinimap

static SCXcodeMinimap *sharedMinimap = nil;
+ (void)pluginDidLoad:(NSBundle *)plugin {
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedMinimap = [[self alloc] init];
	});
}

- (id)init {
	if (self = [super init]) {        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onDidFinishSetup:) name:IDESourceCodeEditorDidFinishSetupNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onDocumentDidChange:) name:IDEEditorDocumentDidChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onCodeEditorBoundsChange:) name:IDESourceCodeEditorTextViewBoundsDidChangeNotification object:nil];
    }
	return self;
}

- (void)onDocumentDidChange:(NSNotification*)sender
{
    if(![[sender object] respondsToSelector:@selector(textStorage)]) {
        NSLog(@"Could not fetch text storage");
        return;
    }
    
    NSTextStorage *textStorage = [[sender object] performSelector:@selector(textStorage)];
    NSTextView *miniMapTextView = objc_getAssociatedObject([sender object], &kKeyMiniMapTextView);
    [self updateMiniMapTextView:miniMapTextView withAttributedString:textStorage];
}

- (void)onCodeEditorBoundsChange:(NSNotification*)sender
{
    if(![sender.object respondsToSelector:@selector(scrollView)]) {
        NSLog(@"Could not fetch scroll view");
        return;
    }
    NSScrollView *editorScrollView = [sender.object performSelector:@selector(scrollView)];
    [self updateMiniMapForEditorScrollView:editorScrollView];
}

- (void)updateMiniMapTextView:(NSTextView*)textView withAttributedString:(NSAttributedString*)attributedString
{
    NSMutableAttributedString *mutableAttributedString = [attributedString mutableCopy];
    
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
    
    [textView.textStorage setAttributedString:mutableAttributedString];
    [mutableAttributedString release];
}

- (void)updateMiniMapForEditorScrollView:(NSScrollView*)editorScrollView
{
    NSScrollView *miniMapScrollView = objc_getAssociatedObject(editorScrollView, &kKeyMiniMapScrollView);
    SCSelectionView *miniMapSelectionView = objc_getAssociatedObject(editorScrollView, &kKeyMiniMapSelectionView);
    NSTextView *miniMapTextView = objc_getAssociatedObject(editorScrollView, &kKeyMiniMapTextView);
        
    if(miniMapScrollView == nil || miniMapSelectionView == nil) {
        return;
    }
    
    CGFloat editorContentHeight = [editorScrollView.documentView frame].size.height - editorScrollView.bounds.size.height;
    if(editorContentHeight == 0) {
        NSRect frame = miniMapSelectionView.frame;
        frame.origin.y = 0;
        miniMapSelectionView.frame = frame;
        return;
    }
    
    CGFloat ratio = ([miniMapScrollView.documentView frame].size.height - miniMapScrollView.bounds.size.height) / editorContentHeight;
    [miniMapScrollView.contentView scrollToPoint:NSMakePoint(0, floorf(editorScrollView.contentView.bounds.origin.y * ratio))];
    
    
    CGFloat textHeight = [miniMapTextView.layoutManager usedRectForTextContainer:miniMapTextView.textContainer].size.height;
    ratio = (textHeight - miniMapSelectionView.bounds.size.height) / editorContentHeight;
    NSRect frame = miniMapSelectionView.frame;
    frame.origin.y = editorScrollView.contentView.bounds.origin.y * ratio;
    miniMapSelectionView.frame = frame;
}

- (void)onDidFinishSetup:(NSNotification*)sender
{
    if(![[sender object] respondsToSelector:@selector(containerView)]) {
        NSLog(@"Could not fetch editor container view");
        return;
    }
    NSView *editorContainerView = [[sender object] performSelector:@selector(containerView)];
    
    
    if(![[sender object] respondsToSelector:@selector(scrollView)]) {
        NSLog(@"Could not fetch editor scroll view");
        return;
    }
    NSScrollView *editorScrollView = [[sender object] performSelector:@selector(scrollView)];

    
    if(![[sender object] respondsToSelector:@selector(textView)]) {
        NSLog(@"Could not fetch editor text view");
        return;
    }
    NSTextView *editorTextView = [[sender object] performSelector:@selector(textView)];
    [editorTextView setAutoresizingMask:NSViewMinXMargin | NSViewMaxXMargin | NSViewWidthSizable | NSViewHeightSizable];
    
    
    if(![[sender object] respondsToSelector:@selector(sourceCodeDocument)]) {
        NSLog(@"Could not fetch editor document");
        return;
    }
    NSDocument *editorDocument = [[sender object] performSelector:@selector(sourceCodeDocument)];
    
    CGFloat width = editorTextView.bounds.size.width * kDefaultZoomLevel;
    
    NSRect frame = editorTextView.frame;
    frame.size.width -= width;
    [editorTextView setFrame:frame];
    
    NSRect miniMapScrollViewFrame = NSMakeRect(editorContainerView.bounds.size.width - width - kRightSidePadding, 0, width, editorScrollView.bounds.size.height);
    NSScrollView *miniMapScrollView = [[NSScrollView alloc] initWithFrame:miniMapScrollViewFrame];
    [miniMapScrollView setWantsLayer:YES];
    [miniMapScrollView setAutoresizingMask: NSViewMinXMargin | NSViewWidthSizable | NSViewHeightSizable];
    [miniMapScrollView setDrawsBackground:NO];
    [miniMapScrollView setHorizontalScrollElasticity:NSScrollElasticityNone];
    [miniMapScrollView setVerticalScrollElasticity:NSScrollElasticityNone];
    [editorContainerView addSubview:miniMapScrollView];
    [miniMapScrollView release];
    
    objc_setAssociatedObject(editorScrollView, &kKeyMiniMapScrollView, miniMapScrollView, OBJC_ASSOCIATION_ASSIGN);
    
    SCTextView *miniMapTextView = [[SCTextView alloc] initWithFrame:miniMapScrollView.bounds];
    [miniMapTextView setAutoresizingMask: NSViewMinXMargin | NSViewMaxXMargin | NSViewWidthSizable | NSViewHeightSizable];
    [miniMapTextView.textContainer setLineFragmentPadding:0.0f];
    [miniMapTextView setSelectable:NO];
    [miniMapTextView.layoutManager setDelegate:(id<NSLayoutManagerDelegate>)self];
    [miniMapTextView setDelegate:self];
    
    objc_setAssociatedObject(miniMapTextView.layoutManager, &kKeyEditorTextView, editorTextView, OBJC_ASSOCIATION_ASSIGN);
    
    [miniMapScrollView setDocumentView:miniMapTextView];
    [miniMapTextView release];
    
    NSColor *miniMapBackgroundColor = [NSColor clearColor];
    Class DVTFontAndColorThemeClass = NSClassFromString(@"DVTFontAndColorTheme");
    if([DVTFontAndColorThemeClass respondsToSelector:@selector(currentTheme)]) {
        NSObject *theme = [DVTFontAndColorThemeClass performSelector:@selector(currentTheme)];
        
        if([theme respondsToSelector:@selector(sourceTextBackgroundColor)]) {
            miniMapBackgroundColor = [theme performSelector:@selector(sourceTextBackgroundColor)];
            
        }
    }
    
    [miniMapTextView setBackgroundColor:[miniMapBackgroundColor shadowWithLevel:kDefaultShadowLevel]];
    
    objc_setAssociatedObject(editorDocument, &kKeyMiniMapTextView, miniMapTextView, OBJC_ASSOCIATION_ASSIGN);
    objc_setAssociatedObject(editorScrollView, &kKeyMiniMapTextView, miniMapTextView, OBJC_ASSOCIATION_ASSIGN);
    objc_setAssociatedObject(miniMapTextView.textContainer, &kKeyEditorScrollView, editorScrollView, OBJC_ASSOCIATION_ASSIGN);
    
    
    NSRect miniMapSelectionViewFrame = NSMakeRect(0, 0, miniMapScrollView.bounds.size.width, editorScrollView.visibleRect.size.height * kDefaultZoomLevel);
    SCSelectionView *miniMapSelectionView = [[SCSelectionView alloc] initWithFrame:miniMapSelectionViewFrame];
    [miniMapSelectionView setAutoresizingMask: NSViewMinXMargin | NSViewMaxXMargin | NSViewWidthSizable | NSViewHeightSizable | NSViewMinYMargin | NSViewMaxYMargin];
    //[miniMapSelectionView setShouldInverseColors:YES];
    [miniMapScrollView.contentView addSubview:miniMapSelectionView];
    [miniMapSelectionView release];
    
    objc_setAssociatedObject(editorScrollView, &kKeyMiniMapSelectionView, miniMapSelectionView, OBJC_ASSOCIATION_ASSIGN);
    
    
    [self updateMiniMapTextView:miniMapTextView withAttributedString:editorTextView.textStorage];
}

#pragma mark - NSLayoutManagerDelegate

- (void)layoutManager:(NSLayoutManager *)layoutManager didCompleteLayoutForTextContainer:(NSTextContainer *)textContainer atEnd:(BOOL)layoutFinished
{
    if(layoutFinished) {
        NSScrollView *editorScrollView = objc_getAssociatedObject(textContainer, &kKeyEditorScrollView);
        [self updateMiniMapForEditorScrollView:editorScrollView];
    }
}

- (NSDictionary *)layoutManager:(NSLayoutManager *)layoutManager shouldUseTemporaryAttributes:(NSDictionary *)attrs forDrawingToScreen:(BOOL)toScreen atCharacterIndex:(NSUInteger)charIndex effectiveRange:(NSRangePointer)effectiveCharRange
{
    NSTextView *editorTextView = objc_getAssociatedObject(layoutManager, &kKeyEditorTextView);
    return [(id<NSLayoutManagerDelegate>)editorTextView layoutManager:layoutManager shouldUseTemporaryAttributes:attrs forDrawingToScreen:toScreen atCharacterIndex:charIndex effectiveRange:effectiveCharRange];
}

#pragma mark - SCTextViewDelegate

- (void)textView:(SCTextView *)textView goAtRelativePosition:(NSPoint)position
{
    NSScrollView *editorScrollView = objc_getAssociatedObject(textView.textContainer, &kKeyEditorScrollView);

    CGFloat documentHeight = [editorScrollView.documentView frame].size.height;
    CGSize boundsSize = editorScrollView.bounds.size;
    CGFloat maxOffset = documentHeight - boundsSize.height;
    
    CGFloat offset =  floor(documentHeight * position.y - boundsSize.height/2);

    offset = MIN(MAX(0, offset), maxOffset);

    NSTextView *editorTextView = objc_getAssociatedObject(textView.layoutManager, &kKeyEditorTextView);
    
    [editorTextView scrollRectToVisible:NSMakeRect(0, offset, boundsSize.width, boundsSize.height)];
}


@end