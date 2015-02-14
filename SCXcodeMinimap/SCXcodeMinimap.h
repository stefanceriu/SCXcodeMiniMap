//
//  SCXcodeMinimap.h
//  SCXcodeMinimap
//
//  Created by Stefan Ceriu on 3/30/13.
//  Copyright (c) 2013 Stefan Ceriu. All rights reserved.
//

#import <Cocoa/Cocoa.h>

const CGFloat kDefaultZoomLevel;

extern NSString *const SCXcodeMinimapShouldDisplayChangeNotification;
extern NSString *const SCXcodeMinimapShouldDisplay;

extern NSString *const SCXcodeMinimapHighlightBreakpointsChangeNotification;
extern NSString *const SCXcodeMinimapShouldHighlightBreakpoints;

extern NSString *const SCXcodeMinimapHighlightCommentsChangeNotification;
extern NSString *const SCXcodeMinimapShouldHighlightComments;

extern NSString *const SCXcodeMinimapHighlightPreprocessorChangeNotification;
extern NSString *const SCXcodeMinimapShouldHighlightPreprocessor;

extern NSString *const SCXcodeMinimapHideEditorScrollerChangeNotification;
extern NSString *const SCXcodeMinimapShouldHideEditorScroller;

extern NSString *const SCXcodeMinimapThemeChangeNotification;
extern NSString *const SCXcodeMinimapTheme;

@interface SCXcodeMinimap : NSObject

@end
