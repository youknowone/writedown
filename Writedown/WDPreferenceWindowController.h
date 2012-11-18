//
//  WDPreferenceWindowController.h
//  Writedown
//
//  Created by Jeong YunWon on 12. 11. 15..
//  Copyright (c) 2012년 youknowone.org. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#define WDPreferenceThemeKey @"PreferenceTheme"

@interface WDPreferenceWindowController : NSWindowController<NSTextViewDelegate> {
    NSTextView *_themeTextView;
}

@property(retain) IBOutlet NSTextView *themeTextView;

+ (NSString *)themeString;

- (IBAction)loadThemeDefault:(id)sender;
- (IBAction)loadThemeFromFile:(id)sender;

@end
