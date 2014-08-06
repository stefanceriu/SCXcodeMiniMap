//
//  SCMiniMapView.h
//  SCXcodeMinimap
//
//  Created by Jérôme ALVES on 30/04/13.
//  Copyright (c) 2013 Stefan Ceriu. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SCSelectionView.h"

extern const CGFloat kDefaultZoomLevel;

@interface SCMiniMapView : NSScrollView

@property (nonatomic, strong) NSTextView *textView;
@property (nonatomic, strong) SCSelectionView *selectionView;

@property (nonatomic, weak) NSScrollView *editorScrollView;
@property (nonatomic, strong) NSTextView *editorTextView;

- (void)updateTextView;
- (void)updateSelectionView;

- (void) show;
- (void) hide;

@end
