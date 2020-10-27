//
//  RZAudioUtil.m
//  RZPaas_macOS
//
//  Created by yxibng on 2020/9/29.
//

#import "RZAudioUtil.h"
#import <AVFoundation/AVFoundation.h>

#if TARGET_OS_OSX

UInt32 channelCountForScope(AudioObjectPropertyScope scope, AudioDeviceID deviceID)

{
    if (deviceID == kAudioDeviceUnknown) {
        return -1;
    }
    AudioObjectPropertyAddress address;
    address.mScope = scope;
    address.mElement = kAudioObjectPropertyElementMaster;
    address.mSelector = kAudioDevicePropertyStreamConfiguration;
    
    AudioBufferList streamConfiguration;
    UInt32 propSize = sizeof(streamConfiguration);
    OSStatus status = AudioObjectGetPropertyData(deviceID,
                                                 &address,
                                                 0,
                                                 NULL,
                                                 &propSize,
                                                 &streamConfiguration);
    assert(status == noErr);
    if (status) {
        return 0;
    }
    UInt32 channelCount = 0;
    for (NSInteger i = 0; i < streamConfiguration.mNumberBuffers; i++) {
        channelCount += streamConfiguration.mBuffers[i].mNumberChannels;
    }
    return channelCount;
}



OSStatus GetIOBufferFrameSizeRange(AudioObjectID inDeviceID,
                                   UInt32 *outMinimum,
                                   UInt32 *outMaximum)
{
    if (inDeviceID == kAudioObjectUnknown) {
        return -1;
    }
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
    if (inDeviceID == kAudioObjectUnknown) {
        return -1;
    }
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
    if (inDeviceID == kAudioObjectUnknown) {
        return -1;
    }
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
    if (inDeviceID == kAudioObjectUnknown) {
        return -1;
    }
    OSStatus err = noErr;
    UInt32 size = 0;
    bool success = false;
    // volume range is 0.0 - 1.0, convert from 0 - 255
    const Float32 vol = volume;
    assert(vol <= 1.0 && vol >= 0.0);
    // Does the capture device have a master volume control?
    // If so, use it exclusively.
    AudioObjectPropertyAddress propertyAddress = {
        kAudioDevicePropertyVolumeScalar, kAudioDevicePropertyScopeInput, 0};
    Boolean isSettable = false;
    err = AudioObjectIsPropertySettable(inDeviceID, &propertyAddress,
                                        &isSettable);
    if (err == noErr && isSettable) {
        size = sizeof(vol);
        AudioObjectSetPropertyData(inDeviceID,
                                   &propertyAddress,
                                   0,
                                   NULL,
                                   size,
                                   &vol);
        return 0;
    }
    UInt32 channelCount = channelCountForScope(kAudioObjectPropertyScopeInput, inDeviceID);
    
    // Otherwise try to set each channel.
    for (UInt32 i = 1; i <= channelCount; i++) {
        propertyAddress.mElement = i;
        isSettable = false;
        err = AudioObjectIsPropertySettable(inDeviceID, &propertyAddress,
                                            &isSettable);
        if (err == noErr && isSettable) {
            size = sizeof(vol);
            err = AudioObjectSetPropertyData(inDeviceID,
                                       &propertyAddress,
                                       0,
                                       NULL,
                                       size,
                                       &vol);
        }
        success = true;
    }
    if (!success) {
        return -1;
    }
    return err;
}

OSStatus GetInputVolumeForDevice(AudioObjectID inDeviceID, float *volume) {
    
    if (inDeviceID == kAudioObjectUnknown) {
        return -1;
    }
    
    OSStatus err = noErr;
    UInt32 size = 0;
    unsigned int channels = 0;
    Float32 channelVol = 0;
    Float32 volFloat32 = 0;
    // Does the device have a master volume control?
    // If so, use it exclusively.
    AudioObjectPropertyAddress propertyAddress = {
        kAudioDevicePropertyVolumeScalar, kAudioDevicePropertyScopeInput, 0};
    Boolean hasProperty =
    AudioObjectHasProperty(inDeviceID, &propertyAddress);
    if (hasProperty) {
        size = sizeof(volFloat32);
        err = AudioObjectGetPropertyData(inDeviceID,
                                         &propertyAddress,
                                         0,
                                         NULL,
                                         &size,
                                         &volFloat32);
        *volume = volFloat32;
    } else {
        // Otherwise get the average volume across channels.
        
        volFloat32 = 0;
        UInt32 channelCount = channelCountForScope(kAudioObjectPropertyScopeInput, inDeviceID);
        
        for (UInt32 i = 1; i <= channelCount; i++) {
            channelVol = 0;
            propertyAddress.mElement = i;
            hasProperty = AudioObjectHasProperty(inDeviceID, &propertyAddress);
            if (hasProperty) {
                size = sizeof(channelVol);
                err = AudioObjectGetPropertyData(inDeviceID,
                                                 &propertyAddress,
                                                 0,
                                                 NULL,
                                                 &size,
                                                 &channelVol);
                volFloat32 += channelVol;
                channels++;
            }
        }
        if (channels == 0) {
            return -1;
        }
        assert(channels > 0);
        // vol 0.0 to 1.0 -> convert to 0 - 255
        *volume = volFloat32;
    }
    return err;
}

OSStatus SetInputMute(AudioObjectID inDeviceID, bool enable) {
    
    if (inDeviceID == kAudioObjectUnknown) {
        return -1;
    }
    
    OSStatus err = noErr;
    UInt32 size = 0;
    UInt32 mute = enable ? 1 : 0;
    bool success = false;
    // Does the capture device have a master mute control?
    // If so, use it exclusively.
    AudioObjectPropertyAddress propertyAddress = {
        kAudioDevicePropertyMute, kAudioDevicePropertyScopeInput, 0};
    Boolean isSettable = false;
    err = AudioObjectIsPropertySettable(inDeviceID, &propertyAddress,
                                        &isSettable);
    if (err == noErr && isSettable) {
        size = sizeof(mute);
        err = AudioObjectSetPropertyData(inDeviceID, &propertyAddress, 0, NULL, size, &mute);
        return err;
    }
    UInt32 channelCount = channelCountForScope(kAudioObjectPropertyScopeInput, inDeviceID);
    // Otherwise try to set each channel.
    for (UInt32 i = 1; i <= channelCount; i++) {
        propertyAddress.mElement = i;
        isSettable = false;
        err = AudioObjectIsPropertySettable(channelCount, &propertyAddress,
                                            &isSettable);
        if (err == noErr && isSettable) {
            size = sizeof(mute);
            err = AudioObjectSetPropertyData(channelCount, &propertyAddress, 0, NULL, size, &mute);
        }
        success = true;
    }
    if (!success) {
        return -1;
    }
    return err;
}

OSStatus GetInputMute(AudioObjectID inDeviceID,bool *mute) {
    if (inDeviceID == kAudioObjectUnknown) {
        return -1;
    }
    OSStatus err = noErr;
    UInt32 size = 0;
    unsigned int channels = 0;
    UInt32 channelMuted = 0;
    UInt32 muted = 0;
    // Does the device have a master volume control?
    // If so, use it exclusively.
    AudioObjectPropertyAddress propertyAddress = {
        kAudioDevicePropertyMute, kAudioDevicePropertyScopeInput, 0};
    Boolean hasProperty =
    AudioObjectHasProperty(inDeviceID, &propertyAddress);
    if (hasProperty) {
        size = sizeof(muted);
        err = AudioObjectGetPropertyData(inDeviceID,
                                         &propertyAddress,
                                         0,
                                         NULL,
                                         &size,
                                         &muted);
        // 1 means muted
        *mute = muted;
    } else {
        UInt32 channelCount = channelCountForScope(kAudioObjectPropertyScopeInput, inDeviceID);
        // Otherwise check if all channels are muted.
        for (UInt32 i = 1; i <= channelCount; i++) {
            muted = 0;
            propertyAddress.mElement = i;
            hasProperty = AudioObjectHasProperty(inDeviceID, &propertyAddress);
            if (hasProperty) {
                size = sizeof(channelMuted);
                err =AudioObjectGetPropertyData(inDeviceID,
                                                &propertyAddress,
                                                0,
                                                NULL,
                                                &size,
                                                &channelMuted);
                muted = (muted && channelMuted);
                channels++;
            }
        }
        if (channels == 0) {
            return -1;
        }
        assert(channels > 0);
        // 1 means muted
        *mute = muted;
    }
    return err;
}

OSStatus SetOutputMute(AudioObjectID inDeviceID, bool enable) {
    if (inDeviceID == kAudioObjectUnknown) {
        return -1;
    }
    OSStatus err = noErr;
    UInt32 size = 0;
    UInt32 mute = enable ? 1 : 0;
    bool success = false;
    // Does the render device have a master mute control?
    // If so, use it exclusively.
    AudioObjectPropertyAddress propertyAddress = {
        kAudioDevicePropertyMute, kAudioDevicePropertyScopeOutput, 0};
    Boolean isSettable = false;
    err = AudioObjectIsPropertySettable(inDeviceID, &propertyAddress,
                                        &isSettable);
    if (err == noErr && isSettable) {
        size = sizeof(mute);
        err = AudioObjectSetPropertyData(inDeviceID,
                                   &propertyAddress,
                                   0,
                                   NULL,
                                   size,
                                   &mute);
        return 0;
    }
    UInt32 channelCount = channelCountForScope(kAudioDevicePropertyScopeOutput, inDeviceID);
    
    // Otherwise try to set each channel.
    for (UInt32 i = 1; i <= channelCount; i++) {
        propertyAddress.mElement = i;
        isSettable = false;
        err = AudioObjectIsPropertySettable(inDeviceID, &propertyAddress,
                                            &isSettable);
        if (err == noErr && isSettable) {
            size = sizeof(mute);
            err = AudioObjectSetPropertyData(inDeviceID,
                                       &propertyAddress,
                                       0,
                                       NULL,
                                       size,
                                       &mute);
        }
        success = true;
    }
    if (!success) {
        return -1;
    }
    return err;
}

OSStatus GetOutputMute(AudioObjectID inDeviceID,bool *mute) {
    if (inDeviceID == kAudioObjectUnknown) {
        return -1;
    }
    OSStatus err = noErr;
    UInt32 size = 0;
    unsigned int channels = 0;
    UInt32 channelMuted = 0;
    UInt32 muted = 0;
    // Does the device have a master volume control?
    // If so, use it exclusively.
    AudioObjectPropertyAddress propertyAddress = {
        kAudioDevicePropertyMute, kAudioDevicePropertyScopeOutput, 0};
    Boolean hasProperty =
    AudioObjectHasProperty(inDeviceID, &propertyAddress);
    if (hasProperty) {
        size = sizeof(muted);
        err = AudioObjectGetPropertyData(inDeviceID, &propertyAddress, 0, NULL, &size, &muted);
        // 1 means muted
        *mute = muted;
    } else {
        UInt32 channelCount = channelCountForScope(kAudioDevicePropertyScopeOutput, inDeviceID);
        // Otherwise check if all channels are muted.
        for (UInt32 i = 1; i <= channelCount; i++) {
            muted = 0;
            propertyAddress.mElement = i;
            hasProperty = AudioObjectHasProperty(inDeviceID, &propertyAddress);
            if (hasProperty) {
                size = sizeof(channelMuted);
                err = AudioObjectGetPropertyData(inDeviceID,
                                           &propertyAddress,
                                           0,
                                           NULL,
                                           &size,
                                           &channelMuted);
                muted = (muted && channelMuted);
                channels++;
            }
        }
        if (channels == 0) {
            
            return -1;
        }
        *mute = muted;
    }
    return err;
}


OSStatus SetOutputVolumeForDevice(AudioObjectID inDeviceID, float volume) {
    if (inDeviceID == kAudioObjectUnknown) {
        return -1;
    }
    assert(volume <= 1.0 && volume >= 0.0);
    OSStatus err = noErr;
    UInt32 size = 0;
    bool success = false;
    // volume range is 0.0 - 1.0, convert from 0 -255
    const Float32 vol = volume;
    // Does the capture device have a master volume control?
    // If so, use it exclusively.
    AudioObjectPropertyAddress propertyAddress = {
        kAudioDevicePropertyVolumeScalar,
        kAudioDevicePropertyScopeOutput,
        0};
    Boolean isSettable = false;
    err = AudioObjectIsPropertySettable(inDeviceID, &propertyAddress,
                                        &isSettable);
    if (err == noErr && isSettable) {
        size = sizeof(vol);
        err = AudioObjectSetPropertyData(
                                   inDeviceID, &propertyAddress, 0, NULL, size, &vol);
        return 0;
    }
    
    UInt32 channelCount = channelCountForScope(kAudioDevicePropertyScopeOutput, inDeviceID);
    // Otherwise try to set each channel.
    for (UInt32 i = 1; i <= channelCount; i++) {
        propertyAddress.mElement = i;
        isSettable = false;
        err = AudioObjectIsPropertySettable(inDeviceID, &propertyAddress,
                                            &isSettable);
        if (err == noErr && isSettable) {
            size = sizeof(vol);
            err = AudioObjectSetPropertyData(inDeviceID,
                                       &propertyAddress,
                                       0,
                                       NULL,
                                       size,
                                       &vol);
        }
        success = true;
    }
    if (!success) {
        return -1;
    }
    return err;
}

OSStatus GetOutputVolumeForDevice(AudioObjectID inDeviceID, float *volume) {
    if (inDeviceID == kAudioObjectUnknown) {
        return -1;
    }
    OSStatus err = noErr;
    UInt32 size = 0;
    unsigned int channels = 0;
    Float32 channelVol = 0;
    Float32 vol = 0;
    // Does the device have a master volume control?
    // If so, use it exclusively.
    AudioObjectPropertyAddress propertyAddress = {
        kAudioDevicePropertyVolumeScalar, kAudioDevicePropertyScopeOutput, 0};
    Boolean hasProperty =
    AudioObjectHasProperty(inDeviceID, &propertyAddress);
    if (hasProperty) {
        size = sizeof(vol);
        err = AudioObjectGetPropertyData(inDeviceID,
                                         &propertyAddress,
                                         0,
                                         NULL,
                                         &size,
                                         &vol);
        *volume = vol;
    } else {
        // Otherwise get the average volume across channels.
        vol = 0;
        UInt32 channelCount = channelCountForScope(kAudioDevicePropertyScopeOutput, inDeviceID);
        for (UInt32 i = 1; i <= channelCount; i++) {
            channelVol = 0;
            propertyAddress.mElement = i;
            hasProperty = AudioObjectHasProperty(inDeviceID, &propertyAddress);
            if (hasProperty) {
                size = sizeof(channelVol);
                err = AudioObjectGetPropertyData(inDeviceID,
                                                 &propertyAddress,
                                                 0,
                                                 NULL,
                                                 &size,
                                                 &channelVol);
                vol += channelVol;
                channels++;
            }
        }
        if (channels == 0) {
            return -1;
        }
        assert(channels > 0);
        *volume = vol;
    }
    return err;
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
