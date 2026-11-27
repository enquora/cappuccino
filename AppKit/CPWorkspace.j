/*
 * CPWorkspace.j
 * AppKit
 *
 * Created by Alexander Ljungberg.
 * Copyright 2012, SlevenBits Ltd.
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


@import <Foundation/CPString.j>
@import <Foundation/CPNotificationCenter.j>

/*!
    Posted on the workspace's notification center when an accessibility display option, such as
    -accessibilityDisplayShouldReduceMotion, changes.
*/
CPWorkspaceAccessibilityDisplayOptionsDidChangeNotification = @"CPWorkspaceAccessibilityDisplayOptionsDidChangeNotification";

var SharedWorkspace = nil;

/*
    2026-11-26: a framework animation had no way to learn that the user asked for reduced
    motion. The workspace now reports the browser's prefers-reduced-motion setting, as
    NSWorkspace reports the system setting, and an application may ask for reduced motion in
    addition to it.
*/
@implementation CPWorkspace : CPObject
{
    CPNotificationCenter    _notificationCenter;
    BOOL                    _applicationShouldReduceMotion;
    BOOL                    _systemShouldReduceMotion;
    BOOL                    _lastReportedReduceMotion;
    id                      _systemReduceMotionOverride;
    Object                  _reduceMotionQuery;
}

+ (CPWorkspace)sharedWorkspace
{
    if (!SharedWorkspace)
        SharedWorkspace = [CPWorkspace new];

    return SharedWorkspace;
}

- (id)init
{
    if (self = [super init])
    {
        _notificationCenter = [[CPNotificationCenter alloc] init];
        _applicationShouldReduceMotion = NO;
        _systemShouldReduceMotion = NO;
        _systemReduceMotionOverride = nil;
        _reduceMotionQuery = nil;

        if (typeof window !== "undefined" && window.matchMedia)
        {
            _reduceMotionQuery = window.matchMedia("(prefers-reduced-motion: reduce)");
            _systemShouldReduceMotion = !!_reduceMotionQuery.matches;

            var workspace = self,
                listener = function(anEvent)
                {
                    workspace._systemShouldReduceMotion = !!anEvent.matches;
                    [workspace _noteAccessibilityDisplayOptionsMayHaveChanged];
                };

            if (_reduceMotionQuery.addEventListener)
                _reduceMotionQuery.addEventListener("change", listener);
            else if (_reduceMotionQuery.addListener)
                _reduceMotionQuery.addListener(listener);
        }

        _lastReportedReduceMotion = [self accessibilityDisplayShouldReduceMotion];
    }

    return self;
}

/*!
    Returns the notification center for workspace notifications, as NSWorkspace does. It is not
    the default notification center.
*/
- (CPNotificationCenter)notificationCenter
{
    return _notificationCenter;
}

/*!
    Returns YES when animations should be reduced: the user asked for reduced motion in the
    browser, or the application asked for it with -setApplicationShouldReduceMotion:. Under
    reduced motion every framework animation goes straight to its end state.
*/
- (BOOL)accessibilityDisplayShouldReduceMotion
{
    var systemValue = _systemReduceMotionOverride !== nil ? !!_systemReduceMotionOverride : _systemShouldReduceMotion;

    return systemValue || _applicationShouldReduceMotion;
}

/*!
    Asks for reduced motion in addition to the browser setting. Cappuccino extension: an
    application can turn reduced motion on for users who cannot change their system setting,
    but cannot turn it off when the browser asks for it.
*/
- (void)setApplicationShouldReduceMotion:(BOOL)shouldReduceMotion
{
    _applicationShouldReduceMotion = !!shouldReduceMotion;
    [self _noteAccessibilityDisplayOptionsMayHaveChanged];
}

- (BOOL)applicationShouldReduceMotion
{
    return _applicationShouldReduceMotion;
}

/*
    Sets the value the browser setting is taken to have, for tests. nil returns to the
    browser setting.
*/
- (void)_setSystemReduceMotionOverride:(id)aValue
{
    _systemReduceMotionOverride = aValue;
    [self _noteAccessibilityDisplayOptionsMayHaveChanged];
}

- (void)_noteAccessibilityDisplayOptionsMayHaveChanged
{
    var value = [self accessibilityDisplayShouldReduceMotion];

    if (value === _lastReportedReduceMotion)
        return;

    _lastReportedReduceMotion = value;
    [_notificationCenter postNotificationName:CPWorkspaceAccessibilityDisplayOptionsDidChangeNotification object:self];
}

- (BOOL)openFile:(CPString)fullPath
{
    var url = [CPURL URLWithString:fullPath];
    return [self openURL:url];
}

- (BOOL)openURL:(CPURL)url
{
    if (!url || ![url absoluteURL])
        return NO;
    window.open([url absoluteURL]);
    return YES;
}

@end
