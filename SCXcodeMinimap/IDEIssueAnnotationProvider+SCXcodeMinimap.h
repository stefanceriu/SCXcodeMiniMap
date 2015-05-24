//
//  IDEIssueAnnotationProvider+SCXcodeMinimap.h
//  SCXcodeMinimap
//
//  Created by Stefan Ceriu on 5/24/15.
//  Copyright (c) 2015 Stefan Ceriu. All rights reserved.
//

#import "IDEIssueAnnotationProvider.h"

@protocol IDEIssueAnnotationProviderDelegate;

@interface IDEIssueAnnotationProvider (SCXcodeMinimap)

@property (nonatomic, weak) id<IDEIssueAnnotationProviderDelegate> minimapDelegate;

@end

@protocol IDEIssueAnnotationProviderDelegate <NSObject>

- (void)issueAnnotationProviderDidChangeIssues:(IDEIssueAnnotationProvider *)annotationProvider;

@end
