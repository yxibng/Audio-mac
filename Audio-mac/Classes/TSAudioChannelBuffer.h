//
//  TSAudioChannelBuffer.h
//  TSRtc_iOS
//
//  Created by yxibng on 2020/1/14.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN


@interface TSAudioChannelBuffer : NSObject

- (void)enqueueAudioData:(void *)audioData length:(int)length;
- (void)dequeueLength:(int)length dstBuffer:(void *)dstBuffer;
- (void)clearBuffer;

@end

NS_ASSUME_NONNULL_END
