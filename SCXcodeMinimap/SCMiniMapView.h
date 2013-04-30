//
//  SCMiniMapView.h
//  SCXcodeMinimap
//
//  Created by Jérôme ALVES on 30/04/13.
//  Copyright (c) 2013 Stefan Ceriu. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SCSelectionView.h"

@interface SCMiniMapView : NSScrollView <NSLayoutManagerDelegate>

@property (nonatomic, retain) NSTextView *textView;
@property (nonatomic, retain) SCSelectionView *selectionView;

@property (nonatomic, assign) NSScrollView *editorScrollView;
@property (nonatomic, assign) NSTextView *editorTextView;

- (void)updateTextView;
- (void)updateSelectionView;

- (void) show;
- (void) hide;

@end
