//
//  TSAudioSessionUtil.m
//  TSRtc_iOS
//
//  Created by yxibng on 2020/9/29.
//


#import "TSAudioSessionUtil.h"

#if TARGET_OS_IOS

#import <AVFoundation/AVFoundation.h>
#import <OSLog/OSLog.h>

const TSAudioSessionConfig TSAuidoSessionDefaultConifg = {
    .mode = TSAudioSessionMode_PlaybackAndRecord,
    .defaultToSpecker = YES,
    .sampleRate = 16000,
    .ioBufferDuration = 0.02
};

#pragma mark -
@implementation TSAudioSessionUtil

+  (instancetype)sharedUtil {
    static TSAudioSessionUtil *util = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        util = [[TSAudioSessionUtil alloc] init];
    });
    return util;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        
        TSAudioSessionConfig config;
        config.defaultToSpecker = YES;
        config.ioBufferDuration = 0.02;
        config.sampleRate = 16000;
        config.mode = TSAudioSessionMode_PlaybackAndRecord;
        
        _config = config;
    }
    return self;
}


- (void)setConfig:(TSAudioSessionConfig)config {
    _config = config;
}

- (void)activeSession {
    
    [self ts_setPlaybackAndRecord];
    
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    NSError *error = nil;
    [audioSession setPreferredSampleRate:self.config.sampleRate error:&error];
    if (error) {
        os_log_error(OS_LOG_DEFAULT, "AVAudioSession setPreferredSampleRate %f error: %@", self.config.sampleRate, error);
    }
    
    [audioSession setPreferredIOBufferDuration: self.config.ioBufferDuration error:&error];
    if (error) {
        os_log_error(OS_LOG_DEFAULT, "AVAudioSession setPreferredIOBufferDuration %f error: %@", self.config.ioBufferDuration, error);
    }
    
    [audioSession setActive:YES withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:&error];
    if (error) {
        os_log_error(OS_LOG_DEFAULT, "AVAudioSession setActive YES error: %@",error);
        if (error.code == AVAudioSessionErrorCodeInsufficientPriority) {
            /*
             例如正在使用facetime 通话，此时打开app，报错：设备被别的应用使用，不允许修改audio category
             */
        }
    }
    assert(error == nil);
    //真正的采样率和 iO 间隔
    _config.ioBufferDuration = audioSession.IOBufferDuration;
    _config.sampleRate = audioSession.sampleRate;
}

- (void)deactiveSession {
    /**
     同步方法
     如果I/O还在运行，会抛出错误。内部会停掉所有的i/o, 将 session 的状态置为 deactive
     */
    NSError *error;
    [[AVAudioSession sharedInstance] setActive:NO error:&error];
    if (error) {
        os_log_error(OS_LOG_DEFAULT, "AVAudioSession setActive NO error: %@",error);
    }
}



- (BOOL)ts_setPlayback {
    
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    BOOL ok = YES;
    NSError *setCategoryError = nil;
    if (audioSession.category == AVAudioSessionCategoryPlayback) {
        return ok;
    }
    ok = [audioSession setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionMixWithOthers | AVAudioSessionCategoryOptionDuckOthers error:&setCategoryError];
    if (setCategoryError) {
        os_log_error(OS_LOG_DEFAULT, "AVAudioSession setCategory AVAudioSessionCategoryPlayback error: %@", setCategoryError);
        return NO;
    }
    return ok;
}

- (BOOL)ts_setRecord {
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    if (audioSession.category == AVAudioSessionCategoryRecord) {
        return YES;
    }
    BOOL ok = NO;
    NSError *error;
    ok = [audioSession setCategory:AVAudioSessionCategoryRecord error:&error];
    if (error) {
        os_log_error(OS_LOG_DEFAULT, "AVAudioSession setCategory AVAudioSessionCategoryRecord error: %@", error);
        return NO;
    }
    return ok;
}


- (AVAudioSessionCategoryOptions)ts_audioSessionCategoryOptions {
    
    AVAudioSessionCategoryOptions options = AVAudioSessionCategoryOptionDuckOthers | AVAudioSessionCategoryOptionAllowBluetooth;
    if (self.config.defaultToSpecker) {
        options |= AVAudioSessionCategoryOptionDefaultToSpeaker;
    }
    if (@available(iOS 10.0, *)) {
        options |= AVAudioSessionCategoryOptionAllowBluetoothA2DP |
        AVAudioSessionCategoryOptionAllowAirPlay;
    }
    return options;
}


- (BOOL)ts_setPlaybackAndRecord {
    
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    AVAudioSessionCategoryOptions options = [self ts_audioSessionCategoryOptions];
    BOOL optionsMatch = (audioSession.categoryOptions & options) >= options;
    BOOL categoryMatch = [audioSession.category isEqualToString:AVAudioSessionCategoryPlayAndRecord];
    
    if (optionsMatch && categoryMatch) {
        return YES;
    }
    
    NSError *setCategoryError = nil;
    BOOL ok;
    if (@available(iOS 11.0, *)) {
        ok = [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord
                                  mode:AVAudioSessionModeVoiceChat
                               options:options
                                 error:&setCategoryError];
    } else {
        ok = [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord
                           withOptions:options
                                 error:&setCategoryError];
    }
    
    return ok;
}

- (BOOL)setEnableSpeakerphone:(BOOL)enableSpeaker {    
    /*
     1.耳机，蓝牙，连接了。 直接了return
     2.如果没有连接外设，听筒和外放的切换
     */
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    for (AVAudioSessionPortDescription *item in audioSession.currentRoute.outputs) {
        if ([item.portType isEqualToString:AVAudioSessionPortHeadphones] ||
            [item.portType isEqualToString:AVAudioSessionPortBluetoothA2DP] ||
            [item.portType isEqualToString:AVAudioSessionPortBluetoothLE] ) {
            return NO;
        }
    }
    
    BOOL ok = NO;
    NSError *error;
    if (audioSession.category == AVAudioSessionCategoryPlayAndRecord) {
        if (enableSpeaker) {
            ok = [audioSession overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:&error];
        } else {
            ok = [audioSession overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:&error];
        }
    }
    return ok;
}


- (BOOL)isSpeakerphoneEnabled {
    AVAudioSessionPortDescription *output = [AVAudioSession sharedInstance].currentRoute.outputs.firstObject;
    BOOL enable =  [output.portType isEqualToString:AVAudioSessionPortBuiltInSpeaker];
    return enable;
}


@end

#endif
