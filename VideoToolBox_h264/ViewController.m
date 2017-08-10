//
//  ViewController.m
//  VideoToolBox_h264
//
//  Created by lyy on 2017/8/10.
//  Copyright © 2017年 LVY. All rights reserved.
//  VideoToolBox
//  硬解码  GPU  性能高 ，低码率的质量比软解码低  跨平台
//  软解码  非常简单直接，码率低的质量比硬解码高
//  Open CL
// H.264

#import "ViewController.h"

#import <AVFoundation/AVFoundation.h>
#import <VideoToolbox/VideoToolbox.h>//iOS8.0推出   同期block也推出出来了


@interface ViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate>

@property(nonatomic,strong)UILabel *cLabel;
@property(nonatomic,strong)AVCaptureSession *cCapturesession;//捕捉会话，输入输出的设备处理,设备连接
@property(nonatomic,strong)AVCaptureDeviceInput *cCaptureDeviceInput;//捕捉输入,从摄像头输入数据
@property(nonatomic,strong)AVCaptureVideoDataOutput *cCaptureDataOutput;//捕捉的数据输出到哪里
@property(nonatomic,strong)AVCaptureVideoPreviewLayer *cPreviewLayer;//预览图层

@end

@implementation ViewController
{
    int  frameID;
    dispatch_queue_t cCaptureQueue;//捕捉队列
    dispatch_queue_t cEncodeQueue;//编码队列
    VTCompressionSessionRef cEncodeingSession;//videoToolBox编码使用到的会话
    CMFormatDescriptionRef format;//捕捉的编码格式
    NSFileHandle *fileHandele;//写入到文件
    
    
}

- (void)viewDidLoad {
    [super viewDidLoad];
    //基础UI实现
    _cLabel = [[UILabel alloc]initWithFrame:CGRectMake(20, 20, 200, 100)];
    _cLabel.text = @"cc课堂之H.264硬编码";
    _cLabel.textColor = [UIColor redColor];
    [self.view addSubview:_cLabel];
    
    UIButton *cButton = [[UIButton alloc]initWithFrame:CGRectMake(200, 20, 100, 100)];
    [cButton setTitle:@"play" forState:UIControlStateNormal];
    [cButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [cButton setBackgroundColor:[UIColor orangeColor]];
    [cButton addTarget:self action:@selector(buttonClick:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:cButton];
}
-(void)buttonClick:(UIButton *)button
{
    
    if (!_cCapturesession || !_cCapturesession.isRunning ) {//开始捕捉
        
        [button setTitle:@"Stop" forState:UIControlStateNormal];
        [self startCapture];
        
        
    }else
    {//停止捕捉
        [button setTitle:@"Play" forState:UIControlStateNormal];
        [self stopCapture];
    }
    
}
//开始捕捉
- (void)startCapture
{
    
    self.cCapturesession = [[AVCaptureSession alloc]init];//给捕捉对象开辟空间
    
    self.cCapturesession.sessionPreset = AVCaptureSessionPreset640x480;//设置分辨率
    
    cCaptureQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);//捕捉队列
    cEncodeQueue  = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);//编码队列
    
    AVCaptureDevice *inputCamera = nil;//捕捉的设备
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];//拿到输入设备（前置后置摄像头）
    for (AVCaptureDevice *device in devices) {
        if ([device position] == AVCaptureDevicePositionBack) {//根据position判断是前置摄像头还是后置摄像头
            inputCamera = device;
        }
    }
    
    self.cCaptureDeviceInput = [[AVCaptureDeviceInput alloc]initWithDevice:inputCamera error:nil];//AVFoundation不能直接识别AVCaptureDevice，需要包装成AVCaptureDeviceInput
    
    //判断是否能加入到AVCaptureSession里面去，可以的话就加入
    if ([self.cCapturesession canAddInput:self.cCaptureDeviceInput]) {
        
        [self.cCapturesession addInput:self.cCaptureDeviceInput];
        
    }
    
    self.cCaptureDataOutput = [[AVCaptureVideoDataOutput alloc]init];
    
    [self.cCaptureDataOutput setAlwaysDiscardsLateVideoFrames:NO];
    
    //设置输入格式
    [self.cCaptureDataOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
    
    //设置输出队列
    [self.cCaptureDataOutput setSampleBufferDelegate:self queue:cCaptureQueue];
    
    //添加到输出队列
    if ([self.cCapturesession canAddOutput:self.cCaptureDataOutput]) {
        
        [self.cCapturesession addOutput:self.cCaptureDataOutput];
    }
    
    //建立连接
    AVCaptureConnection *connection = [self.cCaptureDataOutput connectionWithMediaType:AVMediaTypeVideo];
    
    //设置方向
    [connection setVideoOrientation:AVCaptureVideoOrientationPortrait];
    
    //设置预览图层
    self.cPreviewLayer = [[AVCaptureVideoPreviewLayer alloc]initWithSession:self.cCapturesession];
    
    [self.cPreviewLayer setVideoGravity:AVLayerVideoGravityResizeAspect];
    
    [self.cPreviewLayer setFrame:self.view.bounds];
    
    [self.view.layer addSublayer:self.cPreviewLayer];
    
    
    //文件写入
    NSString *filePath = [NSHomeDirectory()stringByAppendingPathComponent:@"/Documents/cc_video.h264"];
    
    [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
    
    BOOL createFile = [[NSFileManager defaultManager] createFileAtPath:filePath contents:nil attributes:nil];
    if (!createFile) {
        
        NSLog(@"create file failed");
    }else
    {
        NSLog(@"create file success");
    }
    
    NSLog(@"filePaht = %@",filePath);
    //一点点写入文件
    fileHandele = [NSFileHandle fileHandleForWritingAtPath:filePath];
    
    
    //初始化videoToolbBox
    [self initVideoToolBox];
    
    //开始捕捉
    [self.cCapturesession startRunning];
    
}


//停止捕捉
- (void)stopCapture
{
    
    [self.cCapturesession stopRunning];
    
    [self.cPreviewLayer removeFromSuperlayer];
    
    [self endVideoToolBox];
    
    [fileHandele closeFile];
    
    fileHandele = NULL;
    
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate
-(void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    //获取到视频流之后开始编码
    dispatch_sync(cEncodeQueue, ^{
        [self encode:sampleBuffer];
    });
    
}



//初始化videoToolBox  配置
-(void)initVideoToolBox
{
    //编码队列
    dispatch_sync(cEncodeQueue, ^{
        frameID = 0;
        
        int width = 480,height = 640;
        
        /*
         参数1：NULL,分配器 默认分配
         参数2：width
         参数3：height
         参数4：编码类型 H264
         参数5：NULL，编码规范 由VideoToolBox自行选择
         参数6：NULL，源像素缓冲区
         参数7：NULL，压缩数据分配器
         参数8：回调
         参数9：回调参考值
         参数10：编码回话变量
         */
        OSStatus status = VTCompressionSessionCreate(NULL, width, height, kCMVideoCodecType_H264, NULL, NULL, NULL, didCompressH264, (__bridge void *)(self), &cEncodeingSession);
        
        //设置实时编码
        VTSessionSetProperty(cEncodeingSession, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
        VTSessionSetProperty(cEncodeingSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_Baseline_AutoLevel);
        
        //设置关键帧（GOP)  间隔
        int frameInterval = 10;
        CFNumberRef frameIntervalRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &frameInterval);
        
        VTSessionSetProperty(cEncodeingSession,  kVTCompressionPropertyKey_MaxKeyFrameInterval, frameIntervalRef);
        
        //期望帧率
        int fps = 10;
        CFNumberRef fpsRef =CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &fps);
        
        VTSessionSetProperty(cEncodeingSession, kVTCompressionPropertyKey_ExpectedFrameRate, fpsRef);
        
        //码率  上线  最大期望值
        int bigRate = width * height *3 *4 *8;
        
        CFNumberRef bitRateRef =CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &bigRate);
        
        
        VTSessionSetProperty(cEncodeingSession, kVTCompressionPropertyKey_AverageBitRate ,bitRateRef);
        
        //码率  均值
        int bigRateLimit = width * height *3 *4;
        CFNumberRef bitRateLimitRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &bigRateLimit);
        VTSessionSetProperty(cEncodeingSession, kVTCompressionPropertyKey_DataRateLimits, bitRateLimitRef);
        
        //开始编码
        VTCompressionSessionPrepareToEncodeFrames(cEncodeingSession);
        
        
    });
}


//编码
- (void) encode:(CMSampleBufferRef )sampleBuffer
{
    //1.拿到每帧未编码数据
    CVImageBufferRef imageBuffer = (CVImageBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
    
    //2.设置帧时间
    CMTime presentationTimeStamp = CMTimeMake(frameID++, 1000);
    
    VTEncodeInfoFlags flags;
    OSStatus statusCode = VTCompressionSessionEncodeFrame(cEncodeingSession, imageBuffer, presentationTimeStamp, kCMTimeInvalid, NULL, NULL, &flags);
    
    
    if (statusCode != noErr) {
        
        VTCompressionSessionInvalidate(cEncodeingSession);
        CFRelease(cEncodeingSession);
        cEncodeingSession = NULL;
        
    }
    
}


//编码完成回调
/*
 1.H264编码完成后，回调
 2.将编码成功的CMSampleBufferRef 转为 H264码流
 3.解析SPS & PPS 组装码  nalu
 */
void didCompressH264(void *outputCallbackRefCon, void *sourceFrameRefCon, OSStatus status, VTEncodeInfoFlags infoFlags, CMSampleBufferRef sampleBuffer)
{
    if(status != 0){
        return;
    }
    
    if (!CMSampleBufferDataIsReady(sampleBuffer)) {
        return;
    }
    
    ViewController *encoder = (__bridge ViewController *)outputCallbackRefCon;
    
    bool keyFrame = !CFDictionaryContainsKey((CFArrayGetValueAtIndex(CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true), 0)), kCMSampleAttachmentKey_NotSync);//判断关键帧
    
    if (keyFrame) {
        CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
        
        //sps
        size_t sparamrterSetSize,sparamerterSetCount;
        const uint8_t *sparameterSet;
        OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 1,&sparameterSet, &sparamrterSetSize, &sparamerterSetCount, 0);
        if (statusCode == noErr) {
            //pps
            size_t pparamrterSetSize,pparamerterSetCount;
            const uint8_t *pparameterSet;
            
            OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 1, &pparameterSet, &pparamrterSetSize, &pparamerterSetCount, 0);
            
            if (statusCode == noErr) {
                NSData *sps = [NSData dataWithBytes:sparameterSet length:sparamrterSetSize];
                NSData *pps = [NSData dataWithBytes:pparameterSet length:pparamrterSetSize];
                if (encoder) {
                    [encoder gotSpsPps:sps pps:pps];
                }
            }
        }
    }
    
    CMBlockBufferRef dataBuffer  = CMSampleBufferGetDataBuffer(sampleBuffer);
    
    size_t length,totalLength;
    
    char *dataPointer;
    
    OSStatus statusCodeRet = CMBlockBufferGetDataPointer(dataBuffer, 0, &length, &totalLength, &dataPointer);
    
    if (statusCodeRet == noErr) {
        
        size_t bufferOffSet = 0;
        static const int AVVCHeaderLength = 4;
        
        while (bufferOffSet <totalLength - AVVCHeaderLength) {
            uint32_t NALUnitLength = 0;
            memcpy(&NALUnitLength, dataPointer + bufferOffSet, AVVCHeaderLength);
            
            //获取nalu
            NSData *data = [[NSData alloc]initWithBytes:(dataPointer + bufferOffSet + AVVCHeaderLength) length:NALUnitLength];
            
            //将nalu数据写入到文件
            [encoder gotEncodedData:data isKeyFrame:keyFrame];
            
            //读取下一个NALU数据
            bufferOffSet += AVVCHeaderLength + NALUnitLength;
            
            
        }
    }
    
}
/*
 序列参数集SPS
 图像参数集合PPS
 
 编码所用的Profile、level、图像的宽和高、deblock录波器。。。。
 h264码流第一个NALU是 SPS & PPS
 
 
 (1)第一位为禁位
 (2)第2-3位为参考级别
 (3)第4-8位为nal单元类型
 */
- (void)gotSpsPps:(NSData*)sps pps:(NSData*)pps
{
    
    const char bytes[] = "\x00\x00\x00\x01";
    
    size_t length = sizeof(bytes) - 1;
    
    NSData *byteHeader = [NSData dataWithBytes:bytes length:length];
    
    [fileHandele writeData:byteHeader];
    
    [fileHandele writeData:sps];
    
    [fileHandele writeData:byteHeader];
    
    [fileHandele writeData:pps];
    
    
}


- (void)gotEncodedData:(NSData*)data isKeyFrame:(BOOL)isKeyFrame
{
    if (fileHandele != NULL) {
        
        /*
         nalu 0x  0000001  0000001  0x0000003
         H264 2种打包方式：
         annex-b byte steam  format
         原始方式
         */
        const char bytes[] = "\x00\x00\x00\x01";
        
        //获取长度
        size_t length = sizeof(bytes)-1;
        
        NSData *headerByte = [NSData dataWithBytes:bytes length:length];
        
        [fileHandele writeData:headerByte];
        
        [fileHandele writeData:data];
        
        
    }
}

//结束VideoToolBox
-(void)endVideoToolBox
{
    VTCompressionSessionCompleteFrames(cEncodeingSession, kCMTimeInvalid);
    VTCompressionSessionInvalidate(cEncodeingSession);
    CFRelease(cEncodeingSession);
    cEncodeingSession = NULL;
}



- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
