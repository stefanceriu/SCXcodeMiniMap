//
//  SCXcodeMinimapView.h
//  SCXcodeMinimap
//
//  Created by Stefan Ceriu on 24/01/2015.
//  Copyright (c) 2015 Stefan Ceriu. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class IDESourceCodeEditor;

@interface SCXcodeMinimapView : NSView

- (instancetype)initWithEditor:(IDESourceCodeEditor *)editor;

@end
