//
//  IDESourceCodeEditor+SCXcodeMinimap.m
//  SCXcodeMinimap
//
//  Created by Stefan Ceriu on 6/4/15.
//  Copyright (c) 2015 Stefan Ceriu. All rights reserved.
//

#import "IDESourceCodeEditor+SCXcodeMinimap.h"
#import "SCXcodeMinimapCommon.h"

@implementation IDESourceCodeEditor (SCXcodeMinimap)

+ (void)load
{
	sc_swizzleInstanceMethod([self class], @selector(dvtFindBar:didUpdateResults:), @selector(sc_dvtFindBar:didUpdateResults:));
}

- (void)sc_dvtFindBar:(id)findBar didUpdateResults:(NSArray *)searchResults
{
	[self sc_dvtFindBar:findBar didUpdateResults:searchResults];
	[self setSearchResults:searchResults];
}

- (NSArray *)searchResults
{
	return objc_getAssociatedObject(self, @selector(searchResults));
}

- (void)setSearchResults:(NSArray *)searchResults
{
	if([self.searchResults isEqual:searchResults]) {
		return;
	}
	
	objc_setAssociatedObject(self, @selector(searchResults), searchResults, OBJC_ASSOCIATION_RETAIN);
	
	if([self.searchResultsDelegate respondsToSelector:@selector(sourceCodeEditorDidUpdateSearchResults:)]) {
		[self.searchResultsDelegate sourceCodeEditorDidUpdateSearchResults:self];
	}
}

- (id<IDESourceCodeEditorSearchResultsDelegate>)searchResultsDelegate
{
	return objc_getAssociatedObject(self, @selector(searchResultsDelegate));
}

- (void)setSearchResultsDelegate:(id<IDESourceCodeEditorSearchResultsDelegate>)searchResultsDelegate
{
	objc_setAssociatedObject(self, @selector(searchResultsDelegate), searchResultsDelegate, OBJC_ASSOCIATION_ASSIGN);
}

@end
