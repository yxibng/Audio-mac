//
//  RZAudioRecorder.h
//  RZPaas_macOS
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
} RZAudioConfig;


typedef NS_ENUM(NSUInteger, RZAudioRecorderStartError) {
    RZAudioRecorderInitializeFailed,       ///初始化失败
    RZAudioRecorderStartErrorNoPermission, ///没有权限
    RZAudioRecorderStartErrorOK,           ///开启成功
    RZAudioRecorderStartErrorFailed        ///开启失败
};


@class RZAudioRecorder;

@protocol RZAudioRecorderDelegate <NSObject>
/*
 did start
 */
- (void)audioRecorder:(RZAudioRecorder *)audioRecorder didStartWithError:(RZAudioRecorderStartError)error;
/*
 did stop
 */
- (void)audioRecorderDidStop:(RZAudioRecorder *)audioRecorder;
/*
 error occured
 */
- (void)audioRecorder:(RZAudioRecorder *)audioRecorder didOccurError:(NSDictionary *)userInfo;
/*
 did record raw data
*/
- (void)audioRecorder:(RZAudioRecorder *)audioRecorder
   didRecordAudioData:(void *)audioData
                 size:(int)size
           sampleRate:(double)sampleRate
            timestamp:(NSTimeInterval)timestamp;

@end



@interface RZAudioRecorder : NSObject

@property (nonatomic, weak) id<RZAudioRecorderDelegate>delegate;
//是否正运行中
@property (nonatomic, assign, readonly, getter=isRunning) BOOL running;

#if TARGET_OS_OSX
//当前采集设备ID
@property (nonatomic, assign, readonly) AudioDeviceID deviceID;

//更改当前的设备 ID
- (void)setDeviceID:(AudioDeviceID)deviceID;

#endif

//异步开始
- (void)start;
//异步结束
- (void)stop;

//获取当前的采集配置, 实际的配置
@property (nonatomic, assign, readonly) RZAudioConfig realConfig;

//设置当前的采集配置
- (void)setAudioConfig:(RZAudioConfig)audioConfig;

- (instancetype)initWithConfig:(RZAudioConfig)config delegate:(id<RZAudioRecorderDelegate>)delegate;

@end

NS_ASSUME_NONNULL_END
