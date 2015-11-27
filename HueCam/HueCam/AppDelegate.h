
#import <Cocoa/Cocoa.h>
#import <AVFoundation/AVFoundation.h>
#import "CropSelector.h"
#import <CoreImage/CoreImage.h>

@interface AppDelegate : NSObject <NSApplicationDelegate, AVCaptureVideoDataOutputSampleBufferDelegate>

@property (weak) IBOutlet NSButton * connectionButton;
@property (weak) IBOutlet NSTextField * connectionMessage;

@property (weak) IBOutlet NSView * preview;

@property (weak) IBOutlet NSSlider * saturationSlider;
@property (weak) IBOutlet NSSlider * brightness;
@property (weak) IBOutlet NSSlider * updateInterval;
@property (weak) IBOutlet NSTextField * updateIntervalLabel;
@property (weak) IBOutlet NSView * currentColorView;

@property (weak) IBOutlet NSSlider * hueBrightness;
@property (weak) IBOutlet NSButton * powerButton;

@property IBOutlet CropSelector * cropSelector;

@property IBOutlet NSImageView * croppedImagePreview;

@end
