
#import "AppDelegate.h"
#import <HueSDK_OSX/HueSDK.h>
#import "CCColorCube.h"

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

@property NSImage * croppedImageFrame;
@property CGImageRef croppedImageCGFrame;

@property NSColor * currentColor;
@property NSTimer * updateIntervalTimer;
@property CGRect cropRect;

@property CCColorCube * colorCube;

@end

@implementation AppDelegate

- (void) applicationDidFinishLaunching:(NSNotification *) aNotification {
	self.canChangeColor = FALSE;
	self.colorCube = [[CCColorCube alloc] init];
	[self setupUI];
	[self setupSDK];
	[self setupCapture];
	[self intervalUpdate:nil];
}

- (void) setupUI {
	self.croppingImage.wantsLayer = TRUE;
	self.croppingImage.layer.zPosition = 1;
	self.croppingImage.layer.backgroundColor = [[NSColor blackColor] CGColor];
	
	self.preview.wantsLayer = TRUE;
	self.preview.layer.zPosition = 5;
	
	self.currentColorView.wantsLayer = TRUE;
	self.currentColorView.layer.zPosition = 10;
	
	self.cropSelector.wantsLayer = TRUE;
	self.cropSelector.layer.zPosition = 20;
	
	self.cropDisplay.displayOnly = TRUE;
	self.cropDisplay.wantsLayer = TRUE;
	self.cropDisplay.layer.zPosition = 30;
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
	AVCaptureDevice * device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
	AVCaptureDeviceInput * input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
	if(error) {
		NSLog(@"error: %@",error);
	}
	[self.session addInput:input];
	
	//setup preview layer
	self.preview.wantsLayer = TRUE;
	self.preview.layer.zPosition = 5;
	self.preview.layer.backgroundColor = [[NSColor blackColor] CGColor];
	AVCaptureVideoPreviewLayer * previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
	previewLayer.frame = self.preview.bounds;
	[self.preview.layer addSublayer:previewLayer];
	previewLayer.zPosition = 1;
	
	//start session
	[self.session startRunning];
}

- (void) captureOutput:(AVCaptureOutput *) captureOutput didOutputSampleBuffer:(CMSampleBufferRef) sampleBuffer fromConnection:(AVCaptureConnection *) connection {
	[self updateCurrentFrameFromSampleBuffer:sampleBuffer];
	dispatch_async(dispatch_get_main_queue(), ^{
		//[self updateDominantColorForCurrentFrame];
		[self updateDominantColorUsingColorCube];
	});
}

- (void) setupSDK {
	self.sdk = [[PHHueSDK alloc] init];
	//[self.sdk enableLogging:TRUE];
	[self.sdk startUpSDK];
	
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"BridgeConnected"]) {
		[self connect:nil];
	}
}

- (IBAction) connect:(id)sender {
	self.connectionMessage.stringValue = @"Connecting...";
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
		self.connectionMessage.stringValue = @"!! Press Link Button on Bridge !!";
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
	
	//get crop rect from crop selector
	CGRect cropRect = self.cropSelector.cropRect;
	CGFloat diffx = image.size.width / self.cropSelector.frame.size.width;
	CGFloat diffy = image.size.height / self.cropSelector.frame.size.height;
	cropRect.origin.x = floorf(cropRect.origin.x * diffx);
	cropRect.origin.y = floorf(cropRect.origin.y * diffy);
	cropRect.size.width = floorf( cropRect.size.width * diffx );
	cropRect.size.height = floorf( cropRect.size.height * diffy );
	
	//crop image
	NSImage * croppedImage = [[NSImage alloc] initWithSize:NSMakeSize(cropRect.size.width,cropRect.size.height)];
	[croppedImage lockFocus];
	[image drawInRect:NSMakeRect(0, 0, cropRect.size.width,cropRect.size.height) fromRect:cropRect operation:NSCompositeOverlay fraction:1];
	[croppedImage unlockFocus];
	self.croppedImageFrame = croppedImage;
	
	NSRect rect = NSMakeRect(0, 0, cropRect.size.width,cropRect.size.height);
	self.croppedImageCGFrame = [croppedImage CGImageForProposedRect:&rect context:NULL hints:NULL];
}

static struct pixel * pixels = NULL;

- (void) updateDominantColorUsingColorCube {
	NSArray * colors = [self.colorCube extractColorsFromImage:self.croppedImageFrame flags:CCAvoidBlack|CCAvoidWhite|CCOnlyDistinctColors|CCOnlyBrightColors count:1];
	if(colors.count > 0) {
		self.currentColor = [colors objectAtIndex:0];
	}
}

- (void) updateDominantColorForCurrentFrame {
	NSImage * image = self.croppedImageFrame;
	CGImageRef cgimage = self.croppedImageCGFrame;
	
	if(!pixels) {
		pixels = (struct pixel *) calloc(1, image.size.width * image.size.height * sizeof(struct pixel));
	}
	
	NSUInteger red = 0;
	NSUInteger green = 0;
	NSUInteger blue = 0;
	
	if(pixels != nil) {
		CGContextRef context = CGBitmapContextCreate((void*)pixels,image.size.width,image.size.height,8,image.size.width * 4,CGImageGetColorSpace(cgimage),kCGImageAlphaPremultipliedLast);
		if(context != NULL) {
			
			CGContextDrawImage(context, CGRectMake(0.0f, 0.0f, image.size.width,image.size.height),cgimage);
			NSUInteger numberOfPixels = image.size.width * image.size.height;
			
			for(int i = 0; i < numberOfPixels; i++) {
				red += pixels[i].r;
				green += pixels[i].g;
				blue += pixels[i].b;
			}
			
			red /= numberOfPixels;
			green /= numberOfPixels;
			blue/= numberOfPixels;
			
			CGContextRelease(context);
		}
		
		self.currentColor = [NSColor colorWithRed:red/255.0f green:green/255.0f blue:blue/255.0f alpha:1.0f];
	}
}

#pragma mark local connection callbacks

- (void) update {
	self.cropDisplay.cropRect = self.cropSelector.cropRect;
	[self.cropDisplay setNeedsDisplay:TRUE];
	
	if(!self.croppingImage.image) {
		self.croppingImage.image = self.currentFrame;
		
		if(self.croppedImageFrame) {
			self.croppedImagePreview.image = self.croppedImageFrame;
		}
	}
	
	if(self.livePreview.state == NSOnState) {
		
		self.currentColorView.hidden = TRUE;
		
	} else {
		
		self.currentColorView.hidden = FALSE;
		self.currentColorView.layer.backgroundColor = [self.currentColor CGColor];
		
	}
	
	[self changeHueToColor:self.currentColor];
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
	
	lightState.brightness = @(self.brightness.integerValue);
	
	// Create PHBridgeSendAPI object
	PHBridgeSendAPI * bridgeSendAPI = [[PHBridgeSendAPI alloc] init];
	[bridgeSendAPI updateLightStateForId:light.identifier withLightState:lightState completionHandler:^(NSArray *errors) {
		NSLog(@"updated!");
	}];
}

@end
