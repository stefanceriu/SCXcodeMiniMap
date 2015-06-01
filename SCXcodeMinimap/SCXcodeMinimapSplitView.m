//
//  SCXcodeMinimapSplitView.m
//  SCXcodeMinimap
//
//  Created by Mario Barbosa on 25/05/2015.
//  Copyright (c) 2015 Stefan Ceriu. All rights reserved.
//

#import "SCXcodeMinimapSplitView.h"

#import "SCXcodeMinimap.h"

const CGFloat kMiniMapMaxWidth = 300.0f;

@interface SCXcodeMinimapSplitView() <NSSplitViewDelegate>
@property (nonatomic, strong) NSMutableArray *notificationObservers;
@property (nonatomic, assign) BOOL visible;
@end

@implementation SCXcodeMinimapSplitView

- (void)dealloc
{
    for(id observer in self.notificationObservers) {
        [[NSNotificationCenter defaultCenter] removeObserver:observer];
    }
}

- (instancetype)initWithFrame:(NSRect)frameRect
{
    if (self = [super initWithFrame:frameRect]) {
        [self commonInit];
    }
    
    return self;
}

- (void)commonInit
{
    self.delegate = self;
    
    __weak typeof(self) weakSelf = self;
    [self.notificationObservers addObject:[[NSNotificationCenter defaultCenter] addObserverForName:SCXcodeMinimapShouldDisplayChangeNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        [weakSelf setVisible:[[[NSUserDefaults standardUserDefaults] objectForKey:SCXcodeMinimapShouldDisplayKey] boolValue]];
    }]];
}

- (void)viewDidMoveToWindow
{
    if(self.window == nil) {
        return;
    }
    
    [self setVisible:[[[NSUserDefaults standardUserDefaults] objectForKey:SCXcodeMinimapShouldDisplayKey] boolValue]];
}

#pragma mark - Private

- (void)setVisible:(BOOL)visible
{
    if (_visible == visible) {
        return;
    }
    
    _visible = visible;
    
    if (visible) {
        [self setPosition:self.bounds.size.width - self.dividerThickness - kMiniMapMaxWidth/2 ofDividerAtIndex:0];
    } else {
        [self setPosition:self.bounds.size.width - self.dividerThickness ofDividerAtIndex:0];
    }
}

- (void)setExpand:(BOOL)expand
{
    BOOL oldValue = [[[NSUserDefaults standardUserDefaults] objectForKey:SCXcodeMinimapShouldDisplayKey] boolValue];
    
    if (oldValue != expand) {
        if (expand) {
            [self.collapseDelegate minimapSplitViewDidExpand];
        } else {
            [self.collapseDelegate minimapSplitViewDidCollapse];
        }
    }
}

#pragma mark - NSSplitViewDelegate

- (BOOL)splitView:(NSSplitView *)splitView canCollapseSubview:(NSView *)subview;
{
    return NO;
}

- (BOOL)splitView:(NSSplitView *)splitView shouldCollapseSubview:(NSView *)subview forDoubleClickOnDividerAtIndex:(NSInteger)dividerIndex
{
    return NO;
}

- (CGFloat)splitView:(NSSplitView *)sender constrainMinCoordinate:(CGFloat)proposedMin ofSubviewAt:(NSInteger)offset
{
    return MAX(sender.frame.size.width - kMiniMapMaxWidth, 0);
}

- (CGFloat)splitView:(NSSplitView *)sender constrainMaxCoordinate:(CGFloat)proposedMax ofSubviewAt:(NSInteger)offset
{
    return sender.frame.size.width;
}

-(void)splitView:(NSSplitView *)sender resizeSubviewsWithOldSize:(NSSize)oldSize
{
    CGFloat dividerThickness = [sender dividerThickness];
    NSRect leftRect  = [[[sender subviews] objectAtIndex:0] frame];
    NSRect rightRect = [[[sender subviews] objectAtIndex:1] frame];
    NSRect newFrame  = [sender frame];
    
    leftRect.origin = NSMakePoint(0, 0);
    leftRect.size.width = newFrame.size.width - rightRect.size.width - dividerThickness;
    leftRect.size.height = newFrame.size.height;
    
    rightRect.origin.x = leftRect.size.width + dividerThickness;
    rightRect.size.width = newFrame.size.width - leftRect.size.width - dividerThickness;
    rightRect.size.height = newFrame.size.height;
    
    [[[sender subviews] objectAtIndex:0] setFrame:leftRect];
    [[[sender subviews] objectAtIndex:1] setFrame:rightRect];
    
    [self setExpand:rightRect.size.width > 0];
}

@end
