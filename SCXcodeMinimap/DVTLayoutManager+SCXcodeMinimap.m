//
//  DVTLayoutManager+SCXcodeMinimap.m
//  SCXcodeMinimap
//
//  Created by Stefan Ceriu on 5/25/15.
//  Copyright (c) 2015 Stefan Ceriu. All rights reserved.
//

#import "DVTLayoutManager+SCXcodeMinimap.h"
#import "SCXcodeMinimapCommon.h"

@implementation DVTLayoutManager (SCXcodeMinimap)
@dynamic minimapDelegate;

+ (void)load
{
	sc_swizzleInstanceMethod(self, @selector(_displayAutoHighlightTokens), @selector(sc_displayAutoHighlightTokens));
}

- (id<DVTLayoutManagerMinimapDelegate>)minimapDelegate
{
	return objc_getAssociatedObject(self, @selector(minimapDelegate));
}

- (void)setMinimapDelegate:(id<DVTLayoutManagerMinimapDelegate>)minimapDelegate
{
	objc_setAssociatedObject(self, @selector(minimapDelegate), minimapDelegate, OBJC_ASSOCIATION_ASSIGN);
}

- (void)sc_displayAutoHighlightTokens
{
	[self sc_displayAutoHighlightTokens];
	
	if([self.minimapDelegate respondsToSelector:@selector(layoutManagerDidRequestSelectedSymbolInstancesHighlight:)]) {
		[self.minimapDelegate layoutManagerDidRequestSelectedSymbolInstancesHighlight:self];
	}
}

@end
