//
//  RZAudioPlayer.m
//  Pods
//
//  Created by yxibng on 2020/10/10.
//

#import "RZAudioPlayer.h"
#import "DbyAudioChannelBuffer.h"
#import <AudioToolbox/AudioToolbox.h>
#import "DbyAudioDevice.h"
#import "RZAudioUtil.h"

#define kIOBufferFrameSize 160
#define kOutputBus 0
#define kInputBus 1


@interface RZAudioPlayer ()
{
    AudioUnit _audioUnit;
    AUNode _audioNode;
    AUGraph _graph;
    AudioStreamBasicDescription _inputStreamFormat;
}

@property (nonatomic, strong) DbyAudioChannelBuffer *buffer;
@property (nonatomic, assign) BOOL setupSuccess;

@end


@implementation RZAudioPlayer

- (void)dealloc
{
    [self stop];
    
    OSStatus status = DisposeAUGraph(_graph);
    NSAssert(status == noErr, @"DisposeAUGraph error");
    _graph = NULL;
    [_buffer clearBuffer];
    _buffer = nil;
}


- (instancetype)init
{
    self = [super init];
    if (self) {
        _buffer = [[DbyAudioChannelBuffer alloc] init];
        _inputStreamFormat = [RZAudioUtil intFormatWithNumberOfChannels:1 sampleRate:16000];
        [self rz_setup];
    }
    return self;
}


- (void)rz_setup {
    
    //new graph
    NewAUGraph(&_graph);
    OSStatus status = 0;
    
    //output node
    AudioComponentDescription outputComponectDesc;
    outputComponectDesc.componentType = kAudioUnitType_Output;
#if TARGET_OS_IOS
    outputComponectDesc.componentSubType = kAudioUnitSubType_VoiceProcessingIO;
#elif TARGET_OS_OSX
    outputComponectDesc.componentSubType = kAudioUnitSubType_HALOutput;
#endif
    outputComponectDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    outputComponectDesc.componentFlagsMask = 0;
    outputComponectDesc.componentFlags = 0;
    
    status = AUGraphAddNode(_graph, &outputComponectDesc, &_audioNode);
    NSAssert(status == noErr, @"error");
    if (status != noErr) {
        [self trackErrorWithStatus:status funcName:(char *)__FUNCTION__ lineNuber:__LINE__];
        return;
    }
    
    //open graph
    status = AUGraphOpen(_graph);
    NSAssert(status == noErr, @"error");
    if (status != noErr) {
        [self trackErrorWithStatus:status funcName:(char *)__FUNCTION__ lineNuber:__LINE__];
        return;
    }

    //get ouput unit
    status = AUGraphNodeInfo(_graph, _audioNode, &outputComponectDesc, &_audioUnit);
    NSAssert(status == noErr, @"error");
    if (status != noErr) {
        [self trackErrorWithStatus:status funcName:(char *)__FUNCTION__ lineNuber:__LINE__];
        return;
    }
    
#if TARGET_OS_IOS
    //打开回声消除的开关
    UInt32 echoCancellation;
    UInt32 size = sizeof(echoCancellation);

    //0 代表开， 1 代表关
    echoCancellation = 0;
    status = AudioUnitSetProperty(_audioUnit,
                                  kAUVoiceIOProperty_BypassVoiceProcessing,
                                  kAudioUnitScope_Global,
                                  0,
                                  &echoCancellation,
                                  size);

    NSAssert(status == noErr, @"error");
    if (status != noErr) {
        [self trackErrorWithStatus:status funcName:(char *)__FUNCTION__ lineNuber:__LINE__];
        return;
    }
#endif
    
    //ouput unit  input format
    status = AudioUnitSetProperty(_audioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  kOutputBus,
                                  &_inputStreamFormat,
                                  sizeof(AudioStreamBasicDescription));

    NSAssert(status == noErr, @"error");
    if (status != noErr) {
        [self trackErrorWithStatus:status funcName:(char *)__FUNCTION__ lineNuber:__LINE__];
        return;
    }

    
#if TARGET_OS_OSX

    DbyAudioDevice *device = [DbyAudioDevice currentOutputDevice];
    [self setDeviceID:device.deviceID];
#endif

    status = AUGraphInitialize(_graph);
    NSAssert(status == noErr, @"error");
    if (status != noErr) {
        [self trackErrorWithStatus:status funcName:(char *)__FUNCTION__ lineNuber:__LINE__];
        return;
    }
    
    //TODO: 这里的没有理解清楚，之后需要处理一下
    status = AudioUnitSetMaxIOBufferFrameSize(_audioUnit, 4096);
    if (status != noErr) {
        [self trackErrorWithStatus:status funcName:(char *)__FUNCTION__ lineNuber:__LINE__];
        return;
    }
    
    //set callback
    AURenderCallbackStruct rcbs;
    rcbs.inputProc = &playbackCallback;
    rcbs.inputProcRefCon = (__bridge void * _Nullable)(self);
    status = AUGraphSetNodeInputCallback(_graph, _audioNode, kOutputBus, &rcbs);
    NSAssert(status == noErr, @"error");
    if (status != noErr) {
        [self trackErrorWithStatus:status funcName:(char *)__FUNCTION__ lineNuber:__LINE__];
        return;
    }

    //input stream format
    status = AudioUnitSetProperty(_audioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  kOutputBus,
                                  &_inputStreamFormat,
                                  sizeof(AudioStreamBasicDescription));

    NSAssert(status == noErr, @"error");
    if (status != noErr) {
        [self trackErrorWithStatus:status funcName:(char *)__FUNCTION__ lineNuber:__LINE__];
        return;
    }
    //记录设置成功
    self.setupSuccess = YES;
}

- (void)start {
    
    if (!self.setupSuccess) {
        //初始化失败
        if ([self.delegate respondsToSelector:@selector(audioPlayer:didStartwithError:)]) {
            [self.delegate audioPlayer:self didStartwithError:RZAudioPlayerStartErrorInitializeFailed];
        }
        return;
    }
    
    if (self.isRunning) {
        //正在运行
        if ([self.delegate respondsToSelector:@selector(audioPlayer:didStartwithError:)]) {
            [self.delegate audioPlayer:self didStartwithError:RZAudioPlayerStartErrorOK];
        }
        return;
    }
    
    OSStatus status = AUGraphInitialize(_graph);
    NSAssert(status == noErr, @"error");
    if (status != noErr) {
        //失败了
        if ([self.delegate respondsToSelector:@selector(audioPlayer:didStartwithError:)]) {
            [self.delegate audioPlayer:self didStartwithError:RZAudioPlayerStartErrorFailed];
        }
        [self trackErrorWithStatus:status funcName:(char *)__FUNCTION__ lineNuber:__LINE__];
        return;
    }

    status = AUGraphStart(_graph);
    NSAssert(status == noErr, @"error");
    if (status != noErr) {
        //失败了
        if ([self.delegate respondsToSelector:@selector(audioPlayer:didStartwithError:)]) {
            [self.delegate audioPlayer:self didStartwithError:RZAudioPlayerStartErrorFailed];
        }
        [self trackErrorWithStatus:status funcName:(char *)__FUNCTION__ lineNuber:__LINE__];
        return;
    }
    //成功
    if ([self.delegate respondsToSelector:@selector(audioPlayer:didStartwithError:)]) {
        [self.delegate audioPlayer:self didStartwithError:RZAudioPlayerStartErrorOK];
    }

}

- (void)stop {
    
    if ([self.delegate respondsToSelector:@selector(audioPlayerDidStop:)]) {
        [self.delegate audioPlayerDidStop:self];
    }
    
    if (!self.isRunning) {
        return;
    }
    
    OSStatus status = AUGraphStop(_graph);
    if (status) {
        [self trackErrorWithStatus:status funcName:(char *)__FUNCTION__ lineNuber:__LINE__];
    }
}

- (BOOL)isRunning {
    if (_graph == NULL) {
        return NO;
    }
    Boolean isRunning = false;
    OSStatus status = AUGraphIsRunning(_graph, &isRunning);
    NSAssert(status == noErr, @"error");
    if (status != noErr) {
        [self trackErrorWithStatus:status funcName:(char *)__FUNCTION__ lineNuber:__LINE__];
        return NO;
    }
    return isRunning ? YES : NO;
}

- (void)receiveAudioData:(void *)audioData length:(int)length {
    [self.buffer enqueueAudioData:audioData length:length];
}

#if TARGET_OS_OSX

- (void)setDeviceID:(AudioDeviceID)deviceID {
    _deviceID = deviceID;
    OSStatus status = AudioUnitSetProperty(_audioUnit,
                                  kAudioOutputUnitProperty_CurrentDevice,
                                  kAudioUnitScope_Global,
                                  0,
                                  &deviceID,
                                  sizeof(AudioDeviceID));
    NSAssert(status == noErr, @"failed to set current audio output device");
    if (status != noErr) {
        [self trackErrorWithStatus:status funcName:(char *)__FUNCTION__ lineNuber:__LINE__];
        return;
    }
    
    UInt32 min, max;
    status = GetIOBufferFrameSizeRange(deviceID, &min, &max);
    NSLog(@"min = %d, max = %d",min, max);
    //当前 unit 的最大 slice
    [self rz_setMaximumBufferSize:max];
    
    //获取需要输入的数据的格式
    UInt32 propSize = sizeof(AudioStreamBasicDescription);
    AudioStreamBasicDescription desc;
    status = AudioUnitGetProperty(_audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, kOutputBus, &desc, &propSize);
    assert(status == noErr);
    if (status!=noErr) {
        return;
    }
    NSLog(@"input sample rate = %f",desc.mSampleRate);
    UInt32 ioBufferFrameSize = desc.mSampleRate * 0.02;
    //设置当前设备的每次读取的采样个数
    status = SetCurrentIOBufferFrameSize(deviceID, ioBufferFrameSize);
    NSAssert(status == noErr, @"failed to set current io buffer framesize to %d", ioBufferFrameSize);
    if (status != noErr) {
        [self trackErrorWithStatus:status funcName:(char *)__FUNCTION__ lineNuber:__LINE__];
        return;
    }
}

#endif

#pragma mark -
- (void)trackErrorWithStatus:(OSStatus)status funcName:(char *)funcName lineNuber:(int)lineNumber
{
//    if ([self.delegate respondsToSelector:@selector(audioPlayer:didOccurError:)]) {
//        NSString *info = [NSString stringWithFormat:@"%s__%s__%d", __FILE__, funcName, lineNumber];
//        NSDictionary *useInfo = @{ @"status" : @(status),
//                                   @"info" : info
//        };
//        [self.delegate auidoPlayer:self didOccurError:useInfo];
//    }
}


static OSStatus playbackCallback(void *inRefCon,
                                 AudioUnitRenderActionFlags *ioActionFlags,
                                 const AudioTimeStamp *inTimeStamp,
                                 UInt32 inBusNumber,
                                 UInt32 inNumberFrames,
                                 AudioBufferList *ioData)
{
    RZAudioPlayer *player = (__bridge RZAudioPlayer *)inRefCon;
    for (NSInteger i = 0; i < ioData->mNumberBuffers; i++) {
        if (i == 0) {
            int size = ioData->mBuffers[0].mDataByteSize;
            [player.buffer dequeueLength:size dstBuffer:ioData->mBuffers[0].mData];
        } else {
            memcpy(ioData->mBuffers[i].mData, ioData->mBuffers[0].mData, ioData->mBuffers[i].mDataByteSize);
        }
    }
    return noErr;
}


- (OSStatus)rz_setMaximumBufferSize:(UInt32)size {
    
    OSStatus status = AudioUnitSetMaxIOBufferFrameSize(_audioUnit, size);
    return status;
}

@end
