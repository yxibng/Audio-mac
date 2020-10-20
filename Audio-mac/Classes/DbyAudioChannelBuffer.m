//
//  DbyAudioChannelBuffer.m
//  DbyPaas_iOS
//
//  Created by yxibng on 2020/1/14.
//

#import "DbyAudioChannelBuffer.h"
#import "TPCircularBuffer.h"

/**
 16KHZ, s16, 单声道， 20毫秒数据为320byte，
 设置60ms数据的缓冲， 大小为960byte
 */
#define kMaxBufferSize 960

@interface DbyAudioChannelBuffer ()
{
    TPCircularBuffer _buffer;
}
@end


@implementation DbyAudioChannelBuffer

- (void)dealloc
{
    TPCircularBufferCleanup(&_buffer);
}

- (instancetype)init
{
    if (self = [super init]) {
        int size = kMaxBufferSize;
        TPCircularBufferInit(&_buffer, size);
    }
    return self;
}


- (void)enqueueAudioData:(void *)audioData length:(int)length
{
    bool bRet = TPCircularBufferProduceBytes(&_buffer, audioData, length);
    if (bRet) {
        return;
    }
    TPCircularBufferConsume(&_buffer, length);
    TPCircularBufferProduceBytes(&_buffer, audioData, length);
    /*
     由于TPCircularBuffer 内部的长度是内存分页的大小，大概为4096。会一直写，写到4096的大小。
     导致 buffer 过大, 延迟变高
     手动控制 buffer 的大小不超过 kMaxBufferSize
     */
    uint32_t totalDataLength;
    TPCircularBufferTail(&_buffer, &totalDataLength);
    if (totalDataLength > kMaxBufferSize) {
        uint32_t shouldConsumeSize = totalDataLength - kMaxBufferSize;
        TPCircularBufferConsume(&_buffer, shouldConsumeSize);
    }
}

- (void)dequeueLength:(int)length dstBuffer:(void *)dstBuffer
{
    uint32_t bufferLeft = 0;
    void *tmpBuffer = TPCircularBufferTail(&_buffer, &bufferLeft);
    if (bufferLeft >= length) {
        memcpy(dstBuffer, tmpBuffer, length);
        TPCircularBufferConsume(&_buffer, length);
    } else {
        memset(dstBuffer, 0, length);
    }
}

- (void)clearBuffer
{
    TPCircularBufferClear(&_buffer);
}

@end
