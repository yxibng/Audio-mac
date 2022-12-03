//
//  TSAudioRecorder.m
//  TSRtc_macOS
//
//  Created by yxibng on 2020/9/29.
//

#import "TSAudioRecorder.h"
#import "TSAudioDevice.h"
#import "TSAudioUtil.h"
#import <AVFoundation/AVFoundation.h>
#import <mach/mach_time.h>


#define kOutputBus 0
#define kInputBus 1

static uint64_t covnertToNanos(UInt64 inHostTime) {
    static mach_timebase_info_data_t sTimebaseInfo;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        (void) mach_timebase_info(&sTimebaseInfo);
    });
    
#if TARGET_OS_MAC && TARGET_RT_64_BIT
    __uint128_t theAnswer = inHostTime;
#else
    long double theAnswer = inHostTime;
#endif
    UInt32 inNumerator = sTimebaseInfo.numer;
    UInt32 inDenominator = sTimebaseInfo.denom;
    if(inNumerator != inDenominator)
    {
        theAnswer *= inNumerator;
        theAnswer /= inDenominator;
    }
    return (uint64_t)theAnswer;
}


typedef struct {
    AudioUnit audioUnit;
    AUNode audioNode;
    
#if TARGET_OS_OSX
    AudioBufferList *renderBufferList;
    AudioStreamBasicDescription inputScopeFormat;
#endif
    AudioStreamBasicDescription outputScopeFormat;
    
} TSAudioRecordInfo;


static OSStatus inputRenderCallback(void *inRefCon,
                                    AudioUnitRenderActionFlags *ioActionFlags,
                                    const AudioTimeStamp *inTimeStamp,
                                    UInt32 inBusNumber,
                                    UInt32 inNumberFrames,
                                    AudioBufferList *ioData);



@interface TSAudioRecorder ()
{
@public
    TSAudioRecordInfo _recorderInfo;
    AUGraph _graph;
}
@property (nonatomic, assign) BOOL setupSuccess;
@property (nonatomic, assign) TSAudioConfig realConfig;
@property (nonatomic, assign) TSAudioConfig expectedConfig;

@end

@implementation TSAudioRecorder


- (void)dealloc
{
    [self disposeRecorder];
#if TARGET_OS_OSX
    [TSAudioUtil freeAudioBufferList:_recorderInfo.renderBufferList];
#endif
}


- (instancetype)initWithConfig:(TSAudioConfig)config delegate:(id<TSAudioRecorderDelegate>)delegate {
    if (self = [super init]) {
        _expectedConfig = config;
        _delegate = delegate;
        _setupSuccess = NO;
#if TARGET_OS_IOS
        _realConfig.channelCount = 1;
        _realConfig.sampleRate = 16000;
        _realConfig.timeInterval = 20;
#endif
        [self initRecorder];
    }
    return self;
}

//初始化
- (BOOL)initRecorder {
    [self ts_setupGraph];
    return YES;
}
//销毁
- (BOOL)disposeRecorder {
    _setupSuccess = NO;
    if (_graph) {
        AUGraphStop(_graph);
        AUGraphClose(_graph);
        AUGraphUninitialize(_graph);
        DisposeAUGraph(_graph);
        _graph = NULL;
    }
    return YES;
}

- (void)start
{
    if (!self.setupSuccess) {
        //初始化失败
        if ([self.delegate respondsToSelector:@selector(audioRecorder:didStartWithError:)]) {
            [self.delegate audioRecorder:self didStartWithError:TSAudioRecorderInitializeFailed];
        }
        return;
    }
    
#if TARGET_OS_IOS
    [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
        if (granted) {
            [self ts_startRecording];
        } else {
            //no permission, start failed
            [[TSProgressDataHelper shareInstance] saveMessage:@"[ERROR] [TSAudioRecorder] [NO premission to start]"];
            if ([self.delegate respondsToSelector:@selector(audioRecorder:didStartWithError:)]) {
                [self.delegate audioRecorder:self didStartWithError:TSAudioRecorderStartErrorNoPermission];
            }
        }
    }];
    
#elif TARGET_OS_OSX
    if (@available(macOS 10.14, *)) {
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio completionHandler:^(BOOL granted) {
            if (granted) {
                [self ts_startRecording];
            } else {
                //no permission, start failed
                if ([self.delegate respondsToSelector:@selector(audioRecorder:didStartWithError:)]) {
                    [self.delegate audioRecorder:self didStartWithError:TSAudioRecorderStartErrorNoPermission];
                }
            }
        }];
    } else {
        [self ts_startRecording];
    }
#endif
}


- (BOOL)isRunning
{
    if (_graph == NULL || !self.setupSuccess) {
        return NO;
    }
    
    Boolean isInited = FALSE;
    OSStatus status = AUGraphIsInitialized(_graph, &isInited);
    if (!isInited || status != noErr) {
        //没有初始化
        return NO;
    }
    
    Boolean isRunning = FALSE;
    status = AUGraphIsRunning(_graph, &isRunning);
    NSAssert(status == noErr, @"Error trying querying whether graph is running, status %d", (int)status);
    if (status) {
        [self trackErrorWithStatus:status funcName:(char *)__FUNCTION__ lineNuber:__LINE__];
    }
    return isRunning;
}

- (void)stop
{
    if (_graph == NULL) {
        return;
    }
    Boolean isRunning = false;
    OSStatus status = AUGraphIsRunning(_graph, &isRunning);
    NSAssert(status == noErr, @"Error trying querying whether graph is running, status %d", (int)status);
    if (status != noErr) {
        [self trackErrorWithStatus:status funcName:(char *)__FUNCTION__ lineNuber:__LINE__];
    }
    if (!isRunning) {
        return;
    }
    status = AUGraphStop(_graph);
    self.started = NO;
    NSAssert(status == noErr, @"Failed to stop Audio Graph, status %d", (int)status);
    if (status != noErr) {
        [self trackErrorWithStatus:status funcName:(char *)__FUNCTION__ lineNuber:__LINE__];
    }
    if ([self.delegate respondsToSelector:@selector(audioRecorderDidStop:)]) {
        [self.delegate audioRecorderDidStop:self];
    }
}

#pragma mark -

#if TARGET_OS_IOS
-(BOOL)handleMeidaServiesWereReset {
    self.setupSuccess = NO;
    return [self initRecorder];
}
#endif


- (void)setAudioConfig:(TSAudioConfig)audioConfig {
    _expectedConfig = audioConfig;
    //TODO: 这里应该根据配置去修改采集器配置
}
#pragma mark - MacOS
#if TARGET_OS_OSX
- (void)setDeviceID:(AudioDeviceID)deviceID {
    _deviceID = deviceID;
    if (!self.setupSuccess) {
        //没有初始化成功，不可以调用
        return;
    }
    /**
     如果没有初始化，返回
     已经初始化，开始更改设备
     */
    [self ts_changeDeviceTo:deviceID];
}


- (void)ts_changeDeviceTo:(AudioDeviceID)deviceID {
    
    AudioDeviceID deviceId = deviceID;
    OSStatus status = AudioUnitSetProperty(_recorderInfo.audioUnit,
                                           kAudioOutputUnitProperty_CurrentDevice,
                                           kAudioUnitScope_Global,
                                           kOutputBus,
                                           &deviceId,
                                           sizeof(AudioDeviceID));
    NSAssert(status == noErr, @"Couldn't set default device on I/O unit, status %d", status);
    if (status != noErr) {
        [self trackErrorWithStatus:status funcName:(char *)__FUNCTION__ lineNuber:__LINE__];
        return;
    }
    
    
    UInt32 min, max;
    status = GetIOBufferFrameSizeRange(deviceId, &min, &max);
    
    /*
     获取麦克风端的采样率
     */
    UInt32 propSize = sizeof(AudioStreamBasicDescription);
    status = AudioUnitGetProperty(_recorderInfo.audioUnit, kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  kInputBus,
                                  &_recorderInfo.inputScopeFormat,
                                  &propSize);
    NSAssert(status == noErr, @"Couldn't get streamFormat, status %d", status);
    if (status != noErr) {
        [self trackErrorWithStatus:status funcName:(char *)__FUNCTION__ lineNuber:__LINE__];
        return;
    }
    
    /*
     设置麦克风的输出的采样格式，采样率保持和麦风输入端的采样率一致。
     
     麦克风输入端和输出的的采样率要一致
     在外接设备的时候，输入端采样率8000，输出端16000，
     在回掉用调用AudioUnitRender的时候，返回-10863.
     设置成一样的采样率，问题就解决了。
     */
    _recorderInfo.outputScopeFormat = [TSAudioUtil intFormatWithNumberOfChannels:1 sampleRate:_recorderInfo.inputScopeFormat.mSampleRate];
    
    status = AudioUnitSetProperty(_recorderInfo.audioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Output,
                                  kInputBus,
                                  &_recorderInfo.outputScopeFormat,
                                  sizeof(_recorderInfo.outputScopeFormat));
    
    NSAssert(status == noErr, @"Couldn't set streamFormat, status %d", status);
    
    [self ts_setMaximumBufferSize:max];
    status = SetCurrentIOBufferFrameSize(deviceId, _recorderInfo.inputScopeFormat.mSampleRate * 0.02);
    NSAssert(status == noErr, @"Couldn't set IOBufferFrameSize to %f, status %d", _recorderInfo.inputScopeFormat.mSampleRate * 0.02, status);
    if (status != noErr) {
        [self trackErrorWithStatus:status funcName:(char *)__FUNCTION__ lineNuber:__LINE__];
        return;
    }
    
    /*
     每次 IO 128 帧，采样率为 44100，目标采样率 16000
     重采样后，大概为 128 * 16000 / 44100 =  47 帧。
     所以设置为 128帧的缓冲，足够用了
     */
    
    [TSAudioUtil freeAudioBufferList:_recorderInfo.renderBufferList];
    _recorderInfo.renderBufferList = [TSAudioUtil audioBufferListWithNumberOfFrames:max streamFormat:_recorderInfo.outputScopeFormat];
    
    /*
     这里获得了真正的采样率,采样的时间间隔
     */
    _realConfig.channelCount = 1;
    _realConfig.sampleRate = _recorderInfo.outputScopeFormat.mSampleRate;
    _realConfig.timeInterval = _recorderInfo.inputScopeFormat.mSampleRate * 0.02 / _recorderInfo.outputScopeFormat.mSampleRate * 1000;
}
#endif

#pragma mark -

- (UInt32)ts_maximumBufferSize
{
    UInt32 maximumBufferSize;
    UInt32 propSize = sizeof(maximumBufferSize);
    OSStatus status = AudioUnitGetProperty(_recorderInfo.audioUnit,
                                           kAudioUnitProperty_MaximumFramesPerSlice,
                                           kAudioUnitScope_Global,
                                           0,
                                           &maximumBufferSize,
                                           &propSize);
    assert(status == noErr);
    return maximumBufferSize;
}


- (OSStatus)ts_setMaximumBufferSize:(UInt32)size {
    
    OSStatus status = AudioUnitSetMaxIOBufferFrameSize(_recorderInfo.audioUnit, size);
    return status;
}


- (void)ts_setupGraph
{
    if (self.setupSuccess) {
        return;
    }
    
    self.setupSuccess = NO;
    //Create graph
    OSStatus status = NewAUGraph(&_graph);
    NSAssert(status == noErr, @"NewAUGraph error, status %d", (int)status);
    if (status != noErr) {
        [self trackErrorWithStatus:status funcName:(char *)__FUNCTION__ lineNuber:__LINE__];
        return;
    }
    
    AudioComponentDescription componentDescripiton = {0};
    componentDescripiton.componentType = kAudioUnitType_Output;
#if TARGET_OS_IOS
    componentDescripiton.componentSubType = kAudioUnitSubType_VoiceProcessingIO;
#elif TARGET_OS_OSX
    componentDescripiton.componentSubType = kAudioUnitSubType_HALOutput;
#endif
    componentDescripiton.componentManufacturer = kAudioUnitManufacturer_Apple;
    componentDescripiton.componentFlags = 0;
    componentDescripiton.componentFlagsMask = 0;
    
    //add node
    status = AUGraphAddNode(_graph,
                            &componentDescripiton,
                            &_recorderInfo.audioNode);
    NSAssert(status == noErr, @"AUGraphAddNode error, status %d", (int)status);
    if (status != noErr) {
        [self trackErrorWithStatus:status funcName:(char *)__FUNCTION__ lineNuber:__LINE__];
        return;
    }
    //open graph
    status = AUGraphOpen(_graph);
    NSAssert(status == noErr, @"AUGraphOpen error, status %d", (int)status);
    if (status != noErr) {
        [self trackErrorWithStatus:status funcName:(char *)__FUNCTION__ lineNuber:__LINE__];
        return;
    }
    //get unit
    status = AUGraphNodeInfo(_graph,
                             _recorderInfo.audioNode,
                             &componentDescripiton,
                             &_recorderInfo.audioUnit);
    NSAssert(status == noErr, @"AUGraphNodeInfo error, status %d", (int)status);
    if (status != noErr) {
        [self trackErrorWithStatus:status funcName:(char *)__FUNCTION__ lineNuber:__LINE__];
        return;
    }
    
    
    //打开录音的开关
    UInt32 inputEnableFlag = 1;
    status = AudioUnitSetProperty(_recorderInfo.audioUnit,
                                  kAudioOutputUnitProperty_EnableIO,
                                  kAudioUnitScope_Input,
                                  kInputBus,
                                  &inputEnableFlag,
                                  sizeof(inputEnableFlag));
    
    NSAssert(status == noErr, @"EnableIO error, status %d", (int)status);
    if (status != noErr) {
        [self trackErrorWithStatus:status funcName:(char *)__FUNCTION__ lineNuber:__LINE__];
        return;
    }
    
    //禁用播放的开关,不然就一支打印EXCEPTION (-1): ""
    UInt32 playEnableFlag = 0;
    status = AudioUnitSetProperty(_recorderInfo.audioUnit,
                                  kAudioOutputUnitProperty_EnableIO,
                                  kAudioUnitScope_Output,
                                  kOutputBus,
                                  &playEnableFlag,
                                  sizeof(playEnableFlag));
    NSAssert(status == noErr, @"disable output error, status %d", (int)status);
    if (status != noErr) {
        [self trackErrorWithStatus:status funcName:(char *)__FUNCTION__ lineNuber:__LINE__];
        return;
    }
    
#if TARGET_OS_IOS
    //iOS 暂定使用 16KHZ, s16, 单声道来采集
    _recorderInfo.outputScopeFormat = [TSAudioUtil intFormatWithNumberOfChannels:1 sampleRate:16000];
    //设置录音数据的格式
    AudioStreamBasicDescription format = _recorderInfo.outputScopeFormat;
    status = AudioUnitSetProperty(_recorderInfo.audioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Output,
                                  kInputBus,
                                  &format,
                                  sizeof(AudioStreamBasicDescription));
    NSAssert(status == noErr, @"set stream format error, status %d", (int)status);
    if (status != noErr) {
        [self trackErrorWithStatus:status funcName:(char *)__FUNCTION__ lineNuber:__LINE__];
        return;
    }
#endif
    
    //设置录音数据回调
    AURenderCallbackStruct input;
    input.inputProc = inputRenderCallback;
    input.inputProcRefCon = (__bridge void *)(self);
    status = AudioUnitSetProperty(_recorderInfo.audioUnit,
                                  kAudioOutputUnitProperty_SetInputCallback,
                                  kAudioUnitScope_Global,
                                  kInputBus,
                                  &input,
                                  sizeof(input));
    
    NSAssert(status == noErr, @"set input callback error, status %d", (int)status);
    if (status != noErr) {
        [self trackErrorWithStatus:status funcName:(char *)__FUNCTION__ lineNuber:__LINE__];
        return;
    }
#if TARGET_OS_OSX
    if (self.deviceID != kAudioDeviceUnknown) {
        //配置当前设备
        [self ts_changeDeviceTo:self.deviceID];
    } else {
        [self trackErrorWithStatus:-1 funcName:(char *)__FUNCTION__ lineNuber:__LINE__];
    }
#endif
    status = AUGraphInitialize(_graph);
    NSAssert(status == noErr, @"AUGraphInitialize error, status %d", (int)status);
    if (status != noErr) {
        [self trackErrorWithStatus:status funcName:(char *)__FUNCTION__ lineNuber:__LINE__];
        return;
    }
#if TARGET_OS_IOS
    
#endif
    
    self.setupSuccess = YES;
}

#pragma mark -
- (void)ts_startRecording
{
    if ([self isRunning]) {
        return;
    }
    OSStatus status = AUGraphStart(_graph);
    NSAssert(status == noErr, @"AUGraphStart error, status %d", (int)status);
        
    if (status != noErr) {
        //start failed
        if ([self.delegate respondsToSelector:@selector(audioRecorder:didStartWithError:)]) {
            [self.delegate audioRecorder:self didStartWithError:TSAudioRecorderStartErrorFailed];
        }

        return;
    } else {
        self.started = YES;
        //start success
        if ([self.delegate respondsToSelector:@selector(audioRecorder:didStartWithError:)]) {
            [self.delegate audioRecorder:self didStartWithError:TSAudioRecorderStartErrorOK];
        }
    }
}


- (void)trackErrorWithStatus:(OSStatus)status funcName:(char *)funcName lineNuber:(int)lineNumber
{

}


@end


#pragma mark - 录音数据的回调
static OSStatus inputRenderCallback(void *inRefCon,
                                    AudioUnitRenderActionFlags *ioActionFlags,
                                    const AudioTimeStamp *inTimeStamp,
                                    UInt32 inBusNumber,
                                    UInt32 inNumberFrames,
                                    AudioBufferList *ioData)
{
    
    TSAudioRecorder *recorder = (__bridge TSAudioRecorder *)inRefCon;
    
    if (!recorder) {
        return -1;
    }
    
#if TARGET_OS_IOS
    
    OSStatus status;
    AudioBuffer buffer;
    buffer.mData = NULL;
    buffer.mDataByteSize = 0;
    buffer.mNumberChannels = 1;
    
    AudioBufferList bufferList;
    bufferList.mNumberBuffers = 1;
    bufferList.mBuffers[0] = buffer;
    
    
    // render input and check for error
    status = AudioUnitRender(recorder->_recorderInfo.audioUnit,
                             ioActionFlags,
                             inTimeStamp,
                             inBusNumber,
                             inNumberFrames,
                             &bufferList);
    
    
    if (status != noErr) {
        [recorder trackErrorWithStatus:status funcName:(char *)__FUNCTION__ lineNuber:__LINE__];
        return status;
    }
    
    //数据
    void *data = bufferList.mBuffers[0].mData;
    //长度
    UInt32 size = bufferList.mBuffers[0].mDataByteSize;
    //采样率
    double sampleRate = recorder->_recorderInfo.outputScopeFormat.mSampleRate;
    //时间戳
    double stime = covnertToNanos(inTimeStamp->mHostTime) / 1e6;
    
    if ([recorder.delegate respondsToSelector:@selector(audioRecorder:didRecordAudioData:size:sampleRate:timestamp:)]) {
        [recorder.delegate audioRecorder:recorder didRecordAudioData:data size:size sampleRate:sampleRate timestamp:stime];
    }
    
#elif TARGET_OS_OSX
    
    for (int i = 0; i < recorder->_recorderInfo.renderBufferList->mNumberBuffers; i++) {
        recorder->_recorderInfo.renderBufferList->mBuffers[i].mDataByteSize = inNumberFrames * recorder->_recorderInfo.outputScopeFormat.mBytesPerFrame;
    }
    
    OSStatus status = AudioUnitRender(recorder->_recorderInfo.audioUnit, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, recorder->_recorderInfo.renderBufferList);
    
    if (status != noErr) {
        [recorder trackErrorWithStatus:status funcName:(char *)__FUNCTION__ lineNuber:__LINE__];
        return status;
    }
    //数据
    void *data = recorder->_recorderInfo.renderBufferList->mBuffers[0].mData;
    //长度
    UInt32 size = recorder->_recorderInfo.renderBufferList->mBuffers[0].mDataByteSize;
    //采样率
    double sampleRate = recorder->_recorderInfo.outputScopeFormat.mSampleRate;
    //时间戳
    double stime = covnertToNanos(inTimeStamp->mHostTime) / 1e6;
    
    if ([recorder.delegate respondsToSelector:@selector(audioRecorder:didRecordAudioData:size:sampleRate:timestamp:)]) {
        [recorder.delegate audioRecorder:recorder didRecordAudioData:data size:size sampleRate:sampleRate timestamp:stime];
    }
    
#endif
    return noErr;
}


