//
//  SCXcodeMinimap.h
//  SCXcodeMinimap
//
//  Created by Stefan Ceriu on 3/30/13.
//  Copyright (c) 2013 Stefan Ceriu. All rights reserved.
//

#import <Cocoa/Cocoa.h>

extern NSString *const SCXcodeMinimapShouldDisplayChangeNotification;
extern NSString *const SCXcodeMinimapShouldDisplayKey;

extern NSString *const SCXcodeMinimapZoomLevelChangeNotification;
extern NSString *const SCXcodeMinimapZoomLevelKey;

extern NSString *const SCXcodeMinimapHighlightBreakpointsChangeNotification;
extern NSString *const SCXcodeMinimapShouldHighlightBreakpointsKey;

extern NSString *const SCXcodeMinimapHighlightCommentsChangeNotification;
extern NSString *const SCXcodeMinimapShouldHighlightCommentsKey;

extern NSString *const SCXcodeMinimapHighlightPreprocessorChangeNotification;
extern NSString *const SCXcodeMinimapShouldHighlightPreprocessorKey;

extern NSString *const SCXcodeMinimapHighlightEditorChangeNotification;
extern NSString *const SCXcodeMinimapShouldHighlightEditorKey;

extern NSString *const SCXcodeMinimapHideEditorScrollerChangeNotification;
extern NSString *const SCXcodeMinimapShouldHideEditorScrollerKey;

extern NSString *const SCXcodeMinimapThemeChangeNotification;
extern NSString *const SCXcodeMinimapThemeKey;

@interface SCXcodeMinimap : NSObject

@end
