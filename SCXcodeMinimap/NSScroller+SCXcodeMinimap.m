//
//  NSScroller+SCXcodeMinimap.m
//  SCXcodeMinimap
//
//  Created by Stefan Ceriu on 4/26/15.
//  Copyright (c) 2015 Stefan Ceriu. All rights reserved.
//

#import "NSScroller+SCXcodeMinimap.h"
#import <objc/runtime.h>

@implementation NSScroller (SCXcodeMinimap)
@dynamic forcedHidden;

- (BOOL)forcedHidden
{
	return [objc_getAssociatedObject(self, @selector(forcedHidden)) boolValue];
}

- (void)setForcedHidden:(BOOL)forcedHidden
{
	objc_setAssociatedObject(self, @selector(forcedHidden), @(forcedHidden), OBJC_ASSOCIATION_ASSIGN);
	
	[self setHidden:forcedHidden];
}

- (void)setHidden:(BOOL)hidden
{
	if(self.forcedHidden) {
		super.hidden = YES;
		return;
	}
	
	super.hidden = hidden;
}

@end
