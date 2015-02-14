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

NSString *const SCXcodeMinimapShouldDisplayChangeNotification = @"SCXcodeMinimapShouldDisplayChangeNotification";
NSString *const SCXcodeMinimapShouldDisplay = @"SCXcodeMinimapShouldDisplay";

NSString *const SCXcodeMinimapThemeChangeNotification = @"SCXcodeMinimapThemeChangeNotification";
NSString *const SCXcodeMinimapTheme  = @"SCXcodeMinimapTheme";

NSString *const SCXcodeMinimapHighlightCommentsChangeNotification = @"SCXcodeMinimapHighlightCommentsChangeNotification";
NSString *const SCXcodeMinimapShouldHighlightComments  = @"SCXcodeMinimapShouldHighlightComments";

NSString *const SCXcodeMinimapHighlightPreprocessorChangeNotification = @"SCXcodeMinimapHighlightPreprocessorChangeNotification";
NSString *const SCXcodeMinimapShouldHighlightPreprocessor  = @"SCXcodeMinimapShouldHighlightPreprocessor";

NSString *const SCXcodeMinimapHideEditorScrollerChangeNotification = @"SCXcodeMinimapHideEditorScrollerChangeNotification";
NSString *const SCXcodeMinimapShouldHideEditorScroller  = @"SCXcodeMinimapShouldHideEditorScroller";

NSString *const kViewMenuItemTitle = @"View";

NSString *const kMinimapMenuItemTitle = @"Minimap";
NSString *const kShowMinimapMenuItemTitle = @"Show Minimap";
NSString *const kHideMinimapMenuItemTitle = @"Hide Minimap";

NSString *const kHighlightCommentsMenuItemTitle = @"Highlight comments";
NSString *const kHighlightPreprocessorMenuItemTitle = @"Highlight preprocessor";
NSString *const kHideEditorScrollerMenuItemTitle = @"Hide editor scroller";

NSString *const kThemeMenuItemTitle = @"Theme";
NSString *const kEditorThemeMenuItemTitle = @"Editor Theme";

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
		
		[self registerUserDefaults];
		[self createMenuItem];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onDidFinishSetup:) name:IDESourceCodeEditorDidFinishSetupNotification object:nil];
	}
	return self;
}

- (void)registerUserDefaults
{
	NSDictionary *userDefaults = @{SCXcodeMinimapShouldDisplay : @(YES),
								   SCXcodeMinimapShouldHighlightComments : @(YES),
								   SCXcodeMinimapShouldHighlightPreprocessor :@(YES)};
	
	[[NSUserDefaults standardUserDefaults] registerDefaults:userDefaults];
}

#pragma mark - Menu Items and Actions

- (void)createMenuItem
{
	NSMenuItem *editMenuItem = [[NSApp mainMenu] itemWithTitle:kViewMenuItemTitle];
	
	if(editMenuItem == nil) {
		return;
	}
	
	[editMenuItem.submenu addItem:[NSMenuItem separatorItem]];
	
	NSMenuItem *minimapMenuItem = [[NSMenuItem alloc] initWithTitle:kMinimapMenuItemTitle action:nil keyEquivalent:@""];
	[editMenuItem.submenu addItem:minimapMenuItem];
	
	NSMenu *minimapMenu = [[NSMenu alloc] init];
	{
		NSMenuItem *showHideMinimapItem = [[NSMenuItem alloc] initWithTitle:@"" action:@selector(toggleMinimap:) keyEquivalent:@"M"];
		[showHideMinimapItem setKeyEquivalentModifierMask:NSControlKeyMask | NSShiftKeyMask];
		[showHideMinimapItem setTarget:self];
		[minimapMenu addItem:showHideMinimapItem];
		
		BOOL shouldDisplayMinimap = [[[NSUserDefaults standardUserDefaults] objectForKey:SCXcodeMinimapShouldDisplay] boolValue];
		[showHideMinimapItem setTitle:(shouldDisplayMinimap ? kHideMinimapMenuItemTitle : kShowMinimapMenuItemTitle)];
		
		[minimapMenu addItem:[NSMenuItem separatorItem]];
	}
	
	{
		NSMenuItem *highlightCommentsMenuItem = [[NSMenuItem alloc] initWithTitle:kHighlightCommentsMenuItemTitle
																		   action:@selector(toggleCommentsHighlighting:) keyEquivalent:@""];
		[highlightCommentsMenuItem setTarget:self];
		[minimapMenu addItem:highlightCommentsMenuItem];
		
		BOOL commentsHighlightingEnabled = [[[NSUserDefaults standardUserDefaults] objectForKey:SCXcodeMinimapShouldHighlightComments] boolValue];
		[highlightCommentsMenuItem setState:(commentsHighlightingEnabled ? NSOnState : NSOffState)];
		
		
		NSMenuItem *highlightPreprocessorMenuItem = [[NSMenuItem alloc] initWithTitle:kHighlightPreprocessorMenuItemTitle
																			   action:@selector(togglePreprocessorHighlighting:) keyEquivalent:@""];
		[highlightPreprocessorMenuItem setTarget:self];
		[minimapMenu addItem:highlightPreprocessorMenuItem];
		
		BOOL preprocessorHighlightingEnabled = [[[NSUserDefaults standardUserDefaults] objectForKey:SCXcodeMinimapShouldHighlightPreprocessor] boolValue];
		[highlightPreprocessorMenuItem setState:(preprocessorHighlightingEnabled ? NSOnState : NSOffState)];
		
		
		NSMenuItem *hideEditorScrollerMenuItem = [[NSMenuItem alloc] initWithTitle:kHideEditorScrollerMenuItemTitle
																			action:@selector(toggleEditorScrollerHiding:) keyEquivalent:@""];
		[hideEditorScrollerMenuItem setTarget:self];
		[minimapMenu addItem:hideEditorScrollerMenuItem];
		
		BOOL shouldHideEditorScroller = [[[NSUserDefaults standardUserDefaults] objectForKey:SCXcodeMinimapShouldHideEditorScroller] boolValue];
		[hideEditorScrollerMenuItem setState:(shouldHideEditorScroller ? NSOnState : NSOffState)];
		
		
		[minimapMenu addItem:[NSMenuItem separatorItem]];
	}
	
	{
		NSMenuItem *themesMenuItem = [[NSMenuItem alloc] initWithTitle:kThemeMenuItemTitle action:nil keyEquivalent:@""];
		[minimapMenu addItem:themesMenuItem];
		
		NSMenu *themesMenu = [[NSMenu alloc] init];
		{
			NSString *currentThemeName = [[NSUserDefaults standardUserDefaults] objectForKey:SCXcodeMinimapTheme];
			
			NSMenuItem *editorThemeMenuItem = [[NSMenuItem alloc] initWithTitle:kEditorThemeMenuItemTitle action:@selector(setMinimapTheme:) keyEquivalent:@""];
			[editorThemeMenuItem setTarget:self];
			[themesMenu addItem:editorThemeMenuItem];
			
			if(currentThemeName == nil) {
				[editorThemeMenuItem setState:NSOnState];
			}
			
			[themesMenu addItem:[NSMenuItem separatorItem]];
			
			NSArray *themes = [[DVTFontAndColorTheme preferenceSetsManager] availablePreferenceSets];
			NSArray *builtInThemes = [themes filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.isBuiltIn == YES"]];
			NSArray *userThemes = [themes filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.isBuiltIn == NO"]];
			
			for(DVTFontAndColorTheme *theme in builtInThemes) {
				NSMenuItem *themeMenuItem = [[NSMenuItem alloc] initWithTitle:theme.localizedName action:@selector(setMinimapTheme:) keyEquivalent:@""];
				[themeMenuItem setTarget:self];
				[themesMenu addItem:themeMenuItem];
				
				if([theme.localizedName isEqualToString:currentThemeName]) {
					[themeMenuItem setState:NSOnState];
				}
			}
			
			[themesMenu addItem:[NSMenuItem separatorItem]];
			
			for(DVTFontAndColorTheme *theme in userThemes) {
				NSMenuItem *themeMenuItem = [[NSMenuItem alloc] initWithTitle:theme.localizedName action:@selector(setMinimapTheme:) keyEquivalent:@""];
				[themeMenuItem setTarget:self];
				[themesMenu addItem:themeMenuItem];
				
				if([theme.localizedName isEqualToString:currentThemeName]) {
					[themeMenuItem setState:NSOnState];
				}
			}
		}
		[themesMenuItem setSubmenu:themesMenu];
		
	}
	[minimapMenuItem setSubmenu:minimapMenu];
}

- (void)toggleMinimap:(NSMenuItem *)sender
{
	BOOL shouldDisplayMinimap = [[[NSUserDefaults standardUserDefaults] objectForKey:SCXcodeMinimapShouldDisplay] boolValue];
	
	[sender setTitle:(shouldDisplayMinimap ? kHideMinimapMenuItemTitle : kShowMinimapMenuItemTitle)];
	[[NSUserDefaults standardUserDefaults] setObject:@(!shouldDisplayMinimap) forKey:SCXcodeMinimapShouldDisplay];
	[[NSNotificationCenter defaultCenter] postNotificationName:SCXcodeMinimapShouldDisplayChangeNotification object:nil];
}

- (void)toggleCommentsHighlighting:(NSMenuItem *)sender
{
	BOOL commentsHighlightingEnabled = [[[NSUserDefaults standardUserDefaults] objectForKey:SCXcodeMinimapShouldHighlightComments] boolValue];
	
	[sender setState:(commentsHighlightingEnabled ? NSOffState : NSOnState)];
	[[NSUserDefaults standardUserDefaults] setObject:@(!commentsHighlightingEnabled) forKey:SCXcodeMinimapShouldHighlightComments];
	[[NSNotificationCenter defaultCenter] postNotificationName:SCXcodeMinimapHighlightCommentsChangeNotification object:nil];
}

- (void)togglePreprocessorHighlighting:(NSMenuItem *)sender
{
	BOOL preprocessorHighlightingEnabled = [[[NSUserDefaults standardUserDefaults] objectForKey:SCXcodeMinimapShouldHighlightPreprocessor] boolValue];
	
	[sender setState:(preprocessorHighlightingEnabled ? NSOffState : NSOnState)];
	[[NSUserDefaults standardUserDefaults] setObject:@(!preprocessorHighlightingEnabled) forKey:SCXcodeMinimapShouldHighlightPreprocessor];
	[[NSNotificationCenter defaultCenter] postNotificationName:SCXcodeMinimapHighlightPreprocessorChangeNotification object:nil];
}

- (void)toggleEditorScrollerHiding:(NSMenuItem *)sender
{
	BOOL shouldHideEditorScroller = [[[NSUserDefaults standardUserDefaults] objectForKey:SCXcodeMinimapShouldHideEditorScroller] boolValue];
	
	[sender setState:(shouldHideEditorScroller ? NSOffState : NSOnState)];
	[[NSUserDefaults standardUserDefaults] setObject:@(!shouldHideEditorScroller) forKey:SCXcodeMinimapShouldHideEditorScroller];
	[[NSNotificationCenter defaultCenter] postNotificationName:SCXcodeMinimapHideEditorScrollerChangeNotification object:nil];
}

- (void)setMinimapTheme:(NSMenuItem *)sender
{
	NSString *currentThemeName = [[NSUserDefaults standardUserDefaults] objectForKey:SCXcodeMinimapTheme];
	
	if(currentThemeName == sender.title || [currentThemeName isEqualToString:sender.title]) {
		return;
	}
	
	NSMenu *themesSubmenu = [[[[NSApp mainMenu] itemWithTitle:kViewMenuItemTitle].submenu itemWithTitle:kMinimapMenuItemTitle].submenu itemWithTitle:kThemeMenuItemTitle].submenu;
	for(NSMenuItem *item in themesSubmenu.itemArray) {
		[item setState:NSOffState];
	}
	
	[sender setState:NSOnState];
	
	if([sender.menu indexOfItem:sender] == 0) {
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:SCXcodeMinimapTheme];
	} else {
		[[NSUserDefaults standardUserDefaults] setObject:sender.title forKey:SCXcodeMinimapTheme];
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName:SCXcodeMinimapThemeChangeNotification object:nil];
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
	
	[miniMapView setVisible:[[[NSUserDefaults standardUserDefaults] objectForKey:SCXcodeMinimapShouldDisplay] boolValue]];
}

@end
