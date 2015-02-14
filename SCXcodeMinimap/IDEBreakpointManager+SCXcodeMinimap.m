//
//  IDEBreakpointManager+SCXcodeMinimap.m
//  SCXcodeMinimap
//
//  Created by Stefan Ceriu on 14/02/2015.
//  Copyright (c) 2015 Stefan Ceriu. All rights reserved.
//

#import "IDEBreakpointManager+SCXcodeMinimap.h"
#import "IDEFileBreakpoint.h"
#import <objc/runtime.h>

static void *SCXcodeMinimapBreakpointObserverContext = &SCXcodeMinimapBreakpointObserverContext;

@implementation IDEBreakpointManager (SCXcodeMinimap)

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
	sc_swizzleInstanceMethod(self, @selector(addBreakpoint:), @selector(sc_addBreakpoint:));
	sc_swizzleInstanceMethod(self, @selector(removeBreakpoint:), @selector(sc_removeBreakpoint:));
}

- (void)setDelegate:(id<IDEBreakpointManagerDelegate>)delegate
{
	objc_setAssociatedObject(self, @selector(delegate), delegate, OBJC_ASSOCIATION_ASSIGN);
}

- (id<IDEBreakpointManagerDelegate>)delegate
{
	return objc_getAssociatedObject(self, @selector(delegate));
}

- (void)sc_addBreakpoint:(IDEBreakpoint *)breakpoint
{
	[self sc_addBreakpoint:breakpoint];
	
	if([breakpoint isKindOfClass:[IDEFileBreakpoint class]]) {
		[breakpoint addObserver:self forKeyPath:@"location" options:NSKeyValueObservingOptionNew context:SCXcodeMinimapBreakpointObserverContext];
		[breakpoint addObserver:self forKeyPath:@"shouldBeEnabled" options:NSKeyValueObservingOptionNew context:SCXcodeMinimapBreakpointObserverContext];
	}
	
	if([self.delegate respondsToSelector:@selector(breakpointManagerDidAddBreakpoint:)]) {
		[self.delegate breakpointManagerDidAddBreakpoint:self];
	}
}

- (void)sc_removeBreakpoint:(IDEBreakpoint *)breakpoint
{
	if([breakpoint isKindOfClass:[IDEFileBreakpoint class]]) {
		[breakpoint removeObserver:self forKeyPath:@"location" context:SCXcodeMinimapBreakpointObserverContext];
		[breakpoint removeObserver:self forKeyPath:@"shouldBeEnabled" context:SCXcodeMinimapBreakpointObserverContext];
	}
	
	[self sc_removeBreakpoint:breakpoint];
	
	if([self.delegate respondsToSelector:@selector(breakpointManagerDidRemoveBreakpoint:)]) {
		[self.delegate breakpointManagerDidRemoveBreakpoint:self];
	}
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if(context == SCXcodeMinimapBreakpointObserverContext) {
		if([self.delegate respondsToSelector:@selector(breakpointManagerDidChangeBreakpoint:)]) {
			[self.delegate breakpointManagerDidChangeBreakpoint:self];
		}
	}
}

@end
