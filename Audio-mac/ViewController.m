//
//  ViewController.m
//  Audio-mac
//
//  Created by yxibng on 2020/10/13.
//

#import "ViewController.h"
#import "TableCell.h"
#import "DbyAudioDevice.h"
#import "RZAudioRecorder.h"

#import "RZAudioUtil.h"

static NSString *cellMark = @"TableCell";

@interface ViewController ()<NSTableViewDelegate,NSTableViewDataSource, RZAudioRecorderDelegate, DbyAudioDeviceManagerDelegate>

@property (weak) IBOutlet NSTableView *tableView;
@property (nonatomic, strong) NSArray<DbyAudioDevice *> *devices;
@property (nonatomic, strong) RZAudioRecorder *audioRecorder;
@property (weak) IBOutlet NSSlider *sliderBar;

@property (nonatomic, strong) DbyAudioDeviceManager *audioDeviceManage;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
    _audioDeviceManage = [[DbyAudioDeviceManager alloc] initWithDelegate:self];
    
    
    _devices = [DbyAudioDevice inputDevices];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    
    NSNib *nib = [[NSNib alloc] initWithNibNamed:cellMark bundle:nil];
    [self.tableView registerNib:nib forIdentifier:cellMark];
    [self.tableView reloadData];
    
    RZAudioConfig config = (RZAudioConfig){1, 16000, 20};
    _audioRecorder = [[RZAudioRecorder alloc] initWithConfig:config delegate:self];
    
    
    float volume = 0;
    OSStatus status = GetInputVolumeForDevice(_audioRecorder.deviceID, &volume);
    NSLog(@"status = %d,before volume = %f", status, volume);
    _sliderBar.intValue = volume * 100;
    
    int index = -1;
    for (int i = 0; i < _devices.count; i++) {
        DbyAudioDevice *device = _devices[i];
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
    
    

}


- (IBAction)startRecord:(id)sender {
    [_audioRecorder start];
}
- (IBAction)stopRecord:(id)sender {
    [_audioRecorder stop];
}

- (IBAction)sliderValueChange:(NSSlider *)sender {
    
    float volume = sender.intValue/100.0;
    OSStatus status = SetInputVolumeForDevice(_audioRecorder.deviceID, volume);
    if (status) {
        NSLog(@"set volume failed, status = %d, volume = %f",status, volume);
    } else {
        NSLog(@"set volume success volume = %f", volume);

    }
    

    
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
    DbyAudioDevice *device = _devices[selectedRow];
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
    DbyAudioDevice *device = self.devices[row];
    cell.label.stringValue = device.name;
    return cell;
}

#pragma mark -
/*
 did start
 */
- (void)audioRecorder:(RZAudioRecorder *)audioRecorder didStartWithError:(RZAudioRecorderStartError)error {
    
}
/*
 did stop
 */
- (void)audioRecorderDidStop:(RZAudioRecorder *)audioRecorder {
    
}
/*
 error occured
 */
- (void)audioRecorder:(RZAudioRecorder *)audioRecorder didOccurError:(NSDictionary *)userInfo {
    
}
/*
 did record raw data
*/
- (void)audioRecorder:(RZAudioRecorder *)audioRecorder
   didRecordAudioData:(void *)audioData
                 size:(int)size
           sampleRate:(double)sampleRate
            timestamp:(NSTimeInterval)timestamp {
  
//    NSLog(@"size = %d, sampleRate = %f", size, sampleRate);
}


#pragma mark -
- (void)manager:(DbyAudioDeviceManager *)manager inputDeviceChanged:(DbyAudioDevice *)device type:(DbyAudioDeviceChangeType)type {
    
    /*
     设备断开,如果断开的是当前正在使用的设备。采集器需要重新 选择使用的设备
     */
    NSLog(@"%s",__FUNCTION__);
    if (device.deviceID == self.audioRecorder.deviceID && type == DbyAudioDeviceChangeType_Remove) {
        NSLog(@"disconnect name = %@, id = %d, new name = %@, id = %d", device.name, device.deviceID, manager.currentInputDevice.name, manager.currentInputDevice.deviceID);
        [self.audioRecorder setDeviceID:manager.currentInputDevice.deviceID];
    }
    
}
- (void)manager:(DbyAudioDeviceManager *)manager outputDeviceChanged:(DbyAudioDevice *)device type:(DbyAudioDeviceChangeType)type {
    /*
     TODO:设备断开,如果断开的是当前正在使用的设备。者播放器需要重新 选择使用的设备
     */
}


@end
