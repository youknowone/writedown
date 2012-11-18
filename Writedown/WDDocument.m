//
//  WDDocument.m
//  Writedown
//
//  Created by Jeong YunWon on 12. 10. 27..
//  Copyright (c) 2012 youknowone.org. All rights reserved.
//

#import "Markdown.h"

#import "WDDocument.h"
#import "WDPreferenceWindowController.h"

@interface WDDocument ()

- (void)renderBackground;
- (void)renderFinished:(NSString *)result;
- (void)cleanRenderThread;

- (void)documentSourceDidChanged;

@end


@interface WDFileEvent: NSObject {
    FSEventStreamRef stream;
    NSURL *_URL;
    NSDate *_modificationDate;

    id _target;
    SEL _selector;
}

@property(retain) NSDate *modificationDate;

- (id)initWithURL:(NSURL *)URL target:(id)target selector:(SEL)selector;
+ (id)eventWithURL:(NSURL *)URL target:(id)target selector:(SEL)selector;;

- (void)start;
- (void)stop;

@end

@implementation WDFileEvent
@synthesize modificationDate=_modificationDate;

void WDFileEventCallback(ConstFSEventStreamRef streamRef,
                         void *userData,
                         size_t numEvents,
                         void *eventPaths,
                         const FSEventStreamEventFlags eventFlags[],
                         const FSEventStreamEventId eventIds[]) {
    WDFileEvent *self = (WDFileEvent *)userData;
    
    NSError *error = nil;
    NSDictionary *attirbutes = [[NSFileManager defaultManager] attributesOfItemAtPath:self->_URL.path error:&error];
    NSDate *modificationDate = [attirbutes objectForKey:NSFileModificationDate];

    if ([modificationDate isGreaterThan:self.modificationDate]) {
        [self->_target performSelector:self->_selector];
        self.modificationDate = modificationDate;
    }
}

- (id)initWithURL:(NSURL *)URL target:(id)target selector:(SEL)selector {
    self = [super init];
    if (self != nil) {
        self->_URL = [URL retain];
        self->_target = target;
        self->_selector = selector;

        NSString *watchingPath = [URL.path stringByDeletingLastPathComponent];
        NSLog(@"Watching %@", watchingPath);
        NSArray *pathsToWatch = [NSArray arrayWithObject:watchingPath];

        FSEventStreamContext context = {0, (void *)self, NULL, NULL, NULL};
        CFAbsoluteTime latency = 1.0; // Latency in seconds

        /* Create the stream, passing in a callback */
        self->stream = FSEventStreamCreate(NULL,
                                           &WDFileEventCallback,
                                           &context,
                                           (CFArrayRef) pathsToWatch,
                                           kFSEventStreamEventIdSinceNow, /* Or a previous event ID */
                                           (CFAbsoluteTime) latency,
                                           kFSEventStreamCreateFlagUseCFTypes
                                           );

        FSEventStreamScheduleWithRunLoop(self->stream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
        [self start];
    }
    return self;
}

+ (id)eventWithURL:(NSURL *)URL target:(id)target selector:(SEL)selector {
    return [[[self alloc] initWithURL:URL target:target selector:selector] autorelease];
}

- (void)dealloc {
    [self stop];
    FSEventStreamInvalidate(self->stream);
    FSEventStreamRelease(self->stream);

    [self->_URL release];
    [super dealloc];
}

- (void)start {
    NSError *error = nil;
    NSDictionary *attirbutes = [[NSFileManager defaultManager] attributesOfItemAtPath:self->_URL.path error:&error];
    self.modificationDate = [attirbutes objectForKey:NSFileModificationDate];
    FSEventStreamStart(self->stream);
}

- (void)stop {
    FSEventStreamStop(self->stream);
}

@end


@implementation WDDocument
@synthesize source=_source;
@synthesize fileEvent=_fileEvent;
@synthesize renderView=_renderView;
@synthesize editView=_editView;

- (void)awakeFromNib {
    NSString *template = [NSString stringWithContentsOfURL:@"res://template.html".resourceURL encoding:NSUTF8StringEncoding error:NULL];
    NSString *css = [WDPreferenceWindowController themeString];
    self->_template = [[template stringByReplacingOccurrencesOfString:@"{{ style }}" withString:css] retain];
    if (self.source) {
        self.editView.string = self.source;
    }
}

- (void)dealloc {
    [self cleanRenderThread];
    [self->_template release];
    self->_template = nil;

    self.source = nil;
    self.fileEvent = nil;
    [super dealloc];
}

- (NSString *)source {
    if (self->_source == nil) {
        self->_source = [[NSString alloc] initWithContentsOfURL:self.fileURL encoding:NSUTF8StringEncoding error:NULL];
    }
    return self->_source;
}

- (void)setSource:(NSString *)source {
    if (self->_source == source) return;
    
    [self->_source autorelease];
    self->_source = [source retain];

    if (source) {
        [self render];
    }
}

#pragma mark fileevent

- (void)documentSourceDidChanged {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.delegate = self;
    alert.alertStyle = NSInformationalAlertStyle;
    alert.messageText = @"Your document source in filesystem has been changed. Do you want to revert to the file or keep this version?";
    [alert addButtonWithTitle:@"Keep this version"];
    [alert addButtonWithTitle:@"Revert"];
    NSInteger returnCode = [alert runModal];
    if (returnCode == NSAlertSecondButtonReturn) {
        NSError *error = nil;
        NSString *source = [NSString stringWithContentsOfURL:self.fileURL encoding:NSUTF8StringEncoding error:&error];
        if (error) {
            [[NSAlert alertWithError:error] beginSheetModalForWindow:nil modalDelegate:nil didEndSelector:nil contextInfo:nil];
        } else {
            self.editView.string = source;
        }
    }
    [alert release];
}

#pragma mark NSDocument

- (NSString *)windowNibName
{
    // Override returning the nib file name of the document
    // If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this method and override -makeWindowControllers instead.
    return @"WDDocument";
}

- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)error {
    NSString *source = [NSString stringWithContentsOfURL:absoluteURL encoding:NSUTF8StringEncoding error:error];
    self.source = source;
    self.fileEvent = [WDFileEvent eventWithURL:absoluteURL target:self selector:@selector(documentSourceDidChanged)];
    return *error == nil;
}

- (BOOL)writeToURL:(NSURL *)absoluteURL ofType:(NSString *)typeName forSaveOperation:(NSSaveOperationType)saveOperation originalContentsURL:(NSURL *)absoluteOriginalContentsURL error:(NSError **)error {
    
    [self.source writeToURL:absoluteURL atomically:YES encoding:NSUTF8StringEncoding error:error];
    return *error == nil;
}

- (NSPrintOperation *)printOperationWithSettings:(NSDictionary *)printSettings error:(NSError **)outError {
    NSPrintOperation *printOperation = [NSPrintOperation printOperationWithView:self.renderView];
    return printOperation;
}

#pragma mark render

- (void)render {
    @synchronized(self) {
        if (self->_renderThread) {
            self->_renderRequested = YES;
        } else {
            self->_renderThread = [[NSThread alloc] initWithTarget:self selector:@selector(renderBackground) object:nil];
            [self->_renderThread start];
        }
    }
}

- (void)renderBackground {
    NSString *markdown = [self.source stringWithMarkdownAndSmartyPants];
    NSString *result = [self->_template stringByReplacingOccurrencesOfString:@"{{ body }}" withString:markdown];
    if (self->_renderThread && result) {
        [self performSelectorOnMainThread:@selector(renderFinished:) withObject:result waitUntilDone:NO];
    } else {
        [self cleanRenderThread];
    }
}

- (void)renderFinished:(NSString *)result {
    self->_renderOffset = [[self.renderView.windowScriptObject evaluateWebScript:@"window.pageYOffset"] integerValue];
    self.renderView.policyDelegate = nil;
    [self.renderView.mainFrame loadHTMLString:result baseURL:self.fileURL];

    BOOL needRender = NO;
    @synchronized(self) {
        [self cleanRenderThread];
        if (self->_renderRequested) {
            self->_renderRequested = NO;
            needRender = YES;
        }
    }
    if (needRender) {
        [self render];
    }
}

- (void)cleanRenderThread {
    if (self->_renderThread) {
        if (self->_renderThread.isExecuting) {
            [self->_renderThread cancel];
        }
        [self->_renderThread release];
        self->_renderThread = nil;
    }
}

#pragma mark render view delegate

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame {
    NSInteger yOffset = self->_renderOffset;
    NSRect visibleRect = self.editView.visibleRect;
    if (visibleRect.origin.y + visibleRect.size.height > self.editView.frame.size.height - 10) {
        yOffset = 0x100000; // hard code page length
    }
    [sender.windowScriptObject evaluateWebScript:[@"window.scrollTo(0, %d)" format0:nil, yOffset]];
    sender.policyDelegate = self;
}

- (void)webView:(WebView *)sender decidePolicyForNavigationAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id<WebPolicyDecisionListener>)listener
{
	[listener ignore];
	[[NSWorkspace sharedWorkspace] openURL:[request URL]];
}

- (void)webView:(WebView *)sender decidePolicyForNewWindowAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request newFrameName:(NSString *)frameName decisionListener:(id<WebPolicyDecisionListener>)listener
{
	[self webView:sender decidePolicyForNavigationAction:actionInformation request:request frame:sender.mainFrame decisionListener:listener];
}

#pragma mark edit view delegate

- (void)textDidChange:(NSNotification *)notification {
    if (![self.editView.string isEqualToString:self.source]) {
        self.source = [[self.editView.string copy] autorelease];
    }
}

@end
