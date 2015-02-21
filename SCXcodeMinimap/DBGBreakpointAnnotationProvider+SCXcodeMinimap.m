//
//  DBGBreakpointAnnotationProvider+SCXcodeMinimap.m
//  SCXcodeMinimap
//
//  Created by Stefan Ceriu on 21/02/2015.
//  Copyright (c) 2015 Stefan Ceriu. All rights reserved.
//

#import "DBGBreakpointAnnotationProvider+SCXcodeMinimap.h"
#import <objc/runtime.h>
#import "DBGBreakpointAnnotation.h"

@implementation DBGBreakpointAnnotationProvider (SCXcodeMinimap)

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
	sc_swizzleInstanceMethod(self, @selector(_addAnnotationForFileBreakpoint:), @selector(sc_addAnnotationForFileBreakpoint:));
	sc_swizzleInstanceMethod(self, @selector(_removeAnnotation:), @selector(sc_removeAnnotation:));
	sc_swizzleInstanceMethod(self, @selector(didMoveAnnotation:), @selector(sc_didMoveAnnotation:));
}

- (void)setDelegate:(id<DBGBreakpointAnnotationProviderDelegate>)delegate
{
	objc_setAssociatedObject(self, @selector(delegate), delegate, OBJC_ASSOCIATION_ASSIGN);
}

- (id<DBGBreakpointAnnotationProviderDelegate>)delegate
{
	return objc_getAssociatedObject(self, @selector(delegate));
}

- (void)sc_addAnnotationForFileBreakpoint:(id)arg1
{
	[self sc_addAnnotationForFileBreakpoint:arg1];
	
	[self.delegate breakpointAnnotationProviderDidChangeBreakpoints:self];
}

- (void)sc_removeAnnotation:(id)arg1
{
	[self sc_removeAnnotation:arg1];
	
	[self.delegate breakpointAnnotationProviderDidChangeBreakpoints:self];
}

- (void)sc_didMoveAnnotation:(id)arg1
{
	[self.delegate breakpointAnnotationProviderDidChangeBreakpoints:self];
}

@end
