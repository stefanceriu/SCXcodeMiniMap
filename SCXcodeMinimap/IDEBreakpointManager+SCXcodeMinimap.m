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
	sc_swizzleInstanceMethod(self, @selector(_handleWorkspaceContainerRemoved:), @selector(sc_handleWorkspaceContainerRemoved:));
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

- (void)setKvoController:(SCKVOController *)kvoController
{
	objc_setAssociatedObject(self, @selector(kvoController), kvoController, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (SCKVOController *)kvoController
{
	SCKVOController *kvoController = objc_getAssociatedObject(self, @selector(kvoController));
	
	if(kvoController == nil) {
		kvoController = [[SCKVOController alloc] init];
		[self setKvoController:kvoController];
		
		for(IDEBreakpoint *breakpoint in self.breakpoints) {
			if([breakpoint isKindOfClass:[IDEFileBreakpoint class]]) {
				[self _observeBreakpoint:breakpoint];
			}
		}
	}
	
	return kvoController;
}

- (void)sc_handleWorkspaceContainerRemoved:(id)arg1
{
	[self.kvoController unobserveAll];
}

- (void)sc_addBreakpoint:(IDEBreakpoint *)breakpoint
{
	[self sc_addBreakpoint:breakpoint];
	
	[self _observeBreakpoint:breakpoint];
	
	if([self.delegate respondsToSelector:@selector(breakpointManagerDidAddBreakpoint:)]) {
		[self.delegate breakpointManagerDidAddBreakpoint:self];
	}
}

- (void)sc_removeBreakpoint:(IDEBreakpoint *)breakpoint
{
	[self.kvoController unobserveObject:breakpoint];
	
	[self sc_removeBreakpoint:breakpoint];
	
	if([self.delegate respondsToSelector:@selector(breakpointManagerDidRemoveBreakpoint:)]) {
		[self.delegate breakpointManagerDidRemoveBreakpoint:self];
	}
}

- (void)_observeBreakpoint:(IDEBreakpoint *)breakpoint
{
	[self.kvoController observeObject:breakpoint forKeyPath:@"location" options:NSKeyValueObservingOptionNew block:^(id object, NSDictionary *change) {
		if([self.delegate respondsToSelector:@selector(breakpointManagerDidChangeBreakpoint:)]) {
			[self.delegate breakpointManagerDidChangeBreakpoint:self];
		}
	}];
	
	[self.kvoController observeObject:breakpoint forKeyPath:@"shouldBeEnabled" options:NSKeyValueObservingOptionNew block:^(id object, NSDictionary *change) {
		if([self.delegate respondsToSelector:@selector(breakpointManagerDidChangeBreakpoint:)]) {
			[self.delegate breakpointManagerDidChangeBreakpoint:self];
		}
	}];
}

@end


@interface SCKVOKeyPathInfo : NSObject

@property (nonatomic, strong) NSMutableSet *blocks;

@end


@interface SCKVOInfo : NSObject

@property (nonatomic, weak) id observer;
@property (nonatomic, strong) NSMutableDictionary *keyPathInfos;

- (instancetype)initWithObserver:(id)observer;

@end


@interface SCKVOController()

@property (nonatomic, strong) NSMapTable *mapTable;

@end


@implementation SCKVOController

- (void)dealloc
{
	[self unobserveAll];
}

- (void)observeObject:(id)object forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options block:(SCKVONotificationBlock)block
{
	NSParameterAssert(object);
	NSParameterAssert(keyPath);
	NSParameterAssert(block);
	
	SCKVOInfo *info = [self.mapTable objectForKey:object];
	
	if (!info) {
		info = [[SCKVOInfo alloc] initWithObserver:object];
		[self.mapTable setObject:info forKey:object];
	}
	
	SCKVOKeyPathInfo *kvoKeyPathInfo = [info.keyPathInfos objectForKey:keyPath];
	
	BOOL registerObserver = NO;
	
	if (!kvoKeyPathInfo) {
		kvoKeyPathInfo = [[SCKVOKeyPathInfo alloc] init];
		[info.keyPathInfos setValue:kvoKeyPathInfo forKey:keyPath];
		registerObserver = YES;
	}
	
	[kvoKeyPathInfo.blocks addObject:[block copy]];
	
	if (registerObserver) {
		[object addObserver:self forKeyPath:keyPath options:options context:NULL];
	}
}

- (void)unobserveObject:(id)object forKeyPath:(NSString *)keyPath
{
	NSParameterAssert(object);
	NSParameterAssert(keyPath);
	
	SCKVOInfo *info = [self.mapTable objectForKey:object];
	
	if (info) {
		if (info.keyPathInfos[keyPath]) {
			[info.keyPathInfos removeObjectForKey:keyPath];
			[object removeObserver:self forKeyPath:keyPath context:NULL];
			
			if (info.keyPathInfos.count == 0) {
				[self.mapTable removeObjectForKey:object];
			}
		}
	}
}

- (void)unobserveObject:(id)object
{
	NSParameterAssert(object);
	
	SCKVOInfo *info = [self.mapTable objectForKey:object];
	if (info) {
		for (NSString *keyPath in [info.keyPathInfos allKeys]) {
			[self unobserveObject:object forKeyPath:keyPath];
		}
	}
}

- (void)unobserveAll
{
	NSMapTable *mapTable = [self.mapTable copy];
	
	for (id object in mapTable) {
		[self unobserveObject:object];
	}
}

- (NSMapTable *)mapTable
{
	if (!_mapTable) {
		_mapTable = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsWeakMemory|NSPointerFunctionsObjectPointerPersonality valueOptions:NSPointerFunctionsStrongMemory|NSPointerFunctionsObjectPersonality];
	}
	
	return _mapTable;
}

- (void)observeValueForKeyPath:(NSString *)keyPath
					  ofObject:(id)object
						change:(NSDictionary *)change
					   context:(void *)context
{
	SCKVOInfo *info = [self.mapTable objectForKey:object];
	
	if (info) {
		SCKVOKeyPathInfo *kvoKeyPathInfo = [info.keyPathInfos objectForKey:keyPath];
		
		if (kvoKeyPathInfo) {
			for (SCKVONotificationBlock block in  kvoKeyPathInfo.blocks) {
				block(object, change);
			}
		}
	}
}

@end


@implementation SCKVOKeyPathInfo

- (instancetype)init
{
	if (self = [super init]) {
		self.blocks = [NSMutableSet set];
	}
	
	return self;
}

@end


@implementation SCKVOInfo

- (instancetype)initWithObserver:(id)observer
{
	if (self = [super init]) {
		self.observer = observer;
		self.keyPathInfos = [NSMutableDictionary dictionary];
	}
	return self;
}

@end
