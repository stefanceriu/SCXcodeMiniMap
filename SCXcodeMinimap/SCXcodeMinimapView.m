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
#import "DVTLayoutManager+SCXcodeMinimap.h"

#import "DVTPointerArray.h"
#import "DVTSourceTextView.h"
#import "DVTSourceNodeTypes.h"

#import "SCXcodeMinimapTheme.h"
#import "DVTPreferenceSetManager.h"

#import "DVTFoldingManager.h"

#import "DVTAnnotationManager.h"
#import "DBGBreakpointAnnotationProvider+SCXcodeMinimap.h"
#import "DBGBreakpointAnnotation+SCXcodeMinimap.h"
#import "DBGBreakpointAnnotation.h"

#import "IDEIssueAnnotationProvider+SCXcodeMinimap.h"
#import "IDEBuildIssueErrorAnnotation.h"
#import "IDEBuildIssueWarningAnnotation.h"

#import "NSScroller+SCXcodeMinimap.h"

typedef NS_ENUM(NSUInteger, SCXcodeMinimapAnnotationType) {
	SCXcodeMinimapAnnotationTypeUndefined,
	SCXcodeMinimapAnnotationTypeTypeWarning,
	SCXcodeMinimapAnnotationTypeTypeError,
	SCXcodeMinimapAnnotationTypeBreakpoint,
	SCXcodeMinimapAnnotationTypeHighlightToken,
};

const CGFloat kDurationBetweenInvalidations = 0.5f;

static NSString * const kXcodeSyntaxCommentNodeName = @"xcode.syntax.comment";
static NSString * const kXcodeSyntaxCommentDocNodeName = @"xcode.syntax.comment.doc";
static NSString * const kXcodeSyntaxCommentDocKeywordNodeName = @"xcode.syntax.comment.doc.keyword";
static NSString * const kXcodeSyntaxPreprocessorNodeName = @"xcode.syntax.preprocessor";

static NSString * const IDEEditorDocumentDidChangeNotification = @"IDEEditorDocumentDidChangeNotification";
static NSString * const IDESourceCodeEditorTextViewBoundsDidChangeNotification = @"IDESourceCodeEditorTextViewBoundsDidChangeNotification";
static NSString * const DVTFontAndColorSourceTextSettingsChangedNotification = @"DVTFontAndColorSourceTextSettingsChangedNotification";

static NSString * const kAnnotationRangeKey = @"kAnnotationRangeKey";
static NSString * const kAnnotationEnabledKey = @"kAnnotationEnabledKey";
static NSString * const kAnnotationTypeKey = @"kAnnotationTypeKey";


@interface SCXcodeMinimapView () < NSLayoutManagerDelegate,
                                   DVTFoldingManagerDelegate,
                                   DBGBreakpointAnnotationProviderDelegate,
                                   IDEIssueAnnotationProviderDelegate,
                                   DVTLayoutManagerMinimapDelegate >

@property (nonatomic, weak) IDESourceCodeEditor *editor;
@property (nonatomic, strong) DVTSourceTextView *editorTextView;

@property (nonatomic, strong) SCXcodeMinimapScrollView *scrollView;
@property (nonatomic, strong) DVTSourceTextView *textView;
@property (nonatomic, strong) SCXcodeMinimapSelectionView *selectionView;
@property (nonatomic, strong) IDESourceCodeDocument *document;

@property (nonatomic, strong) SCXcodeMinimapTheme *minimapTheme;
@property (nonatomic, strong) SCXcodeMinimapTheme *editorTheme;

@property (nonatomic, assign) BOOL shouldAllowFullSyntaxHighlight;

@property (nonatomic, weak) DBGBreakpointAnnotationProvider *breakpointAnnotationProvider;
@property (nonatomic, weak) IDEIssueAnnotationProvider *issueAnnotationProvider;

@property (nonatomic, assign) BOOL shouldUpdateBreakpointsAndIssues;

@property (nonatomic, strong) NSMutableArray *breakpointsDictionaries;
@property (nonatomic, strong) NSMutableArray *issuesDictionaries;
@property (nonatomic, strong) NSMutableArray *highlightedSymbolDictionaries;

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
	[self.issueAnnotationProvider setMinimapDelegate:nil];
}

- (instancetype)initWithEditor:(IDESourceCodeEditor *)editor
{
	if (self = [super init]) {
		
		self.editor = editor;
		
		self.editorTextView = editor.textView;
		
		[self setWantsLayer:YES];
		[self setAutoresizingMask:NSViewMinXMargin | NSViewMinYMargin | NSViewWidthSizable | NSViewHeightSizable];
		
		self.scrollView = [[SCXcodeMinimapScrollView alloc] initWithFrame:self.bounds editorScrollView:self.editor.scrollView];
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
		
		// The editor's layout manager needs to be the last one, otherwise live issues don't work
		NSTextStorage *storage = self.editorTextView.textStorage;
		[storage removeLayoutManager:self.editorTextView.layoutManager];
		[self.textView setTextStorage:storage];
		[storage addLayoutManager:self.editorTextView.layoutManager];
		
		[self.editorTextView.foldingManager setDelegate:self];
		
		[self.textView setEditable:NO];
		[self.textView setSelectable:NO];
		
		[self.scrollView setDocumentView:self.textView];
		
		self.selectionView = [[SCXcodeMinimapSelectionView alloc] init];
		[self.textView addSubview:self.selectionView];
		
		[self updateTheme];
		
		
		for(NSDictionary *providerDictionary in self.editorTextView.annotationManager.annotationProviders) {
			
			id annotationProvider = providerDictionary[@"annotationProviderObject"];
			if([annotationProvider isKindOfClass:[DBGBreakpointAnnotationProvider class]]) {
				self.breakpointAnnotationProvider = annotationProvider;
				[self.breakpointAnnotationProvider setMinimapDelegate:self];
			} else if([annotationProvider isKindOfClass:[IDEIssueAnnotationProvider class]]) {
				self.issueAnnotationProvider = annotationProvider;
				[self.issueAnnotationProvider setMinimapDelegate:self];
			}
		}
		
		BOOL shouldHighlightBreakpoints = [[[NSUserDefaults standardUserDefaults] objectForKey:SCXcodeMinimapShouldHighlightBreakpointsKey] boolValue];
		BOOL shouldHighlightIssues = [[[NSUserDefaults standardUserDefaults] objectForKey:SCXcodeMinimapShouldHighlightIssuesKey] boolValue];
		if(shouldHighlightBreakpoints || shouldHighlightIssues) {
			[self invalidateBreakpointsAndIssues];
		}
		
		BOOL shouldHighlightSelectedSymbol = [[[NSUserDefaults standardUserDefaults] objectForKey:SCXcodeMinimapShouldHighlightIssuesKey] boolValue];
		if(shouldHighlightSelectedSymbol) {
			[self invalidateHighligtedSymbols];
		}
		
		BOOL shouldHideVerticalScroller = [[[NSUserDefaults standardUserDefaults] objectForKey:SCXcodeMinimapShouldHideEditorScrollerKey] boolValue];
		[self.editor.scrollView.verticalScroller setForcedHidden:shouldHideVerticalScroller];
		
		// Notifications
		
		self.notificationObservers = [NSMutableArray array];
		
		__weak typeof(self) weakSelf = self;
		[self.notificationObservers addObject:[[NSNotificationCenter defaultCenter] addObserverForName:SCXcodeMinimapShouldDisplayChangeNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
			[weakSelf setVisible:[[[NSUserDefaults standardUserDefaults] objectForKey:SCXcodeMinimapShouldDisplayKey] boolValue]];
		}]];
		
		[self.notificationObservers addObject:[[NSNotificationCenter defaultCenter] addObserverForName:SCXcodeMinimapZoomLevelChangeNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
			[weakSelf updateSize];
			[weakSelf delayedInvalidateDisplayForVisibleRange];
		}]];
		
		[self.notificationObservers addObject:[[NSNotificationCenter defaultCenter] addObserverForName:SCXcodeMinimapHighlightBreakpointsChangeNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
			[weakSelf invalidateBreakpointsAndIssues];
		}]];
		
		[self.notificationObservers addObject:[[NSNotificationCenter defaultCenter] addObserverForName:SCXcodeMinimapHighlightIssuesChangeNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
			[weakSelf invalidateBreakpointsAndIssues];
		}]];
		
		[self.notificationObservers addObject:[[NSNotificationCenter defaultCenter] addObserverForName:SCXcodeMinimapHighlightSelectedSymbolChangeNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
			[weakSelf invalidateHighligtedSymbols];
		}]];
		
		[self.notificationObservers addObject:[[NSNotificationCenter defaultCenter] addObserverForName:SCXcodeMinimapHighlightCommentsChangeNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
			[weakSelf delayedInvalidateDisplayForVisibleRange];
		}]];
		
		[self.notificationObservers addObject:[[NSNotificationCenter defaultCenter] addObserverForName:SCXcodeMinimapHighlightPreprocessorChangeNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
			[weakSelf delayedInvalidateDisplayForVisibleRange];
		}]];
		
		[self.notificationObservers addObject:[[NSNotificationCenter defaultCenter] addObserverForName:SCXcodeMinimapHighlightEditorChangeNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
			
			BOOL editorHighlightingEnabled = [[[NSUserDefaults standardUserDefaults] objectForKey:SCXcodeMinimapShouldHighlightEditorKey] boolValue];
			if(editorHighlightingEnabled) {
				[weakSelf.editorTextView.layoutManager setDelegate:weakSelf];
			} else {
				[weakSelf.editorTextView.layoutManager setDelegate:(id<NSLayoutManagerDelegate>)weakSelf.editorTextView];
			}
			
			[weakSelf delayedInvalidateDisplayForVisibleRange];
		}]];
		
		[self.notificationObservers addObject:[[NSNotificationCenter defaultCenter] addObserverForName:SCXcodeMinimapHideEditorScrollerChangeNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
			BOOL shouldHideVerticalScroller = [[[NSUserDefaults standardUserDefaults] objectForKey:SCXcodeMinimapShouldHideEditorScrollerKey] boolValue];
			[weakSelf.editor.scrollView.verticalScroller setForcedHidden:shouldHideVerticalScroller];
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
	
	dispatch_async(dispatch_get_main_queue(), ^{
		[self setVisible:[[[NSUserDefaults standardUserDefaults] objectForKey:SCXcodeMinimapShouldDisplayKey] boolValue]];
	});
}

#pragma mark - Show/Hide

- (void)setVisible:(BOOL)visible
{
	self.hidden  = !visible;
	
	[self updateSize];
	
	[self.textView.layoutManager setDelegate:(self.hidden ? nil : self)];
	[self.textView.layoutManager setBackgroundLayoutEnabled:YES];
	[self.textView.layoutManager setAllowsNonContiguousLayout:YES];
	
	DVTLayoutManager *editorLayoutManager = (DVTLayoutManager *)self.editorTextView.layoutManager;
	[editorLayoutManager setMinimapDelegate:self];
	
	BOOL editorHighlightingEnabled = [[[NSUserDefaults standardUserDefaults] objectForKey:SCXcodeMinimapShouldHighlightEditorKey] boolValue];
	if(editorHighlightingEnabled) {
		[editorLayoutManager setDelegate:self];
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
		[self delayedInvalidateDisplayForVisibleRange];
		return @{NSForegroundColorAttributeName : theme.sourcePlainTextColor};
	}
	
	if(self.shouldAllowFullSyntaxHighlight) {
		
		if(self.highlightedSymbolDictionaries.count) {
			for(NSDictionary *highlightSymbolDictionary in self.highlightedSymbolDictionaries) {
				NSRange range = [highlightSymbolDictionary[kAnnotationRangeKey] rangeValue];
				
				if(NSIntersectionRange(range, NSMakeRange(charIndex, 1)).length) {
					*effectiveCharRange = range;
					return @{NSForegroundColorAttributeName : theme.sourceTextBackgroundColor,
							 NSBackgroundColorAttributeName : theme.highlightedSymbolBackgroundColor};
				}
			}
		}
		
		if(self.breakpointsDictionaries.count) {
			for(NSDictionary *breakpointDictionary in self.breakpointsDictionaries) {
				NSRange range = [breakpointDictionary[kAnnotationRangeKey] rangeValue];
				BOOL enabled = [breakpointDictionary[kAnnotationEnabledKey] boolValue];
				
				if(NSIntersectionRange(range, NSMakeRange(charIndex, 1)).length) {
					*effectiveCharRange = range;
					return @{NSForegroundColorAttributeName : theme.sourceTextBackgroundColor,
							 NSBackgroundColorAttributeName : (enabled ? theme.enabledBreakpointColor : theme.disabledBreakpointColor)};
				}
			}
		}
		
		if(self.issuesDictionaries.count) {
			for(NSDictionary *issueDictionary in self.issuesDictionaries) {
				NSRange range = [issueDictionary[kAnnotationRangeKey] rangeValue];
				SCXcodeMinimapAnnotationType annotationType = [issueDictionary[kAnnotationTypeKey] unsignedIntegerValue];
				
				NSColor *backgroundColor = [NSColor greenColor];
				if(annotationType == SCXcodeMinimapAnnotationTypeTypeError) {
					backgroundColor = self.minimapTheme.buildIssueErrorBackgroundColor;
				} else if(annotationType == SCXcodeMinimapAnnotationTypeTypeWarning) {
					backgroundColor = self.minimapTheme.buildIssueWarningBackgroundColor;
				}
				
				if(NSIntersectionRange(range, NSMakeRange(charIndex, 1)).length) {
					*effectiveCharRange = range;
					return @{NSForegroundColorAttributeName : theme.sourceTextBackgroundColor,
							 NSBackgroundColorAttributeName : backgroundColor};
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
	
	[self.textView.layoutManager ensureLayoutForTextContainer:self.textView.textContainer];
	[self updateOffset];
}

- (void)foldingManager:(DVTFoldingManager *)foldingManager didUnfoldRange:(NSRange)range
{
	[(DVTLayoutManager *)self.editorTextView.layoutManager foldingManager:foldingManager didUnfoldRange:range];
	
	[self.textView.foldingManager unfoldRange:range];
	
	[self.textView.layoutManager ensureLayoutForTextContainer:self.textView.textContainer];
	[self updateOffset];
}

#pragma mark - DBGBreakpointAnnotationProviderDelegate

- (void)breakpointAnnotationProviderDidChangeBreakpoints:(DBGBreakpointAnnotationProvider *)annotationProvider
{
	[self invalidateBreakpointsAndIssues];
}

#pragma mark - IDEIssueAnnotationProviderDelegate

- (void)issueAnnotationProviderDidChangeIssues:(IDEIssueAnnotationProvider *)annotationProvider
{
	[self invalidateBreakpointsAndIssues];
}

#pragma mark - DVTLayoutManagerMinimapDelegate

- (void)layoutManagerDidRequestSelectedSymbolInstancesHighlight:(DVTLayoutManager *)layoutManager
{
	[self invalidateHighligtedSymbols];
}

#pragma mark - Annotations

- (void)updateBreakpointsAndIssuesWithCompletion:(void(^)())completion
{
	self.breakpointsDictionaries = [NSMutableArray array];
	self.issuesDictionaries = [NSMutableArray array];
	
	BOOL canHighlightBreakpoints = [[[NSUserDefaults standardUserDefaults] objectForKey:SCXcodeMinimapShouldHighlightBreakpointsKey] boolValue];
	BOOL canHighlightIssues = [[[NSUserDefaults standardUserDefaults] objectForKey:SCXcodeMinimapShouldHighlightIssuesKey] boolValue];
	
	if(!canHighlightBreakpoints && !canHighlightIssues) {
		if(completion) {
			completion();
		}
		return;
	}
	
	__weak typeof(self) weakSelf = self;
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
		for (NSUInteger index = 0, lineNumber = 0; index < self.textView.string.length; lineNumber++) {
			
			NSRange lineRange = [weakSelf.textView.string lineRangeForRange:NSMakeRange(index, 0)];
			
			if(canHighlightBreakpoints) {
				for(DBGBreakpointAnnotation *breakpointAnnotation in weakSelf.breakpointAnnotationProvider.annotations) {
					if(breakpointAnnotation.paragraphRange.location == lineNumber) {
						[weakSelf.breakpointsDictionaries addObject:@{kAnnotationRangeKey : [NSValue valueWithRange:lineRange],
																	  kAnnotationEnabledKey : @(breakpointAnnotation.enabled),
																	  kAnnotationTypeKey : @(SCXcodeMinimapAnnotationTypeBreakpoint)}];
					}
				}
			}
			
			if(canHighlightIssues) {
				for(IDEBuildIssueAnnotation *issueAnnotation in weakSelf.issueAnnotationProvider.annotations) {
					if(issueAnnotation.paragraphRange.location == lineNumber) {
						
						SCXcodeMinimapAnnotationType annotationType = SCXcodeMinimapAnnotationTypeUndefined;
						if([issueAnnotation isKindOfClass:[IDEBuildIssueErrorAnnotation class]]) {
							annotationType = SCXcodeMinimapAnnotationTypeTypeError;
						} else if([issueAnnotation isKindOfClass:[IDEBuildIssueWarningAnnotation class]]) {
							annotationType = SCXcodeMinimapAnnotationTypeTypeWarning;
						}
						
						[weakSelf.issuesDictionaries addObject:@{kAnnotationRangeKey : [NSValue valueWithRange:lineRange],
																 kAnnotationTypeKey : @(annotationType)}];
					}
				}
			}
			
			index = NSMaxRange(lineRange);
		}
		
		dispatch_async(dispatch_get_main_queue(), ^{
			if(completion) {
				completion();
			}
		});
	});
}

- (void)updateHighlightedSymbols
{
	BOOL canHighlightSelectedSymbol = [[[NSUserDefaults standardUserDefaults] objectForKey:SCXcodeMinimapShouldHighlightSelectedSymbolKey] boolValue];
	
	self.highlightedSymbolDictionaries = [NSMutableArray array];
	
	if(canHighlightSelectedSymbol) {
		DVTLayoutManager *layoutManager = (DVTLayoutManager *)self.editorTextView.layoutManager;
		if(![layoutManager respondsToSelector:@selector(autoHighlightTokenRanges)]) {
			return;
		}
		
		[layoutManager.autoHighlightTokenRanges enumerateObjectsUsingBlock:^(NSValue *rangeValue, NSUInteger idx, BOOL *stop) {
			[self.highlightedSymbolDictionaries addObject:@{kAnnotationRangeKey : rangeValue,
															kAnnotationTypeKey : @(SCXcodeMinimapAnnotationTypeHighlightToken)}];
		}];
	}
}

#pragma mark - Navigation

- (void)updateOffset
{
	if (self.isHidden) {
		return;
	}
	
	[self.editorTextView.layoutManager ensureLayoutForTextContainer:self.editorTextView.textContainer];
	
	CGFloat editorTextHeight = CGRectGetHeight([self.editorTextView.layoutManager usedRectForTextContainer:self.editorTextView.textContainer]);
	CGFloat adjustedEditorContentHeight = editorTextHeight - CGRectGetHeight(self.editor.scrollView.bounds);
	CGFloat adjustedMinimapContentHeight = editorTextHeight - (CGRectGetHeight(self.scrollView.bounds) * (1 / self.scrollView.magnification));
	
	NSRect selectionViewFrame = NSMakeRect(0, 0, self.textView.bounds.size.width * (1 / self.scrollView.magnification), self.editor.scrollView.visibleRect.size.height);
	
	if(adjustedEditorContentHeight == 0.0f) {
		[self.selectionView setFrame:selectionViewFrame];
		return;
	}
	
	CGFloat editorYOffset = CGRectGetMinY(self.editor.scrollView.contentView.bounds) + ABS(CGRectGetMinY(self.editorTextView.frame));
	
	CGFloat ratio = (adjustedMinimapContentHeight / adjustedEditorContentHeight) * (1 / self.scrollView.magnification);
	[self.scrollView.documentView scrollPoint:NSMakePoint(self.editor.scrollView.contentView.bounds.origin.x,
														  MAX(0, floorf(editorYOffset * ratio * self.scrollView.magnification)))];
	
	ratio = (editorTextHeight - self.selectionView.bounds.size.height) / adjustedEditorContentHeight;
	selectionViewFrame.origin.y = editorYOffset * ratio;
	
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
	neededRect.origin.y += CGRectGetMinY(self.editorTextView.frame);
	
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
	self.editorTheme = [SCXcodeMinimapTheme minimapThemeWithTheme:[DVTFontAndColorTheme currentTheme]];
	
	DVTPreferenceSetManager *preferenceSetManager = [DVTFontAndColorTheme preferenceSetsManager];
	NSArray *preferenceSet = [preferenceSetManager availablePreferenceSets];
	
	NSString *themeName = [[NSUserDefaults standardUserDefaults] objectForKey:SCXcodeMinimapThemeKey];
	NSUInteger themeIndex = [preferenceSet indexesOfObjectsPassingTest:^BOOL(DVTFontAndColorTheme *theme, NSUInteger idx, BOOL *stop) {
		return [theme.localizedName isEqualTo:themeName];
	}].lastIndex;
	
	if(themeIndex == NSNotFound) {
		self.minimapTheme = self.editorTheme;
	} else {
		self.minimapTheme = [SCXcodeMinimapTheme minimapThemeWithTheme:preferenceSet[themeIndex]];
	}
	
	[self.scrollView setBackgroundColor:self.minimapTheme.backgroundColor];
	[self.textView setBackgroundColor:self.minimapTheme.backgroundColor];
	
	[self.selectionView setSelectionColor:self.minimapTheme.selectionColor];
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
	
	if(self.editorTextView.textStorage.editedMask) {
		return;
	}
	
	self.shouldAllowFullSyntaxHighlight = NO;
	
	CGRect frame = self.textView.bounds;
	frame.size.width = CGRectGetWidth(self.editorTextView.bounds);
	[self.textView setFrame:frame];
	
	[self updateOffset];
}

#pragma mark - Helpers

- (void)invalidateBreakpointsAndIssues
{
	self.shouldUpdateBreakpointsAndIssues = YES;
	[self delayedInvalidateDisplayForVisibleRange];
}

- (void)invalidateHighligtedSymbols
{
	[self updateHighlightedSymbols];
	[self delayedInvalidateDisplayForVisibleRange];
}

- (void)delayedInvalidateDisplayForVisibleRange
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(invalidateDisplayForVisibleRange) object:nil];
	[self performSelector:@selector(invalidateDisplayForVisibleRange) withObject:nil afterDelay:kDurationBetweenInvalidations];
}

- (void)invalidateDisplayForVisibleRange
{
	void (^performVisibleRangeInvalidation)() = ^{
		self.shouldAllowFullSyntaxHighlight = YES;
		
		NSRange visibleMinimapRange = [self.textView visibleCharacterRange];
		[self.textView.layoutManager invalidateDisplayForCharacterRange:visibleMinimapRange];
		
		NSRange visibleEditorRange = [self.editorTextView visibleCharacterRange];
		[self.editorTextView.layoutManager invalidateDisplayForCharacterRange:visibleEditorRange];
	};
	
	if(self.shouldUpdateBreakpointsAndIssues) {
		self.shouldUpdateBreakpointsAndIssues = NO;
		[self updateBreakpointsAndIssuesWithCompletion:^{
			performVisibleRangeInvalidation();
		}];
	} else {
		performVisibleRangeInvalidation();
	}
}

@end
