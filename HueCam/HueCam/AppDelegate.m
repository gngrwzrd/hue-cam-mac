
#import "AppDelegate.h"
#import <HueSDK_OSX/HueSDK.h>
#import "CCColorCube.h"

static NSString * const BridgeConnected = @"BridgeConnected";
static NSString * const UpdateInterval = @"UpdateInterval";
static NSString * const Brightness = @"Brightness";
static NSString * const Saturation = @"Saturation";
static NSString * const HueBrightness = @"HueBrightness";

struct pixel {
	unsigned char r, g, b, a;
};

static struct pixel * pixels = NULL;
static CGContextRef _context;

@interface AppDelegate ()
@property (weak) IBOutlet NSWindow * window;

@property BOOL canChangeColor;
@property BOOL lightState;

@property PHHueSDK * sdk;
@property PHBridgeSearching * search;

@property AVCaptureSession * session;
@property dispatch_queue_t sampleQueue;

@property NSImage * croppedImageFrame;
@property CGImageRef croppedImageCGFrame;

@property NSColor * currentColor;
@property NSTimer * updateIntervalTimer;
@property CGRect cropRect;

@property CGFloat redHue;
@property CGFloat redPurpleHue;
@property CGFloat purpleHue;
@property CGFloat bluePurpleHue;
@property CGFloat blueHue;
@property CGFloat blueGreenHue;
@property CGFloat greenHue;
@property CGFloat greenYellowHue;
@property CGFloat yellowHue;
@property CGFloat yellowOrangeHue;
@property CGFloat orangeHue;
@property CGFloat orangeRedHue;

@end

@implementation AppDelegate

- (void) applicationDidFinishLaunching:(NSNotification *) aNotification {
	self.canChangeColor = FALSE;
	[self logColors];
	[self setupUI];
	[self setupSDK];
	[self setupCapture];
	[self intervalUpdate:nil];
}

- (void) logColors {
	CGFloat h,s,b;
	
	self.redHue = 1.0;
	self.redPurpleHue = .87;
	self.purpleHue = .83;
	self.bluePurpleHue = .72;
	self.blueHue = .66;
	self.blueGreenHue = .49;
	self.greenHue = .33;
	self.greenYellowHue = .26;
	self.yellowHue = .16;
	self.yellowOrangeHue = .12;
	self.orangeHue = .083;
	self.orangeRedHue = .049;
	
	NSColor * red = [NSColor redColor];
	[red getHue:&h saturation:&s brightness:&b alpha:nil];
	NSLog(@"red: %f %f %f",h,s,b);
	
	NSColor * redPurple = [NSColor colorWithRed:0.979 green:0.215 blue:0.807 alpha:1];
	[redPurple getHue:&h saturation:&s brightness:&b alpha:nil];
	NSLog(@"redPurple: %f %f %f",h,s,b);
	
	NSColor * purple = [NSColor purpleColor];
	[purple getHue:&h saturation:&s brightness:&b alpha:nil];
	NSLog(@"purple: %f %f %f",h,s,b);
	
	NSColor * bluePurple = [NSColor colorWithRed:0.478 green:0.202 blue:0.97 alpha:1];
	[bluePurple getHue:&h saturation:&s brightness:&b alpha:nil];
	NSLog(@"bluePurple: %f %f %f",h,s,b);
	
	NSColor * blue = [NSColor blueColor];
	[blue getHue:&h saturation:&s brightness:&b alpha:nil];
	NSLog(@"blue: %f %f %f",h,s,b);
	
	NSColor * blueGreen = [NSColor colorWithRed:0.034 green:0.614 blue:0.581 alpha:1];
	[blueGreen getHue:&h saturation:&s brightness:&b alpha:nil];
	NSLog(@"blueGreen: %f %f %f",h,s,b);
	
	NSColor * green = [NSColor greenColor];
	[green getHue:&h saturation:&s brightness:&b alpha:nil];
	NSLog(@"green: %f %f %f",h,s,b);
	
	NSColor * greenYellow = [NSColor colorWithRed:0.414 green:0.932 blue:0.063 alpha:1];
	[greenYellow getHue:&h saturation:&s brightness:&b alpha:nil];
	NSLog(@"greenYellow: %f %f %f",h,s,b);
	
	NSColor * yellow = [NSColor yellowColor];
	[yellow getHue:&h saturation:&s brightness:&b alpha:nil];
	NSLog(@"yellow: %f %f %f",h,s,b);
	
	NSColor * yellowOrange = [NSColor colorWithRed:0.982 green:0.741 blue:0.006 alpha:1];
	[yellowOrange getHue:&h saturation:&s brightness:&b alpha:nil];
	NSLog(@"yellowOrange: %f %f %f",h,s,b);
	
	NSColor * orange = [NSColor orangeColor];
	[orange getHue:&h saturation:&s brightness:&b alpha:nil];
	NSLog(@"orange: %f %f %f",h,s,b);
	
	NSColor * orangeRed = [NSColor colorWithRed:0.994 green:0.326 blue:0.046 alpha:1];
	[orangeRed getHue:&h saturation:&s brightness:&b alpha:nil];
	NSLog(@"orangeRed: %f %f %f",h,s,b);
}

- (void) setupUI {
	self.currentColorView.wantsLayer = TRUE;
	self.currentColorView.layer.borderColor = [[NSColor whiteColor] CGColor];
	self.currentColorView.layer.borderWidth = 2;
	
	self.preview.wantsLayer = TRUE;
	self.preview.layer.zPosition = 5;
	
	self.cropSelector.wantsLayer = TRUE;
	self.cropSelector.layer.zPosition = 20;
	
	NSMutableDictionary * defaults = [NSMutableDictionary dictionary];
	defaults[UpdateInterval] = @(1);
	defaults[Brightness] = @(.35);
	defaults[Saturation] = @(.6);
	defaults[HueBrightness] = @(38);
	
	[[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
	
	self.updateInterval.floatValue = [[[NSUserDefaults standardUserDefaults] objectForKey:UpdateInterval] floatValue];
	self.brightness.floatValue = [[[NSUserDefaults standardUserDefaults] objectForKey:Brightness] floatValue];
	self.hueBrightness.integerValue = [[[NSUserDefaults standardUserDefaults] objectForKey:HueBrightness] integerValue];
	self.saturationSlider.floatValue = [[[NSUserDefaults standardUserDefaults] objectForKey:Saturation] floatValue];
	
	NSLog(@"%f",self.updateInterval.floatValue);
	NSLog(@"%f",self.brightness.floatValue);
	NSLog(@"%f",self.saturationSlider.floatValue);
	NSLog(@"%f",self.hueBrightness.floatValue);
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
	[self updateAverageColorForCurrentFrame];
}

- (void) setupSDK {
	self.sdk = [[PHHueSDK alloc] init];
	//[self.sdk enableLogging:TRUE];
	[self.sdk startUpSDK];
	
	if([[NSUserDefaults standardUserDefaults] boolForKey:BridgeConnected]) {
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
	if([[NSUserDefaults standardUserDefaults] boolForKey:BridgeConnected]) {
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
	[[NSUserDefaults standardUserDefaults] setBool:TRUE forKey:BridgeConnected];
	[self startLocalConnection];
}

- (void) authenticationFailed {
	self.connectionMessage.stringValue = @"Connection Failed, Try Again";
	self.connectionButton.hidden = FALSE;
}

- (void) noLocalConnection {
	self.connectionMessage.stringValue = @"Connection Failed, Try Again";
	self.connectionButton.hidden = FALSE;
}

- (void) noLocalBridge {
	self.connectionMessage.stringValue = @"Bridge Not Found, Reconnect";
	self.connectionButton.hidden = FALSE;
}

- (void) buttonNotPressed:(id) sender {
	self.connectionMessage.stringValue = @"!! Press Link Button on Bridge !!";
	self.connectionButton.hidden = FALSE;
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
	
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	
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
	
	// Release the Quartz image
	CGImageRelease(quartzImage);
	
	//get crop rect from crop selector
	CGRect cropRect = self.cropSelector.cropRect;
	CGFloat diffx = image.size.width / self.cropSelector.frame.size.width;
	CGFloat diffy = image.size.height / self.cropSelector.frame.size.height;
	cropRect.origin.x = floorf( cropRect.origin.x * diffx );
	cropRect.origin.y = floorf( cropRect.origin.y * diffy );
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
	
//	dispatch_async(dispatch_get_main_queue(), ^{
//		self.croppedImagePreview.image = self.croppedImageFrame;
//	});
}

- (void) updateAverageColorForCurrentFrame {
	NSImage * image = self.croppedImageFrame;
	CGImageRef cgimage = self.croppedImageCGFrame;
	
	if(!image || !cgimage) {
		return;
	}
	
	if(!pixels) {
		pixels = (struct pixel *) calloc(1, image.size.width * image.size.height * sizeof(struct pixel));
	}
	
	NSUInteger red = 0;
	NSUInteger green = 0;
	NSUInteger blue = 0;
	
	if(!_context) {
		_context = CGBitmapContextCreate((void*)pixels,image.size.width,image.size.height,8,image.size.width * 4,CGImageGetColorSpace(cgimage),kCGImageAlphaPremultipliedLast);
	}
	
	CGContextDrawImage(_context, CGRectMake(0.0f, 0.0f, image.size.width,image.size.height),cgimage);
	NSUInteger numberOfPixels = image.size.width * image.size.height;
	
	for(int i = 0; i < numberOfPixels; i++) {
		
		if(pixels[i].r > 200 && pixels[i].g > 200 && pixels[i].b > 200) {
			continue;
		}
		
		red += pixels[i].r;
		green += pixels[i].g;
		blue += pixels[i].b;
		
	}
	
	red /= numberOfPixels;
	green /= numberOfPixels;
	blue /= numberOfPixels;
	
	CGFloat h,s,b,a;
	
	NSColor * tmp = [NSColor colorWithRed:red/255.0f green:green/255.0f blue:blue/255.0f alpha:1.0f];
	[tmp getHue:&h saturation:&s brightness:&b alpha:&a];
	
	if(s < self.saturationSlider.floatValue) {
		s = self.saturationSlider.floatValue;
	}
	
	if(b < self.brightness.floatValue) {
		b = self.brightness.floatValue;
	}
	
	self.currentColor = [NSColor colorWithHue:h saturation:s brightness:b alpha:a];
	
	dispatch_async(dispatch_get_main_queue(), ^{
		self.currentColorView.layer.backgroundColor = [self.currentColor CGColor];
	});
}

#pragma mark local connection callbacks

- (void) update {
	[self changeHueToColor:self.currentColor];
}

- (IBAction) intervalUpdate:(id) sender {
	[self.updateIntervalTimer invalidate];
	
	self.updateIntervalTimer = [NSTimer scheduledTimerWithTimeInterval:self.updateInterval.floatValue target:self selector:@selector(update) userInfo:nil repeats:TRUE];
	
	if(self.updateInterval.floatValue == 1 || self.updateInterval.floatValue == 2) {
		self.updateIntervalLabel.stringValue = [NSString stringWithFormat:@"%li Seconds", self.updateInterval.integerValue];
	} else {
		self.updateIntervalLabel.stringValue = [NSString stringWithFormat:@"%0.2f Seconds", self.updateInterval.floatValue];
	}
	
	[[NSUserDefaults standardUserDefaults] setObject:@(self.updateInterval.floatValue) forKey:UpdateInterval];
}

- (IBAction) updateSaturation:(id) sender {
	[[NSUserDefaults standardUserDefaults] setObject:@(self.saturationSlider.floatValue) forKey:Saturation];
}

- (IBAction) updateBrightness:(id)sender {
	[[NSUserDefaults standardUserDefaults] setObject:@(self.brightness.floatValue) forKey:Brightness];
}

- (IBAction) updateHueBrightness:(id) sender {
	[[NSUserDefaults standardUserDefaults] setObject:@(self.hueBrightness.integerValue) forKey:HueBrightness];
	
	PHBridgeResourcesCache * cache = [PHBridgeResourcesReader readBridgeResourcesCache];
	PHLight * light = [cache.lights objectForKey:@"1"];
	
	PHLightState * state = [[PHLightState alloc] init];
	state.brightness = @(self.hueBrightness.integerValue);
	
	// Create PHBridgeSendAPI object
	PHBridgeSendAPI * bridgeSendAPI = [[PHBridgeSendAPI alloc] init];
	[bridgeSendAPI updateLightStateForId:light.identifier withLightState:state completionHandler:^(NSArray *errors) {
		
	}];
}

- (IBAction) powerToggle:(id) sender {
	self.lightState = !self.lightState;
	
	if(self.lightState) {
		self.powerButton.title = @"Turn Light Off";
		
		PHBridgeResourcesCache * cache = [PHBridgeResourcesReader readBridgeResourcesCache];
		PHLight * light = [cache.lights objectForKey:@"1"];
		
		PHLightState * state = [[PHLightState alloc] init];
		state.on = @(YES);
		
		// Create PHBridgeSendAPI object
		PHBridgeSendAPI * bridgeSendAPI = [[PHBridgeSendAPI alloc] init];
		[bridgeSendAPI updateLightStateForId:light.identifier withLightState:state completionHandler:^(NSArray *errors) {
			
		}];
		
	} else {
		self.powerButton.title = @"Turn Light On";
		
		PHBridgeResourcesCache * cache = [PHBridgeResourcesReader readBridgeResourcesCache];
		PHLight * light = [cache.lights objectForKey:@"1"];
		
		PHLightState * state = [[PHLightState alloc] init];
		state.on = @(NO);
		
		// Create PHBridgeSendAPI object
		PHBridgeSendAPI * bridgeSendAPI = [[PHBridgeSendAPI alloc] init];
		[bridgeSendAPI updateLightStateForId:light.identifier withLightState:state completionHandler:^(NSArray *errors) {
			
		}];
	}
}

- (void) localConnection {
	self.canChangeColor = TRUE;
	self.connectionMessage.stringValue = @"Connected";
	self.connectionButton.hidden = TRUE;
	
	PHBridgeResourcesCache * cache = [PHBridgeResourcesReader readBridgeResourcesCache];
	PHLight * light = [cache.lights objectForKey:@"1"];
	
	if(light.lightState.on.boolValue) {
		self.lightState = TRUE;
		self.powerButton.title = @"Turn Light Off";
	} else {
		self.lightState = FALSE;
		self.powerButton.title = @"Turn Light On";
	}
}

- (void) notAuthenticated {
	self.connectionMessage.stringValue = @"Not Authenticated, Try Again";
	self.connectionButton.hidden = FALSE;
}

- (void) changeHueToColor:(NSColor *) color {
	CGFloat h,s,b;
	[self.currentColor getHue:&h saturation:&s brightness:&b alpha:nil];
	
	NSLog(@"change color to: %f %f %f",h,s,b);
	
	if(!self.canChangeColor || !self.lightState) {
		return;
	}
	
	PHBridgeResourcesCache * cache = [PHBridgeResourcesReader readBridgeResourcesCache];
	PHLight * light = [cache.lights objectForKey:@"1"];
	CGPoint xy = [PHUtilities calculateXY:color forModel:light.modelNumber];
	PHLightState * lightState = [[PHLightState alloc] init];
	lightState.x = @(xy.x);
	lightState.y = @(xy.y);
	lightState.on = @(self.lightState);
	lightState.brightness = @(self.hueBrightness.integerValue);
	//lightState.transitionTime = @(2.5);
	
	// Create PHBridgeSendAPI object
	PHBridgeSendAPI * bridgeSendAPI = [[PHBridgeSendAPI alloc] init];
	[bridgeSendAPI updateLightStateForId:light.identifier withLightState:lightState completionHandler:^(NSArray *errors) {
		
	}];
}

@end
