/*
 *  ATMHud.m
 *  ATMHud
 *
 *  Created by Marcel Müller on 2011-03-01.
 *  Copyright (c) 2010-2011, Marcel Müller (atomcraft)
 *  All rights reserved.
 *
 *	https://github.com/atomton/ATMHud
 */

#import "ATMHud.h"
#import <QuartzCore/QuartzCore.h>
#import <AudioToolbox/AudioServices.h>
#import "ATMHudView.h"
#import "ATMProgressLayer.h"
#import "ATMHudDelegate.h"
#import "ATMSoundFX.h"
#import "ATMHudQueueItem.h"

@interface ATMHud (Private)
- (void)construct;
@end

@implementation ATMHud
@synthesize margin, padding, alpha, appearScaleFactor, disappearScaleFactor, progressBorderRadius, progressBorderWidth, progressBarRadius, progressBarInset;
@synthesize delegate, accessoryPosition;
@synthesize center;
@synthesize shadowEnabled, blockTouches, allowSuperviewInteraction;
@synthesize showSound, updateSound, hideSound;
@synthesize __view, sound, displayQueue, queuePosition;

- (id)init {
	if ((self = [super init])) {
		[self construct];
	}
	return self;
}

- (id)initWithDelegate:(id)hudDelegate {
	if ((self = [super init])) {
		delegate = hudDelegate;
		[self construct];
	}
	return self;
}

- (id)initWithView:(UIView*)view delegate:(id)hudDelegate {
	if ((self = [self initWithDelegate:hudDelegate])) {
		delegate = hudDelegate;
		[self construct];
		[view addSubview:self.view];
	}
	return self;
}

- (void)loadView {
	UIView *base = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	base.backgroundColor = [UIColor clearColor];
	base.autoresizingMask = (UIViewAutoresizingFlexibleWidth);
	base.userInteractionEnabled = NO;
	[base addSubview:__view];
	
	self.view = base;
	[base release];
}

- (void) addToMainWindow
{
    [self removeFromView];
    UIWindow* window = nil;
    if ([UIApplication sharedApplication].windows.count > 0)
    {
        window = [[UIApplication sharedApplication].windows objectAtIndex:0];
    }
	[window.rootViewController.view addSubview:self.view];
}

- (void) removeFromView
{
	[self.view removeFromSuperview];
}

- (void)showWithStatus:(NSString*)status
{
	[self setCaption:status];
	[self setActivity:YES];
	[self show];
    //LogRect(__view.frame);
}

- (void)showWithSuccess:(NSString*)success
{
    [self show];
    [self hideWithSuccess:success];
}


- (void)viewDidLoad {
    [super viewDidLoad];
}

- (BOOL) shouldAutorotate
{
    return YES;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)viewDidUnload {
    [super viewDidUnload];
}

- (void)dealloc {
	[sound release];
	[__view release];
	[displayQueue release];
	
	[showSound release];
	[updateSound release];
	[hideSound release];
	
    [super dealloc];
}

+ (NSString *)buildInfo {
	return @"atomHUD 1.2 • 2011-03-01";
}

#pragma mark -
#pragma mark Overrides
- (void)setAppearScaleFactor:(CGFloat)value {
	if (value == 0) {
		value = 0.01;
	}
	appearScaleFactor = value;
}

- (void)setDisappearScaleFactor:(CGFloat)value {
	if (value == 0) {
		value = 0.01;
	}
	disappearScaleFactor = value;
}

- (void)setAlpha:(CGFloat)value {
	alpha = value;
	[CATransaction begin];
	[CATransaction setDisableActions:YES];
	__view.backgroundLayer.backgroundColor = [UIColor colorWithWhite:0.0 alpha:value].CGColor;
	[CATransaction commit];
}

- (void)setShadowEnabled:(BOOL)value {
	shadowEnabled = value;
	if (shadowEnabled) {
		__view.layer.shadowOpacity = 0.4;
	} else {
		__view.layer.shadowOpacity = 0.0;
	}
}

#pragma mark -
#pragma mark Property forwards
- (void)setCaption:(NSString *)caption {
	__view.caption = caption;
}

- (void)setImage:(UIImage *)image {
	__view.image = image;
}

- (void)setActivity:(BOOL)activity {
	__view.showActivity = activity;
	if (activity) {
		[__view.activity startAnimating];
	} else {
		[__view.activity stopAnimating];
	}
}

- (void)setActivityStyle:(UIActivityIndicatorViewStyle)activityStyle {
	__view.activityStyle = activityStyle;
	if (activityStyle == UIActivityIndicatorViewStyleWhiteLarge) {
		__view.activitySize = CGSizeMake(37, 37);
	} else {
		__view.activitySize = CGSizeMake(20, 20);
	}
}

- (void)setFixedSize:(CGSize)fixedSize {
	__view.fixedSize = fixedSize;
}

- (void)setProgress:(CGFloat)progress {
	__view.progress = progress;
	
	[__view.progressLayer setTheProgress:progress];
	[__view.progressLayer setNeedsDisplay];
}

#pragma mark -
#pragma mark Queue
- (void)addQueueItem:(ATMHudQueueItem *)item {
	[displayQueue addObject:item];
}

- (void)addQueueItems:(NSArray *)items {
	[displayQueue addObjectsFromArray:items];
}

- (void)clearQueue {
	[displayQueue removeAllObjects];
}

- (void)startQueue {
	queuePosition = 0;
	if (!CGSizeEqualToSize(__view.fixedSize, CGSizeZero)) {
		CGSize newSize = __view.fixedSize;
		CGSize targetSize;
		ATMHudQueueItem *queueItem;
		for (int i = 0; i < [displayQueue count]; i++) {
			queueItem = [displayQueue objectAtIndex:i];
			
			targetSize = [__view calculateSizeForQueueItem:queueItem];
			if (targetSize.width > newSize.width) {
				newSize.width = targetSize.width;
			}
			if (targetSize.height > newSize.height) {
				newSize.height = targetSize.height;
			}
		}
		[self setFixedSize:newSize];
	}
	[self showQueueAtIndex:queuePosition];
}

- (void)showNextInQueue {
	queuePosition++;
	[self showQueueAtIndex:queuePosition];
}

- (void)showQueueAtIndex:(NSInteger)index {
	if ([displayQueue count] > 0) {
		queuePosition = index;
		if (queuePosition == [displayQueue count]) {
			[self hide];
			return;
		}
		ATMHudQueueItem *item = [displayQueue objectAtIndex:queuePosition];
		
		__view.caption = item.caption;
		__view.image = item.image;
		
		BOOL flag = item.showActivity;
		__view.showActivity = flag;
		if (flag) {
			[__view.activity startAnimating];
		} else {
			[__view.activity stopAnimating];
		}
		
		self.accessoryPosition = item.accessoryPosition;
		[self setActivityStyle:item.activityStyle];
		
		if (queuePosition == 0) {
			[__view show];
		} else {
			[__view update];
		}
	}
}

#pragma mark -
#pragma mark Controlling
- (void)show
{
    // PD modification. ref: https://github.com/atomton/ATMHud/issues/12
	NSAssert([NSThread currentThread] == [NSThread mainThread], @"only execute this from the main thread");
    UIView *sv = [self.view superview];
    self.view.center = CGPointMake(sv.bounds.origin.x + sv.bounds.size.width/2, sv.bounds.origin.y + sv.bounds.size.height/2);
    //
	[__view show];
}

- (void) apply
{
    [__view applyWithMode:ATMHudApplyModeUpdate];
}

- (void)update
{
	NSAssert([NSThread currentThread] == [NSThread mainThread], @"only execute this from the main thread");

	[__view update];
}

- (void)hide
{
	NSAssert([NSThread currentThread] == [NSThread mainThread], @"only execute this from the main thread");
    
    // only animate hiding if view is visible. otherwise seems to cause problems (view not fully hidden)
    if (self.isViewLoaded && self.view.window)
    {
        [self hide:YES];
    }
    else
    {
        [self hide:NO];
    }
}

- (void)hide:(BOOL)animated
{
	NSAssert([NSThread currentThread] == [NSThread mainThread], @"only execute this from the main thread");

	[__view hide:animated];
}


- (void)hideAfter:(NSTimeInterval)delay {
	[self performSelector:@selector(hide) withObject:nil afterDelay:delay];
}

- (void) hideWithError:(NSString *)errorString
{
    [self hideWithError:errorString afterDelay:2];
}

- (void) hideWithSuccess:(NSString *)successString
{
    [self hideWithSuccess:successString afterDelay:2];
}

- (void)hideWithSuccess:(NSString*)successString afterDelay:(NSTimeInterval)seconds
{
	[self setCaption:successString];
	[self setActivity:NO];
	[self setImage:[UIImage imageNamed:@"19-check"]];
	[self update];
	[self hideAfter:seconds];
}

- (void)hideWithError:(NSString*)errorString afterDelay:(NSTimeInterval)seconds
{
	[self setCaption:errorString];
	[self setActivity:NO];
	[self setImage:[UIImage imageNamed:@"11-x.png"]];
	[self update];
	[self hideAfter:seconds];
}

#pragma mark -
#pragma mark Internal methods
- (void)construct {
	margin = padding = 10.0;
	alpha = 0.7;
	progressBorderRadius = 8.0;
	progressBorderWidth = 2.0;
	progressBarRadius = 5.0;
	progressBarInset = 3.0;
	accessoryPosition = ATMHudAccessoryPositionBottom;
	appearScaleFactor = disappearScaleFactor = 1.2;
	
	__view = [[ATMHudView alloc] initWithFrame:CGRectZero andController:self];
	__view.autoresizingMask = (UIViewAutoresizingFlexibleTopMargin |
							   UIViewAutoresizingFlexibleRightMargin |
							   UIViewAutoresizingFlexibleBottomMargin |
							   UIViewAutoresizingFlexibleLeftMargin);
	
	displayQueue = [[NSMutableArray alloc] init];
	queuePosition = 0;
	center = CGPointZero;
	blockTouches = NO;
	allowSuperviewInteraction = NO;

}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
	if (!blockTouches) {
		UITouch *aTouch = [touches anyObject];
		if (aTouch.tapCount == 1) {
			CGPoint p = [aTouch locationInView:self.view];
			if (CGRectContainsPoint(__view.frame, p)) {
				if ([(id)self.delegate respondsToSelector:@selector(userDidTapHud:)]) {
					[self.delegate userDidTapHud:self];
				}
			}
		}
	}
}

- (void)playSound:(NSString *)soundPath {
	sound = [[ATMSoundFX alloc] initWithContentsOfFile:soundPath];
	[sound play];
}

// PD modification. ref: https://github.com/atomton/ATMHud/issues/12
- (void)setCenter:(CGPoint)pt
{
    center = pt;
    
    if(__view) __view.center = center;
}

@end
