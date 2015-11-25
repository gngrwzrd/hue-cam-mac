
#import "CropSelector.h"

#define NoHandle 0
#define LeftHandleId 1
#define RightHandleId 2
#define HandleDrag 3
#define HandleSize 10

NSString * const CropSelectorCropRect = @"CropSelectorCropRect";

@interface CropSelector ()
@property CGRect topLeftHandle;
@property CGRect bottomRightHandle;
@property NSTrackingArea * topLeft;
@property NSTrackingArea * bottomRight;
@property CGPoint currentLocation;
@property int currentHandle;
@end

@implementation CropSelector

- (void) awakeFromNib {
	self.cropRect = CGRectInset(self.bounds,2,2);
	self.topLeftHandle = CGRectMake(0,self.bounds.size.height-HandleSize,HandleSize,HandleSize);
	self.bottomRightHandle = CGRectMake(self.bounds.size.width-HandleSize,0,HandleSize,HandleSize);
	self.currentHandle = NoHandle;
	
	if([[NSUserDefaults standardUserDefaults] objectForKey:CropSelectorCropRect]) {
		self.cropRect = NSRectFromString([[NSUserDefaults standardUserDefaults] objectForKey:CropSelectorCropRect]);
		
		CGFloat height = self.cropRect.size.height;
		CGFloat width = self.cropRect.size.width;
		
		self.topLeftHandle = CGRectMake(
			self.cropRect.origin.x,
			(self.cropRect.origin.y+height)-HandleSize,
			HandleSize,HandleSize);
		
		self.bottomRightHandle = CGRectMake(
			(self.topLeftHandle.origin.x + width) - HandleSize,
			self.cropRect.origin.y,
			HandleSize, HandleSize);
	}
}

- (void) drawRect:(NSRect) dirtyRect {
	[super drawRect:dirtyRect];
	
	NSString * rect = NSStringFromRect(self.cropRect);
	[[NSUserDefaults standardUserDefaults] setObject:rect forKey:CropSelectorCropRect];
	
	CGContextRef context = [[NSGraphicsContext currentContext] graphicsPort];
	
	[[NSGraphicsContext currentContext] saveGraphicsState];
	
	if(!self.displayOnly) {
		CGContextSetStrokeColorWithColor(context,[[NSColor yellowColor] CGColor]);
		CGContextSetFillColorWithColor(context,[[NSColor yellowColor] CGColor]);
	} else {
		CGContextSetStrokeColorWithColor(context,[[NSColor redColor] CGColor]);
		CGContextSetFillColorWithColor(context,[[NSColor redColor] CGColor]);
	}
	
	//stroke the outer line
	NSBezierPath * bezier = [NSBezierPath bezierPathWithRect:self.cropRect];
	bezier.lineWidth = 4;
	[bezier stroke];
	
	//draw handles
	if(!self.displayOnly) {
		CGContextFillRect(context,self.topLeftHandle);
		CGContextFillRect(context,self.bottomRightHandle);
		
		//update fill with alpha,
		CGContextSetStrokeColorWithColor(context,[[NSColor colorWithRed:0.999 green:0.985 blue:0 alpha:.1] CGColor]);
		CGContextSetFillColorWithColor(context,[[NSColor colorWithRed:0.999 green:0.985 blue:0 alpha:.1] CGColor]);
		
		//draw fill
		[NSBezierPath fillRect:self.cropRect];
	}
	
	[[NSGraphicsContext currentContext] restoreGraphicsState];
}

- (void) mouseDragged:(NSEvent *)theEvent {
	if(self.displayOnly) {
		return;
	}
	
	if(self.currentHandle == NoHandle) {
		return;
	}
	
	CGPoint location = [self convertPoint:theEvent.locationInWindow fromView:nil];
	CGFloat xdiff = location.x - self.currentLocation.x;
	CGFloat ydiff = location.y - self.currentLocation.y;
	
	NSLog(@"ydiff: %f",ydiff);
	
	if(self.currentHandle == LeftHandleId) {
		CGPoint currentHandlePoint = self.topLeftHandle.origin;
		CGPoint leftHandlePoint = CGPointMake( currentHandlePoint.x + xdiff, currentHandlePoint.y + ydiff);
		self.topLeftHandle = CGRectMake(leftHandlePoint.x, leftHandlePoint.y, HandleSize, HandleSize);
	}
	
	if(self.currentHandle == RightHandleId) {
		CGPoint currentHandlePoint = self.bottomRightHandle.origin;
		CGPoint rightHandlePoint = CGPointMake( currentHandlePoint.x + xdiff, currentHandlePoint.y + ydiff);
		self.bottomRightHandle = CGRectMake(rightHandlePoint.x, rightHandlePoint.y, HandleSize, HandleSize);
		[self setNeedsDisplay:true];
	}
	
	if(self.currentHandle == HandleDrag) {
		CGPoint currentLeftHandlePoint = self.topLeftHandle.origin;
		CGPoint leftHandlePoint = CGPointMake( currentLeftHandlePoint.x + xdiff, currentLeftHandlePoint.y + ydiff);
		self.topLeftHandle = CGRectMake(leftHandlePoint.x, leftHandlePoint.y, HandleSize, HandleSize);
		
		CGPoint currentRightHandlePoint = self.bottomRightHandle.origin;
		CGPoint rightHandlePoint = CGPointMake( currentRightHandlePoint.x + xdiff, currentRightHandlePoint.y + ydiff);
		self.bottomRightHandle = CGRectMake(rightHandlePoint.x, rightHandlePoint.y, HandleSize, HandleSize);
	}
	
	CGFloat width = (self.bottomRightHandle.origin.x - self.topLeftHandle.origin.x) + HandleSize;
	CGFloat height = (self.topLeftHandle.origin.y - self.bottomRightHandle.origin.y) + HandleSize;
	CGRect cropRect = CGRectMake(self.topLeftHandle.origin.x,self.bottomRightHandle.origin.y, width, height);
	self.cropRect = cropRect;
	
	self.currentLocation = location;
	[self setNeedsDisplay:true];
}

- (void) mouseDown:(NSEvent *) theEvent {
	if(self.displayOnly) {
		return;
	}
	
	CGPoint location = [self convertPoint:theEvent.locationInWindow fromView:nil];
	
	if(CGRectContainsPoint(self.topLeftHandle,location)) {
		self.currentHandle = LeftHandleId;
	} else if(CGRectContainsPoint(self.bottomRightHandle,location)) {
		self.currentHandle = RightHandleId;
	} else if(CGRectContainsPoint(self.cropRect,location)) {
		self.currentHandle = HandleDrag;
	}
	
	if(self.currentHandle != NoHandle) {
		self.currentLocation = location;
	}
}

- (void) mouseUp:(NSEvent *) theEvent {
	if(self.displayOnly) {
		return;
	}
	
	self.currentHandle = NoHandle;
}

@end
