//
//  IDEBreakpointManager+SCXcodeMinimap.h
//  SCXcodeMinimap
//
//  Created by Stefan Ceriu on 14/02/2015.
//  Copyright (c) 2015 Stefan Ceriu. All rights reserved.
//

#import "IDEBreakpointManager.h"

typedef void (^SCKVONotificationBlock)(id object, NSDictionary *change);

@interface SCKVOController : NSObject

- (void)observeObject:(id)object forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options block:(SCKVONotificationBlock)block;
- (void)unobserveObject:(id)object forKeyPath:(NSString *)keyPath;
- (void)unobserveObject:(id)object;
- (void)unobserveAll;

@end

@protocol IDEBreakpointManagerDelegate;

@interface IDEBreakpointManager (SCXcodeMinimap)

@property (nonatomic, weak) id<IDEBreakpointManagerDelegate> delegate;
@property (nonatomic, strong) SCKVOController *kvoController;

@end

@protocol IDEBreakpointManagerDelegate <NSObject>

- (void)breakpointManagerDidAddBreakpoint:(IDEBreakpointManager *)breakpointManager;
- (void)breakpointManagerDidRemoveBreakpoint:(IDEBreakpointManager *)breakpointManager;
- (void)breakpointManagerDidChangeBreakpoint:(IDEBreakpointManager *)breakpointManager;

@end