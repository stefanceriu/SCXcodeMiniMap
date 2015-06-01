//
//  SCXcodeMinimapSplitView.h
//  SCXcodeMinimap
//
//  Created by Mario Barbosa on 25/05/2015.
//  Copyright (c) 2015 Stefan Ceriu. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol SCXcodeMinimapSplitViewCollapseProtocol <NSObject>

- (void)minimapSplitViewDidCollapse;
- (void)minimapSplitViewDidExpand;

@end

@interface SCXcodeMinimapSplitView : NSSplitView

@property (nonatomic, weak) id<SCXcodeMinimapSplitViewCollapseProtocol> collapseDelegate;

@end
