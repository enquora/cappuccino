/*
 * SettingsWindowController.j
 * People
 *
 * Settings window with the application's appearance: Light, Dark or Auto, which follows
 * the system, and a Reduce motion switch. The choices are kept in the user defaults and
 * applied at launch.
 * Exercises CPSegmentedControl, CPCheckBox, CPPanel, CPApplication's appearance and
 * CPWorkspace's reduced motion.
 *
 * Reduce motion sets the application's own value. It can turn reduced motion on, but it
 * cannot turn off the system setting: the workspace reduces motion when either one is on.
 */

@import <AppKit/AppKit.j>

var SettingsAppearanceKey   = @"PeopleAppearance",
    SettingsAppearanceNames = [CPAppearanceNameAqua, CPAppearanceNameDarkAqua, nil],
    SettingsAutoSegment     = 2,
    SettingsReduceMotionKey = @"PeopleReduceMotion",
    SettingsDidResetNotification = @"SettingsDidResetNotification";

@implementation SettingsWindowController : CPWindowController
{
    CPSegmentedControl  _appearanceControl;
    CPCheckBox          _reduceMotionCheckBox;
}

/*
    Applies the settings kept in the user defaults. Without an appearance, the application
    follows the system appearance. Without a Reduce motion value, it follows the system
    setting only.
*/
+ (void)applySavedSettings
{
    var defaults = [CPUserDefaults standardUserDefaults],
        segment = [defaults objectForKey:SettingsAppearanceKey];

    [self _applyAppearanceOfSegment:segment == nil ? SettingsAutoSegment : segment];
    [[CPWorkspace sharedWorkspace] setApplicationShouldReduceMotion:[defaults boolForKey:SettingsReduceMotionKey]];
}

/*
    Removes the kept settings, so the application follows the system appearance and the system
    reduced motion setting again. An open Settings window shows Auto and an unchecked Reduce
    motion.
*/
+ (void)resetSettings
{
    var defaults = [CPUserDefaults standardUserDefaults];

    [defaults removeObjectForKey:SettingsAppearanceKey];
    [defaults removeObjectForKey:SettingsReduceMotionKey];
    [self _applyAppearanceOfSegment:SettingsAutoSegment];
    [[CPWorkspace sharedWorkspace] setApplicationShouldReduceMotion:NO];
    [[CPNotificationCenter defaultCenter] postNotificationName:SettingsDidResetNotification object:self];
}

+ (void)_applyAppearanceOfSegment:(int)aSegment
{
    var name = SettingsAppearanceNames[aSegment];

    [CPApp setAppearance:name ? [CPAppearance appearanceNamed:name] : nil];
}

- (id)init
{
    var panel = [[CPPanel alloc] initWithContentRect:CGRectMake(0, 0, 320, 120) styleMask:CPTitledWindowMask | CPClosableWindowMask];

    if (self = [super initWithWindow:panel])
    {
        [panel setTitle:@"Settings"];

        var contentView = [panel contentView],
            label = [CPTextField labelWithTitle:@"Appearance:"];

        [label sizeToFit];
        [label setFrameOrigin:CGPointMake(20, 24)];
        [contentView addSubview:label];

        _appearanceControl = [[CPSegmentedControl alloc] initWithFrame:CGRectMake(110, 20, 180, 24)];
        [_appearanceControl setSegmentCount:3];
        [_appearanceControl setLabel:@"Light" forSegment:0];
        [_appearanceControl setLabel:@"Dark" forSegment:1];
        [_appearanceControl setLabel:@"Auto" forSegment:2];
        [_appearanceControl setWidth:60 forSegment:0];
        [_appearanceControl setWidth:60 forSegment:1];
        [_appearanceControl setWidth:60 forSegment:2];
        [_appearanceControl setTarget:self];
        [_appearanceControl setAction:@selector(appearanceDidChange:)];
        [contentView addSubview:_appearanceControl];

        var segment = [[CPUserDefaults standardUserDefaults] objectForKey:SettingsAppearanceKey];
        [_appearanceControl setSelectedSegment:segment == nil ? SettingsAutoSegment : segment];

        _reduceMotionCheckBox = [CPCheckBox checkBoxWithTitle:@"Reduce motion"];
        [_reduceMotionCheckBox sizeToFit];
        [_reduceMotionCheckBox setFrameOrigin:CGPointMake(110, 64)];
        [_reduceMotionCheckBox setState:[[CPUserDefaults standardUserDefaults] boolForKey:SettingsReduceMotionKey] ? CPOnState : CPOffState];
        [_reduceMotionCheckBox setTarget:self];
        [_reduceMotionCheckBox setAction:@selector(reduceMotionDidChange:)];
        [contentView addSubview:_reduceMotionCheckBox];

        [[CPNotificationCenter defaultCenter] addObserver:self selector:@selector(settingsDidReset:) name:SettingsDidResetNotification object:nil];

        [panel center];
    }

    return self;
}

- (void)settingsDidReset:(CPNotification)aNotification
{
    [_appearanceControl setSelectedSegment:SettingsAutoSegment];
    [_reduceMotionCheckBox setState:CPOffState];
}

- (void)appearanceDidChange:(id)aSender
{
    var segment = [aSender selectedSegment];

    [[CPUserDefaults standardUserDefaults] setObject:segment forKey:SettingsAppearanceKey];
    [[self class] _applyAppearanceOfSegment:segment];
}

- (void)reduceMotionDidChange:(id)aSender
{
    var shouldReduceMotion = [aSender state] === CPOnState;

    [[CPUserDefaults standardUserDefaults] setBool:shouldReduceMotion forKey:SettingsReduceMotionKey];
    [[CPWorkspace sharedWorkspace] setApplicationShouldReduceMotion:shouldReduceMotion];
}

@end
