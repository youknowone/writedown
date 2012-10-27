//
//  WDDocument.h
//  Writedown
//
//  Created by Jeong YunWon on 12. 10. 27..
//  Copyright (c) 2012 youknowone.org. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@class WDFileEvent;

@interface WDDocument : NSDocument<NSTextViewDelegate, NSAlertDelegate> {
    NSString *_template;
    NSString *_source;
    WDFileEvent *_fileEvent;

    NSThread *_renderThread;
    BOOL _renderRequested;
    NSInteger _renderOffset;

    IBOutlet WebView *_renderView;
    IBOutlet NSTextView *_editView;
}

@property(retain) NSString *source;
@property(retain) WDFileEvent *fileEvent;
@property(retain) WebView *renderView;
@property(retain) NSTextView *editView;

- (void)render;

@end
