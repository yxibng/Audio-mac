//
//  TSAudioChannelBuffer.m
//  TSRtc_iOS
//
//  Created by yxibng on 2020/1/14.
//

#import "TSAudioChannelBuffer.h"
#import "TPCircularBuffer.h"

/**
 16KHZ, s16, 单声道， 20毫秒数据为640byte，
 设置60ms数据的缓冲， 大小为1920byte
 */
#define kMaxBufferSize 1920

@interface TSAudioChannelBuffer ()
{
    TPCircularBuffer _buffer;
}

@property (nonatomic, assign) BOOL shouldPlay;

@end


@implementation TSAudioChannelBuffer

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
    if (self.shouldPlay) {
        if (bufferLeft <= 0) {
            self.shouldPlay = NO;
        }
    } else {
        if (bufferLeft >= length * 3) {
            self.shouldPlay = YES;
        }
    }
    
    
    if (self.shouldPlay) {
        memset(dstBuffer, 0, length);
        if (bufferLeft >= length) {
            memcpy(dstBuffer, tmpBuffer, length);
            TPCircularBufferConsume(&_buffer, length);
            if (bufferLeft - length == 0) {
                self.shouldPlay = NO;
            }
        } else {
            //缓存小于要的数据长度, 这里可能会发生卡顿
            memcpy(dstBuffer, tmpBuffer, bufferLeft);
            TPCircularBufferConsume(&_buffer, bufferLeft);
            self.shouldPlay = NO;
        }
    } else {
        memset(dstBuffer, 0, length);
    }
    
    writePcm(dstBuffer, length);
}

static void writePcm(void *data, int length) {
    
#if 0
    //用来调试音频卡顿
    static FILE* m_pOutFile = NULL;
    if (!m_pOutFile) {
        NSString *file = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
        file = [file stringByAppendingPathComponent:@"play.pcm"];
        m_pOutFile = fopen([file cStringUsingEncoding:NSUTF8StringEncoding], "a+");
    }
    fwrite(data, 1, length, m_pOutFile);
#endif
}


- (void)clearBuffer
{
    TPCircularBufferClear(&_buffer);
}

@end
