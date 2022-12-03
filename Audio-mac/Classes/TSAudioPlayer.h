//
//  TSAudioPlayer.h
//  Pods
//
//  Created by yxibng on 2020/10/10.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

NS_ASSUME_NONNULL_BEGIN
@class TSAudioPlayer;

typedef NS_ENUM(NSUInteger, TSAudioPlayerStartError) {
    TSAudioPlayerStartErrorOK,
    TSAudioPlayerStartErrorInitializeFailed,
    TSAudioPlayerStartErrorFailed
};


@protocol TSAudioPlayerDelegate <NSObject>

@optional
- (void)audioPlayer:(TSAudioPlayer *)audioPlayer didStartwithError:(TSAudioPlayerStartError)error;

- (void)auidoPlayer:(TSAudioPlayer *)audioPlayer didOccurError:(NSDictionary *)userInfo;

- (void)audioPlayerDidStop:(TSAudioPlayer *)audioPlayer;

- (void)audioPlayer:(TSAudioPlayer *)audioPlayer fillAudioBufferList:(AudioBufferList *)list inNumberOfFrames:(UInt32)inNumberOfFrames;


@end


@interface TSAudioPlayer : NSObject

@property (nonatomic, weak) id<TSAudioPlayerDelegate>delegate;

@property (nonatomic, assign, readonly) AudioStreamBasicDescription streamDesc;


//初始化
- (BOOL)initPlayer;
//销毁
- (BOOL)disposePlayer;


- (void)start;
- (void)stop;

#if TARGET_OS_OSX
//当前采集设备ID
@property (nonatomic, assign, readonly) AudioDeviceID deviceID;

//更改当前的设备 ID
- (void)setDeviceID:(AudioDeviceID)deviceID;

#endif

#if TARGET_OS_IOS
- (void)handleMeidaServiesWereReset;
#endif

@property (nonatomic, assign, getter=isRunning) BOOL running;

/**
 暂定以16KHZ，int16， 单声道来播放
 */
- (void)receiveAudioData:(void *)audioData length:(int)length;

@end

NS_ASSUME_NONNULL_END
