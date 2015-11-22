
#import "CropSelector.h"

#define NoHandle 0
#define LeftHandleId 1
#define RightHandleId 2
#define HandleSize 10

@interface CropSelector ()
@property CGRect topLeftHandle;
@property CGRect bottomRightHandle;
@property NSTrackingArea * topLeft;
@property NSTrackingArea * bottomRight;
@property CGPoint currentLocation;
@property int currentHandle;
@end

@implementation CropSelector

- (BOOL) isFlipped {
	return TRUE;
}

- (void) awakeFromNib {
	self.cropRect = CGRectInset(self.bounds,2,2);
	self.topLeftHandle = CGRectMake(0,0,HandleSize,HandleSize);
	self.bottomRightHandle = CGRectMake(self.bounds.size.width-HandleSize,self.bounds.size.height-HandleSize,HandleSize,HandleSize);
	self.currentHandle = NoHandle;
}

- (void) drawRect:(NSRect) dirtyRect {
	[super drawRect:dirtyRect];
	
	CGContextRef context = [[NSGraphicsContext currentContext] graphicsPort];
	
	[[NSGraphicsContext currentContext] saveGraphicsState];
	
	if(!self.displayOnly) {
		CGContextSetStrokeColorWithColor(context,[[NSColor orangeColor] CGColor]);
		CGContextSetFillColorWithColor(context,[[NSColor orangeColor] CGColor]);
	} else {
		CGContextSetStrokeColorWithColor(context,[[NSColor redColor] CGColor]);
		CGContextSetFillColorWithColor(context,[[NSColor redColor] CGColor]);
	}
	
	
	NSBezierPath * bezier = [NSBezierPath bezierPathWithRect:self.cropRect];
	bezier.lineWidth = 4;
	[bezier stroke];
	
	if(!self.displayOnly) {
		CGContextFillRect(context,self.topLeftHandle);
		CGContextFillRect(context,self.bottomRightHandle);
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
	
	if(self.currentHandle == LeftHandleId) {
		CGFloat xdiff = location.x - self.currentLocation.x;
		CGFloat ydiff = location.y - self.currentLocation.y;
		
		CGPoint currentHandlePoint = self.topLeftHandle.origin;
		CGPoint leftHandlePoint = CGPointMake( currentHandlePoint.x + xdiff, currentHandlePoint.y + ydiff);
		
		self.topLeftHandle = CGRectMake(leftHandlePoint.x, leftHandlePoint.y, HandleSize, HandleSize);
		
		[self setNeedsDisplay:true];
	}
	
	if(self.currentHandle == RightHandleId) {
		CGFloat xdiff = location.x - self.currentLocation.x;
		CGFloat ydiff = location.y - self.currentLocation.y;
		
		CGPoint currentHandlePoint = self.bottomRightHandle.origin;
		CGPoint leftHandlePoint = CGPointMake( currentHandlePoint.x + xdiff, currentHandlePoint.y + ydiff);
		
		self.bottomRightHandle = CGRectMake(leftHandlePoint.x, leftHandlePoint.y, HandleSize, HandleSize);
		
		CGRect cropRect = CGRectMake(self.topLeftHandle.origin.x,self.topLeftHandle.origin.y,  self.bounds.size.width - (self.bottomRightHandle.origin.x), self.bounds.size.height - self.bottomRightHandle.origin.y);
		self.cropRect = cropRect;
		
		[self setNeedsDisplay:true];
	}
	
	CGFloat width = (self.bottomRightHandle.origin.x - self.topLeftHandle.origin.x) + HandleSize;
	CGFloat height = (self.bottomRightHandle.origin.y - self.topLeftHandle.origin.y) + HandleSize;
	CGRect cropRect = CGRectMake(self.topLeftHandle.origin.x,self.topLeftHandle.origin.y, width, height);
	
	self.cropRect = cropRect;
	
	self.currentLocation = location;
}

- (void) mouseDown:(NSEvent *) theEvent {
	if(self.displayOnly) {
		return;
	}
	
	CGPoint location = [self convertPoint:theEvent.locationInWindow fromView:nil];
	
	if(CGRectContainsPoint(self.topLeftHandle,location)) {
		self.currentHandle = LeftHandleId;
	}
	
	if(CGRectContainsPoint(self.bottomRightHandle,location)) {
		self.currentHandle = RightHandleId;
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
