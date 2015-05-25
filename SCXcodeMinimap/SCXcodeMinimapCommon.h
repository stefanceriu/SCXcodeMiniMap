//
//  SCXcodeMinimapCommon.h
//  SCXcodeMinimap
//
//  Created by Stefan Ceriu on 5/25/15.
//  Copyright (c) 2015 Stefan Ceriu. All rights reserved.
//

#import <objc/runtime.h>

extern void sc_swizzleInstanceMethod(Class class, SEL originalSelector, SEL swizzledSelector);
