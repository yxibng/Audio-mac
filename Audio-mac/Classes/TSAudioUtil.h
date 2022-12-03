//
//  TSAudioUtil.h
//  TSRtc_macOS
//
//  Created by yxibng on 2020/9/29.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
NS_ASSUME_NONNULL_BEGIN

#ifdef __cplusplus
extern "C" {
#endif

#if TARGET_OS_OSX

OSStatus GetIOBufferFrameSizeRange(AudioObjectID inDeviceID,
                                   UInt32 *outMinimum,
                                   UInt32 *outMaximum);


OSStatus SetCurrentIOBufferFrameSize(AudioObjectID inDeviceID,
                                     UInt32 inIOBufferFrameSize);


OSStatus GetCurrentIOBufferFrameSize(AudioObjectID inDeviceID,
                                     UInt32 *outIOBufferFrameSize);

OSStatus AudioUnitSetCurrentIOBufferFrameSize(AudioUnit inAUHAL,
                                              UInt32 inIOBufferFrameSize);

OSStatus AudioUnitGetCurrentIOBufferFrameSize(AudioUnit inAUHAL,
                                              UInt32 *outIOBufferFrameSize);

//设置采集音量0-1.0，设置为 0 则为静音模式
OSStatus SetInputVolumeForDevice(AudioObjectID inDeviceID, float volume);
//获取采集音量0-1.0
OSStatus GetInputVolumeForDevice(AudioObjectID inDeviceID, float *volume);

OSStatus SetInputMute(AudioObjectID inDeviceID,bool mute);
OSStatus GetInputMute(AudioObjectID inDeviceID,bool *mute);

OSStatus SetOutputMute(AudioObjectID inDeviceID,bool mute);
OSStatus GetOutputMute(AudioObjectID inDeviceID,bool *mute);


//设置播放音量0-1.0，  设置为0 播放静音
OSStatus SetOutputVolumeForDevice(AudioObjectID inDeviceID, float volume);
//获取播放音量0-1.0
OSStatus GetOutputVolumeForDevice(AudioObjectID inDeviceID, float *volume);

#endif

OSStatus AudioUnitSetMaxIOBufferFrameSize(AudioUnit inAUHAL,
                                          UInt32 inIOBufferFrameSize);
OSStatus AudioUnitGetMaxIOBufferFrameSize(AudioUnit inAUHAL,
                                          UInt32 *outIOBufferFrameSize);

#ifdef __cplusplus
}
#endif


@interface TSAudioUtil : NSObject
//uint 16, 平面存储
+ (AudioStreamBasicDescription)intFormatWithNumberOfChannels:(UInt32)channels
                                                  sampleRate:(float)sampleRate;

//float 32, 平面存储
+ (AudioStreamBasicDescription)floatFormatWithNumberOfChannels:(UInt32)channels
                                                    sampleRate:(float)sampleRate;

//uint 16, 平面 or 交错
+ (AudioStreamBasicDescription)intFormatWithNumberOfChannels:(UInt32)channels
                                                  sampleRate:(float)sampleRate
                                               isInterleaved:(BOOL)isInterleaved;

//float 32, 平面 or 交错
+ (AudioStreamBasicDescription)floatFormatWithNumberOfChannels:(UInt32)channels
                                                    sampleRate:(float)sampleRate
                                                 isInterleaved:(BOOL)isInterleaved;

//根据 AudioStreamBasicDescription，申请AudioBufferList
+ (AudioBufferList *)audioBufferListWithNumberOfFrames:(UInt32)frames
                                          streamFormat:(AudioStreamBasicDescription)asbd;


//判断是否是交错类型
+ (BOOL)isInterleaved:(AudioStreamBasicDescription)asbd;

//释放 AudioBufferList
+ (void)freeAudioBufferList:(AudioBufferList *)bufferList;

@end

NS_ASSUME_NONNULL_END
