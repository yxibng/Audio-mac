//
//  AudioFileReader.m
//  AudioGraph-iOS
//
//  Created by yxibng on 2020/2/16.
//  Copyright © 2020 姚晓丙. All rights reserved.
//

#import "AudioFileReader.h"

typedef struct {
    CFURLRef fileURL;
    //    AudioFileTypeID audioFileTypeID;
    ExtAudioFileRef extAudioFileRef;
    AudioStreamBasicDescription inStreamDesc;
    AudioStreamBasicDescription clientStreamDesc;
    BOOL closed;

    //文件ID
    AudioFileID audioFileID;
    //文件数据流格式
    AudioStreamBasicDescription fileStreamFormat;
    //文件时长
    NSTimeInterval duration;
    //文件总帧数
    SInt64 frames;
} AudioFileInfo;


@interface AudioFileReader ()

@property (nonatomic) AudioFileInfo audioFileInfo;
@end


@implementation AudioFileReader

- (instancetype)initWithFileURL:(NSURL *)URL clientFormat:(AudioStreamBasicDescription)clientFormat
{
    if (self = [super init]) {
        _audioFileInfo.fileURL = (__bridge CFURLRef)(URL);
        _audioFileInfo.clientStreamDesc = clientFormat;
        [self start];
    }
    return self;
}

- (void)start
{
    OSStatus status = ExtAudioFileOpenURL(_audioFileInfo.fileURL, &_audioFileInfo.extAudioFileRef);
    assert(status == noErr);
    if (status) {
        return;
    }

    // set client format
    UInt32 propSize = sizeof(AudioStreamBasicDescription);
    status = ExtAudioFileSetProperty(_audioFileInfo.extAudioFileRef,
                                     kExtAudioFileProperty_ClientDataFormat,
                                     propSize,
                                     &_audioFileInfo.clientStreamDesc);
    assert(status == noErr);
    if (status) {
        return;
    }

    // get audioFileID
    propSize = sizeof(_audioFileInfo.audioFileID);
    status = ExtAudioFileGetProperty(_audioFileInfo.extAudioFileRef,
                                     kExtAudioFileProperty_AudioFile,
                                     &propSize, &_audioFileInfo.audioFileID);
    assert(status == noErr);
    if (status) {
        return;
    }


    // get fileStreamFormat
    propSize = sizeof(AudioStreamBasicDescription);
    status = ExtAudioFileGetProperty(_audioFileInfo.extAudioFileRef,
                                     kExtAudioFileProperty_FileDataFormat,
                                     &propSize,
                                     &_audioFileInfo.fileStreamFormat);

    assert(status == noErr);
    if (status) {
        return;
    }

    // get total frames
    propSize = sizeof(SInt64);
    status = ExtAudioFileGetProperty(_audioFileInfo.extAudioFileRef,
                                     kExtAudioFileProperty_FileLengthFrames,
                                     &propSize,
                                     &_audioFileInfo.frames);

    assert(status == noErr);
    if (status) {
        return;
    }

    // get duration
    _audioFileInfo.duration = _audioFileInfo.frames / _audioFileInfo.fileStreamFormat.mSampleRate;


    NSLog(@"frames = %d, duration = %f", _audioFileInfo.frames, _audioFileInfo.duration);


    //mark start
    _audioFileInfo.closed = NO;
}


- (NSDictionary *)metaData
{
    // get size of metadata property (dictionary)
    UInt32 propSize = sizeof(self.audioFileInfo.audioFileID);
    CFDictionaryRef metadata;
    UInt32 writable;
    OSStatus status = AudioFileGetPropertyInfo(self.audioFileInfo.audioFileID,
                                               kAudioFilePropertyInfoDictionary,
                                               &propSize,
                                               &writable);
    assert(status == noErr);
    // pull metadata
    status = AudioFileGetProperty(self.audioFileInfo.audioFileID,
                                  kAudioFilePropertyInfoDictionary,
                                  &propSize,
                                  &metadata);
    assert(status == noErr);
    // cast to NSDictionary
    return (__bridge NSDictionary *)metadata;
}


- (void)readFrames:(UInt32)frames audioBufferList:(AudioBufferList *)audioBufferList bufferSize:(UInt32 *)bufferSize eof:(BOOL *)eof
{
    if (_audioFileInfo.closed) {
        return;
    }

    OSStatus status = ExtAudioFileRead(_audioFileInfo.extAudioFileRef, &frames, audioBufferList);
    assert(status == noErr);
    if (status) {
        return;
    }

    *bufferSize = frames;
    *eof = frames == 0;
}


- (void)seekToFrame:(SInt64)frame {
    if (_audioFileInfo.closed) {
        return;
    }
    
    OSStatus status = ExtAudioFileSeek(_audioFileInfo.extAudioFileRef, frame);
    assert(status == noErr);
    if (status) {
        return;
    }
    
}


- (void)stop
{
    if (_audioFileInfo.closed) {
        //alread stopped
        return;
    }

    if (!_audioFileInfo.extAudioFileRef) {
        return;
    }

    ExtAudioFileDispose(_audioFileInfo.extAudioFileRef);
    _audioFileInfo.extAudioFileRef = NULL;
    _audioFileInfo.closed = YES;
}


@end
