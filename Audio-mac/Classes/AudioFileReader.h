//
//  AudioFileReader.h
//  AudioGraph-iOS
//
//  Created by yxibng on 2020/2/16.
//  Copyright © 2020 姚晓丙. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

NS_ASSUME_NONNULL_BEGIN


@interface AudioFileReader : NSObject

- (instancetype)initWithFileURL:(NSURL *)URL clientFormat:(AudioStreamBasicDescription)clientFormat;

/*
 Provides a dictionary containing the metadata (ID3) tags that are included in the header for the audio file.
 Typically this contains stuff like artist, title, release year, etc.
 */
@property (nonatomic, readonly) NSDictionary *metaData;

/**
 Provides the frame index (a.k.a the seek positon) within the audio file as SInt64. This can be helpful when seeking through the audio file.
 @return The current frame index within the audio file as a SInt64.
 */
@property (nonatomic, readonly) SInt64 frameIndex;;

/**
 Provides the total frame count of the audio file in the file format.
 @return The total number of frames in the audio file in the AudioStreamBasicDescription representing the file format as a SInt64.
 */
@property (readonly) SInt64 totalFrames;

/**
 Provides the total frame count of the audio file in the client format.
 @return The total number of frames in the audio file in the AudioStreamBasicDescription representing the client format as a SInt64.
 */
@property (readonly) SInt64 totalClientFrames;

/**
 Provides the common AudioStreamBasicDescription that will be used for in-app interaction.
 The file's format will be converted to this format and then sent back as either a float array or a `AudioBufferList` pointer.
 @warning This must be a linear PCM format!
 @return An AudioStreamBasicDescription structure describing the format of the audio file.
 */
@property (readwrite) AudioStreamBasicDescription clientFormat;

/**
 Provides the AudioStreamBasicDescription structure containing the format of the file.
 @return An AudioStreamBasicDescription structure describing the format of the audio file.
 */
@property (readonly) AudioStreamBasicDescription fileFormat;
/**
 Provides the current offset in the audio file as an NSTimeInterval (i.e. in seconds).  When setting this it will determine the correct frame offset and perform a `seekToFrame` to the new time offset.
 @warning Make sure the new current time offset is less than the `duration` or you will receive an invalid seek assertion.
 */
@property (nonatomic, readwrite) NSTimeInterval currentTime;
/**
 Provides the duration of the audio file in seconds.
 */
@property (readonly) NSTimeInterval duration;

/**
 Seeks through an audio file to a specified frame. This will notify the EZAudioFileDelegate (if specified) with the audioFile:updatedPosition: function.
 @param frame The new frame position to seek to as a SInt64.
 */
- (void)seekToFrame:(SInt64)frame;


- (void)start;
- (void)stop;

- (void)readFrames:(UInt32)frames
   audioBufferList:(AudioBufferList *)audioBufferList
        bufferSize:(UInt32 *)bufferSize
               eof:(BOOL *)eof;


@end

NS_ASSUME_NONNULL_END
