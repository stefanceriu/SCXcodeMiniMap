//
//  SCXcodeMinimapScrollView.m
//  SCXcodeMinimap
//
//  Created by Stefan Ceriu on 28/02/2015.
//  Copyright (c) 2015 Stefan Ceriu. All rights reserved.
//

#import "SCXcodeMinimapScrollView.h"

@interface SCXcodeMinimapScrollView ()

@property (nonatomic, strong) NSScrollView *editorScrollView;

@end

@implementation SCXcodeMinimapScrollView

- (instancetype)initWithFrame:(CGRect)frame
			 editorScrollView:(NSScrollView *)scrollView
{
	if(self = [super initWithFrame:frame]) {
		_editorScrollView = scrollView;
	}
	
	return self;
}

- (void)scrollWheel:(NSEvent *)theEvent
{
	[self.editorScrollView scrollWheel:theEvent];
}

@end
