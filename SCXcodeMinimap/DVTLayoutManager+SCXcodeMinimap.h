//
//  DVTLayoutManager+SCXcodeMinimap.h
//  SCXcodeMinimap
//
//  Created by Stefan Ceriu on 5/25/15.
//  Copyright (c) 2015 Stefan Ceriu. All rights reserved.
//

#import "DVTLayoutManager.h"

@protocol DVTLayoutManagerMinimapDelegate;

@interface DVTLayoutManager (SCXcodeMinimap)

@property (nonatomic, weak) id<DVTLayoutManagerMinimapDelegate> minimapDelegate;

@end

@protocol DVTLayoutManagerMinimapDelegate <NSObject>

- (void)layoutManagerDidRequestSelectedSymbolInstancesHighlight:(DVTLayoutManager *)layoutManager;

@end