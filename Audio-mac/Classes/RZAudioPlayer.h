//
//  RZAudioPlayer.h
//  Pods
//
//  Created by yxibng on 2020/10/10.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

NS_ASSUME_NONNULL_BEGIN
@class RZAudioPlayer;

typedef NS_ENUM(NSUInteger, RZAudioPlayerStartError) {
    RZAudioPlayerStartErrorOK,
    RZAudioPlayerStartErrorInitializeFailed,
    RZAudioPlayerStartErrorFailed
};


@protocol RZAudioPlayerDelegate <NSObject>

@optional
- (void)audioPlayer:(RZAudioPlayer *)audioPlayer didStartwithError:(RZAudioPlayerStartError)error;

- (void)auidoPlayer:(RZAudioPlayer *)audioPlayer didOccurError:(NSDictionary *)userInfo;

- (void)audioPlayerDidStop:(RZAudioPlayer *)audioPlayer;

- (void)audioPlayer:(RZAudioPlayer *)audioPlayer fillAudioBufferList:(AudioBufferList *)list inNumberOfFrames:(UInt32)inNumberOfFrames;


@end


@interface RZAudioPlayer : NSObject

@property (nonatomic, weak) id<RZAudioPlayerDelegate>delegate;

@property (nonatomic, assign, readonly) AudioStreamBasicDescription streamDesc;

- (void)start;
- (void)stop;

#if TARGET_OS_OSX
//当前采集设备ID
@property (nonatomic, assign, readonly) AudioDeviceID deviceID;

//更改当前的设备 ID
- (void)setDeviceID:(AudioDeviceID)deviceID;

#endif

@property (nonatomic, assign, getter=isRunning) BOOL running;

/**
 暂定以16KHZ，int16， 单声道来播放
 */
- (void)receiveAudioData:(void *)audioData length:(int)length;

@end

NS_ASSUME_NONNULL_END
