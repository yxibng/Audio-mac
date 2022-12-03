//
//  TSAudioRecorder.h
//  TSRtc_macOS
//
//  Created by yxibng on 2020/9/29.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

NS_ASSUME_NONNULL_BEGIN


typedef struct {
    /**
     支持的声道数，默认采集的声道数为 1
     */
    int channelCount;
    /**
     采集，采样率， 默认为 16KHZ， 支持48000，44100, 32000, 24000, 16000
     */
    UInt32 sampleRate;
    /**
     IO 回调的时间间隔， 默认为 20ms
     */
    int timeInterval;
} TSAudioConfig;


typedef NS_ENUM(NSUInteger, TSAudioRecorderStartError) {
    TSAudioRecorderInitializeFailed,       ///初始化失败
    TSAudioRecorderStartErrorNoPermission, ///没有权限
    TSAudioRecorderStartErrorOK,           ///开启成功
    TSAudioRecorderStartErrorFailed        ///开启失败
};


@class TSAudioRecorder;

@protocol TSAudioRecorderDelegate <NSObject>
/*
 did start
 */
- (void)audioRecorder:(TSAudioRecorder *)audioRecorder didStartWithError:(TSAudioRecorderStartError)error;
/*
 did stop
 */
- (void)audioRecorderDidStop:(TSAudioRecorder *)audioRecorder;
/*
 error occured
 */
- (void)audioRecorder:(TSAudioRecorder *)audioRecorder didOccurError:(NSDictionary *)userInfo;
/*
 did record raw data
*/
- (void)audioRecorder:(TSAudioRecorder *)audioRecorder
   didRecordAudioData:(void *)audioData
                 size:(int)size
           sampleRate:(double)sampleRate
            timestamp:(NSTimeInterval)timestamp;

@end



@interface TSAudioRecorder : NSObject

@property (nonatomic, weak) id<TSAudioRecorderDelegate>delegate;
/**
  通过查询AudioGraph查询是否在运行中
 */
@property (nonatomic, assign, readonly, getter=isRunning) BOOL running;

/*
 是否调运了AudioGraphStrat
 ios 音频被打断之后。AudioGraph 会被系统stop, running 变成 NO。
 音频打断结束之后， 不会自己恢复运行。
 通过 改标志位，在打断结束之后，重新恢复运行。
 */
@property (nonatomic, assign) BOOL started;

#if TARGET_OS_OSX
//当前采集设备ID
@property (nonatomic, assign, readonly) AudioDeviceID deviceID;

//更改当前的设备 ID
- (void)setDeviceID:(AudioDeviceID)deviceID;

#endif


#if TARGET_OS_IOS
/**
 处理系统媒体服务被重置，
 例如设置-开发者-Reset Media Services,需要AudioUnit， AudioGraph实例需要重新构建
 */
- (BOOL)handleMeidaServiesWereReset;
#endif


////初始化
//- (BOOL)initRecorder;
////销毁
//- (BOOL)disposeRecorder;


//异步开始
- (void)start;
//异步结束
- (void)stop;




//获取当前的采集配置, 实际的配置
@property (nonatomic, assign, readonly) TSAudioConfig realConfig;

//设置当前的采集配置
- (void)setAudioConfig:(TSAudioConfig)audioConfig;

- (instancetype)initWithConfig:(TSAudioConfig)config delegate:(id<TSAudioRecorderDelegate>)delegate;

@end

NS_ASSUME_NONNULL_END
