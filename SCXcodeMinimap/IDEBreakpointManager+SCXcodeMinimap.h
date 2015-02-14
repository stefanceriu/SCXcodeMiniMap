//
//  IDEBreakpointManager+SCXcodeMinimap.h
//  SCXcodeMinimap
//
//  Created by Stefan Ceriu on 14/02/2015.
//  Copyright (c) 2015 Stefan Ceriu. All rights reserved.
//

#import "IDEBreakpointManager.h"

@protocol IDEBreakpointManagerDelegate;

@interface IDEBreakpointManager (SCXcodeMinimap)

@property (nonatomic, weak) id<IDEBreakpointManagerDelegate> delegate;

@end

@protocol IDEBreakpointManagerDelegate <NSObject>

- (void)breakpointManagerDidAddBreakpoint:(IDEBreakpointManager *)breakpointManager;
- (void)breakpointManagerDidRemoveBreakpoint:(IDEBreakpointManager *)breakpointManager;
- (void)breakpointManagerDidChangeBreakpoint:(IDEBreakpointManager *)breakpointManager;

@end