/*
 *  CPOutlineViewDisclosureAnimationTest.j
 *  AppKit
 *
 *  Created by David Richardson on 2026-11-26.
 *  Copyright David Richardson 2026.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 */

@import <AppKit/AppKit.j>

/*
    As in AppKit, a direct -expandItem: or -collapseItem: does not animate. It animates when the
    developer calls it through the animator, for the animation context's duration, or 0.25
    seconds when the context sets none; an explicit duration of 0 turns the animation off. It
    also animates when the user presses an arrow key. Under reduced motion nothing animates.

    A collapse that animates shows copies of the removed rows, plain views, while the rows slide.
    The animation does not run in a unit test, so the copies stay, and their presence shows
    whether the collapse animated.
*/
@implementation DisclosureAnimationItem : CPObject
{
    CPArray     children    @accessors;
}

+ (id)itemWithChildren:(CPArray)someChildren
{
    var item = [[self alloc] init];

    [item setChildren:someChildren];

    return item;
}

@end

@implementation CPOutlineViewDisclosureAnimationTest : OJTestCase
{
    CPWindow        theWindow;
    CPOutlineView   outlineView;
    CPArray         rootItems;
}

- (void)setUp
{
    // This will init the global var CPApp which are used internally in the AppKit
    [[CPApplication alloc] init];

    [[CPWorkspace sharedWorkspace] _setSystemReduceMotionOverride:NO];
    [[CPWorkspace sharedWorkspace] setApplicationShouldReduceMotion:NO];

    theWindow = [[CPWindow alloc] initWithContentRect:CGRectMake(0.0, 0.0, 400.0, 400.0) styleMask:CPWindowNotSizable];

    rootItems = [];

    for (var i = 0; i < 5; i++)
        rootItems.push([DisclosureAnimationItem itemWithChildren:[[DisclosureAnimationItem itemWithChildren:[]], [DisclosureAnimationItem itemWithChildren:[]]]]);

    var column = [[CPTableColumn alloc] initWithIdentifier:@"Column"];

    outlineView = [[CPOutlineView alloc] initWithFrame:CGRectMake(0.0, 0.0, 300.0, 200.0)];
    [outlineView addTableColumn:column];
    [outlineView setOutlineTableColumn:column];

    var scrollView = [[CPScrollView alloc] initWithFrame:CGRectMake(0.0, 0.0, 300.0, 200.0)];
    [scrollView setDocumentView:outlineView];
    [[theWindow contentView] addSubview:scrollView];

    [outlineView setDataSource:self];
    [outlineView reloadData];
    [outlineView expandItem:rootItems[1]];
    [outlineView layoutIfNeeded];
}

- (void)tearDown
{
    [[CPWorkspace sharedWorkspace] setApplicationShouldReduceMotion:NO];
    [[CPWorkspace sharedWorkspace] _setSystemReduceMotionOverride:nil];
}

- (id)outlineView:(CPOutlineView)anOutlineView child:(CPInteger)anIndex ofItem:(id)anItem
{
    return anItem ? [anItem children][anIndex] : rootItems[anIndex];
}

- (BOOL)outlineView:(CPOutlineView)anOutlineView isItemExpandable:(id)anItem
{
    return [[anItem children] count] > 0;
}

- (int)outlineView:(CPOutlineView)anOutlineView numberOfChildrenOfItem:(id)anItem
{
    return anItem ? [[anItem children] count] : rootItems.length;
}

- (id)outlineView:(CPOutlineView)anOutlineView objectValueForTableColumn:(CPTableColumn)aColumn byItem:(id)anItem
{
    return @"Item";
}

/*
    The number of plain views in the outline view: the copies a collapse shows while it animates.
*/
- (int)rowCopyCount
{
    return [outlineView subviews].filter(function(aView)
    {
        return [aView class] === [CPView class];
    }).length;
}

- (void)testADirectCollapseDoesNotAnimate
{
    var copiesBefore = [self rowCopyCount];

    [outlineView collapseItem:rootItems[1]];

    [self assertFalse:[outlineView isItemExpanded:rootItems[1]] message:@"the item collapsed"];
    [self assert:copiesBefore equals:[self rowCopyCount] message:@"no row copies"];
}

- (void)testACollapseThroughTheAnimatorAnimates
{
    var copiesBefore = [self rowCopyCount];

    [[outlineView animator] collapseItem:rootItems[1]];

    [self assertFalse:[outlineView isItemExpanded:rootItems[1]] message:@"the item collapsed"];
    [self assertTrue:[self rowCopyCount] > copiesBefore message:@"row copies are shown while the rows slide"];
}

- (void)testAnExplicitZeroDurationTurnsTheAnimationOff
{
    var copiesBefore = [self rowCopyCount];

    [CPAnimationContext runAnimationGroup:function(aContext)
    {
        [aContext setDuration:0.0];
        [[outlineView animator] collapseItem:rootItems[1]];
    } completionHandler:nil];

    [self assertFalse:[outlineView isItemExpanded:rootItems[1]] message:@"the item collapsed"];
    [self assert:copiesBefore equals:[self rowCopyCount] message:@"no row copies"];
}

- (void)testReducedMotionStopsTheAnimation
{
    var copiesBefore = [self rowCopyCount];

    [[CPWorkspace sharedWorkspace] _setSystemReduceMotionOverride:YES];
    [[outlineView animator] collapseItem:rootItems[1]];

    [self assertFalse:[outlineView isItemExpanded:rootItems[1]] message:@"the item collapsed"];
    [self assert:copiesBefore equals:[self rowCopyCount] message:@"no row copies"];
}

- (void)testACollapseByTheUserWithTheLeftArrowKeyAnimates
{
    var copiesBefore = [self rowCopyCount],
        arrow = [CPEvent keyEventWithType:CPKeyDown location:CGPointMakeZero() modifierFlags:0
                                timestamp:0 windowNumber:[theWindow windowNumber] context:nil
                               characters:CPLeftArrowFunctionKey charactersIgnoringModifiers:CPLeftArrowFunctionKey
                                isARepeat:NO keyCode:123];

    [outlineView selectRowIndexes:[CPIndexSet indexSetWithIndex:[outlineView rowForItem:rootItems[1]]] byExtendingSelection:NO];
    [outlineView keyDown:arrow];

    [self assertFalse:[outlineView isItemExpanded:rootItems[1]] message:@"the item collapsed"];
    [self assertTrue:[self rowCopyCount] > copiesBefore message:@"row copies are shown while the rows slide"];
}

- (void)testAnOperationCalledThroughTheAnimatorStaysInTheCallersGroup
{
    var context = nil;

    [CPAnimationContext runAnimationGroup:function(aContext)
    {
        context = aContext;
        [[outlineView animator] collapseItem:rootItems[1]];

        [self assertTrue:[CPAnimationContext currentContext] === aContext message:@"the call left the current group in place"];
    } completionHandler:nil];

    [self assertFalse:[context _isAnimatorOperation] message:@"the mark ends with the call"];
}

@end
