//
//  RZAudioRecorder.m
//  RZPaas_macOS
//
//  Created by yxibng on 2020/9/29.
//

#import "RZAudioRecorder.h"
#import "DbyAudioDevice.h"
#import "RZAudioUtil.h"
#import <AVFoundation/AVFoundation.h>
#import "AudioFileWriter.h"
#import "RZFileUtil.h"

#define kOutputBus 0
#define kInputBus 1


/*
 macOS 每次 IO 的帧的数量 128
 macOS 支持的采样率为 44100.0， 每次 IO 128帧，
 每次 IO 的时长为 128/44100 = 0.002毫秒， 这个已经是很高的实时性了
 */
#define kIOBufferFrameSize 128


static uint64_t getTickCount(void)
{
    static mach_timebase_info_data_t sTimebaseInfo;
    uint64_t machTime = mach_absolute_time();
    
    // Convert to nanoseconds - if this is the first time we've run, get the timebase.
    if (sTimebaseInfo.denom == 0 )
    {
        (void) mach_timebase_info(&sTimebaseInfo);
    }
    // 得到毫秒级别时间差
    uint64_t millis = ((machTime / 1e6) * sTimebaseInfo.numer) / sTimebaseInfo.denom;
    return millis;
}



typedef struct {
    AudioUnit audioUnit;
    AUNode audioNode;

#if TARGET_OS_OSX
    AudioBufferList *renderBufferList;
    AudioStreamBasicDescription inputScopeFormat;
#endif
    AudioStreamBasicDescription outputScopeFormat;

} RZAudioRecordInfo;


static OSStatus inputRenderCallback(void *inRefCon,
                             AudioUnitRenderActionFlags *ioActionFlags,
                             const AudioTimeStamp *inTimeStamp,
                             UInt32 inBusNumber,
                             UInt32 inNumberFrames,
                                    AudioBufferList *ioData);



@interface RZAudioRecorder ()
{
    @public
    RZAudioRecordInfo _recorderInfo;
    AUGraph _graph;
    
    
}
@property (nonatomic, assign) BOOL setupSuccess;
@property (nonatomic, assign) RZAudioConfig realConfig;
@property (nonatomic, assign) RZAudioConfig expectedConfig;
@property (nonatomic, strong) AudioFileWriter *fileWriter;

@end

@implementation RZAudioRecorder


- (void)dealloc
{
    AUGraphClose(_graph);
    AUGraphUninitialize(_graph);
    DisposeAUGraph(_graph);
    _graph = NULL;
#if TARGET_OS_OSX
    [RZAudioUtil freeAudioBufferList:_recorderInfo.renderBufferList];
#endif
}


- (instancetype)initWithConfig:(RZAudioConfig)config delegate:(id<RZAudioRecorderDelegate>)delegate {
    if (self = [super init]) {
        _expectedConfig = config;
        _delegate = delegate;
        _setupSuccess = NO;
#if TARGET_OS_IOS
        _realConfig.channelCount = 1;
        _realConfig.sampleRate = 16000;
        _realConfig.timeInterval = 20;
#endif
        [self rz_setupGraph];
    }
    return self;
}

- (void)setAudioConfig:(RZAudioConfig)audioConfig {
    _expectedConfig = audioConfig;
    //TODO: 这里应该根据配置去修改采集器配置
}

#if TARGET_OS_OSX
- (void)setDeviceID:(AudioDeviceID)deviceID {
    _deviceID = deviceID;
    [self rz_changeDeviceTo:deviceID];
}


- (void)rz_changeDeviceTo:(AudioDeviceID)deviceID {
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
    NSLog(@"min = %d, max = %d",min, max);
    
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
    _recorderInfo.outputScopeFormat = [RZAudioUtil intFormatWithNumberOfChannels:1 sampleRate:_recorderInfo.inputScopeFormat.mSampleRate];

    status = AudioUnitSetProperty(_recorderInfo.audioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Output,
                                  kInputBus,
                                  &_recorderInfo.outputScopeFormat,
                                  sizeof(_recorderInfo.outputScopeFormat));
    
    
    
    
    

    NSAssert(status == noErr, @"Couldn't set streamFormat, status %d", status);
    
    [self rz_setMaximumBufferSize:max];
    status = SetCurrentIOBufferFrameSize(deviceId, _recorderInfo.inputScopeFormat.mSampleRate * 0.02);
    NSAssert(status == noErr, @"Couldn't set IOBufferFrameSize to %d, status %d", kIOBufferFrameSize, status);
    if (status != noErr) {
        [self trackErrorWithStatus:status funcName:(char *)__FUNCTION__ lineNuber:__LINE__];
        return;
    }

    /*
     每次 IO 128 帧，采样率为 44100，目标采样率 16000
     重采样后，大概为 128 * 16000 / 44100 =  47 帧。
     所以设置为 128帧的缓冲，足够用了
     */
    
    [RZAudioUtil freeAudioBufferList:_recorderInfo.renderBufferList];
    _recorderInfo.renderBufferList = [RZAudioUtil audioBufferListWithNumberOfFrames:max streamFormat:_recorderInfo.outputScopeFormat];
 
    /*
     这里获得了真正的采样率,采样的时间间隔
     */
    _realConfig.channelCount = 1;
    _realConfig.sampleRate = _recorderInfo.outputScopeFormat.mSampleRate;
    _realConfig.timeInterval = kIOBufferFrameSize / _recorderInfo.outputScopeFormat.mSampleRate * 1000;
    
    //创建文件写入管理
    if (_fileWriter) {
        [_fileWriter dispose];
        _fileWriter = nil;
    }
    
    NSString *filePath = [[RZFileUtil documentPath] stringByAppendingPathComponent:@"recording_audio.caf"];
    NSLog(@"recording file path = %@",filePath);
    
    _fileWriter = [[AudioFileWriter alloc] initWithInStreamDesc:_recorderInfo.outputScopeFormat filePath:filePath];
    [_fileWriter setup];
}
#endif

- (UInt32)rz_maximumBufferSize
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


- (OSStatus)rz_setMaximumBufferSize:(UInt32)size {
    
    OSStatus status = AudioUnitSetMaxIOBufferFrameSize(_recorderInfo.audioUnit, size);
    return status;
}


- (void)rz_setupGraph
{
    self.setupSuccess = NO;

    //Create graph
    OSStatus status = NewAUGraph(&_graph);
    NSAssert(status == noErr, @"NewAUGraph error, status %d", status);
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
    NSAssert(status == noErr, @"AUGraphAddNode error, status %d", status);
    if (status != noErr) {
        [self trackErrorWithStatus:status funcName:(char *)__FUNCTION__ lineNuber:__LINE__];
        return;
    }
    //open graph
    status = AUGraphOpen(_graph);
    NSAssert(status == noErr, @"AUGraphOpen error, status %d", status);
    if (status != noErr) {
        [self trackErrorWithStatus:status funcName:(char *)__FUNCTION__ lineNuber:__LINE__];
        return;
    }
    //get unit
    status = AUGraphNodeInfo(_graph,
                             _recorderInfo.audioNode,
                             &componentDescripiton,
                             &_recorderInfo.audioUnit);
    NSAssert(status == noErr, @"AUGraphNodeInfo error, status %d", status);
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

    NSAssert(status == noErr, @"EnableIO error, status %d", status);
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
    NSAssert(status == noErr, @"disable output error, status %d", status);
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
    status = AudioUnitSetProperty(_recorderInfo.audioUnit,
                                  kAUVoiceIOProperty_BypassVoiceProcessing,
                                  kAudioUnitScope_Global,
                                  0,
                                  &echoCancellation,
                                  size);
    NSAssert(status == noErr, @"enable echo cancellation error, status %d", status);
    if (status != noErr) {
        [self trackErrorWithStatus:status funcName:(char *)__FUNCTION__ lineNuber:__LINE__];
        return;
    }
#endif

#if TARGET_OS_IOS
    //iOS 暂定使用 16KHZ, s16, 单声道来采集
    _recorderInfo.outputScopeFormat = [RZAudioUtil intFormatWithNumberOfChannels:1 sampleRate:16000];
    //设置录音数据的格式
    AudioStreamBasicDescription format = _recorderInfo.outputScopeFormat;
    status = AudioUnitSetProperty(_recorderInfo.audioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Output,
                                  kInputBus,
                                  &format,
                                  sizeof(AudioStreamBasicDescription));
    NSAssert(status == noErr, @"set stream format error, status %d", status);
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

    NSAssert(status == noErr, @"set input callback error, status %d", status);
    if (status != noErr) {
        [self trackErrorWithStatus:status funcName:(char *)__FUNCTION__ lineNuber:__LINE__];
        return;
    }

#if TARGET_OS_OSX
    DbyAudioDevice *device = [DbyAudioDevice currentInputDevice];
    NSLog(@"audio capture device = %@, id = %d", device.name, device.deviceID);
    [self setDeviceID:device.deviceID];
#endif
    
    status = AUGraphInitialize(_graph);
    NSAssert(status == noErr, @"AUGraphInitialize error, status %d", status);
    if (status != noErr) {
        [self trackErrorWithStatus:status funcName:(char *)__FUNCTION__ lineNuber:__LINE__];
        return;
    }
#if TARGET_OS_IOS
    
#endif
    
    self.setupSuccess = YES;
}


- (void)start
{
#if TARGET_OS_OSX
    if (_deviceID == kAudioObjectUnknown) {
        //回调没有指定设备
        return;
    }
#endif
    if (!self.setupSuccess) {
        //初始化失败
        if ([self.delegate respondsToSelector:@selector(audioRecorder:didStartWithError:)]) {
            [self.delegate audioRecorder:self didStartWithError:RZAudioRecorderInitializeFailed];
        }
        return;
    }

#if TARGET_OS_IOS
    [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
        if (granted) {
            [self rz_startRecording];
        } else {
            //no permission, start failed
            if ([self.delegate respondsToSelector:@selector(audioRecorder:didStartWithError:)]) {
                [self.delegate audioRecorder:self didStartWithError:RZAudioRecorderStartErrorNoPermission];
            }
        }
    }];

#elif TARGET_OS_OSX
    if (@available(macOS 10.14, *)) {
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio completionHandler:^(BOOL granted) {
            if (granted) {
                [self rz_startRecording];
            } else {
                //no permission, start failed
                if ([self.delegate respondsToSelector:@selector(audioRecorder:didStartWithError:)]) {
                    [self.delegate audioRecorder:self didStartWithError:RZAudioRecorderStartErrorNoPermission];
                }
            }
        }];
    } else {
        [self rz_startRecording];
    }
#endif
}


- (BOOL)isRuning
{
    if (_graph == NULL) {
        return NO;
    }
    Boolean isRunning = false;
    OSStatus status = AUGraphIsRunning(_graph, &isRunning);
    NSAssert(status == noErr, @"Error trying querying whether graph is running, status %d", status);
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
    NSAssert(status == noErr, @"Error trying querying whether graph is running, status %d", status);
    if (status != noErr) {
        [self trackErrorWithStatus:status funcName:(char *)__FUNCTION__ lineNuber:__LINE__];
    }

    if (!isRunning) {
        return;
    }
    status = AUGraphStop(_graph);
    NSAssert(status == noErr, @"Failed to stop Audio Graph, status %d", status);
    if (status != noErr) {
        [self trackErrorWithStatus:status funcName:(char *)__FUNCTION__ lineNuber:__LINE__];
    }
    if ([self.delegate respondsToSelector:@selector(audioRecorderDidStop:)]) {
        [self.delegate audioRecorderDidStop:self];
    }
}


#pragma mark -

- (void)rz_startRecording
{
    if (self.isRunning) {
        return;
    }
    OSStatus status = AUGraphStart(_graph);
    NSAssert(status == noErr, @"AUGraphStart error, status %d", status);
    if (status != noErr) {
        //start failed
        if ([self.delegate respondsToSelector:@selector(audioRecorder:didStartWithError:)]) {
            [self.delegate audioRecorder:self didStartWithError:RZAudioRecorderStartErrorFailed];
        }
        [self trackErrorWithStatus:status funcName:(char *)__FUNCTION__ lineNuber:__LINE__];
        return;
    } else {
        //start success
        if ([self.delegate respondsToSelector:@selector(audioRecorder:didStartWithError:)]) {
            [self.delegate audioRecorder:self didStartWithError:RZAudioRecorderStartErrorOK];
        }
    }
}


- (void)trackErrorWithStatus:(OSStatus)status funcName:(char *)funcName lineNuber:(int)lineNumber
{
//TODO: - finish this
    NSLog(@"%s, status = %d, func = %s, line = %d",__FUNCTION__,status, funcName, lineNumber);
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
    
    RZAudioRecorder *recorder = (__bridge RZAudioRecorder *)inRefCon;
    // a variable where we check the status

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
    
    //TODO: 时间戳
    //时间戳
    double stime = [[NSDate date] timeIntervalSince1970] * 1000;
    
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

    //TODO: 时间戳
    //时间戳
    double stime = getTickCount();

    if ([recorder.delegate respondsToSelector:@selector(audioRecorder:didRecordAudioData:size:sampleRate:timestamp:)]) {
        [recorder.delegate audioRecorder:recorder didRecordAudioData:data size:size sampleRate:sampleRate timestamp:stime];
    }
    //写入文件
    [recorder.fileWriter writeWithAudioBufferList:recorder->_recorderInfo.renderBufferList inNumberFrames:inNumberFrames];
#endif
    return noErr;
}


