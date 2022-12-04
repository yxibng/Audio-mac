//
//  TSAudioConverter.m
//  BroadcastExtention
//
//  Created by xiaobing yao on 2022/12/2.
//

#import "TSAudioConverter.h"
#import <AudioToolbox/AudioToolbox.h>

typedef struct {
    int totalsize;
    int offset;
    uint8_t *data;
} AudioDataModel;


void writePCM(uint8_t * pcm, int length) {
    static FILE* m_pOutFile = NULL;
    if (!m_pOutFile) {
        NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"xx.pcm"];
        m_pOutFile = fopen([path cStringUsingEncoding:NSUTF8StringEncoding], "a+");
        NSLog(@"path = %@", path);
    }
    fwrite(pcm, 1, length, m_pOutFile);
}




@interface TSAudioConverter ()
{
    AudioConverterRef _converterRef;
    AudioStreamBasicDescription _srcFormat;
    AudioStreamBasicDescription _dstFormat;
}

@end


@implementation TSAudioConverter

- (void)dealloc {
    if (_converterRef) {
        AudioConverterDispose(_converterRef);
        _converterRef = nil;
    }
}

- (instancetype)initWithSrcFormat:(AudioStreamBasicDescription)srcFormat dstFormat:(AudioStreamBasicDescription)dstForamt
{
    self = [super init];
    if (self) {
        OSStatus status = AudioConverterNew(&srcFormat, &dstForamt, &_converterRef);
        if (status) {
            NSLog(@"AudioConverterNew failed, code = %d", status);
            return nil;
        }
        _srcFormat = srcFormat;
        _dstFormat = dstForamt;
    }
    return self;
}

- (BOOL)convertMonoPCMWithSrc:(uint8_t *)srcData
                    srcLength:(int32_t)srcLength
               srcSampleCount:(int32_t)srcSampleCount
             outputBufferSize:(int32_t)outputBufferSize
                  outputBuffer:(uint8_t *)outputBuffer
                  outputLength:(int32_t *)outputLength
            outputSampleCount:(int32_t *)outputSampleCount
{
    
    //计算重采样后，应该有多少个采样点
    UInt32 totalPacketsShoudOutput = ceil(_dstFormat.mSampleRate * srcSampleCount / _srcFormat.mSampleRate);
    /*
     调用时，告诉AudioConverterFillComplexBuffer，期待返回多少个重采样后的数据包
     AudioConverterFillComplexBuffer 返回后，告诉你实际返回了多少个重采样后的数据包
     */
    UInt32 ioOutputDataPacketSize = totalPacketsShoudOutput;
    //目前已经读到了多少个采样后的数据包
    UInt32 totalPacketsRead = 0;
    //目前已经获取的长度
    UInt32 totalSizeRead = 0;
    

    AudioDataModel dataModel;
    dataModel.data = srcData;
    dataModel.offset = 0;
    dataModel.totalsize = srcLength;
    
    //处理的是单声道的pcm，一个包里面就一个采样点
    const int mDataByteSize = totalPacketsShoudOutput *_dstFormat.mBytesPerPacket;
    uint8_t *mData = (uint8_t *)malloc(mDataByteSize);
    
    AudioBufferList outAudioBufferList;
    outAudioBufferList.mNumberBuffers = 1;
    outAudioBufferList.mBuffers[0].mNumberChannels = 1;
    outAudioBufferList.mBuffers[0].mDataByteSize = mDataByteSize;
    outAudioBufferList.mBuffers[0].mData = mData;
    
    //循环读取重采样后的数据
    OSStatus convertResult = noErr;
    while (convertResult == noErr && dataModel.offset < dataModel.totalsize) {
        memset(mData, 0, mDataByteSize);
        convertResult = AudioConverterFillComplexBuffer(_converterRef,
                                                        inInputDataProc,
                                                        &dataModel,
                                                        &ioOutputDataPacketSize,
                                                        &outAudioBufferList,
                                                        NULL);
        if (ioOutputDataPacketSize == 0) {
            break;
        }
        UInt32 readSize = outAudioBufferList.mBuffers[0].mDataByteSize;
        if (totalSizeRead + readSize > outputBufferSize) {
            //提供的buffe太小了
            free(mData);
            return NO;
        }
        
        memcpy(outputBuffer + totalSizeRead, mData, readSize);
        totalPacketsRead += ioOutputDataPacketSize;
        totalSizeRead += readSize;
    }

    *outputLength = totalSizeRead;
    *outputSampleCount = totalPacketsRead;
    
    free(mData);
    return YES;
}


OSStatus inInputDataProc(AudioConverterRef inAudioConverter, UInt32 *ioNumberDataPackets, AudioBufferList *ioData, AudioStreamPacketDescription **outDataPacketDescription, void *inUserData)
{
    AudioDataModel *model = (AudioDataModel *)inUserData;
    int requireSize = ioData->mBuffers[0].mDataByteSize;
    int leftSize = model->totalsize - model->offset;
    
    if (leftSize <= 0) {
        *ioNumberDataPackets = 0;
        return -1;
    }
    if (leftSize < requireSize) {
        memcpy(ioData->mBuffers[0].mData, model->data + model->offset, leftSize);
        model->offset += leftSize;
        *ioNumberDataPackets = leftSize / 2;
        return noErr;
    } else {
        memcpy(ioData->mBuffers[0].mData, model->data + model->offset, requireSize);
        model->offset += requireSize;
        return noErr;
    }
}

@end
