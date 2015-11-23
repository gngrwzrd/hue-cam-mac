
#import <Cocoa/Cocoa.h>
#import <AVFoundation/AVFoundation.h>
#import "CropSelector.h"

@interface AppDelegate : NSObject <NSApplicationDelegate, AVCaptureVideoDataOutputSampleBufferDelegate>
@property IBOutlet NSView * preview;
@property (weak) IBOutlet NSButton * connectionButton;
@property (weak) IBOutlet NSTextField * connectionMessage;
@property (weak) IBOutlet NSSlider * brightness;
@property (weak) IBOutlet NSSlider * updateInterval;
@property (weak) IBOutlet NSTextField * updateIntervalLabel;
@property (weak) IBOutlet NSButton * darkColors;
@property (weak) IBOutlet NSButton * brightColors;
@property (weak) IBOutlet NSButton * avoidWhite;
@property (weak) IBOutlet NSButton * avoidBlack;
@property (weak) IBOutlet NSButton * powerButton;

@property IBOutlet CropSelector * cropSelector;
@end
