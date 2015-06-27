//
//  ViewController.m
//  HelloRomo
//

#import "ViewController.h"
#import "GCDAsyncSocket.h"
#include <ifaddrs.h>
#include <arpa/inet.h>
#include <AVFoundation/AVCaptureDevice.h>
#include <AVFoundation/AVCaptureInput.h>
#include <AVFoundation/AVCaptureSession.h>
#include <AVFoundation/AVCaptureVideoPreviewLayer.h>
#include <AVFoundation/AVCaptureOutput.h>
#include <AVFoundation/AVMediaSelectionGroup.h>
#include <AVFoundation/AVMetadataFormat.h>
#include <AVFoundation/AVFoundation.h>
#import <ImageIO/CGImageProperties.h>
#include <ImageIO/CGImageDestination.h>
#include <ImageIO/CGImageSource.h>
#import "ImageIO/ImageIO.h"
#import <CoreMotion/CoreMotion.h>

//opencv framework
#import <opencv2/objdetect/objdetect.hpp>
#include <opencv2/core/core.hpp>
#include <opencv2/highgui/highgui.hpp>
#include <opencv2/imgproc/imgproc.hpp>
#import "opencv2/opencv.hpp"

//#include "AbstractOCVViewController.h"

using namespace std;
using namespace cv;



#define WELCOME_MSG  0
#define ECHO_MSG     1
#define WARNING_MSG  2

#define READ_TIMEOUT 15.0
#define READ_TIMEOUT_EXTENSION 10.0

#define FORMAT(format, ...) [NSString stringWithFormat:(format), ##__VA_ARGS__]
#define PORT 1234

@interface ViewController () {
    dispatch_queue_t socketQueue;
    NSMutableArray *connectedSockets;
    BOOL isRunning;
    
    GCDAsyncSocket *listenSocket;
}

@end


float gravity[] = {0,0,0};
float xPoint=0;
float yPoint=0;
float zPoint=0;
float xPoint1;
float yPoint1;
float zPoint1;
Boolean slope_traversal;
@implementation ViewController

#pragma mark - View Management
 double speed=0.3;
CMMotionManager *mManager ;
- (void)viewDidLoad
{
    [super viewDidLoad];
  
    
    // To receive messages when Robots connect & disconnect, set RMCore's delegate to self
    [RMCore setDelegate:self];
    
    // Grab a shared instance of the Romo character
    self.Romo = [RMCharacter Romo];
    [RMCore setDelegate:self];
    
    [self addGestureRecognizers];
    
    // Do any additional setup after loading the view, typically from a nib.
    socketQueue = dispatch_queue_create("socketQueue", NULL);
    
    listenSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:socketQueue];
    
    // Setup an array to store all accepted client connections
    connectedSockets = [[NSMutableArray alloc] initWithCapacity:1];
    
    isRunning = NO;
    
    NSLog(@"%@", [self getIPAddress]);
    
    [self toggleSocketState];   //Statrting the Socket
}

- (void)viewWillAppear:(BOOL)animated
{
    // Add Romo's face to self.view whenever the view will appear
    [self.Romo addToSuperview:self.view];
    [self setupCamera];
    [self turnCameraOn];
}

#pragma mark -
#pragma mark Robo Movement

- (NSString *)direction:(NSString *)message {
    
    return @"";
}

- (void)perform:(NSString *)command {
    
 
    NSString *cmd = [command uppercaseString];
    
    NSLog(@"In Command");
    NSLog(@"%@",cmd);
    if ([cmd isEqualToString:@"UP"]) {
        NSLog(@"%f",speed);
        speed=speed+0.3;
        [self.Romo3 turnByAngle:0 withRadius:0.0 completion:^(BOOL success, float heading) {
            if (success) {
                [self.Romo3 driveForwardWithSpeed:speed];
            }
        }];
    }
    else if ([cmd isEqualToString:@"DOWN"]) {
            speed=speed-0.3;
            [self.Romo3 turnByAngle:0 withRadius:0.0 completion:^(BOOL success, float heading) {
                if (success) {
                    [self.Romo3 driveForwardWithSpeed:speed];
                }
            }];
        
    }else if ([cmd isEqualToString:@"LEFT"]) {
        [self.Romo3 turnByAngle:-90 withRadius:0.0 completion:^(BOOL success, float heading) {
            if (success) {
                [self.Romo3 driveForwardWithSpeed:speed];
            }
        }];
    } else if ([cmd isEqualToString:@"RIGHT"]) {
        [self.Romo3 turnByAngle:90 withRadius:0.0 completion:^(BOOL success, float heading) {
            [self.Romo3 driveForwardWithSpeed:speed];
        }];
    } else if ([cmd isEqualToString:@"BACK"]) {
        [self.Romo3 driveBackwardWithSpeed:speed];
    } else if ([cmd isEqualToString:@"GO"]) {
        
        if(speed <= 0){
                    speed = 0.3;
                   [self.Romo3 driveForwardWithSpeed:speed];
            NSLog(@"%f",speed);
        }
        else{
            
            [self.Romo3 driveForwardWithSpeed:speed];NSLog(@"%f",speed);
        }
        NSLog(@"Before Accelerometer");
        [self checkAccelerometer];
        NSLog(@"After Accelreomter");
    } else if ([cmd isEqualToString:@"SMILE"]) {
        self.Romo.expression=RMCharacterExpressionChuckle;
        self.Romo.emotion=RMCharacterEmotionHappy;
    } else if([cmd isEqualToString:@"STOP"]){
        speed=0.0;
        [self.Romo3 stopDriving];
        [mManager stopAccelerometerUpdates];
        
    }
    else if ([cmd isEqualToString:@"FAST"]) {
        speed=speed+1.0;
        [self.Romo3 turnByAngle:0 withRadius:0.0 completion:^(BOOL success, float heading) {
            if (success) {
                [self.Romo3 driveForwardWithSpeed:speed];
            }
        }];
        NSLog(@"%f",speed);
    }
    else if ([cmd isEqualToString:@"SLOW"]) {
        if((speed-1.0) > 0){
            speed=speed-1.0;
        }
        else
              speed=0;
            [self.Romo3 driveForwardWithSpeed:speed];

        
        
    }
    
    else if ([cmd isEqualToString:@"CAMERA"]) {
        
         NSLog(@"inside>>>>>");
    
        AVCaptureSession *session = [[AVCaptureSession alloc] init];
        NSError *error = nil;
        [session setSessionPreset:AVCaptureSessionPresetLow];
        
        NSArray *devices = [AVCaptureDevice devices];
        for (AVCaptureDevice *device in devices) {
            NSLog(@"Device name: %@", [device localizedName]);
            if([[device localizedName] isEqual:@"Front Camera"]){
                NSLog(@"front camera checked");
                //aquiring the lock
                if ([device isFocusModeSupported:AVCaptureFocusModeLocked]) {
                    
                    if ([device lockForConfiguration:&error]) {
                        device.focusMode = AVCaptureFocusModeLocked;
                        [device unlockForConfiguration];
                    }
                }
                    AVCaptureDeviceInput *input =
                    [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
                    if (!input) {
                        // Handle the error appropriately.
                        NSLog(@"no imput detected");
                        
                    }
                    else{
                        NSLog(@"input detected");
                        AVCaptureSession *captureSession = session;
                        AVCaptureDeviceInput *captureDeviceInput = input;
                        if ([captureSession canAddInput:captureDeviceInput]) {
                            NSLog(@"success in adding input");
                            [captureSession addInput:captureDeviceInput];
                                    AVCaptureVideoPreviewLayer *previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:session];
                                    [previewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
                                    CALayer *rootLayer = [[self view] layer];
                                    [rootLayer setMasksToBounds:YES];
                                    [previewLayer setFrame:CGRectMake(-70, 0, rootLayer.bounds.size.height, rootLayer.bounds.size.height)];
                                    [rootLayer insertSublayer:previewLayer atIndex:0];
                            [captureSession startRunning];
                            
                            
                            
                            //capturing image
                            NSLog(@"before still ");
                            AVCaptureStillImageOutput *stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
                            NSDictionary *outputSettings = @{ AVVideoCodecKey : AVVideoCodecJPEG};
                            [stillImageOutput setOutputSettings:outputSettings];
                            
                            NSLog( @"%@",stillImageOutput.description);
                            NSLog(@"after still ");
                            
                            AVCaptureConnection *videoConnection = nil;
                            for (AVCaptureConnection *connection in stillImageOutput.connections) {
                                for (AVCaptureInputPort *port in [connection inputPorts]) {
                                    if ([[port mediaType] isEqual:AVMediaTypeVideo] ) {
                                        videoConnection = connection;
                                        break;
                                    }
                                }
                                if (videoConnection) { NSLog(@"Got video connection. breaking from loop");break; }
                            }
                            
//                           @try{
//                            [stillImageOutput captureStillImageAsynchronouslyFromConnection:videoConnection completionHandler:
//                             ^(CMSampleBufferRef imageSampleBuffer, NSError *error) {
//                                // CFDictionaryRef exifAttachments =
//                                 //CMGetAttachment(imageSampleBuffer, kCGImagePropertyExifDictionary, NULL);
//                                //if (exifAttachments) {
//                                     // Do something with the attachments.
//                                 //}
//                                 // Continue as appropriate.
//                             }];
//                           }
//                            @catch(NSException *e)
//                            {
//                                NSLog(@"%@",e);
//                            }
                            
                            
                                                      //  [session startRunning ];
                            
                            
                        }
                        else {
                            // Handle the failure.
                            NSLog(@"failure in adding input");
                        }
                    }
                    
                
            }
        }
        
        
        }
   }
//accelorometer dat collection

int count = 0 ;
-(void) checkAccelerometer
{
    NSLog(@"In Accelerometer");
 
    NSTimeInterval delta = 0.005;
    NSTimeInterval updateInterval = 1 + delta * 2;
    
    NSLog(@"Before CMManager");
    mManager = [(AppDelegate *)[[UIApplication sharedApplication] delegate] sharedManager];

    NSLog(@"After CMManager");
  // float alpha = (float) 0.2;
    //ViewController * __weak weakSelf = self;
    
 //  while()
    if ([mManager isAccelerometerAvailable] == YES) {
        [mManager setAccelerometerUpdateInterval:updateInterval];
     
        [mManager startAccelerometerUpdatesToQueue:[NSOperationQueue mainQueue] withHandler:^(CMAccelerometerData *accelerometerData, NSError *error) {
            
            xPoint1  = xPoint;
            yPoint1 = yPoint;
            zPoint1 = zPoint;
            xPoint =  accelerometerData.acceleration.x;
            yPoint =  accelerometerData.acceleration.y;
            zPoint =  accelerometerData.acceleration.z;
            

            if(zPoint - zPoint1 < 0 && yPoint - yPoint1 > 0.01)
            {
                slope_traversal = true;
                if(speed < 0.6){
                                       speed = speed + 0.5;
                                            [self.Romo3 driveForwardWithSpeed:speed];}
                                        NSLog(@"IN z-z1 <0 and y-y1 > 0.15");
                NSLog(@"Speed : %f", speed);

            }
            else if(yPoint - yPoint1 < 0.01 &&zPoint-zPoint1<0){
                
                slope_traversal=true;
                
                if(speed > 0.4){
                    speed = speed - 0.3;
                    [self.Romo3 driveForwardWithSpeed:speed];}
                NSLog(@"IN z-z1 <0 and y-y1 < 0.15");
                NSLog(@"Speed : %f", speed);
                
            }
            
            else if(yPoint - yPoint1 < 0.005&& yPoint - yPoint1 > -0.001)
            {
                if(slope_traversal)
                {
                    [self.Romo3 stopDriving];
                    slope_traversal = false;
                    self.Romo.expression=RMCharacterExpressionChuckle;
                    self.Romo.emotion=RMCharacterEmotionHappy;
                   
                    
                    
                    sleep(2);
                    
                    [self.Romo3 driveForwardWithSpeed:0.3];
                }
                
            }
            
            else if (zPoint-zPoint1==0){
                
                if(speed < 0.6){
                speed = speed + 0.3;
                
                 [self.Romo3 driveForwardWithSpeed:speed];
                    
                }
                NSLog(@"Z DIff : %f", zPoint1-zPoint1);
                NSLog(@"Y Diff : %f", yPoint-yPoint1);
            
                NSLog(@"In Else");
            }
            else if(zPoint - zPoint1 > 2)
            {
                
                if(speed > 0.4){
                    speed = speed - 0.3;
                    [self.Romo3 driveForwardWithSpeed:speed];}
                NSLog(@"IN z-z1 <0 and y-y1 < 0.15");
                NSLog(@"Speed : %f", speed);
                
            }
            
        
         }];
        
    }
    else
    {
        NSLog(@"Accelerometer not available");
    }

    
}

- (void)setupCamera
{
    _captureDevice = nil;
    
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    
    for (AVCaptureDevice *device in devices)
    {
        if (device.position == AVCaptureDevicePositionFront && !_useBackCamera)
        {
            _captureDevice = device;
            break;
        }
        if (device.position == AVCaptureDevicePositionBack && _useBackCamera)
        {
            _captureDevice = device;
            break;
        }
    }
    
    if (!_captureDevice)
        _captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
}


- (void)turnCameraOn
{
    NSError *error;
    
    _session = [[AVCaptureSession alloc] init];
    [_session beginConfiguration];
    [_session setSessionPreset:AVCaptureSessionPresetMedium];
    
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:_captureDevice error:&error];
    
    if (input == nil)
        NSLog(@"%@", error);
    
    [_session addInput:input];
    
    AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc] init];
    [output setSampleBufferDelegate:self queue:dispatch_queue_create("myQueue", NULL)];
    output.videoSettings = @{(id)kCVPixelBufferPixelFormatTypeKey:@(kCVPixelFormatType_32BGRA)};
    output.alwaysDiscardsLateVideoFrames = YES;
    
    [_session addOutput:output];
    
    [_session commitConfiguration];
    [_session startRunning];
    NSLog(@"Camera turned on");
}


- (void)turnCameraOff
{
    [_session stopRunning];
    _session = nil;
}


- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    //NSLog(@"didoutSampleBuffer executed");
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    IplImage *iplimage;
    if (baseAddress)
    {
        iplimage = cvCreateImageHeader(cvSize(width, height), IPL_DEPTH_8U, 4);
        iplimage->imageData = (char*)baseAddress;
    }
    
    IplImage *workingCopy = cvCreateImage(cvSize(height, width), IPL_DEPTH_8U, 4);
    
    if (_captureDevice.position == AVCaptureDevicePositionFront)
    {
        cvTranspose(iplimage, workingCopy);
    }
    else
    {
        cvTranspose(iplimage, workingCopy);
        cvFlip(workingCopy, nil, 1);
    }
    
    cvReleaseImageHeader(&iplimage);
    
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    
   // NSLog(@"before invoking didcaptureImlImage");
    [self didCaptureIplImage:workingCopy];
}


#pragma mark - Image processing


static void ReleaseDataCallback(void *info, const void *data, size_t size)
{
#pragma unused(data)
#pragma unused(size)
    //  IplImage *iplImage = info;
    //  cvReleaseImage(&iplImage);
}


- (CGImageRef)getCGImageFromIplImage:(IplImage*)iplImage
{
   // NSLog(@"getCGImageFromIplImage invoked");
    size_t bitsPerComponent = 8;
    size_t bytesPerRow = iplImage->widthStep;
    
    size_t bitsPerPixel;
    CGColorSpaceRef space;
    
    if (iplImage->nChannels == 1)
    {
        bitsPerPixel = 8;
        space = CGColorSpaceCreateDeviceGray();
    }
    else if (iplImage->nChannels == 3)
    {
        bitsPerPixel = 24;
        space = CGColorSpaceCreateDeviceRGB();
    }
    else if (iplImage->nChannels == 4)
    {
        bitsPerPixel = 32;
        space = CGColorSpaceCreateDeviceRGB();
    }
    else
    {
        abort();
    }
    
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault | kCGImageAlphaNone;
    CGDataProviderRef provider = CGDataProviderCreateWithData(iplImage,
                                                              iplImage->imageData,
                                                              0,
                                                              ReleaseDataCallback);
    const CGFloat *decode = NULL;
    bool shouldInterpolate = true;
    CGColorRenderingIntent intent = kCGRenderingIntentDefault;
    
    CGImageRef cgImageRef = CGImageCreate(iplImage->width,
                                          iplImage->height,
                                          bitsPerComponent,
                                          bitsPerPixel,
                                          bytesPerRow,
                                          space,
                                          bitmapInfo,
                                          provider,
                                          decode,
                                          shouldInterpolate,
                                          intent);
    CGColorSpaceRelease(space);
    CGDataProviderRelease(provider);
    return cgImageRef;
}


- (UIImage*)getUIImageFromIplImage:(IplImage*)iplImage
{
   // NSLog(@"getUIImageFromIplImage invoked");
    CGImageRef cgImage = [self getCGImageFromIplImage:iplImage];
    UIImage *uiImage = [[UIImage alloc] initWithCGImage:cgImage
                                                  scale:1.0
                                            orientation:UIImageOrientationUp];
    
    CGImageRelease(cgImage);
    return uiImage;
}


#pragma mark - Captured Ipl Image


//- (void)didCaptureIplImage:(IplImage *)iplImage
//{
//    IplImage *rgbImage = cvCreateImage(cvGetSize(iplImage), IPL_DEPTH_8U, 3);
//    cvCvtColor(iplImage, rgbImage, CV_BGR2RGB);
//    cvReleaseImage(&iplImage);
//    
//    [self didFinishProcessingImage:rgbImage];
//}


#pragma mark - didFinishProcessingImage


- (void)didFinishProcessingImage:(IplImage *)iplImage
{
 //   NSLog(@"didFinishProcessingImage invoked");
    dispatch_async(dispatch_get_main_queue(), ^{
        //UIImage *uiImage =
        [self getUIImageFromIplImage:iplImage];
        //_imageView.image = uiImage;
    });
}


#pragma mark -

#pragma mark - RMCoreDelegate Methods
- (void)robotDidConnect:(RMCoreRobot *)robot
{
    // Currently the only kind of robot is Romo3, so this is just future-proofing
    if ([robot isKindOfClass:[RMCoreRobotRomo3 class]]) {
        self.Romo3 = (RMCoreRobotRomo3 *)robot;
        
        // Change Romo's LED to be solid at 80% power
        [self.Romo3.LEDs setSolidWithBrightness:0.8];
        
        // When we plug Romo in, he get's excited!
        self.Romo.expression = RMCharacterExpressionExcited;
    }
}

- (void)robotDidDisconnect:(RMCoreRobot *)robot
{
    if (robot == self.Romo3) {
        self.Romo3 = nil;
        
        // When we plug Romo in, he get's excited!
        self.Romo.expression = RMCharacterExpressionSad;
    }
}

#pragma mark - Gesture recognizers

- (void)addGestureRecognizers
{
    // Let's start by adding some gesture recognizers with which to interact with Romo
    UISwipeGestureRecognizer *swipeLeft = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipedLeft:)];
    swipeLeft.direction = UISwipeGestureRecognizerDirectionLeft;
    [self.view addGestureRecognizer:swipeLeft];
    
    UISwipeGestureRecognizer *swipeRight = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipedRight:)];
    swipeRight.direction = UISwipeGestureRecognizerDirectionRight;
    [self.view addGestureRecognizer:swipeRight];
    
    UISwipeGestureRecognizer *swipeUp = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipedUp:)];
    swipeUp.direction = UISwipeGestureRecognizerDirectionUp;
    [self.view addGestureRecognizer:swipeUp];
    
    UITapGestureRecognizer *tapReceived = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tappedScreen:)];
    [self.view addGestureRecognizer:tapReceived];
}

- (void)driveLeft {

}

- (void)swipedLeft:(UIGestureRecognizer *)sender
{
    [self.Romo3 turnByAngle:-90 withRadius:0.0 completion:NULL];
    // When the user swipes left, Romo will turn in a circle to his left
    //[self.Romo3 driveWithRadius:-1.0 speed:1.0];
}

- (void)swipedRight:(UIGestureRecognizer *)sender
{
    [self.Romo3 turnByAngle:90 withRadius:0.0 completion:NULL];
    // When the user swipes right, Romo will turn in a circle to his right
//    [self.Romo3 driveWithRadius:1.0 speed:1.0];
}

// Swipe up to change Romo's emotion to some random emotion
- (void)swipedUp:(UIGestureRecognizer *)sender
{
    //int numberOfEmotions = 7;
    
    // Choose a random emotion from 1 to numberOfEmotions
    // That's different from the current emotion
  //  RMCharacterEmotion randomEmotion = 1 + (arc4random() % numberOfEmotions);
    
   // self.Romo.emotion = randomEmotion;
}

// Simply tap the screen to stop Romo
- (void)tappedScreen:(UIGestureRecognizer *)sender
{
    [self.Romo3 stopDriving];
}

#pragma mark -
#pragma mark Socket

- (void)toggleSocketState
{
    if(!isRunning)
    {
        NSError *error = nil;
        if(![listenSocket acceptOnPort:PORT error:&error])
        {
            [self log:FORMAT(@"Error starting server: %@", error)];
            return;
        }
        
        [self log:FORMAT(@"Echo server started on port %hu", [listenSocket localPort])];
        isRunning = YES;
    }
    else
    {
        // Stop accepting connections
        [listenSocket disconnect];
        
        // Stop any client connections
        @synchronized(connectedSockets)
        {
            NSUInteger i;
            for (i = 0; i < [connectedSockets count]; i++)
            {
                // Call disconnect on the socket,
                // which will invoke the socketDidDisconnect: method,
                // which will remove the socket from the list.
                [[connectedSockets objectAtIndex:i] disconnect];
            }
        }
        
        [self log:@"Stopped Echo server"];
        isRunning = false;
    }
}

- (void)log:(NSString *)msg {
    NSLog(@"%@", msg);
}

- (NSString *)getIPAddress
{
    NSString *address = @"error";
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    int success = 0;
    
    // retrieve the current interfaces - returns 0 on success
    success = getifaddrs(&interfaces);
    if (success == 0) {
        // Loop through linked list of interfaces
        temp_addr = interfaces;
        while (temp_addr != NULL) {
            if( temp_addr->ifa_addr->sa_family == AF_INET) {
                // Check if interface is en0 which is the wifi connection on the iPhone
                if ([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"]) {
                    // Get NSString from C String
                    address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
                }
            }
            
            temp_addr = temp_addr->ifa_next;
        }
    }
    // Free memory
    freeifaddrs(interfaces);
    
    return address;
}

#pragma mark -
#pragma mark GCDAsyncSocket Delegate

- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket
{
    // This method is executed on the socketQueue (not the main thread)
    
    @synchronized(connectedSockets)
    {
        [connectedSockets addObject:newSocket];
    }
    
    NSString *host = [newSocket connectedHost];
    UInt16 port = [newSocket connectedPort];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        @autoreleasepool {
            
            [self log:FORMAT(@"Accepted client %@:%hu", host, port)];
            
        }
    });
    
    NSString *welcomeMsg = @"Welcome to the AsyncSocket Echo Server\r\n";
    NSData *welcomeData = [welcomeMsg dataUsingEncoding:NSUTF8StringEncoding];
    
    [newSocket writeData:welcomeData withTimeout:-1 tag:WELCOME_MSG];
    

    [newSocket readDataWithTimeout:READ_TIMEOUT tag:0];
    newSocket.delegate = self;
    
    //    [newSocket readDataToData:[GCDAsyncSocket CRLFData] withTimeout:READ_TIMEOUT tag:0];
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag
{
    // This method is executed on the socketQueue (not the main thread)
    
    if (tag == ECHO_MSG)
    {
        [sock readDataToData:[GCDAsyncSocket CRLFData] withTimeout:100 tag:0];
    }
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    
    NSLog(@"== didReadData %@ ==", sock.description);
    
    NSString *msg = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    [self log:msg];
    [self perform:msg];
    [sock readDataWithTimeout:READ_TIMEOUT tag:0];
}

/**
 * This method is called if a read has timed out.
 * It allows us to optionally extend the timeout.
 * We use this method to issue a warning to the user prior to disconnecting them.
 **/
- (NSTimeInterval)socket:(GCDAsyncSocket *)sock shouldTimeoutReadWithTag:(long)tag
                 elapsed:(NSTimeInterval)elapsed
               bytesDone:(NSUInteger)length
{
    if (elapsed <= READ_TIMEOUT)
    {
        NSString *warningMsg = @"Are you still there?\r\n";
        NSData *warningData = [warningMsg dataUsingEncoding:NSUTF8StringEncoding];
        
        [sock writeData:warningData withTimeout:-1 tag:WARNING_MSG];
        
        return READ_TIMEOUT_EXTENSION;
    }
    
    return 0.0;
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
    if (sock != listenSocket)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            @autoreleasepool {
                [self log:FORMAT(@"Client Disconnected")];
            }
        });
        
        @synchronized(connectedSockets)
        {
            [connectedSockets removeObject:sock];
        }
    }
}

static BOOL _debug = NO;


- (void)didCaptureIplImage:(IplImage *)iplImage
{
    //ipl image is in BGR format, it needs to be converted to RGB for display in UIImageView
    IplImage *imgRGB = cvCreateImage(cvGetSize(iplImage), IPL_DEPTH_8U, 3);
    cvCvtColor(iplImage, imgRGB, CV_BGR2RGB);
    Mat matRGB = Mat(imgRGB);
    
    //ipl imaeg is also converted to HSV; hue is used to find certain color
    IplImage *imgHSV = cvCreateImage(cvGetSize(iplImage), 8, 3);
    cvCvtColor(iplImage, imgHSV, CV_BGR2HSV);
    
    IplImage *imgThreshed = cvCreateImage(cvGetSize(iplImage), 8, 1);
    
    //it is important to release all images EXCEPT the one that is going to be passed to
    //the didFinishProcessingImage: method and displayed in the UIImageView
    cvReleaseImage(&iplImage);
    
    //filter all pixels in defined range, everything in range will be white, everything else
    //is going to be black
    cvInRangeS(imgHSV, cvScalar(160, 100, 100), cvScalar(179, 255, 255), imgThreshed);
    
    cvReleaseImage(&imgHSV);
    
    Mat matThreshed = Mat(imgThreshed);
    
    //smooths edges
    cv::GaussianBlur(matThreshed,
                     matThreshed,
                     cv::Size(9, 9),
                     2,
                     2);
    
    //debug shows threshold image, otherwise the circles are detected in the
    //threshold image and shown in the RGB image
    if (_debug)
    {
        cvReleaseImage(&imgRGB);
        [self didFinishProcessingImage:imgThreshed];
    }
    else
    {
        vector<Vec3f> circles;
        
        //get circles
        HoughCircles(matThreshed,
                     circles,
                     CV_HOUGH_GRADIENT,
                     2,
                     matThreshed.rows / 4,
                     150,
                     75,
                     10,
                     150);
        
        for (size_t i = 0; i < circles.size(); i++)
        {
            cout << "Circle position x = " << (int)circles[i][0] << ", y = " << (int)circles[i][1] << ", radius = " << (int)circles[i][2] << "\n";
            
            cv::Point center(cvRound(circles[i][0]), cvRound(circles[i][1]));
            
            int radius = cvRound(circles[i][2]);
            
            circle(matRGB, center, 3, Scalar(0, 255, 0), -1, 8, 0);
            circle(matRGB, center, radius, Scalar(0, 0, 255), 3, 8, 0);
            
            [self.Romo3 stopDriving];
            self.Romo.expression=RMCharacterExpressionChuckle;
            self.Romo.emotion=RMCharacterEmotionHappy;
        }
        
        //threshed image is not needed any more and needs to be released
        cvReleaseImage(&imgThreshed);
        
        //imgRGB will be released once it is not needed, the didFinishProcessingImage:
        //method will take care of that
        [self didFinishProcessingImage:imgRGB];
    }
}



@end
