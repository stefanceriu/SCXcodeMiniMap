//
//  DBGBreakpointAnnotation+SCXcodeMinimap.m
//  SCXcodeMinimap
//
//  Created by Stefan Ceriu on 24/02/2015.
//  Copyright (c) 2015 Stefan Ceriu. All rights reserved.
//

#import "DBGBreakpointAnnotation+SCXcodeMinimap.h"
#import <objc/runtime.h>

#import "IDEFileBreakpoint.h"

@implementation DBGBreakpointAnnotation (SCXcodeMinimap)
@dynamic minimapDelegate;

static void sc_swizzleInstanceMethod(Class class, SEL originalSelector, SEL swizzledSelector) {
	Method originalMethod = class_getInstanceMethod(class, originalSelector);
	Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);
	if (class_addMethod(class, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod))) {
		class_replaceMethod(class, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
	} else {
		method_exchangeImplementations(originalMethod, swizzledMethod);
	}
}

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
