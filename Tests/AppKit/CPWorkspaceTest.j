/*
 *  CPWorkspaceTest.j
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
    CPWorkspace reports whether animations should be reduced, as NSWorkspace does. The value is
    YES when the browser asks for reduced motion or the application does. An application can
    turn reduced motion on, never off. A change of the value is posted on the workspace's own
    notification center.

    The browser setting is replaced by a private override, so the tests do not depend on the
    machine that runs them.
*/
@implementation CPWorkspaceTest : OJTestCase
{
    CPWorkspace     workspace;
    int             notificationCount;
}

- (void)setUp
{
    workspace = [CPWorkspace sharedWorkspace];
    [workspace _setSystemReduceMotionOverride:NO];
    [workspace setApplicationShouldReduceMotion:NO];

    notificationCount = 0;
    [[workspace notificationCenter] addObserver:self
                                       selector:@selector(optionsDidChange:)
                                           name:CPWorkspaceAccessibilityDisplayOptionsDidChangeNotification
                                         object:workspace];
}

- (void)tearDown
{
    [[workspace notificationCenter] removeObserver:self];
    [workspace setApplicationShouldReduceMotion:NO];
    [workspace _setSystemReduceMotionOverride:nil];
}

- (void)optionsDidChange:(CPNotification)aNotification
{
    notificationCount++;
}

- (void)testMotionIsNotReducedByDefault
{
    [self assertFalse:[workspace accessibilityDisplayShouldReduceMotion]];
}

- (void)testTheBrowserSettingReducesMotion
{
    [workspace _setSystemReduceMotionOverride:YES];

    [self assertTrue:[workspace accessibilityDisplayShouldReduceMotion]];
}

- (void)testTheApplicationCanReduceMotion
{
    [workspace setApplicationShouldReduceMotion:YES];

    [self assertTrue:[workspace accessibilityDisplayShouldReduceMotion]];
}

- (void)testTheApplicationCannotTurnOffReducedMotionThatTheBrowserAsksFor
{
    [workspace _setSystemReduceMotionOverride:YES];
    [workspace setApplicationShouldReduceMotion:NO];

    [self assertTrue:[workspace accessibilityDisplayShouldReduceMotion]];
}

- (void)testAChangeIsPostedOnceOnTheWorkspaceNotificationCenter
{
    [workspace setApplicationShouldReduceMotion:YES];
    [workspace setApplicationShouldReduceMotion:YES];

    [self assert:1 equals:notificationCount message:@"one change, one notification"];

    [workspace setApplicationShouldReduceMotion:NO];

    [self assert:2 equals:notificationCount message:@"the change back is posted too"];
}

- (void)testNoChangeIsPostedWhenTheValueStaysTheSame
{
    [workspace _setSystemReduceMotionOverride:YES];
    notificationCount = 0;

    [workspace setApplicationShouldReduceMotion:YES];

    [self assert:0 equals:notificationCount];
}

- (void)testTheNotificationCenterIsNotTheDefaultCenter
{
    [self assertTrue:[workspace notificationCenter] !== [CPNotificationCenter defaultCenter]];
}

@end
