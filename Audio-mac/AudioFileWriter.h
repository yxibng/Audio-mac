//
//  AudioFileWriter.h
//  AudioGraph-iOS
//
//  Created by yxibng on 2020/2/16.
//  Copyright © 2020 姚晓丙. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
NS_ASSUME_NONNULL_BEGIN


@interface AudioFileWriter : NSObject

- (instancetype)initWithInStreamDesc:(AudioStreamBasicDescription)inStreamDesc filePath:(NSString *)filePath;

- (void)setup;

- (void)writeWithAudioBufferList:(AudioBufferList *)audioBufferList inNumberFrames:(UInt32)inNumberFrames;
//调用之后，如果想继续重新写入。必须调用 setup
- (void)dispose;

@end

NS_ASSUME_NONNULL_END
