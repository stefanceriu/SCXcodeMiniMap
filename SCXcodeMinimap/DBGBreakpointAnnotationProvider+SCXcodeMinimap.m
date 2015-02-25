//
//  DBGBreakpointAnnotationProvider+SCXcodeMinimap.m
//  SCXcodeMinimap
//
//  Created by Stefan Ceriu on 21/02/2015.
//  Copyright (c) 2015 Stefan Ceriu. All rights reserved.
//

#import "DBGBreakpointAnnotationProvider+SCXcodeMinimap.h"
#import <objc/runtime.h>

#import "DBGBreakpointAnnotation+SCXcodeMinimap.h"

@implementation DBGBreakpointAnnotationProvider (SCXcodeMinimap)
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
	sc_swizzleInstanceMethod(self, @selector(_addAnnotationForFileBreakpoint:), @selector(sc_addAnnotationForFileBreakpoint:));
	sc_swizzleInstanceMethod(self, @selector(_removeAnnotation:), @selector(sc_removeAnnotation:));
	sc_swizzleInstanceMethod(self, @selector(didMoveAnnotation:), @selector(sc_didMoveAnnotation:));
}

- (void)setMinimapDelegate:(id<DBGBreakpointAnnotationProviderDelegate>)minimapDelegate
{
	for(DBGBreakpointAnnotation *annotation in self.annotations) {
		[annotation setMinimapDelegate:(id<DBGBreakpointAnnotationDelegate>)self];
	}
	
	objc_setAssociatedObject(self, @selector(minimapDelegate), minimapDelegate, OBJC_ASSOCIATION_ASSIGN);
}

- (id<DBGBreakpointAnnotationProviderDelegate>)minimapDelegate
{
	return objc_getAssociatedObject(self, @selector(minimapDelegate));
}

- (void)sc_addAnnotationForFileBreakpoint:(id)arg1
{
	[self sc_addAnnotationForFileBreakpoint:arg1];
	
	for(DBGBreakpointAnnotation *annotation in self.annotations) {
		if([annotation.representedObject isEqual:arg1]) {
			[annotation setMinimapDelegate:(id<DBGBreakpointAnnotationDelegate>)self];
		}
	}
	
	if([self.minimapDelegate respondsToSelector:@selector(breakpointAnnotationProviderDidChangeBreakpoints:)]) {
		[self.minimapDelegate breakpointAnnotationProviderDidChangeBreakpoints:self];
	}
}

- (void)sc_removeAnnotation:(DBGBreakpointAnnotation *)annotation
{
	[annotation setMinimapDelegate:nil];
	[self sc_removeAnnotation:annotation];
	
	if([self.minimapDelegate respondsToSelector:@selector(breakpointAnnotationProviderDidChangeBreakpoints:)]) {
		[self.minimapDelegate breakpointAnnotationProviderDidChangeBreakpoints:self];
	}
}

- (void)sc_didMoveAnnotation:(DBGBreakpointAnnotation *)annotation
{
	[self sc_didMoveAnnotation:annotation];
	
	if([self.minimapDelegate respondsToSelector:@selector(breakpointAnnotationProviderDidChangeBreakpoints:)]) {
		[self.minimapDelegate breakpointAnnotationProviderDidChangeBreakpoints:self];
	}
}

#pragma mark - DBGBreakpointAnnotationDelegate

- (void)breakpointAnnotationDidChangeState:(DBGBreakpointAnnotation *)annotation
{
	if([self.minimapDelegate respondsToSelector:@selector(breakpointAnnotationProviderDidChangeBreakpoints:)]) {
		[self.minimapDelegate breakpointAnnotationProviderDidChangeBreakpoints:self];
	}
}

@end
