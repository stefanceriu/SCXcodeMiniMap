//
//  SCXcodeMinimap.m
//  SCXcodeMinimap
//
//  Created by Stefan Ceriu on 3/30/13.
//  Copyright (c) 2013 Stefan Ceriu. All rights reserved
//

#import "SCXcodeMinimap.h"
#import "SCXcodeMinimapView.h"
#import <objc/runtime.h>

#import "IDESourceCodeEditor.h"
#import "DVTSourceTextView.h"

const CGFloat kDefaultZoomLevel = 0.15f;

static NSString * const IDESourceCodeEditorDidFinishSetupNotification = @"IDESourceCodeEditorDidFinishSetup";

NSString * const SCXodeMinimapShowNotification = @"SCXodeMinimapShowNotification";
NSString * const SCXodeMinimapHideNotification = @"SCXodeMinimapHideNotification";

NSString * const SCXodeMinimapIsInitiallyHidden  = @"SCXodeMinimapIsInitiallyHidden";

@implementation SCXcodeMinimap

+ (void)pluginDidLoad:(NSBundle *)plugin
{
	static SCXcodeMinimap *sharedMinimap = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedMinimap = [[self alloc] init];
	});
}

- (id)init
{
	if (self = [super init]) {
		
		[self createMenuItem];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onDidFinishSetup:) name:IDESourceCodeEditorDidFinishSetupNotification object:nil];
	}
	return self;
}

#pragma mark - Menu Items and Actions

- (void)createMenuItem
{
	NSMenuItem *editMenuItem = [[NSApp mainMenu] itemWithTitle:@"View"];
	
	if(editMenuItem == nil) {
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
	
	[sender setTitle:@"Show Minimap"];
	[sender setAction:@selector(showMiniMap:)];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:SCXodeMinimapHideNotification object:nil];
}

- (void)showMiniMap:(NSMenuItem *)sender
{
	[[NSUserDefaults standardUserDefaults] setBool:NO forKey:SCXodeMinimapIsInitiallyHidden];
	
	[sender setTitle:@"Hide Minimap"];
	[sender setAction:@selector(hideMiniMap:)];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:SCXodeMinimapShowNotification object:nil];
}

#pragma mark - Xcode Notification

- (void)onDidFinishSetup:(NSNotification*)sender
{
	if(![sender.object isKindOfClass:[IDESourceCodeEditor class]]) {
		NSLog(@"Could not fetch source code editor container");
		return;
	}
	
	IDESourceCodeEditor *editor = (IDESourceCodeEditor *)[sender object];
	[editor.textView setAutoresizingMask:NSViewMinXMargin | NSViewMaxXMargin | NSViewWidthSizable | NSViewHeightSizable];
	
	CGFloat width = editor.textView.bounds.size.width * kDefaultZoomLevel;
	NSRect miniMapScrollViewFrame = NSMakeRect(editor.containerView.bounds.size.width - width, 0, width, editor.scrollView.bounds.size.height);
	
	SCXcodeMinimapView *miniMapView = [[SCXcodeMinimapView alloc] initWithFrame:miniMapScrollViewFrame editor:editor];
	[editor.containerView addSubview:miniMapView];
	
	[miniMapView setVisible:![[NSUserDefaults standardUserDefaults] boolForKey:SCXodeMinimapIsInitiallyHidden]];
}

@end
