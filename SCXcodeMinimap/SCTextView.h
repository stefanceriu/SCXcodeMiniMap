//
//  SCTextView.h
//  SCXcodeMinimap
//
//  Created by Jérôme ALVES on 29/04/13.
//  Copyright (c) 2013 Stefan Ceriu. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class SCTextView;

@protocol SCTextViewDelegate <NSTextViewDelegate>

- (void)textView:(SCTextView *)textView goAtRelativePosition:(NSPoint)position;

@end

@interface SCTextView : NSTextView

- (void)setDelegate:(id<SCTextViewDelegate>)anObject;
- (id<SCTextViewDelegate>)delegate;

@end
