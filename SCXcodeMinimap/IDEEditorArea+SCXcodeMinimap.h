//
//  IDEEditorArea+SCXcodeMinimap.h
//  SCXcodeMinimap
//
//  Created by Stefan Ceriu on 8/16/15.
//  Copyright (c) 2015 Stefan Ceriu. All rights reserved.
//

#import "IDEEditorArea.h"

@protocol IDEEditorAreaMinimapDelegate;

@interface IDEEditorArea (SCXcodeMinimap)

@property (nonatomic, weak) id<IDEEditorAreaMinimapDelegate> minimapDelegate;

@end

@protocol IDEEditorAreaMinimapDelegate <NSObject>

- (void)editorAreaDidChangeEditorMode:(IDEEditorArea *)editorArea;

@end
