/*
 * AppController.j
 * CPViewController
 *
 * Created by You on November 11, 2015.
 * Copyright 2015, Your Company All rights reserved.
 */

@import <Foundation/Foundation.j>
@import <AppKit/AppKit.j>

@implementation Button : CPButton
{
}

- (void)mouseDown:(CPEvent)anEvent
{
    [[CPApp delegate] load];
    [super mouseDown:anEvent];
}

- (void)mouseUp:(CPEvent)anEvent
{
    [[CPApp delegate] removeSubviews];
    [super mouseUp:anEvent];
}

@end

@implementation AppController : CPObject
{
    @outlet CPWindow    theWindow;
    @outlet CPView      containerView;

            BOOL        async @accessors;
}

- (void)applicationDidFinishLaunching:(CPNotification)aNotification
{
    // This is called when the application is done loading.
}

- (void)awakeFromCib
{
    // This is called when the cib is done loading.
    // You can implement this method on any object instantiated from a Cib.
    // It's a useful hook for setting up current UI values, and other things.

    // In this case, we want the window from Cib to become our full browser window
    [theWindow setFullPlatformWindow:NO];

}

- (void)load
{
    if (async)
        [self loadAsync];
    else
        [self loadSync];
}

- (void)loadAsync
{
    var vcOuter = [[CPViewController alloc] initWithCibName:@"ViewControllerOuter" bundle:nil];
    var vcInner = [[CPViewController alloc] initWithCibName:@"ViewControllerInner" bundle:nil];

    [vcOuter loadViewWithCompletionHandler:function(viewOuter, error)
    {
        [viewOuter setBackgroundColor:[CPColor redColor]];
		[containerView addSubview:viewOuter];

        [vcInner loadViewWithCompletionHandler:function(viewInner, error)
        {
            [viewInner setBackgroundColor:[CPColor greenColor]];
            [viewOuter addSubview:viewInner];
        }];
    }];
}

- (void)loadSync
{
    var vcOuter = [[CPViewController alloc] initWithCibName:@"ViewControllerOuter" bundle:nil];
    var vcInner = [[CPViewController alloc] initWithCibName:@"ViewControllerInner" bundle:nil];

    var viewOuter = [vcOuter view];
    [viewOuter setBackgroundColor:[CPColor redColor]];
	[containerView addSubview:viewOuter];

    var viewInner = [vcInner view];
    [viewInner setBackgroundColor:[CPColor greenColor]];
    [viewOuter addSubview:viewInner];
}

- (@action)removeSubviews:(id)sender
{
	[[containerView subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
}

@end
