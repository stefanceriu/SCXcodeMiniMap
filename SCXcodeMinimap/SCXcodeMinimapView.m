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
#import "IDEEditorDocument.h"

#import "DVTTextStorage.h"
#import "DVTLayoutManager.h"

#import "DVTPointerArray.h"
#import "DVTSourceTextView.h"
#import "DVTSourceNodeTypes.h"

#import "DVTFontAndColorTheme.h"
#import "DVTPreferenceSetManager.h"

#import "DVTFoldingManager.h"
#import "IDEBreakpointManager+SCXcodeMinimap.h"
#import "IDEFileBreakpoint.h"
#import "DVTTextDocumentLocation.h"

const CGFloat kBackgroundColorShadowLevel = 0.1f;
const CGFloat kDurationBetweenInvalidations = 0.5f;

static NSString * const kXcodeSyntaxCommentNodeName = @"xcode.syntax.comment";
static NSString * const kXcodeSyntaxCommentDocNodeName = @"xcode.syntax.comment.doc";
static NSString * const kXcodeSyntaxCommentDocKeywordNodeName = @"xcode.syntax.comment.doc.keyword";
static NSString * const kXcodeSyntaxPreprocessorNodeName = @"xcode.syntax.preprocessor";

static NSString * const IDEEditorDocumentDidChangeNotification = @"IDEEditorDocumentDidChangeNotification";
static NSString * const IDESourceCodeEditorTextViewBoundsDidChangeNotification = @"IDESourceCodeEditorTextViewBoundsDidChangeNotification";
static NSString * const DVTFontAndColorSourceTextSettingsChangedNotification = @"DVTFontAndColorSourceTextSettingsChangedNotification";

static NSString * const kBreakpointRangeKey = @"kBreakpointRangeKey";
static NSString * const kBreakpointEnabledKey = @"kBreakpointEnabledKey";


@interface SCXcodeMinimapTheme : NSObject

@property (nonatomic, strong) NSColor *backgroundColor;
@property (nonatomic, strong) NSColor *selectionColor;

@property (nonatomic, strong) NSColor *sourcePlainTextColor;
@property (nonatomic, strong) NSColor *sourceTextBackgroundColor;
@property (nonatomic, strong) NSColor *commentBackgroundColor;
@property (nonatomic, strong) NSColor *preprocessorBackgroundColor;
@property (nonatomic, strong) NSColor *enabledBreakpointColor;
@property (nonatomic, strong) NSColor *disabledBreakpointColor;

@property (nonatomic, strong) DVTFontAndColorTheme *dvtTheme;

@end

@implementation SCXcodeMinimapTheme

@end


@interface SCXcodeMinimapView () <NSLayoutManagerDelegate, DVTFoldingManagerDelegate, IDEBreakpointManagerDelegate>

@property (nonatomic, strong) IDESourceCodeEditor *editor;
@property (nonatomic, strong) NSScrollView *editorScrollView;
@property (nonatomic, strong) DVTSourceTextView *editorTextView;

@property (nonatomic, strong) NSScrollView *scrollView;
@property (nonatomic, strong) DVTSourceTextView *textView;
@property (nonatomic, strong) SCXcodeMinimapSelectionView *selectionView;
@property (nonatomic, strong) IDESourceCodeDocument *document;

@property (nonatomic, strong) SCXcodeMinimapTheme *minimapTheme;
@property (nonatomic, strong) SCXcodeMinimapTheme *editorTheme;

@property (nonatomic, assign) BOOL shouldAllowFullSyntaxHighlight;
@property (nonatomic, strong) NSMutableArray *breakpointDictionaries;

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
		[self.editorTextView.foldingManager setDelegate:self];

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
		
		
		BOOL shouldHighlightBreakpoints = [[[NSUserDefaults standardUserDefaults] objectForKey:SCXcodeMinimapShouldHighlightBreakpointsKey] boolValue];
		if(shouldHighlightBreakpoints) {
			IDEBreakpointManager *breakpointManager = [self.editor _breakpointManager];
			[breakpointManager setDelegate:self];
			[self updateBreakpoints];
		}
		
		BOOL shouldHideEditorVerticalScroller = [[[NSUserDefaults standardUserDefaults] objectForKey:SCXcodeMinimapShouldHideEditorScrollerKey] boolValue];
		[self.editorScrollView setHasVerticalScroller:!shouldHideEditorVerticalScroller];
		
		__weak typeof(self) weakSelf = self;
		[[NSNotificationCenter defaultCenter] addObserverForName:SCXcodeMinimapShouldDisplayChangeNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
			[weakSelf setVisible:[[[NSUserDefaults standardUserDefaults] objectForKey:SCXcodeMinimapShouldDisplayKey] boolValue]];
		}];
		
		[[NSNotificationCenter defaultCenter] addObserverForName:SCXcodeMinimapHighlightBreakpointsChangeNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
			[weakSelf updateBreakpoints];
		}];
		
		[[NSNotificationCenter defaultCenter] addObserverForName:SCXcodeMinimapHighlightCommentsChangeNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
			[weakSelf invalidateDisplayForVisibleMinimapRange];
		}];
		
		[[NSNotificationCenter defaultCenter] addObserverForName:SCXcodeMinimapHighlightPreprocessorChangeNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
			[weakSelf invalidateDisplayForVisibleMinimapRange];
		}];
		
		[[NSNotificationCenter defaultCenter] addObserverForName:SCXcodeMinimapHighlightEditorChangeNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
			
			BOOL editorHighlightingEnabled = [[[NSUserDefaults standardUserDefaults] objectForKey:SCXcodeMinimapShouldHighlightEditorKey] boolValue];
			if(editorHighlightingEnabled) {
				[weakSelf.editorTextView.layoutManager setDelegate:weakSelf];
			} else {
				[weakSelf.editorTextView.layoutManager setDelegate:(id<NSLayoutManagerDelegate>)weakSelf.editorTextView];
			}
			
			[weakSelf invalidateDisplayForVisibleEditorRange];
		}];
		
		[[NSNotificationCenter defaultCenter] addObserverForName:SCXcodeMinimapHideEditorScrollerChangeNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
			[weakSelf.editorScrollView setHasVerticalScroller:![[[NSUserDefaults standardUserDefaults] objectForKey:SCXcodeMinimapShouldHideEditorScrollerKey] boolValue]];
		}];
		
		[[NSNotificationCenter defaultCenter] addObserverForName:SCXcodeMinimapThemeChangeNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
			[weakSelf updateTheme];
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
		
		BOOL editorHighlightingEnabled = [[[NSUserDefaults standardUserDefaults] objectForKey:SCXcodeMinimapShouldHighlightEditorKey] boolValue];
		if(editorHighlightingEnabled) {
			[self.editorTextView.layoutManager setDelegate:self];
		}
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
	
	SCXcodeMinimapTheme *theme = ([layoutManager isEqualTo:self.textView.layoutManager] ? self.minimapTheme : self.editorTheme);
	
	// Delay invalidation for performance reasons and attempt a full range invalidation later
	if(!self.shouldAllowFullSyntaxHighlight && ![layoutManager isEqual:self.editorTextView.layoutManager]) {
		
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(invalidateDisplayForVisibleMinimapRange) object:nil];
		[self performSelector:@selector(invalidateDisplayForVisibleMinimapRange) withObject:nil afterDelay:kDurationBetweenInvalidations];
		
		return @{NSForegroundColorAttributeName : theme.sourcePlainTextColor};
	}
	
	// Set background colors for breakpoints
	if(self.breakpointDictionaries.count) {
		for(NSDictionary *breakpointDictionary in self.breakpointDictionaries) {
			NSRange range = [breakpointDictionary[kBreakpointRangeKey] rangeValue];
			BOOL enabled = [breakpointDictionary[kBreakpointEnabledKey] boolValue];
			
			if(NSIntersectionRange(range, NSMakeRange(charIndex, 1)).length) {
				*effectiveCharRange = range;
				return @{NSForegroundColorAttributeName : theme.sourceTextBackgroundColor,
						 NSBackgroundColorAttributeName : (enabled ? theme.enabledBreakpointColor : theme.disabledBreakpointColor)};
			}
		}
	}
	
	// Set background colors for comments and preprocessor directives
	short nodeType = [(DVTTextStorage *)[self.textView textStorage] nodeTypeAtCharacterIndex:charIndex
																			  effectiveRange:effectiveCharRange
																					 context:self.editorTextView.syntaxColoringContext];
	
	BOOL shouldHighlightComments = [[[NSUserDefaults standardUserDefaults] objectForKey:SCXcodeMinimapShouldHighlightCommentsKey] boolValue];
	if(shouldHighlightComments) {
		if(nodeType == [DVTSourceNodeTypes registerNodeTypeNamed:kXcodeSyntaxCommentNodeName] ||
		   nodeType == [DVTSourceNodeTypes registerNodeTypeNamed:kXcodeSyntaxCommentDocNodeName] ||
		   nodeType == [DVTSourceNodeTypes registerNodeTypeNamed:kXcodeSyntaxCommentDocKeywordNodeName])
		{
			return @{NSForegroundColorAttributeName : theme.sourceTextBackgroundColor, NSBackgroundColorAttributeName : theme.commentBackgroundColor};
		}
	}
	
	BOOL shouldHighlightPreprocessor = [[[NSUserDefaults standardUserDefaults] objectForKey:SCXcodeMinimapShouldHighlightPreprocessorKey] boolValue];
	if(shouldHighlightPreprocessor) {
		if(nodeType == [DVTSourceNodeTypes registerNodeTypeNamed:kXcodeSyntaxPreprocessorNodeName]) {
			return @{NSForegroundColorAttributeName : theme.sourceTextBackgroundColor, NSBackgroundColorAttributeName : theme.preprocessorBackgroundColor};
		}
	}
	
	NSColor *foregroundColor = [[((DVTFontAndColorTheme *)theme.dvtTheme) syntaxColorsByNodeType] pointerAtIndex:nodeType];
	if(foregroundColor == nil) {
		foregroundColor = theme.sourcePlainTextColor;
	}
	
	return @{NSForegroundColorAttributeName : foregroundColor};
}

- (void)layoutManager:(NSLayoutManager *)layoutManager didCompleteLayoutForTextContainer:(NSTextContainer *)textContainer atEnd:(BOOL)layoutFinishedFlag
{
	self.shouldAllowFullSyntaxHighlight = NO;
}

#pragma mark - DVTFoldingManagerDelegate

- (void)foldingManager:(DVTFoldingManager *)foldingManager didFoldRange:(NSRange)range
{
	[(DVTLayoutManager *)self.editorTextView.layoutManager foldingManager:foldingManager didFoldRange:range];
	
	[self.textView.foldingManager foldRange:range];
	
	[self invalidateLayoutForVisibleMinimapRange];
}

- (void)foldingManager:(DVTFoldingManager *)foldingManager didUnfoldRange:(NSRange)range
{
	[(DVTLayoutManager *)self.editorTextView.layoutManager foldingManager:foldingManager didUnfoldRange:range];
	
	[self.textView.foldingManager unfoldRange:range];
	
	[self invalidateLayoutForVisibleMinimapRange];
}

#pragma mark - IDEBreakpointManagerDelegate

- (void)breakpointManagerDidAddBreakpoint:(IDEBreakpointManager *)breakpointManager
{
	[self updateBreakpoints];
}

- (void)breakpointManagerDidRemoveBreakpoint:(IDEBreakpointManager *)breakpointManager
{
	[self updateBreakpoints];
}

- (void)breakpointManagerDidChangeBreakpoint:(IDEBreakpointManager *)breakpointManager
{
	[self updateBreakpoints];
}

- (void)updateBreakpoints
{
	BOOL shouldHighlightBreakpoints = [[[NSUserDefaults standardUserDefaults] objectForKey:SCXcodeMinimapShouldHighlightBreakpointsKey] boolValue];
	if(!shouldHighlightBreakpoints) {
		self.breakpointDictionaries = nil;
		return;
	}
	
	self.breakpointDictionaries = [NSMutableArray array];
	
	IDEBreakpointManager *breakpointManager = [self.editor _breakpointManager];
	
	for (NSUInteger index = 0, lineNumber = 1; index < self.textView.string.length; lineNumber++) {
		
		NSRange lineRange = [self.textView.string lineRangeForRange:NSMakeRange(index, 0)];
		
		for(IDEBreakpoint *breakpoint in breakpointManager.breakpoints) {
			if([breakpoint isKindOfClass:[IDEFileBreakpoint class]]) {
				IDEFileBreakpoint *fileBreakpoint = (IDEFileBreakpoint *)breakpoint;
				
				if([fileBreakpoint.documentURL isEqualTo:self.editor.document.fileURL] && fileBreakpoint.location.startingLineNumber == lineNumber) {
					[self.breakpointDictionaries addObject:@{kBreakpointRangeKey : [NSValue valueWithRange:lineRange],
															 kBreakpointEnabledKey : @(fileBreakpoint.shouldBeEnabled && breakpointManager.breakpointsActivated)}];
				}
			}
		}
		
		index = NSMaxRange(lineRange);
	}
	
	[self invalidateDisplayForVisibleMinimapRange];
	
	BOOL editorHighlightingEnabled = [[[NSUserDefaults standardUserDefaults] objectForKey:SCXcodeMinimapShouldHighlightEditorKey] boolValue];
	if(editorHighlightingEnabled) {
		[self invalidateDisplayForVisibleEditorRange];
	}
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
	self.editorTheme = [self minimapThemeWithTheme:[DVTFontAndColorTheme currentTheme]];

	DVTPreferenceSetManager *preferenceSetManager = [DVTFontAndColorTheme preferenceSetsManager];
	NSArray *preferenceSet = [preferenceSetManager availablePreferenceSets];
	
	NSString *themeName = [[NSUserDefaults standardUserDefaults] objectForKey:SCXcodeMinimapThemeKey];
	NSUInteger themeIndex = [preferenceSet indexesOfObjectsPassingTest:^BOOL(DVTFontAndColorTheme *theme, NSUInteger idx, BOOL *stop) {
		return [theme.localizedName isEqualTo:themeName];
	}].lastIndex;
	
	if(themeIndex == NSNotFound) {
		self.minimapTheme = self.editorTheme;
	} else {
		self.minimapTheme = [self minimapThemeWithTheme:preferenceSet[themeIndex]];
	}
	
	[self.scrollView setBackgroundColor:self.minimapTheme.backgroundColor];
	[self.textView setBackgroundColor:self.minimapTheme.backgroundColor];
	
	[self.selectionView setSelectionColor:self.minimapTheme.selectionColor];
}

- (SCXcodeMinimapTheme *)minimapThemeWithTheme:(DVTFontAndColorTheme *)theme
{
	SCXcodeMinimapTheme *minimapTheme = [[SCXcodeMinimapTheme alloc] init];
	
	minimapTheme.backgroundColor = [theme.sourceTextBackgroundColor shadowWithLevel:kBackgroundColorShadowLevel];
	
	minimapTheme.selectionColor = [NSColor colorWithCalibratedRed:(1.0f - [minimapTheme.backgroundColor redComponent])
															green:(1.0f - [minimapTheme.backgroundColor greenComponent])
															 blue:(1.0f - [minimapTheme.backgroundColor blueComponent])
															alpha:0.2f];
	
	
	DVTPointerArray *colors = [theme syntaxColorsByNodeType];
	minimapTheme.commentBackgroundColor = [colors pointerAtIndex:[DVTSourceNodeTypes registerNodeTypeNamed:kXcodeSyntaxCommentNodeName]];
	minimapTheme.commentBackgroundColor = [NSColor colorWithCalibratedRed:minimapTheme.commentBackgroundColor.redComponent
																	green:minimapTheme.commentBackgroundColor.greenComponent
																	 blue:minimapTheme.commentBackgroundColor.blueComponent
																	alpha:0.3f];
	
	
	minimapTheme.preprocessorBackgroundColor = [colors pointerAtIndex:[DVTSourceNodeTypes registerNodeTypeNamed:kXcodeSyntaxPreprocessorNodeName]];
	minimapTheme.preprocessorBackgroundColor = [NSColor colorWithCalibratedRed:minimapTheme.preprocessorBackgroundColor.redComponent
																		 green:minimapTheme.preprocessorBackgroundColor.greenComponent
																		  blue:minimapTheme.preprocessorBackgroundColor.blueComponent
																		 alpha:0.3f];
	
	minimapTheme.enabledBreakpointColor = [NSColor colorWithRed:65.0f/255.0f green:113.0f/255.0f blue:200.0f/255.0f alpha:1.0f];
	minimapTheme.disabledBreakpointColor = [NSColor colorWithRed:65.0f/255.0f green:113.0f/255.0f blue:200.0f/255.0f alpha:0.5f];
	
	minimapTheme.sourcePlainTextColor = theme.sourcePlainTextColor;
	minimapTheme.sourceTextBackgroundColor = theme.sourceTextBackgroundColor;
	minimapTheme.dvtTheme = theme;
	
	return minimapTheme;
}

#pragma mark - Autoresizing

- (void)resizeWithOldSuperviewSize:(NSSize)oldSize
{
	[super resizeWithOldSuperviewSize:oldSize];
	[self updateOffset];
}

#pragma mark - Helpers

- (void)invalidateDisplayForVisibleMinimapRange
{
	self.shouldAllowFullSyntaxHighlight = YES;
	
	NSRange visibleMinimapRange = [self.textView visibleCharacterRange];
	[self.textView.layoutManager invalidateDisplayForCharacterRange:visibleMinimapRange];
}

- (void)invalidateLayoutForVisibleMinimapRange
{
	NSRange visibleMinimapRange = [self.textView visibleCharacterRange];
	[self.textView.layoutManager invalidateLayoutForCharacterRange:visibleMinimapRange actualCharacterRange:nil];
}

- (void)invalidateDisplayForVisibleEditorRange
{
	NSRange visibleEditorRange = [self.editorTextView visibleCharacterRange];
	[self.editorTextView.layoutManager invalidateDisplayForCharacterRange:visibleEditorRange];
}

@end
