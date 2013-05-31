//
//  SCXcodeMinimap.m
//  SCXcodeMinimap
//
//  Created by Stefan Ceriu on 3/30/13.
//  Copyright (c) 2013 Stefan Ceriu. All rights reserved
//

#import "SCMiniMapView.h"
#import "SCXcodeMinimap.h"
#import <objc/runtime.h>

static char kKeyMiniMapView;

static NSString * const IDESourceCodeEditorDidFinishSetupNotification = @"IDESourceCodeEditorDidFinishSetup";
static NSString * const IDEEditorDocumentDidChangeNotification = @"IDEEditorDocumentDidChangeNotification";
static NSString * const IDESourceCodeEditorTextViewBoundsDidChangeNotification = @"IDESourceCodeEditorTextViewBoundsDidChangeNotification";

NSString * const SCXodeMinimapWantsToBeShownNotification = @"SCXodeMinimapWantsToBeShownNotification";
NSString * const SCXodeMinimapWantsToBeHiddenNotification = @"SCXodeMinimapWantsToBeHiddenNotification";

NSString * const SCXodeMinimapIsInitiallyHidden  = @"SCXodeMinimapIsInitiallyHidden";

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
        
        [self createMenuItem];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onDidFinishSetup:) name:IDESourceCodeEditorDidFinishSetupNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onDocumentDidChange:) name:IDEEditorDocumentDidChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onCodeEditorBoundsChange:) name:IDESourceCodeEditorTextViewBoundsDidChangeNotification object:nil];
    }
	return self;
}

- (void)createMenuItem
{
    NSMenuItem *editMenuItem = [[NSApp mainMenu] itemWithTitle:@"View"];
    
    if(editMenuItem == nil) {
        NSLog(@"Could not fetch 'View' main menu item");
        return;
    }
    
    NSMenuItem *miniMapItem = [[NSMenuItem alloc] initWithTitle:@""
                                                               action:NULL
                                                        keyEquivalent:@"M"];
    [miniMapItem setKeyEquivalentModifierMask:NSControlKeyMask | NSShiftKeyMask];
    
    miniMapItem.target = self;
    
    [editMenuItem.submenu insertItem:[NSMenuItem separatorItem]
                               atIndex:[editMenuItem.submenu numberOfItems]];
    [editMenuItem.submenu insertItem:miniMapItem
                               atIndex:[editMenuItem.submenu numberOfItems]];
    
    [miniMapItem release];

    if ([[NSUserDefaults standardUserDefaults] boolForKey:SCXodeMinimapIsInitiallyHidden]) {
        [self hideMiniMap:miniMapItem];
    }
    else {
        [self showMiniMap:miniMapItem];
    }
}

- (void)hideMiniMap:(NSMenuItem *)sender
{
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:SCXodeMinimapIsInitiallyHidden];

    [sender setTitle:@"Show MiniMap"];
    [sender setAction:@selector(showMiniMap:)];

    [[NSNotificationCenter defaultCenter] postNotificationName:SCXodeMinimapWantsToBeHiddenNotification object:nil];
}

- (void)showMiniMap:(NSMenuItem *)sender
{
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:SCXodeMinimapIsInitiallyHidden];

    [sender setTitle:@"Hide MiniMap"];
    [sender setAction:@selector(hideMiniMap:)];

    [[NSNotificationCenter defaultCenter] postNotificationName:SCXodeMinimapWantsToBeShownNotification object:nil];
}

- (void)onDocumentDidChange:(NSNotification*)sender
{
    SCMiniMapView *miniMapView = objc_getAssociatedObject([sender object], &kKeyMiniMapView);
    [miniMapView updateTextView];
}

- (void)onCodeEditorBoundsChange:(NSNotification*)sender
{
    if(![sender.object respondsToSelector:@selector(scrollView)]) {
        NSLog(@"Could not fetch scroll view");
        return;
    }
    NSScrollView *editorScrollView = [sender.object performSelector:@selector(scrollView)];
    SCMiniMapView *miniMapView = objc_getAssociatedObject(editorScrollView, &kKeyMiniMapView);
    [miniMapView updateSelectionView];
}

- (void)onDidFinishSetup:(NSNotification*)sender
{
    if(![[sender object] respondsToSelector:@selector(containerView)]) {
        NSLog(@"Could not fetch editor container view");
        return;
    }
    if(![[sender object] respondsToSelector:@selector(scrollView)]) {
        NSLog(@"Could not fetch editor scroll view");
        return;
    }
    if(![[sender object] respondsToSelector:@selector(textView)]) {
        NSLog(@"Could not fetch editor text view");
        return;
    }
    if(![[sender object] respondsToSelector:@selector(sourceCodeDocument)]) {
        NSLog(@"Could not fetch editor document");
        return;
    }

    /* Get Editor Components */
    NSDocument *editorDocument      = [[sender object] performSelector:@selector(sourceCodeDocument)];
    NSView *editorContainerView     = [[sender object] performSelector:@selector(containerView)];
    NSScrollView *editorScrollView  = [[sender object] performSelector:@selector(scrollView)];
    NSTextView *editorTextView      = [[sender object] performSelector:@selector(textView)];
    
    [editorTextView setAutoresizingMask:NSViewMinXMargin | NSViewMaxXMargin | NSViewWidthSizable | NSViewHeightSizable];

    /* Create Mini Map */
    CGFloat width = editorTextView.bounds.size.width * kDefaultZoomLevel;
    
    NSRect miniMapScrollViewFrame = NSMakeRect(editorContainerView.bounds.size.width - width - kRightSidePadding,
                                               0,
                                               width,
                                               editorScrollView.bounds.size.height);

    SCMiniMapView *miniMapView = [[SCMiniMapView alloc] initWithFrame:miniMapScrollViewFrame];
    miniMapView.editorScrollView = editorScrollView;
    miniMapView.editorTextView = editorTextView;
    [editorContainerView addSubview:miniMapView];

    /* Setup Associated Objects */
    objc_setAssociatedObject(editorScrollView,  &kKeyMiniMapView, miniMapView, OBJC_ASSOCIATION_ASSIGN);
    objc_setAssociatedObject(editorDocument,    &kKeyMiniMapView, miniMapView, OBJC_ASSOCIATION_ASSIGN);

    if ([[NSUserDefaults standardUserDefaults] boolForKey:SCXodeMinimapIsInitiallyHidden]) {
        [miniMapView hide];
    }
    else {
        [miniMapView show];
    }

    [miniMapView release];
}

@end