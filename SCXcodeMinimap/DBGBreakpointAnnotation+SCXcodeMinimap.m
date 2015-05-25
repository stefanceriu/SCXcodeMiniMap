//
//  DBGBreakpointAnnotation+SCXcodeMinimap.m
//  SCXcodeMinimap
//
//  Created by Stefan Ceriu on 24/02/2015.
//  Copyright (c) 2015 Stefan Ceriu. All rights reserved.
//

#import "DBGBreakpointAnnotation+SCXcodeMinimap.h"
#import "SCXcodeMinimapCommon.h"
#import "IDEFileBreakpoint.h"

@implementation DBGBreakpointAnnotation (SCXcodeMinimap)
@dynamic minimapDelegate;

+ (void)load
{
	sc_swizzleInstanceMethod(self, @selector(_redisplay), @selector(sc_redisplay));
	sc_swizzleInstanceMethod(self, @selector(adjustParagraphIndexBy:lengthBy:), @selector(sc_adjustParagraphIndexBy:lengthBy:));
}

- (id<DBGBreakpointAnnotationDelegate>)minimapDelegate
{
	return objc_getAssociatedObject(self, @selector(minimapDelegate));
}

- (void)setMinimapDelegate:(id<DBGBreakpointAnnotationDelegate>)minimapDelegate
{
	objc_setAssociatedObject(self, @selector(minimapDelegate), minimapDelegate, OBJC_ASSOCIATION_ASSIGN);
}

- (BOOL)enabled
{
	if([self.representedObject isKindOfClass:[IDEFileBreakpoint class]]) {
		IDEFileBreakpoint *fileBreakpoint = (IDEFileBreakpoint *)self.representedObject;
		return fileBreakpoint.shouldBeEnabled;
	}
	
	return NO;
}

- (void)sc_redisplay
{
	[self sc_redisplay];
	
	if([self.representedObject isKindOfClass:[IDEFileBreakpoint class]]) {
		if([self.minimapDelegate respondsToSelector:@selector(breakpointAnnotationDidChangeState:)]) {
			[self.minimapDelegate breakpointAnnotationDidChangeState:self];
		}
	}
}

- (void)sc_adjustParagraphIndexBy:(long long)arg1 lengthBy:(long long)arg2
{
	[self sc_adjustParagraphIndexBy:arg1 lengthBy:arg2];
	
	if([self.representedObject isKindOfClass:[IDEFileBreakpoint class]]) {
		if([self.minimapDelegate respondsToSelector:@selector(breakpointAnnotationDidChangeState:)]) {
			[self.minimapDelegate breakpointAnnotationDidChangeState:self];
		}
	}
}

@end
