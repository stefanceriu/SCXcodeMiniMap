//
//  SCMinimapView.m
//  SCXcodeMinimap
//
//  Created by Stefan Ceriu on 24/01/2015.
//  Copyright (c) 2015 Stefan Ceriu. All rights reserved.
//

#import "SCXcodeMinimapView.h"
#import "SCXcodeMinimap.h"
#import "SCXcodeMinimapSelectionView.h"

#import "IDESourceCodeEditor.h"
#import "DVTTextStorage.h"
#import "DVTPointerArray.h"
#import "DVTSourceTextView.h"
#import "DVTSourceNodeTypes.h"
#import "DVTFontAndColorTheme.h"

const CGFloat kBackgroundColorShadowLevel = 0.1f;
const CGFloat kHighlightColorAlphaLevel = 0.3f;

static NSString * const kXcodeSyntaxCommentNodeName = @"xcode.syntax.comment";
static NSString * const kXcodeSyntaxCommentDocNodeName = @"xcode.syntax.comment.doc";
static NSString * const kXcodeSyntaxCommentDocKeywordNodeName = @"xcode.syntax.comment.doc.keyword";
static NSString * const kXcodeSyntaxPreprocessorNodeName = @"xcode.syntax.preprocessor";

static NSString * const DVTFontAndColorSourceTextSettingsChangedNotification = @"DVTFontAndColorSourceTextSettingsChangedNotification";

@interface SCXcodeMinimapView () <NSLayoutManagerDelegate>

@property (nonatomic, strong) NSScrollView *editorScrollView;
@property (nonatomic, strong) DVTSourceTextView *editorTextView;

@property (nonatomic, strong) NSScrollView *scrollView;
@property (nonatomic, strong) DVTSourceTextView *textView;
@property (nonatomic, strong) SCXcodeMinimapSelectionView *selectionView;

@end

@implementation SCXcodeMinimapView

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype)initWithFrame:(NSRect)frame editor:(IDESourceCodeEditor *)editor
{
	if (self = [super initWithFrame:frame])
	{
		self.editorScrollView = editor.scrollView;
		self.editorTextView = editor.textView;
		
		[self setWantsLayer:YES];
		[self setAutoresizingMask:NSViewMinXMargin | NSViewHeightSizable];
		
		self.scrollView = [[NSScrollView alloc] initWithFrame:self.bounds];
		[self.scrollView setAutoresizingMask:NSViewMinXMargin | NSViewHeightSizable];
		[self.scrollView setDrawsBackground:NO];
		
		[self.scrollView setHorizontalScrollElasticity:NSScrollElasticityNone];
		[self.scrollView setVerticalScrollElasticity:NSScrollElasticityNone];
		[self addSubview:self.scrollView];
		
		self.textView = [[DVTSourceTextView alloc] initWithFrame:self.editorTextView.bounds];
		[self.textView setTextStorage:editor.textView.textStorage];
		[self.textView setEditable:NO];
		[self.textView setSelectable:NO];
		
		[self.scrollView setDocumentView:self.textView];
		
		self.selectionView = [[SCXcodeMinimapSelectionView alloc] init];
		[self.textView addSubview:_selectionView];
		
		[self updateTheme];
		
		[[NSNotificationCenter defaultCenter] addObserverForName:SCXodeMinimapShowNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
			[self setVisible:YES];
		}];
		
		[[NSNotificationCenter defaultCenter] addObserverForName:SCXodeMinimapHideNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
			[self setVisible:NO];
		}];
		
		[[NSNotificationCenter defaultCenter] addObserverForName:DVTFontAndColorSourceTextSettingsChangedNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
			[self updateTheme];
		}];
		
		[self.scrollView setAllowsMagnification:YES];
		[self.scrollView setMinMagnification:kDefaultZoomLevel];
		[self.scrollView setMagnification:kDefaultZoomLevel];
	}
	
	return self;
}

#pragma mark - Show/Hide

- (void)setVisible:(BOOL)visible
{
	self.hidden = !visible;
	
	NSRect editorTextViewFrame = self.editorScrollView.frame;
	editorTextViewFrame.size.width = self.editorScrollView.superview.frame.size.width - (visible ? self.bounds.size.width : 0.0f);
	self.editorScrollView.frame = editorTextViewFrame;
	
	if(visible) {
		[self updateOffset];
	}
	
	// Ensure the layout manager's delegate is set to self. The DVTSourceTextView resets it if called to early.
	[self.textView.layoutManager setDelegate:self];
}

#pragma mark - NSLayoutManagerDelegate

- (NSDictionary *)layoutManager:(NSLayoutManager *)layoutManager shouldUseTemporaryAttributes:(NSDictionary *)attrs forDrawingToScreen:(BOOL)toScreen atCharacterIndex:(NSUInteger)charIndex effectiveRange:(NSRangePointer)effectiveCharRange
{
	DVTTextStorage *storage = [self.editorTextView textStorage];
	
	short currentNodeId = [storage nodeTypeAtCharacterIndex:charIndex effectiveRange:effectiveCharRange context:nil];
	
	NSColor *color = [storage colorAtCharacterIndex:charIndex effectiveRange:effectiveCharRange context:nil];
	NSColor *backgroundColor = nil;
	
	if(currentNodeId == [DVTSourceNodeTypes registerNodeTypeNamed:kXcodeSyntaxCommentNodeName] ||
	   currentNodeId == [DVTSourceNodeTypes registerNodeTypeNamed:kXcodeSyntaxCommentDocNodeName] ||
	   currentNodeId == [DVTSourceNodeTypes registerNodeTypeNamed:kXcodeSyntaxCommentDocKeywordNodeName])
	{
		NSColor *color =  [[[DVTFontAndColorTheme currentTheme] syntaxColorsByNodeType] pointerAtIndex:[DVTSourceNodeTypes registerNodeTypeNamed:kXcodeSyntaxCommentNodeName]];
		backgroundColor = [NSColor colorWithCalibratedRed:color.redComponent green:color.greenComponent blue:color.blueComponent alpha:kHighlightColorAlphaLevel];
	} else if(currentNodeId == [DVTSourceNodeTypes registerNodeTypeNamed:kXcodeSyntaxPreprocessorNodeName])
	{
		NSColor *color = [[[DVTFontAndColorTheme currentTheme] syntaxColorsByNodeType] pointerAtIndex:[DVTSourceNodeTypes registerNodeTypeNamed:kXcodeSyntaxPreprocessorNodeName]];
		backgroundColor = [NSColor colorWithCalibratedRed:color.redComponent green:color.greenComponent blue:color.blueComponent alpha:kHighlightColorAlphaLevel];
	}
	
	if(backgroundColor) {
		NSColor *foregroundColor = [[DVTFontAndColorTheme currentTheme] sourceTextBackgroundColor];
		return @{NSForegroundColorAttributeName : foregroundColor, NSBackgroundColorAttributeName : backgroundColor};
	} else {
		return @{NSForegroundColorAttributeName : color};
	}
}

- (void)layoutManager:(NSLayoutManager *)layoutManager didCompleteLayoutForTextContainer:(NSTextContainer *)textContainer atEnd:(BOOL)layoutFinished
{
	if(layoutFinished) {
		[self updateOffset];
	}
}


#pragma mark - Navigation

- (void)updateOffset
{
	if ([self isHidden]) {
		return;
	}
	
	CGFloat editorContentHeight = [self.editorScrollView.documentView frame].size.height - self.editorScrollView.bounds.size.height;
	
	NSRect selectionViewFrame = NSMakeRect(0, 0, self.bounds.size.width * (1 / self.scrollView.magnification), self.editorScrollView.visibleRect.size.height);
	
	if(editorContentHeight == 0.0f) {
		NSLog(@"editorContentHeight IS %f", editorContentHeight);
		[self.selectionView setFrame:selectionViewFrame];
		return;
	}
	
	CGFloat ratio = (CGRectGetHeight([self.scrollView.documentView frame]) - CGRectGetHeight(self.scrollView.bounds) * (1 / self.scrollView.magnification)) / editorContentHeight * (1 / self.scrollView.magnification);
	
	CGPoint offset = NSMakePoint(0, MAX(0, floorf(self.editorScrollView.contentView.bounds.origin.y * ratio * self.scrollView.magnification)));
	[self.scrollView.documentView scrollPoint:offset];
	
	CGFloat textHeight = [self.textView.layoutManager usedRectForTextContainer:self.textView.textContainer].size.height;
	ratio = (textHeight - self.selectionView.bounds.size.height) / editorContentHeight;
	selectionViewFrame.origin.y = self.editorScrollView.contentView.bounds.origin.y * ratio;
	
	[self.selectionView setFrame:selectionViewFrame];
}

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

- (void)handleMouseEvent:(NSEvent *)theEvent
{
	NSPoint point = [self.textView convertPoint:theEvent.locationInWindow fromView:nil];
	NSUInteger characterIndex = [self.textView characterIndexForInsertionAtPoint:point];
	[self.editorTextView scrollRangeToVisible:NSMakeRange(characterIndex, 0)];
}

#pragma mark - Theme

- (void)updateTheme
{
	DVTFontAndColorTheme *theme = [DVTFontAndColorTheme currentTheme];
	NSColor *backgroundColor = [theme.sourceTextBackgroundColor shadowWithLevel:kBackgroundColorShadowLevel];
	
	[self.scrollView setBackgroundColor:backgroundColor];
	[self.textView setBackgroundColor:backgroundColor];
	
	NSColor *selectionColor = [NSColor colorWithCalibratedRed:(1.0f - [backgroundColor redComponent])
														green:(1.0f - [backgroundColor greenComponent])
														 blue:(1.0f - [backgroundColor blueComponent])
														alpha:kHighlightColorAlphaLevel];
	
	[self.selectionView setSelectionColor:selectionColor];
}

#pragma mark - Autoresizing

- (void)resizeWithOldSuperviewSize:(NSSize)oldSize
{
	[super resizeWithOldSuperviewSize:oldSize];
	[self updateOffset];
}

@end
