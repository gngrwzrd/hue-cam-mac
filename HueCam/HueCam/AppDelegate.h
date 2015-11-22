
#import <Cocoa/Cocoa.h>
#import <AVFoundation/AVFoundation.h>
#import "CropSelector.h"

@interface AppDelegate : NSObject <NSApplicationDelegate, AVCaptureVideoDataOutputSampleBufferDelegate>
@property IBOutlet NSView * preview;
@property (weak) IBOutlet NSButton * livePreview;
@property (weak) IBOutlet NSSlider * updateInterval;
@property (weak) IBOutlet NSSlider * brightness;
@property (weak) IBOutlet NSView * currentColorView;
@property (weak) IBOutlet NSImageView * croppingImage;
@property (weak) IBOutlet NSImageView * croppedImagePreview;
@property (weak) IBOutlet NSTextField * connectionMessage;

@property IBOutlet CropSelector * cropSelector;
@property IBOutlet CropSelector * cropDisplay;
@end

