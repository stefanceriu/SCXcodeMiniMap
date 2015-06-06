//
//  SCXcodeMinimapTheme.m
//  SCXcodeMinimap
//
//  Created by Stefan Ceriu on 5/24/15.
//  Copyright (c) 2015 Stefan Ceriu. All rights reserved.
//

#import "SCXcodeMinimapTheme.h"
#import "DVTSourceNodeTypes.h"
#import "DVTPointerArray.h"

const CGFloat kBackgroundColorShadowLevel = 0.1f;

static NSString * const kXcodeSyntaxCommentNodeName = @"xcode.syntax.comment";
static NSString * const kXcodeSyntaxPreprocessorNodeName = @"xcode.syntax.preprocessor";

@implementation SCXcodeMinimapTheme

+ (SCXcodeMinimapTheme *)minimapThemeWithTheme:(DVTFontAndColorTheme *)theme
{
	SCXcodeMinimapTheme *minimapTheme = [[SCXcodeMinimapTheme alloc] init];
	
	minimapTheme.dvtTheme = theme;
	
	minimapTheme.backgroundColor = [theme.sourceTextBackgroundColor shadowWithLevel:kBackgroundColorShadowLevel];
	
	minimapTheme.selectionColor = [NSColor colorWithCalibratedRed:(1.0f - [minimapTheme.backgroundColor redComponent])
															green:(1.0f - [minimapTheme.backgroundColor greenComponent])
															 blue:(1.0f - [minimapTheme.backgroundColor blueComponent])
															alpha:0.2f];
	
	minimapTheme.sourcePlainTextColor = theme.sourcePlainTextColor;
	minimapTheme.sourceTextBackgroundColor = theme.sourceTextBackgroundColor;
	
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
	
	minimapTheme.buildIssueWarningBackgroundColor = [NSColor colorWithRed:1.0f green:1.0f blue:0.0f alpha:0.75f];
	minimapTheme.buildIssueErrorBackgroundColor = [NSColor colorWithRed:1.0f green:0.0f blue:0.0f alpha:0.75f];
	minimapTheme.highlightedSymbolBackgroundColor = [NSColor colorWithRed:255.0f/255.0f green:29.0f/255.0f blue:21.0f/255.0f alpha:0.75f];
	
	minimapTheme.searchResultForegroundColor = [minimapTheme.sourcePlainTextColor colorWithAlphaComponent:0.25f];
	minimapTheme.searchResultBackgroundColor = [NSColor colorWithRed:255.0f/255.0f green:29.0f/255.0f blue:21.0f/255.0f alpha:0.75f];
	
	return minimapTheme;
}

@end
