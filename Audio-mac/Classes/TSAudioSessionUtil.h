//
//  RZAudioSessionUtil.h
//  RZPaas_iOS
//
//  Created by yxibng on 2020/9/29.
//

#include <TargetConditionals.h>

#if TARGET_OS_IOS


#import <Foundation/Foundation.h>


NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, TSAudioSessionMode) {
    TSAudioSessionMode_Record,
    TSAudioSessionMode_Playback,
    TSAudioSessionMode_PlaybackAndRecord,
};


typedef struct  {
    TSAudioSessionMode mode; //默认 play&record
    BOOL defaultToSpecker;//默认 true
    double sampleRate; //默认为16000
    double ioBufferDuration; //单位秒
} TSAudioSessionConfig;

//默认配置
extern const TSAudioSessionConfig TSAuidoSessionDefaultConifg;

@interface TSAudioSessionUtil : NSObject

+ (instancetype)sharedUtil;


@property (nonatomic, assign, readonly) TSAudioSessionConfig config;

- (void)setConfig:(TSAudioSessionConfig)config;
//激活 session, 激活以后，可以查询具体的 config 配置
- (void)activeSession;
//停止 session
- (void)deactiveSession;

/// 启用/关闭扬声器播放
/// @param enableSpeaker YES: 切换到外放. NO: 切换到听筒。如果设备连接了耳机，则语音路由走耳机。
- (BOOL)setEnableSpeakerphone:(BOOL)enableSpeaker;

///YES: 扬声器已开启，语音会输出到扬声器
///NO: 扬声器未开启，语音会输出到非扬声器（听筒、耳机等）
- (BOOL)isSpeakerphoneEnabled;

@end

NS_ASSUME_NONNULL_END

#endif