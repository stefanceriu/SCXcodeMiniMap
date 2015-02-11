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

#import "DVTPreferenceSetManager.h"
#import "DVTFontAndColorTheme.h"

const CGFloat kDefaultZoomLevel = 0.1f;

NSString *const IDESourceCodeEditorDidFinishSetupNotification = @"IDESourceCodeEditorDidFinishSetup";

NSString *const SCXodeMinimapShowNotification = @"SCXodeMinimapShowNotification";
NSString *const SCXodeMinimapHideNotification = @"SCXodeMinimapHideNotification";

NSString *const SCXodeMinimapThemeChangeNotification = @"SCXodeMinimapThemeChangeNotification";

NSString *const SCXodeMinimapIsInitiallyHidden  = @"SCXodeMinimapIsInitiallyHidden";
NSString *const SCXodeMinimapTheme  = @"SCXodeMinimapTheme";

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
	
	[editMenuItem.submenu addItem:[NSMenuItem separatorItem]];
	
	NSMenuItem *minimapMenuItem = [[NSMenuItem alloc] initWithTitle:@"Minimap" action:nil keyEquivalent:@""];
	[editMenuItem.submenu addItem:minimapMenuItem];
	
	NSMenu *minimapMenu = [[NSMenu alloc] init];
	{
		NSMenuItem *showHideMinimapItem = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@"M"];
		[showHideMinimapItem setKeyEquivalentModifierMask:NSControlKeyMask | NSShiftKeyMask];
		[showHideMinimapItem setTarget:self];
		[minimapMenu addItem:showHideMinimapItem];
		
		if ([[NSUserDefaults standardUserDefaults] boolForKey:SCXodeMinimapIsInitiallyHidden]) {
			[self hideMiniMap:showHideMinimapItem];
		}
		else {
			[self showMiniMap:showHideMinimapItem];
		}
		
		[minimapMenu addItem:[NSMenuItem separatorItem]];
	}
	
	{
		NSMenuItem *themesMenuItem = [[NSMenuItem alloc] initWithTitle:@"Theme" action:nil keyEquivalent:@""];
		[minimapMenu addItem:themesMenuItem];
		
		NSMenu *themesMenu = [[NSMenu alloc] init];
		{
			NSMenuItem *editorThemeMenuItem = [[NSMenuItem alloc] initWithTitle:@"Editor Theme" action:@selector(setMinimapTheme:) keyEquivalent:@""];
			[editorThemeMenuItem setTarget:self];
			[themesMenu addItem:editorThemeMenuItem];
			
			[themesMenu addItem:[NSMenuItem separatorItem]];
			
			NSArray *themes = [[DVTFontAndColorTheme preferenceSetsManager] availablePreferenceSets];
			NSArray *builtInThemes = [themes filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.isBuiltIn == YES"]];
			NSArray *userThemes = [themes filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.isBuiltIn == NO"]];
			
			for(DVTFontAndColorTheme *theme in builtInThemes) {
				NSMenuItem *themeMenuItem = [[NSMenuItem alloc] initWithTitle:theme.localizedName action:@selector(setMinimapTheme:) keyEquivalent:@""];
				[themeMenuItem setTarget:self];
				[themesMenu addItem:themeMenuItem];
			}
			
			[themesMenu addItem:[NSMenuItem separatorItem]];
			
			for(DVTFontAndColorTheme *theme in userThemes) {
				NSMenuItem *themeMenuItem = [[NSMenuItem alloc] initWithTitle:theme.localizedName action:@selector(setMinimapTheme:) keyEquivalent:@""];
				[themeMenuItem setTarget:self];
				[themesMenu addItem:themeMenuItem];
			}
		}
		[themesMenuItem setSubmenu:themesMenu];
		
	}
	[minimapMenuItem setSubmenu:minimapMenu];
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

- (void)setMinimapTheme:(NSMenuItem *)sender
{
	if([sender.menu indexOfItem:sender] == 0) {
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:SCXodeMinimapTheme];
	} else {
		[[NSUserDefaults standardUserDefaults] setObject:sender.title forKey:SCXodeMinimapTheme];
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName:SCXodeMinimapThemeChangeNotification object:nil];
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
