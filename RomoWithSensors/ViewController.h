//
//  ViewController.h
//  HelloRomo
//

#import <UIKit/UIKit.h>
#import <RMCore/RMCore.h>
#import <RMCharacter/RMCharacter.h>
#import "AppDelegate.h"
#import <AVFoundation/AVFoundation.h>
#import <opencv2/imgproc/imgproc_c.h>

@interface ViewController : UIViewController <RMCoreDelegate, AVCaptureVideoDataOutputSampleBufferDelegate>
{
    AVCaptureSession *_session;
    AVCaptureDevice *_captureDevice;
    
    BOOL _useBackCamera;
    
}
@property (nonatomic, strong) RMCoreRobotRomo3 *Romo3;
@property (nonatomic, strong) RMCharacter *Romo;


- (void)addGestureRecognizers;


- (UIImage*)getUIImageFromIplImage:(IplImage *)iplImage;
- (void)didCaptureIplImage:(IplImage *)iplImage;
- (void)didFinishProcessingImage:(IplImage *)iplImage;


@end