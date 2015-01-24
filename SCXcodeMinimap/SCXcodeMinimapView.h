//
//  SCXcodeMinimapView.h
//  SCXcodeMinimap
//
//  Created by Stefan Ceriu on 24/01/2015.
//  Copyright (c) 2015 Stefan Ceriu. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class DVTSourceTextView;
@class SCSelectionView;

extern const CGFloat kDefaultZoomLevel;

@interface SCXcodeMinimapView : NSView

- (instancetype)initWithFrame:(NSRect)frameRect
			 editorScrollView:(NSScrollView *)editorScrollView
			   editorTextView:(DVTSourceTextView *)editorTextView;

- (void)updateOffset;

- (void)setVisible:(BOOL)visible;

@end
