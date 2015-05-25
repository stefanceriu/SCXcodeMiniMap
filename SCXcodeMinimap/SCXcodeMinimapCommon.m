//
//  SCXcodeMinimapCommon.m
//  SCXcodeMinimap
//
//  Created by Stefan Ceriu on 5/25/15.
//  Copyright (c) 2015 Stefan Ceriu. All rights reserved.
//

#import "SCXcodeMinimapCommon.h"

void sc_swizzleInstanceMethod(Class class, SEL originalSelector, SEL swizzledSelector) {
	Method originalMethod = class_getInstanceMethod(class, originalSelector);
	Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);
	if (class_addMethod(class, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod))) {
		class_replaceMethod(class, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
	} else {
		method_exchangeImplementations(originalMethod, swizzledMethod);
	}
}
