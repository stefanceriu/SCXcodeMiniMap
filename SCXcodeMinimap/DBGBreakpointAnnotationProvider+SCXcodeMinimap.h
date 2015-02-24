//
//  DBGBreakpointAnnotationProvider+SCXcodeMinimap.h
//  SCXcodeMinimap
//
//  Created by Stefan Ceriu on 21/02/2015.
//  Copyright (c) 2015 Stefan Ceriu. All rights reserved.
//

#import "DBGBreakpointAnnotationProvider.h"

@protocol DBGBreakpointAnnotationProviderDelegate;

@interface DBGBreakpointAnnotationProvider (SCXcodeMinimap)

@property (nonatomic, weak) id<DBGBreakpointAnnotationProviderDelegate> minimapDelegate;

@end

@protocol DBGBreakpointAnnotationProviderDelegate <NSObject>

- (void)breakpointAnnotationProviderDidChangeBreakpoints:(DBGBreakpointAnnotationProvider *)annotationProvider;

@end