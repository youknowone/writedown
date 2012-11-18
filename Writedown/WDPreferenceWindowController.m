//
//  WDPreferenceWindowController.m
//  Writedown
//
//  Created by Jeong YunWon on 12. 11. 15..
//  Copyright (c) 2012년 youknowone.org. All rights reserved.
//

#import "WDPreferenceWindowController.h"

@interface WDPreferenceWindowController ()

- (void)saveTheme;

@end

@implementation WDPreferenceWindowController
@synthesize themeTextView=_themeTextView;

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {

    }
    return self;
}

- (void)awakeFromNib {
    [super awakeFromNib];
    
    self.themeTextView.placeholderString = [NSString stringWithContentsOfURL:@"res://template.css".resourceURL encoding:NSUTF8StringEncoding error:NULL];
    NSString *savedString = [[NSUserDefaults standardUserDefaults] objectForKey:WDPreferenceThemeKey];
    self.themeTextView.string = savedString ? savedString : @"";
}

- (void)loadThemeDefault:(id)sender {
    self.themeTextView.string = @"";
    [self saveTheme];
}

- (void)loadThemeFromFile:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    if (NSFileHandlingPanelOKButton == [panel runModal]) {
        self.themeTextView.string = [NSString stringWithContentsOfURL:panel.URL encoding:NSUTF8StringEncoding error:NULL];
        [self saveTheme];
    }
}

- (void)saveTheme {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setObject:self.themeTextView.string forKey:WDPreferenceThemeKey];
    [userDefaults synchronize];
}

+ (NSString *)themeString {
    NSString *theme = [[NSUserDefaults standardUserDefaults] objectForKey:WDPreferenceThemeKey];
    if (theme.length == 0) {
        theme = [NSString stringWithContentsOfURL:@"res://template.css".resourceURL encoding:NSUTF8StringEncoding error:NULL];
    }
    return theme;
}

#pragma mark - text view delegate

- (void)textDidChange:(NSNotification *)notification {
    [self saveTheme];
}

@end
