
#import "AppDelegate.h"
#import <HueSDK_OSX/HueSDK.h>

struct pixel {
	unsigned char r, g, b, a;
};

@interface AppDelegate ()
@property (weak) IBOutlet NSWindow * window;

@property BOOL canChangeColor;

@property PHHueSDK * sdk;
@property PHBridgeSearching * search;

@property AVCaptureSession * session;
@property dispatch_queue_t sampleQueue;

@property NSImage * currentFrame;
@property CGImageRef currentCGFrame;
@property NSColor * currentColor;
@property NSTimer * updateIntervalTimer;

@end

@implementation AppDelegate

- (void) applicationDidFinishLaunching:(NSNotification *) aNotification {
	self.canChangeColor = FALSE;
	[self setupUI];
	[self setupSDK];
	[self setupCapture];
}

- (void) setupUI {
	self.croppingImage.wantsLayer = TRUE;
	self.croppingImage.layer.backgroundColor = [[NSColor blackColor] CGColor];
	self.currentColorView.wantsLayer = TRUE;
}

- (void) setupCapture {
	//setup queue to receive sample buffers on
	self.sampleQueue = dispatch_queue_create("sample queue",NULL);
	
	//setup session
	self.session = [[AVCaptureSession alloc] init];
	self.session.sessionPreset = AVCaptureSessionPresetHigh;
	
	//setup video data output for buffers
	NSMutableDictionary * settings = [NSMutableDictionary dictionary];
	[settings setObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey:(NSString *)kCVPixelBufferPixelFormatTypeKey];
	AVCaptureVideoDataOutput * videoData = [[AVCaptureVideoDataOutput alloc] init];
	videoData.videoSettings = settings;
	[videoData setSampleBufferDelegate:self queue:self.sampleQueue];
	[self.session addOutput:videoData];
	
	//setup input for default camera
	NSError * error = nil;
	AVCaptureDevice* device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
	AVCaptureDeviceInput * input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
	if(error) {
		NSLog(@"error: %@",error);
	}
	[self.session addInput:input];
	
	//setup preview layer
	self.preview.wantsLayer = TRUE;
	self.preview.layer.backgroundColor = [[NSColor blackColor] CGColor];
	AVCaptureVideoPreviewLayer * previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
	previewLayer.frame = self.preview.bounds;
	[self.preview.layer addSublayer:previewLayer];
	
	//start session
	[self.session startRunning];
}

- (void) captureOutput:(AVCaptureOutput *) captureOutput didOutputSampleBuffer:(CMSampleBufferRef) sampleBuffer fromConnection:(AVCaptureConnection *) connection {
	[self updateCurrentFrameFromSampleBuffer:sampleBuffer];
	dispatch_async(dispatch_get_main_queue(), ^{
		[self updateDominantColorForCurrentFrame];
	});
}

- (void) setupSDK {
	self.sdk = [[PHHueSDK alloc] init];
	[self.sdk enableLogging:TRUE];
	[self.sdk startUpSDK];
	
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"BridgeConnected"]) {
		[self connect:nil];
	}
}

- (IBAction) connect:(id)sender {
	self.search = [[PHBridgeSearching alloc] initWithUpnpSearch:TRUE andPortalSearch:FALSE andIpAdressSearch:FALSE];
	[self.search startSearchWithCompletionHandler:^(NSDictionary *bridgesFound) {
		for(NSString * key in bridgesFound) {
			NSString * ip = bridgesFound[key];
			[self.sdk setBridgeToUseWithId:key ipAddress:ip];
			break;
		}
		[self authorizePushLink];
	}];
}

- (void) authorizePushLink {
	// Register for notifications about pushlinking
	PHNotificationManager * phNotificationMgr = [PHNotificationManager defaultManager];
	
	[phNotificationMgr registerObject:self withSelector:@selector(authenticationSuccess) forNotification:PUSHLINK_LOCAL_AUTHENTICATION_SUCCESS_NOTIFICATION];
	[phNotificationMgr registerObject:self withSelector:@selector(authenticationFailed) forNotification:PUSHLINK_LOCAL_AUTHENTICATION_FAILED_NOTIFICATION];
	[phNotificationMgr registerObject:self withSelector:@selector(noLocalConnection) forNotification:PUSHLINK_NO_LOCAL_CONNECTION_NOTIFICATION];
	[phNotificationMgr registerObject:self withSelector:@selector(noLocalBridge) forNotification:PUSHLINK_NO_LOCAL_BRIDGE_KNOWN_NOTIFICATION];
	[phNotificationMgr registerObject:self withSelector:@selector(buttonNotPressed:) forNotification:PUSHLINK_BUTTON_NOT_PRESSED_NOTIFICATION];
	
	// Call to the Hue SDK to start the pushlinking process
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"BridgeConnected"]) {
		[self startLocalConnection];
	} else {
		[self.sdk startPushlinkAuthentication];
	}
}

- (void) startLocalConnection {
	PHNotificationManager * notificationManager = [PHNotificationManager defaultManager];
	[notificationManager registerObject:self withSelector:@selector(localConnection) forNotification:LOCAL_CONNECTION_NOTIFICATION];
	[notificationManager registerObject:self withSelector:@selector(noLocalConnection) forNotification:NO_LOCAL_CONNECTION_NOTIFICATION];
	[notificationManager registerObject:self withSelector:@selector(notAuthenticated) forNotification:NO_LOCAL_AUTHENTICATION_NOTIFICATION];
	[self.sdk enableLocalConnection];
}

#pragma mark push link callbacks.

- (void) authenticationSuccess {
	[[NSUserDefaults standardUserDefaults] setBool:TRUE forKey:@"BridgeConnected"];
	[self startLocalConnection];
}

- (void) authenticationFailed {
	self.connectionMessage.stringValue = @"Connection Failed, Try Again";
}

- (void) noLocalConnection {
	self.connectionMessage.stringValue = @"Connection Failed, Try Again";
}

- (void) noLocalBridge {
	self.connectionMessage.stringValue = @"Bridge Not Found, Reconnect";
}

- (void) buttonNotPressed:(id) sender {
	self.connectionMessage.stringValue = @"Button Not Pressed, Try Again";
}

#pragma mark utils

- (void) updateCurrentFrameFromSampleBuffer:(CMSampleBufferRef) sampleBuffer {
	
	// Get a CMSampleBuffer's Core Video image buffer for the media data
	CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
	// Lock the base address of the pixel buffer
	CVPixelBufferLockBaseAddress(imageBuffer, 0);
 
	// Get the number of bytes per row for the pixel buffer
	void * baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
 
	// Get the number of bytes per row for the pixel buffer
	size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
	// Get the pixel buffer width and height
	size_t width = CVPixelBufferGetWidth(imageBuffer);
	size_t height = CVPixelBufferGetHeight(imageBuffer);
 
	// Create a device-dependent RGB color space
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
 
	// Create a bitmap graphics context with the sample buffer data
	CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
	// Create a Quartz image from the pixel data in the bitmap graphics context
	CGImageRef quartzImage = CGBitmapContextCreateImage(context);
	// Unlock the pixel buffer
	CVPixelBufferUnlockBaseAddress(imageBuffer,0);
 
	// Free up the context and color space
	CGContextRelease(context);
	CGColorSpaceRelease(colorSpace);
 
	// Create an image object from the Quartz image
	NSImage * image = [[NSImage alloc] initWithCGImage:quartzImage size:NSMakeSize(width, height)];
	
	self.currentFrame = image;
	self.currentCGFrame = quartzImage;
	
	// Release the Quartz image
	CGImageRelease(quartzImage);
}

- (void) updateDominantColorForCurrentFrame {
	NSUInteger red = 0;
	NSUInteger green = 0;
	NSUInteger blue = 0;
	struct pixel * pixels = (struct pixel*) calloc(1, self.currentFrame.size.width * self.currentFrame.size.height * sizeof(struct pixel));
	if(pixels != nil) {
		CGContextRef context = CGBitmapContextCreate((void*) pixels,self.currentFrame.size.width,self.currentFrame.size.height,8,self.currentFrame.size.width * 4,CGImageGetColorSpace(self.currentCGFrame),kCGImageAlphaPremultipliedLast);
		if(context != NULL) {
			CGContextDrawImage(context, CGRectMake(0.0f, 0.0f, self.currentFrame.size.width, self.currentFrame.size.height), self.currentCGFrame);
			NSUInteger numberOfPixels = self.currentFrame.size.width * self.currentFrame.size.height;
			for (int i=0; i < numberOfPixels; i++) {
				red += pixels[i].r;
				green += pixels[i].g;
				blue += pixels[i].b;
			}
			red /= numberOfPixels;
			green /= numberOfPixels;
			blue/= numberOfPixels;
			CGContextRelease(context);
		}
		free(pixels);
	}
	self.currentColor = [NSColor colorWithRed:red/255.0f green:green/255.0f blue:blue/255.0f alpha:1.0f];
}

#pragma mark local connection callbacks

- (void) update {
	[self changeHueToColor:self.currentColor];
	
	if(self.livePreview.state == NSOnState) {
		
		if(!self.preview.superview) {
			[self.window.contentView addSubview:self.preview];
		}
		
	} else {
		
		if(self.preview.superview) {
			[self.preview removeFromSuperview];
		}
		self.currentColorView.layer.backgroundColor = [self.currentColor CGColor];
		
	}
	
	if(!self.croppingImage.image) {
		self.croppingImage.image = self.currentFrame;
	}
}

- (IBAction) captureImageForCropping:(id)sender {
	self.croppingImage.image = nil;
}

- (IBAction) intervalUpdate:(id)sender {
	[self.updateIntervalTimer invalidate];
	self.updateIntervalTimer = [NSTimer scheduledTimerWithTimeInterval:1/self.updateInterval.floatValue target:self selector:@selector(update) userInfo:nil repeats:TRUE];
}

- (void) localConnection {
	self.canChangeColor = TRUE;
	self.connectionMessage.stringValue = @"Connected";
}

- (void) notAuthenticated {
	self.connectionMessage.stringValue = @"Not Authenticated, Try Again";
}

- (void) changeHueToColor:(NSColor *) color {
	if(!self.canChangeColor) {
		return;
	}
	
	PHBridgeResourcesCache * cache = [PHBridgeResourcesReader readBridgeResourcesCache];
	// And now you can get any resource you want, for example:
	//NSArray * myLights = [cache.lights allValues];
	
	// Get light from cache
	PHLight * light = [cache.lights objectForKey:@"1"];
	
	// Convert color red to a XY value
	CGPoint xy = [PHUtilities calculateXY:color forModel:light.modelNumber];
	
	// Create new light state object
	PHLightState * lightState = [[PHLightState alloc] init];
	
	// Set converted XY value to light state
	lightState.x = @(xy.x);
	lightState.y = @(xy.y);
	
	// Create PHBridgeSendAPI object
	PHBridgeSendAPI * bridgeSendAPI = [[PHBridgeSendAPI alloc] init];
	[bridgeSendAPI updateLightStateForId:light.identifier withLightState:lightState completionHandler:^(NSArray *errors) {
		NSLog(@"updated!");
	}];
}

@end
