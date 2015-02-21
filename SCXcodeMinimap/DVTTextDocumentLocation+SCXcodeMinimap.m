//
//  DVTTextDocumentLocation+SCXcodeMinimap.m
//  SCXcodeMinimap
//
//  Created by Stefan Ceriu on 21/02/2015.
//  Copyright (c) 2015 Stefan Ceriu. All rights reserved.
//

#import "DVTTextDocumentLocation+SCXcodeMinimap.h"
#import <objc/runtime.h>

@implementation DVTTextDocumentLocation (SCXcodeMinimap)

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
//	sc_swizzleInstanceMethod(self, @selector(initWithDocumentURL:timestamp:startingColumnNumber:endingColumnNumber:startingLineNumber:endingLineNumber:characterRange:), @selector(sc_initWithDocumentURL:timestamp:startingColumnNumber:endingColumnNumber:startingLineNumber:endingLineNumber:characterRange:));
//	
//	sc_swizzleInstanceMethod(self, @selector(initWithDocumentURL:timestamp:), @selector(sc_initWithDocumentURL:timestamp:));
//	sc_swizzleInstanceMethod(self, @selector(initWithDocumentURL:timestamp:characterRange:), @selector(sc_initWithDocumentURL:timestamp:characterRange:));
//	sc_swizzleInstanceMethod(self, @selector(initWithDocumentURL:timestamp:lineRange:), @selector(sc_initWithDocumentURL:timestamp:lineRange:));
}

- (id)sc_initWithDocumentURL:(id)arg1 timestamp:(id)arg2 startingColumnNumber:(long long)arg3 endingColumnNumber:(long long)arg4 startingLineNumber:(long long)arg5 endingLineNumber:(long long)arg6 characterRange:(struct _NSRange)arg7
{
	NSLog(@"%@", [NSThread callStackSymbols]);
	
	return [self sc_initWithDocumentURL:arg1 timestamp:arg2 startingColumnNumber:arg3 endingColumnNumber:arg4 startingLineNumber:arg5 endingLineNumber:arg6 characterRange:arg7];
}

- (id)sc_initWithDocumentURL:(id)arg1 timestamp:(id)arg2
{
	NSLog(@"%@", [NSThread callStackSymbols]);
	
	return [self sc_initWithDocumentURL:arg1 timestamp:arg2];
}

- (id)sc_initWithDocumentURL:(id)arg1 timestamp:(id)arg2 characterRange:(struct _NSRange)arg3
{
	NSLog(@"%@", [NSThread callStackSymbols]);
	
	return [self sc_initWithDocumentURL:arg1 timestamp:arg2 characterRange:arg3];
}

- (id)sc_initWithDocumentURL:(id)arg1 timestamp:(id)arg2 lineRange:(struct _NSRange)arg3
{
	NSLog(@"%@", [NSThread callStackSymbols]);
	
	return [self sc_initWithDocumentURL:arg1 timestamp:arg2 lineRange:arg3];
}

@end
