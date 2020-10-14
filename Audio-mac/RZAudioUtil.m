//
//  RZAudioUtil.m
//  RZPaas_macOS
//
//  Created by yxibng on 2020/9/29.
//

#import "RZAudioUtil.h"
#import <AVFoundation/AVFoundation.h>

#if TARGET_OS_OSX

OSStatus GetIOBufferFrameSizeRange(AudioObjectID inDeviceID,
                                   UInt32 *outMinimum,
                                   UInt32 *outMaximum)
{
    AudioObjectPropertyAddress theAddress = {kAudioDevicePropertyBufferFrameSizeRange,
                                             kAudioObjectPropertyScopeGlobal,
                                             kAudioObjectPropertyElementMaster};

    AudioValueRange theRange = {0, 0};
    UInt32 theDataSize = sizeof(AudioValueRange);
    OSStatus theError = AudioObjectGetPropertyData(inDeviceID,
                                                   &theAddress,
                                                   0,
                                                   NULL,
                                                   &theDataSize,
                                                   &theRange);
    if (theError == 0) {
        *outMinimum = theRange.mMinimum;
        *outMaximum = theRange.mMaximum;
    }
    return theError;
}

OSStatus SetCurrentIOBufferFrameSize(AudioObjectID inDeviceID,
                                     UInt32 inIOBufferFrameSize)
{
    AudioObjectPropertyAddress theAddress = {kAudioDevicePropertyBufferFrameSize,
                                             kAudioObjectPropertyScopeGlobal,
                                             kAudioObjectPropertyElementMaster};

    return AudioObjectSetPropertyData(inDeviceID,
                                      &theAddress,
                                      0,
                                      NULL,
                                      sizeof(UInt32), &inIOBufferFrameSize);
}

OSStatus GetCurrentIOBufferFrameSize(AudioObjectID inDeviceID,
                                     UInt32 *outIOBufferFrameSize)
{
    AudioObjectPropertyAddress theAddress = {kAudioDevicePropertyBufferFrameSize,
                                             kAudioObjectPropertyScopeGlobal,
                                             kAudioObjectPropertyElementMaster};

    UInt32 theDataSize = sizeof(UInt32);
    return AudioObjectGetPropertyData(inDeviceID,
                                      &theAddress,
                                      0,
                                      NULL,
                                      &theDataSize,
                                      outIOBufferFrameSize);
}

OSStatus AudioUnitSetCurrentIOBufferFrameSize(AudioUnit inAUHAL,
                                              UInt32 inIOBufferFrameSize)
{
    return AudioUnitSetProperty(inAUHAL,
                                kAudioDevicePropertyBufferFrameSize,
                                kAudioUnitScope_Global,
                                0,
                                &inIOBufferFrameSize, sizeof(UInt32));
}

OSStatus AudioUnitGetCurrentIOBufferFrameSize(AudioUnit inAUHAL,
                                              UInt32 *outIOBufferFrameSize)
{
    UInt32 theDataSize = sizeof(UInt32);
    return AudioUnitGetProperty(inAUHAL,
                                kAudioDevicePropertyBufferFrameSize,
                                kAudioUnitScope_Global,
                                0,
                                outIOBufferFrameSize, &theDataSize);
}

OSStatus SetInputVolumeForDevice(AudioObjectID inDeviceID, float volume) {
    
    AudioObjectPropertyAddress theAddress = {kAudioDevicePropertyVolumeScalar,
                                                kAudioObjectPropertyScopeInput,
                                             kAudioObjectPropertyElementMaster};
    
    return AudioObjectSetPropertyData(inDeviceID,
                                      &theAddress,
                                      0,
                                      NULL,
                                      sizeof(float),
                                      &volume);

}

OSStatus GetInputVolumeForDevice(AudioObjectID inDeviceID, float *volume) {
    
    AudioObjectPropertyAddress theAddress = {
        kAudioDevicePropertyVolumeScalar,
        kAudioObjectPropertyScopeInput,
        kAudioObjectPropertyElementMaster};

    UInt32 theDataSize = sizeof(float);
    return AudioObjectGetPropertyData(inDeviceID,
                                      &theAddress,
                                      0,
                                      NULL,
                                      &theDataSize,
                                      volume);
    
}

OSStatus SetInputMute(AudioObjectID inDeviceID,bool mute) {
    //TODO: mute 保存当前音量， unmute 的时候恢复
    return noErr;
}

OSStatus GetInputMute(AudioObjectID inDeviceID,bool *mute) {
    //TODO: 音量为0，mute， 否则 unmute
    return noErr;
}


OSStatus SetOutputVolumeForDevice(AudioObjectID inDeviceID, float volume) {
    AudioObjectPropertyAddress theAddress = {kAudioDevicePropertyVolumeScalar,
                                                kAudioObjectPropertyScopeOutput,
                                             kAudioObjectPropertyElementMaster};
    
    return AudioObjectSetPropertyData(inDeviceID,
                                      &theAddress,
                                      0,
                                      NULL,
                                      sizeof(float),
                                      &volume);
}
OSStatus GetOutputVolumeForDevice(AudioObjectID inDeviceID, float *volume) {
    
    AudioObjectPropertyAddress theAddress = {
        kAudioDevicePropertyVolumeScalar,
        kAudioObjectPropertyScopeOutput,
        kAudioObjectPropertyElementMaster};

    UInt32 theDataSize = sizeof(float);
    return AudioObjectGetPropertyData(inDeviceID,
                                      &theAddress,
                                      0,
                                      NULL,
                                      &theDataSize,
                                      volume);
}


#endif

OSStatus AudioUnitSetMaxIOBufferFrameSize(AudioUnit audioUnit,
                                          UInt32 inIOBufferFrameSize)
{
    UInt32 maximumBufferSize;
    UInt32 propSize = sizeof(maximumBufferSize);
    OSStatus status = AudioUnitSetProperty(audioUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &inIOBufferFrameSize, propSize);
    return status;
}

OSStatus AudioUnitGetMaxIOBufferFrameSize(AudioUnit audioUnit,
                                          UInt32 *outIOBufferFrameSize)
{
    UInt32 maximumBufferSize;
    UInt32 propSize = sizeof(maximumBufferSize);
    OSStatus status = AudioUnitGetProperty(audioUnit,
                                           kAudioUnitProperty_MaximumFramesPerSlice,
                                           kAudioUnitScope_Global,
                                           0,
                                           outIOBufferFrameSize,
                                           &propSize);
    return status;
}




@implementation RZAudioUtil
+ (AudioStreamBasicDescription)floatFormatWithNumberOfChannels:(UInt32)channels
                                                    sampleRate:(float)sampleRate
{
    return [self floatFormatWithNumberOfChannels:channels sampleRate:sampleRate isInterleaved:NO];
}

+ (AudioStreamBasicDescription)floatFormatWithNumberOfChannels:(UInt32)channels
                                                    sampleRate:(float)sampleRate
                                                 isInterleaved:(BOOL)isInterleaved
{
    AVAudioFormat *format = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32 sampleRate:sampleRate channels:channels interleaved:isInterleaved];
    AudioStreamBasicDescription desc = *(format.streamDescription);
    format = nil;
    return desc;
}

+ (AudioStreamBasicDescription)intFormatWithNumberOfChannels:(UInt32)channels
                                                  sampleRate:(float)sampleRate
                                               isInterleaved:(BOOL)isInterleaved
{
    AVAudioFormat *format = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatInt16 sampleRate:sampleRate channels:channels interleaved:isInterleaved];
    AudioStreamBasicDescription desc = *(format.streamDescription);
    format = nil;
    return desc;
}


+ (AudioStreamBasicDescription)intFormatWithNumberOfChannels:(UInt32)channels
                                                  sampleRate:(float)sampleRate
{
    return [self intFormatWithNumberOfChannels:channels sampleRate:sampleRate isInterleaved:NO];
}


+ (AudioBufferList *)audioBufferListWithNumberOfFrames:(UInt32)frames
                                          streamFormat:(AudioStreamBasicDescription)asbd
{
    BOOL isInterleaved = [self isInterleaved:asbd];

    UInt32 typeSize = asbd.mBytesPerFrame;
    UInt32 channels = asbd.mChannelsPerFrame;

    unsigned nBuffers;
    unsigned bufferSize;
    unsigned channelsPerBuffer;
    if (isInterleaved) {
        nBuffers = 1;
        bufferSize = typeSize * frames * channels;
        channelsPerBuffer = channels;
    } else {
        nBuffers = channels;
        bufferSize = typeSize * frames;
        channelsPerBuffer = 1;
    }

    AudioBufferList *audioBufferList = (AudioBufferList *)malloc(sizeof(AudioBufferList) + sizeof(AudioBuffer) * (channels - 1));
    audioBufferList->mNumberBuffers = nBuffers;
    for (unsigned i = 0; i < nBuffers; i++) {
        audioBufferList->mBuffers[i].mNumberChannels = channelsPerBuffer;
        audioBufferList->mBuffers[i].mDataByteSize = bufferSize;
        audioBufferList->mBuffers[i].mData = calloc(bufferSize, 1);
    }
    return audioBufferList;
}


+ (BOOL)isInterleaved:(AudioStreamBasicDescription)asbd
{
    return !(asbd.mFormatFlags & kAudioFormatFlagIsNonInterleaved);
}

+ (void)freeAudioBufferList:(AudioBufferList *)bufferList
{
    if (bufferList) {
        if (bufferList->mNumberBuffers) {
            for (int i = 0; i < bufferList->mNumberBuffers; i++) {
                if (bufferList->mBuffers[i].mData) {
                    free(bufferList->mBuffers[i].mData);
                }
            }
        }
        free(bufferList);
    }
    bufferList = NULL;
}


@end
