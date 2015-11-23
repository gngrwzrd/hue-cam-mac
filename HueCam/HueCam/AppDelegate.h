
#import <Cocoa/Cocoa.h>
#import <AVFoundation/AVFoundation.h>
#import "CropSelector.h"

@interface AppDelegate : NSObject <NSApplicationDelegate, AVCaptureVideoDataOutputSampleBufferDelegate>
@property IBOutlet NSView * preview;
@property (weak) IBOutlet NSButton * connectionButton;
@property (weak) IBOutlet NSSlider * brightness;
@property (weak) IBOutlet NSTextField * connectionMessage;
@property (weak) IBOutlet NSButton * powerButton;

@property IBOutlet CropSelector * cropSelector;
@end
