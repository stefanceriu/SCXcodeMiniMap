//
//  IDESourceCodeEditor+SCXcodeMinimap.h
//  SCXcodeMinimap
//
//  Created by Stefan Ceriu on 6/4/15.
//  Copyright (c) 2015 Stefan Ceriu. All rights reserved.
//

#import "IDESourceCodeEditor.h"

@protocol IDESourceCodeEditorSearchResultsDelegate;

@interface IDESourceCodeEditor (SCXcodeMinimap)

@property (nonatomic, weak) id<IDESourceCodeEditorSearchResultsDelegate> searchResultsDelegate;

@property (nonatomic, strong) NSArray *searchResults;

@end

@protocol IDESourceCodeEditorSearchResultsDelegate <NSObject>

- (void)sourceCodeEditorDidUpdateSearchResults:(IDESourceCodeEditor *)editor;

@end
