
#import <Cocoa/Cocoa.h>
#import <AVFoundation/AVFoundation.h>

@interface AppDelegate : NSObject <NSApplicationDelegate, AVCaptureVideoDataOutputSampleBufferDelegate>
@property IBOutlet NSView * preview;
@property (weak) IBOutlet NSButton * livePreview;
@property (weak) IBOutlet NSSlider * updateInterval;
@property (weak) IBOutlet NSView * currentColorView;
@property (weak) IBOutlet NSImageView * croppingImage;
@property (weak) IBOutlet NSTextField * connectionMessage;
@end

