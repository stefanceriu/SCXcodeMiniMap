//
//  DBGBreakpointAnnotation+SCXcodeMinimap.h
//  SCXcodeMinimap
//
//  Created by Stefan Ceriu on 24/02/2015.
//  Copyright (c) 2015 Stefan Ceriu. All rights reserved.
//

#import "DBGBreakpointAnnotation.h"

@protocol DBGBreakpointAnnotationDelegate;

@interface DBGBreakpointAnnotation (SCXcodeMinimap)

@property (nonatomic, readonly) BOOL enabled;
@property (nonatomic, weak) id<DBGBreakpointAnnotationDelegate> minimapDelegate;

@end

@protocol DBGBreakpointAnnotationDelegate <NSObject>

- (void)breakpointAnnotationDidChangeState:(DBGBreakpointAnnotation *)annotation;

@end
