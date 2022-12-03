//
//  TSAudioPlayer.m
//  Pods
//
//  Created by yxibng on 2020/10/10.
//

#import "TSAudioPlayer.h"
#import "TSAudioChannelBuffer.h"
#import <AudioToolbox/AudioToolbox.h>
#import "TSAudioDevice.h"
#import "TSAudioUtil.h"

#define kIOBufferFrameSize 160
#define kOutputBus 0
#define kInputBus 1


@interface TSAudioPlayer ()
{
    AudioUnit _audioUnit;
    AUNode _audioNode;
    AUGraph _graph;
    AudioStreamBasicDescription _inputStreamFormat;
}

@property (nonatomic, strong) TSAudioChannelBuffer *buffer;
@property (nonatomic, assign) BOOL setupSuccess;

@end


@implementation TSAudioPlayer

- (void)dealloc
{
    [self disposePlayer];
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _buffer = [[TSAudioChannelBuffer alloc] init];
        _inputStreamFormat = [TSAudioUtil intFormatWithNumberOfChannels:1 sampleRate:16000];
        _streamDesc = _inputStreamFormat;
    }
    return self;
}


//初始化
- (BOOL)initPlayer {
    if (self.setupSuccess) {
        //不可以重复初始化
        return YES;
    }
    [self ts_setup];
    return self.setupSuccess;
}
//销毁
- (BOOL)disposePlayer {
    
    if (!_graph) {
        return YES;
    }
    [self stop];
    OSStatus status = DisposeAUGraph(_graph);
    NSAssert(status == noErr, @"DisposeAUGraph error, status = %d", (int)status);
    _graph = NULL;
    [_buffer clearBuffer];
    _setupSuccess = NO;
    return YES;
}


- (void)ts_setup {
    //new graph
    NewAUGraph(&_graph);
    OSStatus status = 0;
    
    //output node
    AudioComponentDescription outputComponentDesc;
    outputComponentDesc.componentType = kAudioUnitType_Output;
#if TARGET_OS_IOS
    outputComponentDesc.componentSubType = kAudioUnitSubType_VoiceProcessingIO;
#elif TARGET_OS_OSX
    outputComponentDesc.componentSubType = kAudioUnitSubType_HALOutput;
#endif
    outputComponentDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    outputComponentDesc.componentFlagsMask = 0;
    outputComponentDesc.componentFlags = 0;
    
    status = AUGraphAddNode(_graph, &outputComponentDesc, &_audioNode);
    NSAssert(status == noErr, @"failed to add node, status = %d", (int)status);
    if (status != noErr) {
        [self trackErrorWithStatus:status funcName:(char *)__FUNCTION__ lineNuber:__LINE__];
        return;
    }
    
    //open graph
    status = AUGraphOpen(_graph);
    NSAssert(status == noErr, @"failed to open graph, status = %d", (int)status);
    if (status != noErr) {
        [self trackErrorWithStatus:status funcName:(char *)__FUNCTION__ lineNuber:__LINE__];
        return;
    }
    
    //get ouput unit
    status = AUGraphNodeInfo(_graph, _audioNode, &outputComponentDesc, &_audioUnit);
    NSAssert(status == noErr, @"failed to get audio unit, status = %d",(int)status);
    if (status != noErr) {
        [self trackErrorWithStatus:status funcName:(char *)__FUNCTION__ lineNuber:__LINE__];
        return;
    }
    
    //ouput unit  input format
    status = AudioUnitSetProperty(_audioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  kOutputBus,
                                  &_inputStreamFormat,
                                  sizeof(AudioStreamBasicDescription));
    
    NSAssert(status == noErr, @"failed to set streamformat in scope input, status = %d",(int)status);
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
    NSAssert(status == noErr, @"failed to set input callback, status = %d",(int)status);
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
    
    NSAssert(status == noErr, @"failed to set StreamFormat in input scope, status = %d",(int)status);
    if (status != noErr) {
        [self trackErrorWithStatus:status funcName:(char *)__FUNCTION__ lineNuber:__LINE__];
        return;
    }
    
    status = AUGraphInitialize(_graph);
    NSAssert(status == noErr, @"failed to initialize graph, status = %d",(int)status);
    if (status != noErr) {
        [self trackErrorWithStatus:status funcName:(char *)__FUNCTION__ lineNuber:__LINE__];
        return;
    }
    //记录设置成功
    self.setupSuccess = YES;
    
#if TARGET_OS_OSX
    TSAudioDevice *device = [TSAudioDevice currentOutputDevice];
    [self setDeviceID:device.deviceID];
#endif
    
}

- (void)start {
    
    if (!self.setupSuccess) {
        //初始化失败
        if ([self.delegate respondsToSelector:@selector(audioPlayer:didStartwithError:)]) {
            [self.delegate audioPlayer:self didStartwithError:TSAudioPlayerStartErrorInitializeFailed];
        }
        return;
    }
    
    if (self.isRunning) {
        //正在运行
        if ([self.delegate respondsToSelector:@selector(audioPlayer:didStartwithError:)]) {
            [self.delegate audioPlayer:self didStartwithError:TSAudioPlayerStartErrorOK];
        }
        return;
    }
    
    OSStatus status = AUGraphInitialize(_graph);
    NSAssert(status == noErr, @"failed to initialize audio graph, status = %d",(int)status);
    if (status != noErr) {
        //失败了
        if ([self.delegate respondsToSelector:@selector(audioPlayer:didStartwithError:)]) {
            [self.delegate audioPlayer:self didStartwithError:TSAudioPlayerStartErrorFailed];
        }
        [self trackErrorWithStatus:status funcName:(char *)__FUNCTION__ lineNuber:__LINE__];
        return;
    }
    
    status = AUGraphStart(_graph);
    NSAssert(status == noErr, @"failed to start audio graph, status = %d", (int)status);
    if (status != noErr) {
        //失败了
        if ([self.delegate respondsToSelector:@selector(audioPlayer:didStartwithError:)]) {
            [self.delegate audioPlayer:self didStartwithError:TSAudioPlayerStartErrorFailed];
        }
        [self trackErrorWithStatus:status funcName:(char *)__FUNCTION__ lineNuber:__LINE__];
        return;
    }
    //成功
    if ([self.delegate respondsToSelector:@selector(audioPlayer:didStartwithError:)]) {
        [self.delegate audioPlayer:self didStartwithError:TSAudioPlayerStartErrorOK];
    }
    //开始播放，清空缓冲区
    [self ts_clearBuffer];
}

- (void)stop {
    
    if ([self.delegate respondsToSelector:@selector(audioPlayerDidStop:)]) {
        [self.delegate audioPlayerDidStop:self];
    }
    
    if (_graph == NULL || !self.setupSuccess) {
        return;
    }
    
    if (!self.isRunning) {
        return;
    }
    
    OSStatus status = AUGraphStop(_graph);
    if (status) {
        [self trackErrorWithStatus:status funcName:(char *)__FUNCTION__ lineNuber:__LINE__];
    }
    //停止播放，清空缓冲区
    [self ts_clearBuffer];
}


- (void)ts_clearBuffer {
    /*
     开启和关闭时候，需要清空当前缓冲区的数据
     */
    [self.buffer clearBuffer];
}

- (BOOL)isRunning {
    if (_graph == NULL || !self.setupSuccess) {
        return NO;
    }
    
    Boolean isInited = FALSE;
    OSStatus status = AUGraphIsInitialized(_graph, &isInited);
    if (status != noErr) {
        return NO;
    }
    if (!isInited) {
        //没有初始化
        return NO;
    }
    Boolean isRunning = FALSE;
    status = AUGraphIsRunning(_graph, &isRunning);
    NSAssert(status == noErr, @"failed to check graph running state, status = %d",(int)status);
    if (status != noErr) {
        [self trackErrorWithStatus:status funcName:(char *)__FUNCTION__ lineNuber:__LINE__];
        return NO;
    }
    
    return isRunning ? YES : NO;
}

- (void)receiveAudioData:(void *)audioData length:(int)length {
    [self.buffer enqueueAudioData:audioData length:length];
}

#if TARGET_OS_IOS
- (void)handleMeidaServiesWereReset {
    [self ts_setup];
}
#endif


#if TARGET_OS_OSX

- (void)setDeviceID:(AudioDeviceID)deviceID {
    _deviceID = deviceID;
    
    if (!_setupSuccess) {
        return;
    }
    
    [self ts_changeToDevice:deviceID];
}

- (void)ts_changeToDevice:(AudioDeviceID)deviceID {
    assert(deviceID != kAudioDeviceUnknown);
    if (deviceID == kAudioDeviceUnknown) {
        [self trackErrorWithStatus:-1 funcName:(char *)__FUNCTION__ lineNuber:__LINE__];
        return;
    }
    
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
    
    //获取需要输入的数据的格式
    UInt32 propSize = sizeof(AudioStreamBasicDescription);
    AudioStreamBasicDescription desc;
    status = AudioUnitGetProperty(_audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, kOutputBus, &desc, &propSize);
    assert(status == noErr);
    if (status!=noErr) {
        return;
    }
    UInt32 ioBufferFrameSize = desc.mSampleRate * 0.02;
    //设置当前设备的每次读取的采样个数
    //当前 unit 的最大 slice
    [self ts_setMaximumBufferSize:max];
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
    
    TSAudioPlayer *player = (__bridge TSAudioPlayer *)inRefCon;
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


- (OSStatus)ts_setMaximumBufferSize:(UInt32)size {
    
    OSStatus status = AudioUnitSetMaxIOBufferFrameSize(_audioUnit, size);
    return status;
}

@end
