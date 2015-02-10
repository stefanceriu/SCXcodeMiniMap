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
#import "DVTLayoutManager.h"

#import "DVTPointerArray.h"
#import "DVTSourceTextView.h"
#import "DVTSourceNodeTypes.h"

#import "DVTFontAndColorTheme.h"
#import "DVTPreferenceSetManager.h"

const CGFloat kBackgroundColorShadowLevel = 0.1f;
const CGFloat kHighlightColorAlphaLevel = 0.3f;

static NSString * const kXcodeSyntaxCommentNodeName = @"xcode.syntax.comment";
static NSString * const kXcodeSyntaxCommentDocNodeName = @"xcode.syntax.comment.doc";
static NSString * const kXcodeSyntaxCommentDocKeywordNodeName = @"xcode.syntax.comment.doc.keyword";
static NSString * const kXcodeSyntaxPreprocessorNodeName = @"xcode.syntax.preprocessor";

static NSString * const IDEEditorDocumentDidChangeNotification = @"IDEEditorDocumentDidChangeNotification";
static NSString * const IDESourceCodeEditorTextViewBoundsDidChangeNotification = @"IDESourceCodeEditorTextViewBoundsDidChangeNotification";
static NSString * const DVTFontAndColorSourceTextSettingsChangedNotification = @"DVTFontAndColorSourceTextSettingsChangedNotification";

@interface SCXcodeMinimapView () <NSLayoutManagerDelegate>

@property (nonatomic, strong) IDESourceCodeEditor *editor;
@property (nonatomic, strong) NSScrollView *editorScrollView;
@property (nonatomic, strong) DVTSourceTextView *editorTextView;

@property (nonatomic, strong) NSScrollView *scrollView;
@property (nonatomic, strong) DVTSourceTextView *textView;
@property (nonatomic, strong) SCXcodeMinimapSelectionView *selectionView;
@property (nonatomic, strong) IDESourceCodeDocument *document;

@property (nonatomic, assign) BOOL shouldAllowFullSyntaxHighlight;

@property (nonatomic, strong) NSColor *commentColor;
@property (nonatomic, strong) NSColor *preprocessorColor;

@property (nonatomic, strong) DVTFontAndColorTheme *theme;

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
		self.editor = editor;
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
		[self.textView setTextStorage:self.editorTextView.textStorage];
		[self.textView setEditable:NO];
		[self.textView setSelectable:NO];
		
		[self.scrollView setDocumentView:self.textView];
		
		[self.scrollView setAllowsMagnification:YES];
		[self.scrollView setMinMagnification:kDefaultZoomLevel];
		[self.scrollView setMaxMagnification:kDefaultZoomLevel];
		[self.scrollView setMagnification:kDefaultZoomLevel];
		
		
		self.selectionView = [[SCXcodeMinimapSelectionView alloc] init];
		[self.textView addSubview:_selectionView];
		
		
		[self updateTheme];
		
		
		__weak typeof(self) weakSelf = self;
		[[NSNotificationCenter defaultCenter] addObserverForName:SCXodeMinimapShowNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
			[weakSelf setVisible:YES];
		}];
		
		[[NSNotificationCenter defaultCenter] addObserverForName:SCXodeMinimapHideNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
			[weakSelf setVisible:NO];
		}];
		
		[[NSNotificationCenter defaultCenter] addObserverForName:DVTFontAndColorSourceTextSettingsChangedNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
			[weakSelf updateTheme];
		}];
		
		[[NSNotificationCenter defaultCenter] addObserverForName:IDESourceCodeEditorTextViewBoundsDidChangeNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
			if([note.object isEqual:weakSelf.editor]) {
				[weakSelf updateOffset];
			}
		}];
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
		
		[self.textView.layoutManager setDelegate:self];
	} else {
		[self.textView.layoutManager setDelegate:nil];
	}
}

#pragma mark - NSLayoutManagerDelegate

- (NSDictionary *)layoutManager:(NSLayoutManager *)layoutManager
   shouldUseTemporaryAttributes:(NSDictionary *)attrs
			 forDrawingToScreen:(BOOL)toScreen
			   atCharacterIndex:(NSUInteger)charIndex
				 effectiveRange:(NSRangePointer)effectiveCharRange
{
	if(!toScreen || self.hidden) {
		return nil;
	}
	
	// Prevent full range invalidation for performance reasons.
	if(!self.shouldAllowFullSyntaxHighlight) {
		
		// Attempt a full range invalidation after all temporary attributes are set
		__weak typeof(self) weakSelf = self;
		void(^invalidationBlock)() = ^{
			weakSelf.shouldAllowFullSyntaxHighlight = YES;
			NSRange visibleMinimapRange = [weakSelf.textView visibleCharacterRange];
			[weakSelf.textView.layoutManager invalidateDisplayForCharacterRange:visibleMinimapRange];
		};
		
		NSRange visibleEditorRange = [self.editorTextView visibleCharacterRange];
		if(charIndex > visibleEditorRange.location + visibleEditorRange.length ) {
			*effectiveCharRange = NSMakeRange(visibleEditorRange.location + visibleEditorRange.length,
											  layoutManager.textStorage.length - visibleEditorRange.location - visibleEditorRange.length);
		
			[self performBlock:invalidationBlock afterDelay:0.5f cancelPreviousRequest:YES];
			
			return @{NSForegroundColorAttributeName : [self.theme sourcePlainTextColor]};
		}
		
		if(charIndex < visibleEditorRange.location) {
			*effectiveCharRange = NSMakeRange(0, visibleEditorRange.location);
			
			[self performBlock:invalidationBlock afterDelay:0.5f cancelPreviousRequest:YES];
			
			return @{NSForegroundColorAttributeName : [self.theme sourcePlainTextColor]};
		}
	}
	
	// Rely on the colorAtCharacterIndex: method to update the effective range
	DVTTextStorage *storage = [self.editorTextView textStorage];
	NSColor *color = [storage colorAtCharacterIndex:charIndex effectiveRange:effectiveCharRange context:nil];
	
	// Background color for comments and preprocessor directives. Could query for nodeTypeAtCharacterIndex: but it's too slow.
	DVTPointerArray *colors = [[DVTFontAndColorTheme currentTheme] syntaxColorsByNodeType];
	if([color isEqual:[colors pointerAtIndex:[DVTSourceNodeTypes registerNodeTypeNamed:kXcodeSyntaxCommentNodeName]]] ||
	   [color isEqual:[colors pointerAtIndex:[DVTSourceNodeTypes registerNodeTypeNamed:kXcodeSyntaxCommentDocNodeName]]] ||
	   [color isEqual:[colors pointerAtIndex:[DVTSourceNodeTypes registerNodeTypeNamed:kXcodeSyntaxCommentDocKeywordNodeName]]])
	{
		return @{NSForegroundColorAttributeName : [self.theme sourceTextBackgroundColor], NSBackgroundColorAttributeName : self.commentColor};
	} else if([color isEqual:[colors pointerAtIndex:[DVTSourceNodeTypes registerNodeTypeNamed:kXcodeSyntaxPreprocessorNodeName]]]) {
		return @{NSForegroundColorAttributeName : [self.theme sourceTextBackgroundColor], NSBackgroundColorAttributeName : self.preprocessorColor};
	}
	
	return @{NSForegroundColorAttributeName : color};
}

- (void)layoutManager:(NSLayoutManager *)layoutManager didCompleteLayoutForTextContainer:(NSTextContainer *)textContainer atEnd:(BOOL)layoutFinishedFlag
{
	self.shouldAllowFullSyntaxHighlight = NO;
}

#pragma mark - Navigation

- (void)updateOffset
{
	if (self.isHidden) {
		return;
	}
	
	CGFloat editorTextHeight = CGRectGetHeight([self.editorTextView.layoutManager usedRectForTextContainer:self.editorTextView.textContainer]);
	CGFloat minimapTextHeight = CGRectGetHeight([self.textView.layoutManager usedRectForTextContainer:self.textView.textContainer]);
	
	CGFloat adjustedEditorContentHeight = editorTextHeight - CGRectGetHeight(self.editorScrollView.bounds);
	CGFloat adjustedMinimapContentHeight = minimapTextHeight - (CGRectGetHeight(self.scrollView.bounds) * (1 / self.scrollView.magnification));
	
	NSRect selectionViewFrame = NSMakeRect(0, 0, self.bounds.size.width * (1 / self.scrollView.magnification), self.editorScrollView.visibleRect.size.height);
	
	if(adjustedEditorContentHeight == 0.0f) {
		[self.selectionView setFrame:selectionViewFrame];
		return;
	}
	
	CGFloat ratio = (adjustedMinimapContentHeight / adjustedEditorContentHeight) * (1 / self.scrollView.magnification);
	CGPoint offset = NSMakePoint(0, MAX(0, floorf(self.editorScrollView.contentView.bounds.origin.y * ratio * self.scrollView.magnification)));
	
	[self.scrollView.documentView scrollPoint:offset];
	
	
	ratio = (minimapTextHeight - self.selectionView.bounds.size.height) / adjustedEditorContentHeight;
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
	[self.editorTextView scrollRangeToVisible:NSMakeRange(characterIndex, 0) animate:YES];
}

#pragma mark - Theme

- (void)updateTheme
{
	//DVTPreferenceSetManager *preferenceSetManager = [DVTFontAndColorTheme preferenceSetsManager];
	//NSArray *preferenceSet = [preferenceSetManager availablePreferenceSets];
	//self.theme = [preferenceSet lastObject];
	self.theme = [DVTFontAndColorTheme currentTheme];
	
	NSColor *backgroundColor = [self.theme.sourceTextBackgroundColor shadowWithLevel:kBackgroundColorShadowLevel];
	
	[self.scrollView setBackgroundColor:backgroundColor];
	[self.textView setBackgroundColor:backgroundColor];
	
	NSColor *selectionColor = [NSColor colorWithCalibratedRed:(1.0f - [backgroundColor redComponent])
														green:(1.0f - [backgroundColor greenComponent])
														 blue:(1.0f - [backgroundColor blueComponent])
														alpha:kHighlightColorAlphaLevel];
	
	DVTPointerArray *colors = [self.theme syntaxColorsByNodeType];
	self.commentColor = [colors pointerAtIndex:[DVTSourceNodeTypes registerNodeTypeNamed:kXcodeSyntaxCommentNodeName]];
	self.commentColor = [NSColor colorWithCalibratedRed:self.commentColor.redComponent
												  green:self.commentColor.greenComponent
												   blue:self.commentColor.blueComponent
												  alpha:kHighlightColorAlphaLevel];
	
	
	self.preprocessorColor = [colors pointerAtIndex:[DVTSourceNodeTypes registerNodeTypeNamed:kXcodeSyntaxPreprocessorNodeName]];
	self.preprocessorColor = [NSColor colorWithCalibratedRed:self.preprocessorColor.redComponent
													   green:self.preprocessorColor.greenComponent
														blue:self.preprocessorColor.blueComponent
													   alpha:kHighlightColorAlphaLevel];
	
	[self.selectionView setSelectionColor:selectionColor];
}

#pragma mark - Autoresizing

- (void)resizeWithOldSuperviewSize:(NSSize)oldSize
{
	[super resizeWithOldSuperviewSize:oldSize];
	[self updateOffset];
}

#pragma mark - Helpers

- (void)performBlock:(void (^)(void))block afterDelay:(NSTimeInterval)delay cancelPreviousRequest:(BOOL)cancel {
	if (cancel) {
		[NSObject cancelPreviousPerformRequestsWithTarget:self];
	}
	
	[self performSelector:@selector(delayedAddOperation:)
			   withObject:[NSBlockOperation blockOperationWithBlock:block]
			   afterDelay:delay];
}

- (void)delayedAddOperation:(NSOperation *)operation {
	[[NSOperationQueue currentQueue] addOperation:operation];
}

@end
