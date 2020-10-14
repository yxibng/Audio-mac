//
//  AudioFileHelper.h
//  CoreAudioDemos
//
//  Created by yxibng on 2019/11/13.
//  Copyright © 2019 姚晓丙. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreAudioKit/CoreAudioKit.h>

NS_ASSUME_NONNULL_BEGIN


typedef struct {
    AudioStreamBasicDescription asbd;
    Float32 *data;
    UInt32 numFrames;
    UInt32 sampleNum;
} SoundBuffer, *SoundBufferPtr;


@interface AudioFileReader : NSObject
@property (nonatomic, copy) NSString *filePath;
- (instancetype)initWithFilePath:(NSString *)filePath streamFormat:(AudioStreamBasicDescription)streamFormat;

- (void)start;
- (BOOL)readSoundTo:(void *)data size:(int)length;
- (void)stop;

@end

@interface AudioFileWriter : NSObject
@property (nonatomic, copy) NSString *filePath;
- (instancetype)initWithFilePath:(NSString *)filePath streamFormat:(AudioStreamBasicDescription)streamFormat;
- (void)start;
- (void)writeData:(void *)data size:(int)length;
- (void)stop;

@end


@interface AudioFileHelper : NSObject


@end

NS_ASSUME_NONNULL_END
