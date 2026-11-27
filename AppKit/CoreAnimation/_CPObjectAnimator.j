
@import <Foundation/CPProxy.j>
@import "CPAnimationContext.j"

var _supportsCSSAnimations = null;

@protocol CPAnimatablePropertyContainer <CPObject>

+ (id)defaultAnimationForKey:(CPString)key;
- (id)animationForKey:(CPString)key;

- (id)animator;
- (CPDictionary)animations;
- (void)setAnimations:(CPDictionary)animations;

@end

@implementation _CPObjectAnimator : CPProxy
{
    id <CPAnimatablePropertyContainer> _target;
}

+ (void)initialize
{
    if ([self class] !== [_CPObjectAnimator class])
        return;

    var compat = (CPBrowserCSSProperty("animation") != nil);
    CPSetPlatformFeature(CPCSSAnimationFeature, compat);
}

- (id)initWithTarget:(id)aTarget
{
    _target = aTarget;

    return self;
}

- (id)animator
{
    return self;
}

- (BOOL)isEqual:(id)anObject
{
   return [_target isEqual:anObject];
}

/*
    Returns nil, so that the runtime sends every call the animator does not implement through
    -forwardInvocation:, which runs it as an animator operation. With the target returned here,
    the runtime sent the call straight to the target, outside any group.
*/
- (id)forwardingTargetForSelector:(SEL)aSelector
{
    return nil;
}

/*
    The runtime forwards a call through -forwardInvocation: only when it gets a signature.
    Method signatures are not implemented, so, as CPUndoManager's proxy does, the animator gives
    a placeholder for each selector its target responds to. Any other selector reaches
    -doesNotRecognizeSelector:.
*/
- (CPMethodSignature)methodSignatureForSelector:(SEL)aSelector
{
    return [_target respondsToSelector:aSelector] ? 1 : nil;
}

/*
    Runs a forwarded call as an animator operation, so that a framework operation such as
    -[CPOutlineView collapseItem:] can tell that the developer asked for it to animate. The
    current context carries the mark for the length of the call. The call stays in the caller's
    group, so its animations end with that group and its completion handler waits for them.
*/
- (void)forwardInvocation:(CPInvocation)anInvocation
{
    var context = [CPAnimationContext currentContext],
        wasAnimatorOperation = [context _isAnimatorOperation];

    [context _setAnimatorOperation:YES];

    try
    {
        [anInvocation invokeWithTarget:_target];
    }
    finally
    {
        [context _setAnimatorOperation:wasAnimatorOperation];
    }
}

- (void)doesNotRecognizeSelector:(SEL)aSelector
{
    [CPException raise:CPInvalidArgumentException reason:@"Animator does not recognize selector " + CPStringFromSelector(aSelector)];
}

- (CPString)description
{
    return [CPString stringWithFormat:@"%@ Animator Proxy for %@", [self class], _target];
}

- (void)setValue:(id)aTargetValue forKey:(id)aKeyPath
{
    var animation = [_target animationForKey:aKeyPath],
        context = [CPAnimationContext currentContext];

    if (!animation || ![animation isKindOfClass:[CAAnimation class]] || (![context duration] && ![animation duration]) || !CPFeatureIsCompatible(CPCSSAnimationFeature))
        [_target setValue:aTargetValue forKey:aKeyPath];
    else
    {
        [context _enqueueActionForObject:_target keyPath:aKeyPath targetValue:aTargetValue animationCompletion:function()
        {
            [_target setValue:aTargetValue forKey:aKeyPath];
        }];
    }
}

@end
