//
//  IDEEditorArea+SCXcodeMinimap.m
//  SCXcodeMinimap
//
//  Created by Stefan Ceriu on 8/16/15.
//  Copyright (c) 2015 Stefan Ceriu. All rights reserved.
//

#import "IDEEditorArea+SCXcodeMinimap.h"
#import "SCXcodeMinimapCommon.h"

static void *IDEEditorAreaEditorModeObservingContext = &IDEEditorAreaEditorModeObservingContext;

@implementation IDEEditorArea (SCXcodeMinimap)

+ (void)load
{
	sc_swizzleInstanceMethod([self class], @selector(viewDidInstall), @selector(sc_viewDidInstall));
	sc_swizzleInstanceMethod([self class], @selector(viewWillUninstall), @selector(sc_viewWillUninstall));
}

- (id<IDEEditorAreaMinimapDelegate>)minimapDelegate
{
	return objc_getAssociatedObject(self, @selector(minimapDelegate));
}

- (void)setMinimapDelegate:(id<IDEEditorAreaMinimapDelegate>)minimapDelegate
{
	objc_setAssociatedObject(self, @selector(minimapDelegate), minimapDelegate, OBJC_ASSOCIATION_ASSIGN);
}

- (void)sc_viewDidInstall
{
	[self addObserver:self forKeyPath:@"editorMode" options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew context:IDEEditorAreaEditorModeObservingContext];

	[self sc_viewDidInstall];
}

- (void)sc_viewWillUninstall
{
	[self removeObserver:self forKeyPath:@"editorMode"];
	
	[self sc_viewWillUninstall];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if(context == IDEEditorAreaEditorModeObservingContext) {
		if([self.minimapDelegate respondsToSelector:@selector(editorAreaDidChangeEditorMode:)]) {
			[self.minimapDelegate editorAreaDidChangeEditorMode:self];
		}
	}
}

@end
