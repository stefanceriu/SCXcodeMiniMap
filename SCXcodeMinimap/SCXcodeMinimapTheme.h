//
//  SCXcodeMinimapTheme.h
//  SCXcodeMinimap
//
//  Created by Stefan Ceriu on 5/24/15.
//  Copyright (c) 2015 Stefan Ceriu. All rights reserved.
//

#import "DVTFontAndColorTheme.h"

@interface SCXcodeMinimapTheme : NSObject

+ (SCXcodeMinimapTheme *)minimapThemeWithTheme:(DVTFontAndColorTheme *)theme;

@property (nonatomic, strong) NSColor *backgroundColor;
@property (nonatomic, strong) NSColor *selectionColor;

@property (nonatomic, strong) NSColor *sourcePlainTextColor;
@property (nonatomic, strong) NSColor *sourceTextBackgroundColor;
@property (nonatomic, strong) NSColor *commentBackgroundColor;
@property (nonatomic, strong) NSColor *preprocessorBackgroundColor;
@property (nonatomic, strong) NSColor *enabledBreakpointColor;
@property (nonatomic, strong) NSColor *disabledBreakpointColor;

@property (nonatomic, strong) NSColor *buildIssueWarningBackgroundColor;
@property (nonatomic, strong) NSColor *buildIssueErrorBackgroundColor;

@property (nonatomic, strong) DVTFontAndColorTheme *dvtTheme;

@end
