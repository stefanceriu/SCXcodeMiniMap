//
//  IDEIssueAnnotationProvider+SCXcodeMinimap.m
//  SCXcodeMinimap
//
//  Created by Stefan Ceriu on 5/24/15.
//  Copyright (c) 2015 Stefan Ceriu. All rights reserved.
//

#import "IDEIssueAnnotationProvider+SCXcodeMinimap.h"
#import "SCXcodeMinimapCommon.h"

static void *IDEIssueAnnotationProviderIssuesObservingContext = &IDEIssueAnnotationProviderIssuesObservingContext;

@interface IDEIssueAnnotationProvider (SCXcodeMinimap_Private)

@property (nonatomic, assign) BOOL isObservingAnnotations;

@end

@implementation IDEIssueAnnotationProvider (SCXcodeMinimap)
@dynamic minimapDelegate;

+ (void)load
{
	sc_swizzleInstanceMethod(self, @selector(providerWillUninstall), @selector(sc_providerWillUninstall));
	sc_swizzleInstanceMethod(self, @selector(didDeleteOrReplaceParagraphForAnnotation:), @selector(sc_didDeleteOrReplaceParagraphForAnnotation:));
}

- (void)sc_providerWillUninstall
{
	[self sc_providerWillUninstall];
	
	if(self.isObservingAnnotations) {
		[self removeObserver:self forKeyPath:@"annotations"];
	}
}

- (void)_didDeleteOrReplaceParagraphForAnnotation:(id)annotation
{
	[self _didDeleteOrReplaceParagraphForAnnotation:annotation];
	
	if([self.minimapDelegate respondsToSelector:@selector(issueAnnotationProviderDidChangeIssues:)]) {
		[self.minimapDelegate issueAnnotationProviderDidChangeIssues:self];
	}
}

- (id<IDEIssueAnnotationProviderDelegate>)minimapDelegate
{
	return objc_getAssociatedObject(self, @selector(minimapDelegate));
}

- (void)setMinimapDelegate:(id<IDEIssueAnnotationProviderDelegate>)minimapDelegate
{
	objc_setAssociatedObject(self, @selector(minimapDelegate), minimapDelegate, OBJC_ASSOCIATION_ASSIGN);
	
	if(minimapDelegate) {
		self.isObservingAnnotations = YES;
		[self addObserver:self forKeyPath:@"annotations" options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew context:IDEIssueAnnotationProviderIssuesObservingContext];
	}
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if(context == IDEIssueAnnotationProviderIssuesObservingContext) {
		if([self.minimapDelegate respondsToSelector:@selector(issueAnnotationProviderDidChangeIssues:)]) {
			[self.minimapDelegate issueAnnotationProviderDidChangeIssues:self];
		}
	}
}

- (BOOL)isObservingAnnotations
{
	return [objc_getAssociatedObject(self, @selector(isObservingAnnotations)) boolValue];
}

- (void)setIsObservingAnnotations:(BOOL)isObservingAnnotations
{
	objc_setAssociatedObject(self, @selector(isObservingAnnotations), @(isObservingAnnotations), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
