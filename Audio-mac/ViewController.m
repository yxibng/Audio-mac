//
//  ViewController.m
//  Audio-mac
//
//  Created by yxibng on 2020/10/13.
//

#import "ViewController.h"
#import "TableCell.h"
#import "TSAudioDevice.h"
#import "TSAudioRecorder.h"
#import "TSAudioUtil.h"
#import "TSAudioConverter.h"
#import <AVFoundation/AVFoundation.h>


static NSString *cellMark = @"TableCell";


const int outputBufferSize = 48000 * 2 * 8;
static uint8_t outputBuffer[outputBufferSize];


@interface ViewController ()<NSTableViewDelegate,NSTableViewDataSource, TSAudioRecorderDelegate, TSAudioDeviceManagerDelegate>

@property (weak) IBOutlet NSTableView *tableView;
@property (nonatomic, strong) NSArray<TSAudioDevice *> *devices;
@property (nonatomic, strong) TSAudioRecorder *audioRecorder;
@property (weak) IBOutlet NSSlider *sliderBar;

@property (nonatomic, strong) TSAudioDeviceManager *audioDeviceManage;

@property (nonatomic, strong) TSAudioConverter *converter;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
    _audioDeviceManage = [[TSAudioDeviceManager alloc] initWithDelegate:self];
    
    
    _devices = [TSAudioDevice inputDevices];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    
    NSNib *nib = [[NSNib alloc] initWithNibNamed:cellMark bundle:nil];
    [self.tableView registerNib:nib forIdentifier:cellMark];
    [self.tableView reloadData];
    
    TSAudioConfig config = (TSAudioConfig){1, 16000, 20};
    _audioRecorder = [[TSAudioRecorder alloc] initWithConfig:config delegate:self];
    
    
    float volume = 0;
    OSStatus status = GetInputVolumeForDevice(_audioRecorder.deviceID, &volume);
    NSLog(@"status = %d,before volume = %f", status, volume);
    _sliderBar.intValue = volume * 100;
    
    int index = -1;
    for (int i = 0; i < _devices.count; i++) {
        TSAudioDevice *device = _devices[i];
        if (device.deviceID == _audioRecorder.deviceID) {
            index = i;
            break;;
        }
    }
    
    if (index >= 0) {
        //初始选中状态
        NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:index];
        [self.tableView selectRowIndexes:indexSet byExtendingSelection:NO];
    }
    
    bool mute = false;
    status = GetInputMute(_audioRecorder.deviceID, &mute);
    NSLog(@"status = %d, before mute = %d",status, mute);
    status = SetInputMute(_audioRecorder.deviceID, true);
    NSLog(@"status = %d, before mute = %d", status, mute);
    status = GetInputMute(_audioRecorder.deviceID, &mute);
    NSLog(@"status = %d, before mute = %d",status, mute);
    
    
    AVAudioFormat *src = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatInt16 sampleRate:48000 channels:1 interleaved:YES];
    AVAudioFormat *dst = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatInt16 sampleRate:16000 channels:1 interleaved:YES];
    _converter = [[TSAudioConverter alloc] initWithSrcFormat: *(src.streamDescription) dstFormat: *(dst.streamDescription) ];
}


- (IBAction)startRecord:(id)sender {
    [_audioRecorder start];
}
- (IBAction)stopRecord:(id)sender {
    [_audioRecorder stop];
}

- (IBAction)sliderValueChange:(NSSlider *)sender {
#if 0
    float volume = sender.intValue/100.0;
    OSStatus status = SetInputVolumeForDevice(_audioRecorder.deviceID, volume);
    if (status) {
        NSLog(@"set volume failed, status = %d, volume = %f",status, volume);
    } else {
        NSLog(@"set volume success volume = %f", volume);

    }
#endif
}


- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}

#pragma mark -
- (IBAction)tableViewSelectionChange:(NSTableView *)sender {
    NSInteger selectedRow = [self.tableView selectedRow];
    NSLog(@"selectedRow = %ld",(long)selectedRow);

    
    //change device
    TSAudioDevice *device = _devices[selectedRow];
    [_audioRecorder setDeviceID:device.deviceID];
    
}


- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.devices.count;
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row {
    return 20;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSString *identifier = cellMark;
    TableCell *cell = [tableView makeViewWithIdentifier:identifier owner:self];
    TSAudioDevice *device = self.devices[row];
    cell.label.stringValue = device.name;
    return cell;
}

#pragma mark -
/*
 did start
 */
- (void)audioRecorder:(TSAudioRecorder *)audioRecorder didStartWithError:(TSAudioRecorderStartError)error {
    
}
/*
 did stop
 */
- (void)audioRecorderDidStop:(TSAudioRecorder *)audioRecorder{
    
}
/*
 error occured
 */
- (void)audioRecorder:(TSAudioRecorder *)audioRecorder didOccurError:(NSDictionary *)userInfo {
    
}
/*
 did record raw data
*/
- (void)audioRecorder:(TSAudioRecorder *)audioRecorder
   didRecordAudioData:(void *)audioData
                 size:(int)size
           sampleRate:(double)sampleRate
            timestamp:(NSTimeInterval)timestamp {
    
    NSLog(@"size = %d, sampleRate = %f", size, sampleRate);
    
    int sampleCount = size / 2;
    int32_t outLength = 0;
    int32_t outCount = 0;
    
   BOOL ret = [self.converter convertMonoPCMWithSrc:(uint8_t *)audioData
                                          srcLength:size
                                     srcSampleCount:sampleCount
                                   outputBufferSize:outputBufferSize
                                       outputBuffer:outputBuffer
                                       outputLength: &outLength
                                  outputSampleCount: &outCount];
    
    NSLog(@"src count = %d, size = %d,\
          dst count = %d, size = %d", sampleCount, size, outCount, outLength);
}



#pragma mark -
- (void)manager:(TSAudioDeviceManager *)manager inputDeviceChanged:(TSAudioDevice *)device type:(TSAudioDeviceChangeType)type {
    
    /*
     设备断开,如果断开的是当前正在使用的设备。采集器需要重新 选择使用的设备
     */
    NSLog(@"%s",__FUNCTION__);
    if (device.deviceID == self.audioRecorder.deviceID && type == TSAudioDeviceChangeType_Remove) {
        NSLog(@"disconnect name = %@, id = %d, new name = %@, id = %d", device.name, device.deviceID, manager.currentInputDevice.name, manager.currentInputDevice.deviceID);
        [self.audioRecorder setDeviceID:manager.currentInputDevice.deviceID];
    }
    
}
- (void)manager:(TSAudioDeviceManager *)manager outputDeviceChanged:(TSAudioDevice *)device type:(TSAudioDeviceChangeType)type {
    /*
     TODO:设备断开,如果断开的是当前正在使用的设备。者播放器需要重新 选择使用的设备
     */
}


@end
