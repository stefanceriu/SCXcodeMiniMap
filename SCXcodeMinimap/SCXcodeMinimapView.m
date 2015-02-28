//
//  SCMinimapView.m
//  SCXcodeMinimap
//
//  Created by Stefan Ceriu on 24/01/2015.
//  Copyright (c) 2015 Stefan Ceriu. All rights reserved.
//

#import "SCXcodeMinimapView.h"
#import "SCXcodeMinimap.h"
#import "SCXcodeMinimapScrollView.h"
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

#import "DVTAnnotationManager.h"
#import "DBGBreakpointAnnotationProvider+SCXcodeMinimap.h"
#import "DBGBreakpointAnnotation+SCXcodeMinimap.h"
#import "DBGBreakpointAnnotation.h"

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


@interface SCXcodeMinimapView () <NSLayoutManagerDelegate, DVTFoldingManagerDelegate, DBGBreakpointAnnotationProviderDelegate>

@property (nonatomic, weak) IDESourceCodeEditor *editor;
@property (nonatomic, strong) DVTSourceTextView *editorTextView;

@property (nonatomic, strong) SCXcodeMinimapScrollView *scrollView;
@property (nonatomic, strong) DVTSourceTextView *textView;
@property (nonatomic, strong) SCXcodeMinimapSelectionView *selectionView;
@property (nonatomic, strong) IDESourceCodeDocument *document;

@property (nonatomic, strong) SCXcodeMinimapTheme *minimapTheme;
@property (nonatomic, strong) SCXcodeMinimapTheme *editorTheme;

@property (nonatomic, assign) BOOL shouldAllowFullSyntaxHighlight;

@property (nonatomic, assign) BOOL shouldUpdateBreakpoints;
@property (nonatomic, strong) NSMutableArray *breakpointDictionaries;

@property (nonatomic, weak) DBGBreakpointAnnotationProvider *breakpointAnnotationProvider;

@property (nonatomic, strong) NSMutableArray *notificationObservers;

@end

@implementation SCXcodeMinimapView

- (void)dealloc
{	
	for(id observer in self.notificationObservers) {
		[[NSNotificationCenter defaultCenter] removeObserver:observer];
	}
	
	[self.textView.textStorage removeLayoutManager:self.textView.layoutManager];
	[self.breakpointAnnotationProvider setMinimapDelegate:nil];
}

- (instancetype)initWithEditor:(IDESourceCodeEditor *)editor
{
	if (self = [super init])
	{
		self.editor = editor;
		
		self.editorTextView = editor.textView;
		[self.editorTextView.foldingManager setDelegate:self];

		[self setWantsLayer:YES];
		[self setAutoresizingMask:NSViewMinXMargin | NSViewMinYMargin | NSViewWidthSizable | NSViewHeightSizable];
		
		self.scrollView = [[SCXcodeMinimapScrollView alloc] initWithFrame:self.bounds];
		[self.scrollView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
		[self.scrollView setDrawsBackground:NO];
		[self.scrollView setMinMagnification:0.0f];
		[self.scrollView setMaxMagnification:1.0f];
		[self.scrollView setAllowsMagnification:NO];
		
		[self.scrollView setHasHorizontalScroller:NO];
		[self.scrollView setHasVerticalScroller:NO];
		[self.scrollView setHorizontalScrollElasticity:NSScrollElasticityNone];
		[self.scrollView setVerticalScrollElasticity:NSScrollElasticityNone];
		[self addSubview:self.scrollView];
		
		self.textView = [[DVTSourceTextView alloc] init];
		[self.textView setTextStorage:self.editorTextView.textStorage];
		[self.textView setEditable:NO];
		[self.textView setSelectable:NO];
		
		[self.scrollView setDocumentView:self.textView];
		
		self.selectionView = [[SCXcodeMinimapSelectionView alloc] init];
		[self.textView addSubview:self.selectionView];
		
		[self updateTheme];
		
		
		for(NSDictionary *providerDictionary in self.editorTextView.annotationManager.annotationProviders) {
			if([providerDictionary[@"annotationProviderObject"] isKindOfClass:[DBGBreakpointAnnotationProvider class]]) {
				self.breakpointAnnotationProvider = providerDictionary[@"annotationProviderObject"];
				[self.breakpointAnnotationProvider setMinimapDelegate:self];
				break;
			}
		}
		
		BOOL shouldHighlightBreakpoints = [[[NSUserDefaults standardUserDefaults] objectForKey:SCXcodeMinimapShouldHighlightBreakpointsKey] boolValue];
		if(shouldHighlightBreakpoints) {
			self.shouldUpdateBreakpoints = YES;
			[self invalidateDisplayForVisibleRange];
		}
		
		
		BOOL shouldHideEditorVerticalScroller = [[[NSUserDefaults standardUserDefaults] objectForKey:SCXcodeMinimapShouldHideEditorScrollerKey] boolValue];
		[self.editor.scrollView setHasVerticalScroller:!shouldHideEditorVerticalScroller];
		
		
		// Notifications
		
		self.notificationObservers = [NSMutableArray array];
		
		__weak typeof(self) weakSelf = self;
		[self.notificationObservers addObject:[[NSNotificationCenter defaultCenter] addObserverForName:SCXcodeMinimapShouldDisplayChangeNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
			[weakSelf setVisible:[[[NSUserDefaults standardUserDefaults] objectForKey:SCXcodeMinimapShouldDisplayKey] boolValue]];
		}]];
		
		[self.notificationObservers addObject:[[NSNotificationCenter defaultCenter] addObserverForName:SCXcodeMinimapZoomLevelChangeNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
			[weakSelf updateSize];
			[weakSelf invalidateDisplayForVisibleRange];
		}]];
		
		[self.notificationObservers addObject:[[NSNotificationCenter defaultCenter] addObserverForName:SCXcodeMinimapHighlightBreakpointsChangeNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
			weakSelf.shouldUpdateBreakpoints = YES;
			[weakSelf invalidateDisplayForVisibleRange];
		}]];
		
		[self.notificationObservers addObject:[[NSNotificationCenter defaultCenter] addObserverForName:SCXcodeMinimapHighlightCommentsChangeNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
			[weakSelf invalidateDisplayForVisibleRange];
		}]];
		
		[self.notificationObservers addObject:[[NSNotificationCenter defaultCenter] addObserverForName:SCXcodeMinimapHighlightPreprocessorChangeNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
			[weakSelf invalidateDisplayForVisibleRange];
		}]];
		
		[self.notificationObservers addObject:[[NSNotificationCenter defaultCenter] addObserverForName:SCXcodeMinimapHighlightEditorChangeNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
			
			BOOL editorHighlightingEnabled = [[[NSUserDefaults standardUserDefaults] objectForKey:SCXcodeMinimapShouldHighlightEditorKey] boolValue];
			if(editorHighlightingEnabled) {
				[weakSelf.editorTextView.layoutManager setDelegate:weakSelf];
			} else {
				[weakSelf.editorTextView.layoutManager setDelegate:(id<NSLayoutManagerDelegate>)weakSelf.editorTextView];
			}
			
			[weakSelf invalidateDisplayForVisibleRange];
		}]];
		
		[self.notificationObservers addObject:[[NSNotificationCenter defaultCenter] addObserverForName:SCXcodeMinimapHideEditorScrollerChangeNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
			[weakSelf.editor.scrollView setHasVerticalScroller:![[[NSUserDefaults standardUserDefaults] objectForKey:SCXcodeMinimapShouldHideEditorScrollerKey] boolValue]];
		}]];
		
		[self.notificationObservers addObject:[[NSNotificationCenter defaultCenter] addObserverForName:SCXcodeMinimapThemeChangeNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
			[weakSelf updateTheme];
		}]];
		
		[self.notificationObservers addObject:[[NSNotificationCenter defaultCenter] addObserverForName:DVTFontAndColorSourceTextSettingsChangedNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
			[weakSelf updateTheme];
		}]];
		
		[self.notificationObservers addObject:[[NSNotificationCenter defaultCenter] addObserverForName:IDESourceCodeEditorTextViewBoundsDidChangeNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
			if([note.object isEqual:weakSelf.editor]) {
				[weakSelf updateOffset];
			}
		}]];
	}
	
	return self;
}

- (void)viewDidMoveToWindow
{
	if(self.window == nil) {
		return;
	}
	
	[self setVisible:[[[NSUserDefaults standardUserDefaults] objectForKey:SCXcodeMinimapShouldDisplayKey] boolValue]];
}

#pragma mark - Show/Hide

- (void)setVisible:(BOOL)visible
{
	self.hidden  = !visible;
	
	[self updateSize];
	
	[self.textView.layoutManager setDelegate:(self.hidden ? nil : self)];	
	[self.textView.layoutManager setBackgroundLayoutEnabled:YES];
	[self.textView.layoutManager setAllowsNonContiguousLayout:YES];
	
	BOOL editorHighlightingEnabled = [[[NSUserDefaults standardUserDefaults] objectForKey:SCXcodeMinimapShouldHighlightEditorKey] boolValue];
	if(editorHighlightingEnabled) {
		[self.editorTextView.layoutManager setDelegate:self];
	}
}

#pragma mark - NSLayoutManagerDelegate

- (NSDictionary *)layoutManager:(NSLayoutManager *)layoutManager
   shouldUseTemporaryAttributes:(NSDictionary *)attrs
			 forDrawingToScreen:(BOOL)toScreen
			   atCharacterIndex:(NSUInteger)charIndex
				 effectiveRange:(NSRangePointer)effectiveCharRange
{
	if(!toScreen) {
		return nil;
	}
	
	if(self.hidden && [layoutManager isEqual:self.textView.layoutManager]) {
		return nil;
	}
	
	SCXcodeMinimapTheme *theme = ([layoutManager isEqualTo:self.textView.layoutManager] ? self.minimapTheme : self.editorTheme);
	
	// Delay invalidation for performance reasons and attempt a full range invalidation later
	if(!self.shouldAllowFullSyntaxHighlight && [layoutManager isEqual:self.textView.layoutManager]) {
		
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(invalidateDisplayForVisibleRange) object:nil];
		[self performSelector:@selector(invalidateDisplayForVisibleRange) withObject:nil afterDelay:kDurationBetweenInvalidations];
		
		return @{NSForegroundColorAttributeName : theme.sourcePlainTextColor};
	}
	
	if(self.shouldAllowFullSyntaxHighlight) {
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

#pragma mark - DBGBreakpointAnnotationProviderDelegate

- (void)breakpointAnnotationProviderDidChangeBreakpoints:(DBGBreakpointAnnotationProvider *)annotationProvider
{
	self.shouldUpdateBreakpoints = YES;
	
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(invalidateDisplayForVisibleRange) object:nil];
	[self performSelector:@selector(invalidateDisplayForVisibleRange) withObject:nil afterDelay:kDurationBetweenInvalidations];
}

- (void)updateBreakpoints
{
	BOOL shouldHighlightBreakpoints = [[[NSUserDefaults standardUserDefaults] objectForKey:SCXcodeMinimapShouldHighlightBreakpointsKey] boolValue];
	if(!shouldHighlightBreakpoints) {
		self.breakpointDictionaries = nil;
		return;
	}
	
	self.breakpointDictionaries = [NSMutableArray array];
	
	for (NSUInteger index = 0, lineNumber = 0; index < self.textView.string.length; lineNumber++) {
		
		NSRange lineRange = [self.textView.string lineRangeForRange:NSMakeRange(index, 0)];
		
		for(DBGBreakpointAnnotation *breakpointAnnotation in self.breakpointAnnotationProvider.annotations) {
			if(breakpointAnnotation.paragraphRange.location == lineNumber) {
				[self.breakpointDictionaries addObject:@{kBreakpointRangeKey : [NSValue valueWithRange:lineRange],
														 kBreakpointEnabledKey : @(breakpointAnnotation.enabled)}];
			}
		}
		
		index = NSMaxRange(lineRange);
	}
	
	self.shouldUpdateBreakpoints = NO;
}

#pragma mark - Navigation

- (void)updateOffset
{
	if (self.isHidden) {
		return;
	}
	
	CGFloat editorTextHeight = CGRectGetHeight([self.editorTextView.layoutManager usedRectForTextContainer:self.editorTextView.textContainer]);
	CGFloat minimapTextHeight = CGRectGetHeight([self.textView.layoutManager usedRectForTextContainer:self.textView.textContainer]);
	
	CGFloat adjustedEditorContentHeight = editorTextHeight - CGRectGetHeight(self.editor.scrollView.bounds);
	CGFloat adjustedMinimapContentHeight = minimapTextHeight - (CGRectGetHeight(self.scrollView.bounds) * (1 / self.scrollView.magnification));
	
	NSRect selectionViewFrame = NSMakeRect(0, 0, self.textView.bounds.size.width * (1 / self.scrollView.magnification), self.editor.scrollView.visibleRect.size.height);
	
	if(adjustedEditorContentHeight == 0.0f) {
		[self.selectionView setFrame:selectionViewFrame];
		return;
	}
	
	CGFloat ratio = (adjustedMinimapContentHeight / adjustedEditorContentHeight) * (1 / self.scrollView.magnification);
	CGPoint offset = NSMakePoint(self.editor.scrollView.contentView.bounds.origin.x,
								 MAX(0, floorf(self.editor.scrollView.contentView.bounds.origin.y * ratio * self.scrollView.magnification)));
	
	[self.scrollView.documentView scrollPoint:offset];
	
	
	ratio = (minimapTextHeight - self.selectionView.bounds.size.height) / adjustedEditorContentHeight;
	selectionViewFrame.origin.y = self.editor.scrollView.contentView.bounds.origin.y * ratio;
	
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
	NSRange lineRange = [self.textView.string lineRangeForRange:NSMakeRange(characterIndex, 0)];
	NSRange activeRange = [self.textView.layoutManager glyphRangeForCharacterRange:lineRange actualCharacterRange:NULL];
	
	NSRect neededRect = [self.editorTextView.layoutManager boundingRectForGlyphRange:activeRange inTextContainer:self.editorTextView.textContainer];
	neededRect.origin.y = MAX(0, neededRect.origin.y - CGRectGetHeight(self.editor.containerView.bounds) / 2);
	
	BOOL shouldAnimateContentOffset = (theEvent.type != NSLeftMouseDragged);
	
	if(shouldAnimateContentOffset) {
		[NSAnimationContext beginGrouping];
		[[NSAnimationContext currentContext] setDuration:0.25f];
		[self.editor.scrollView.contentView.animator setBoundsOrigin:CGPointMake(0, neededRect.origin.y)];
		[self.editor.scrollView reflectScrolledClipView:self.editor.scrollView.contentView];
		[NSAnimationContext endGrouping];
	} else {
		[self.editor.scrollView.contentView setBoundsOrigin:CGPointMake(0, neededRect.origin.y)];
	}
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

#pragma mark - Sizing

- (void)updateSize
{
	CGFloat zoomLevel = [[[NSUserDefaults standardUserDefaults] objectForKey:SCXcodeMinimapZoomLevelKey] doubleValue];
	
	CGFloat minimapWidth = (self.hidden ? 0.0f : self.editor.containerView.bounds.size.width * zoomLevel);
	
	NSRect editorScrollViewFrame = self.editor.scrollView.frame;
	editorScrollViewFrame.size.width = self.editor.scrollView.superview.frame.size.width - minimapWidth;
	self.editor.scrollView.frame = editorScrollViewFrame;
	
	[self setFrame:NSMakeRect(CGRectGetMaxX(editorScrollViewFrame), 0, minimapWidth, CGRectGetHeight(self.editor.containerView.bounds))];
	
	CGRect frame = self.textView.bounds;
	frame.size.width = CGRectGetWidth(self.editorTextView.bounds);
	[self.textView setFrame:frame];

	CGFloat actualZoomLevel =  CGRectGetWidth(self.bounds) / CGRectGetWidth(self.editor.textView.bounds);
	[self.scrollView setMagnification:actualZoomLevel];
	
	[self updateOffset];
}

- (void)resizeWithOldSuperviewSize:(NSSize)oldSize
{
	[super resizeWithOldSuperviewSize:oldSize];
	
	self.shouldAllowFullSyntaxHighlight = NO;
	
	CGRect frame = self.textView.bounds;
	frame.size.width = CGRectGetWidth(self.editorTextView.bounds);
	[self.textView setFrame:frame];
	
	[self updateOffset];
}

#pragma mark - Helpers

- (void)invalidateDisplayForVisibleRange
{
	if(self.shouldUpdateBreakpoints) {
		[self updateBreakpoints];
	}
	
	self.shouldAllowFullSyntaxHighlight = YES;
	
	NSRange visibleMinimapRange = [self.textView visibleCharacterRange];
	[self.textView.layoutManager invalidateDisplayForCharacterRange:visibleMinimapRange];
	
	NSRange visibleEditorRange = [self.editorTextView visibleCharacterRange];
	[self.editorTextView.layoutManager invalidateDisplayForCharacterRange:visibleEditorRange];
}

- (void)invalidateLayoutForVisibleMinimapRange
{
	NSRange visibleMinimapRange = [self.textView visibleCharacterRange];
	[self.textView.layoutManager invalidateLayoutForCharacterRange:visibleMinimapRange actualCharacterRange:nil];
}

@end
