//
//  SCSelectionView.h
//  SCXcodeMinimap
//
//  Created by Stefan Ceriu on 4/21/13.
//  Copyright (c) 2013 Stefan Ceriu. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SCSelectionView : NSView

@property (nonatomic, strong) NSColor *selectionColor;
@property (nonatomic, assign) BOOL shouldInverseColors;

@end
