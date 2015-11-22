
#import <Cocoa/Cocoa.h>
#import <AVFoundation/AVFoundation.h>
#import "CropSelector.h"

@interface AppDelegate : NSObject <NSApplicationDelegate, AVCaptureVideoDataOutputSampleBufferDelegate>
@property IBOutlet NSView * preview;
@property (weak) IBOutlet NSButton * livePreview;
@property (weak) IBOutlet NSSlider * brightness;
@property (weak) IBOutlet NSView * currentColorView;
@property (weak) IBOutlet NSImageView * croppingImage;
@property (weak) IBOutlet NSTextField * connectionMessage;
@property (weak) IBOutlet NSButton * powerButton;

@property IBOutlet CropSelector * cropSelector;
@property IBOutlet CropSelector * cropDisplay;
@end
