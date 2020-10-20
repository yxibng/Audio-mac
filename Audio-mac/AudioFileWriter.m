//
//  AudioFileWriter.m
//  AudioGraph-iOS
//
//  Created by yxibng on 2020/2/16.
//  Copyright © 2020 姚晓丙. All rights reserved.
//

#import "AudioFileWriter.h"
#import <AudioToolbox/AudioToolbox.h>


typedef struct {
    CFURLRef fileURL;
    AudioFileTypeID audioFileTypeID;
    ExtAudioFileRef extAudioFileRef;
    //输入数据的格式
    AudioStreamBasicDescription inStreamDesc;
    //希望转换的格式
    AudioStreamBasicDescription clientStreamDesc;
    BOOL closed;
} AudioFileInfo;


@interface AudioFileWriter ()

@property (nonatomic) AudioFileInfo audioFileInfo;
@property (nonatomic, copy) NSString *filePath;

@end


@implementation AudioFileWriter


- (instancetype)initWithInStreamDesc:(AudioStreamBasicDescription)inStreamDesc filePath:(nonnull NSString *)filePath
{
    if (self = [super init]) {
        _audioFileInfo.inStreamDesc = inStreamDesc;
        _audioFileInfo.audioFileTypeID = kAudioFileCAFType;
        _filePath = filePath;
        _audioFileInfo.fileURL = (__bridge CFURLRef)([NSURL URLWithString:filePath]);
    }
    return self;
}

- (void)setup {
    [self creatFile];
}

- (void)creatFile
{
    //创建并打开文件
   OSStatus status = ExtAudioFileCreateWithURL(_audioFileInfo.fileURL,
                                       _audioFileInfo.audioFileTypeID,
                                       &_audioFileInfo.inStreamDesc,
                                       NULL,
                                       kAudioFileFlags_EraseFile,
                                       &_audioFileInfo.extAudioFileRef);


    assert(status == noErr);
    if (status) {
        return;
    }
    _audioFileInfo.closed = NO;
}


- (void)writeWithAudioBufferList:(AudioBufferList *)audioBufferList inNumberFrames:(UInt32)inNumberFrames
{
    if (!audioBufferList) {
        return;
    }

    if (_audioFileInfo.closed) {
        return;
    }

    OSStatus status = ExtAudioFileWriteAsync(_audioFileInfo.extAudioFileRef, inNumberFrames, audioBufferList);
    assert(status == noErr);
    if (status) {
        return;
    }
}

- (void)dispose
{
    ExtAudioFileDispose(_audioFileInfo.extAudioFileRef);
    _audioFileInfo.extAudioFileRef = NULL;

    _audioFileInfo.closed = YES;
}


@end
