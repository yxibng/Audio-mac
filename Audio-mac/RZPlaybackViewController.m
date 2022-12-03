//
//  RZPlaybackViewController.m
//  Audio-mac
//
//  Created by yxibng on 2020/10/20.
//

#import "RZPlaybackViewController.h"
#import "TableCell.h"
#import "TSAudioDevice.h"
#import "TSAudioRecorder.h"
#import "TSAudioPlayer.h"
#import "AudioFileReader.h"
#import "TSAudioUtil.h"
#import "RZFileUtil.h"

static char *codeToString(UInt32 code)
{
    static char str[5] = { '\0' };
    UInt32 swapped = CFSwapInt32HostToBig(code);
    memcpy(str, &swapped, sizeof(swapped));
    return str;
}

static NSString *cellMark = @"TableCell";

@interface RZPlaybackViewController ()<NSTableViewDelegate,NSTableViewDataSource, TSAudioPlayerDelegate,TSAudioDeviceManagerDelegate>
@property (weak) IBOutlet NSTableView *tableView;
@property (nonatomic, strong) NSArray<TSAudioDevice *> *devices;
@property (weak) IBOutlet NSSlider *sliderBar;
@property (nonatomic, strong) TSAudioPlayer *audioPlayer;
@property (nonatomic, strong) AudioFileReader *fileReader;

@property (nonatomic, strong) TSAudioDeviceManager *deviceManager;

@property (weak) IBOutlet NSButton *muteBox;

@end

@implementation RZPlaybackViewController
- (void)dealloc
{

}


- (void)viewDidLoad {
    [super viewDidLoad];
    
    _deviceManager = [[TSAudioDeviceManager alloc] initWithDelegate:self];
    
    _devices = [TSAudioDevice outputDevices];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    
    NSNib *nib = [[NSNib alloc] initWithNibNamed:cellMark bundle:nil];
    [self.tableView registerNib:nib forIdentifier:cellMark];
    [self.tableView reloadData];
    
    _audioPlayer = [[TSAudioPlayer alloc] init];
    _audioPlayer.delegate = self;
    
    
    float volume = 0;
    OSStatus status =  GetOutputVolumeForDevice(_audioPlayer.deviceID, &volume);
    NSLog(@"status = %d, volume = %f",status, volume);
    
    if (status == noErr) {
        self.sliderBar.integerValue = volume * 100;
    }
    
    bool mute;
    status = GetOutputMute(_audioPlayer.deviceID, &mute);
    if (status == noErr && mute) {
        self.muteBox.state = NSControlStateValueOn;
    }
    
    
    NSURL *fileURL = [[NSBundle mainBundle] URLForResource:@"senorita" withExtension:@"mp3"];
    _fileReader = [[AudioFileReader alloc] initWithFileURL:fileURL clientFormat:_audioPlayer.streamDesc];
    [_fileReader start];
    
    int index = -1;
    for (int i = 0; i < _devices.count; i++) {
        TSAudioDevice *device = _devices[i];
        if (device.deviceID == _audioPlayer.deviceID) {
            index = i;
            break;
        }
    }
    
    if (index >= 0) {
        //初始选中状态
        NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:index];
        [self.tableView selectRowIndexes:indexSet byExtendingSelection:NO];
    }
    // Do view setup here.
}
- (IBAction)start:(id)sender {
    [_audioPlayer start];
}

- (IBAction)stop:(id)sender {
    [_audioPlayer stop];
}

- (IBAction)muteChange:(NSButton *)sender {

    bool mute = sender.state == NSControlStateValueOn;
    SetOutputMute(_audioPlayer.deviceID, mute);
    
}

- (IBAction)sliderValueChange:(NSSlider *)sender {
    
    float volume = sender.intValue/100.0;
    OSStatus status = SetOutputVolumeForDevice(_audioPlayer.deviceID, volume);
    if (status) {
        NSLog(@"set volume failed, status = %d, volume = %f",status, volume);
    } else {
        NSLog(@"set volume success volume = %f", volume);

    }
}


#pragma mark -
- (IBAction)tableViewSelectionChange:(NSTableView *)sender {
    NSInteger selectedRow = [self.tableView selectedRow];
    NSLog(@"selectedRow = %ld",(long)selectedRow);
    if (selectedRow >= 0 && selectedRow <_devices.count) {
        //change device
        TSAudioDevice *device = _devices[selectedRow];
        [_audioPlayer setDeviceID:device.deviceID];
    }

    
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
    cell.label.stringValue = [device.name stringByAppendingFormat:@" type = %s", codeToString(device.portType)];
    return cell;
}

#pragma mark -
- (void)audioPlayer:(TSAudioPlayer *)audioPlayer didStartwithError:(TSAudioPlayerStartError)error {
    
}

- (void)auidoPlayer:(TSAudioPlayer *)audioPlayer didOccurError:(NSDictionary *)userInfo {
    
}

- (void)audioPlayerDidStop:(TSAudioPlayer *)audioPlayer {
    
}

- (void)audioPlayer:(TSAudioPlayer *)audioPlayer fillAudioBufferList:(AudioBufferList *)list inNumberOfFrames:(UInt32)inNumberOfFrames {
 
    UInt32 size = 0;
    BOOL eof = NO;
    [_fileReader readFrames:inNumberOfFrames audioBufferList:list bufferSize:&size eof:&eof];
    if (eof) {
        [_fileReader seekToFrame:0];
    }
}


#pragma mark -
- (void)manager:(TSAudioDeviceManager *)manager inputDeviceChanged:(TSAudioDevice *)device type:(TSAudioDeviceChangeType)type {
    
    /*
     设备断开,如果断开的是当前正在使用的设备。采集器需要重新 选择使用的设备
     */

    
}
- (void)manager:(TSAudioDeviceManager *)manager outputDeviceChanged:(TSAudioDevice *)device type:(TSAudioDeviceChangeType)type {
    /*
     TODO:设备断开,如果断开的是当前正在使用的设备。者播放器需要重新 选择使用的设备
     */
    if (type == TSAudioDeviceChangeType_Remove && device.deviceID == self.audioPlayer.deviceID) {
        //切换播放设备
        TSAudioDevice *next = [TSAudioDevice currentOutputDevice];
        [self.audioPlayer setDeviceID:next.deviceID];
        NSLog(@"disconnect is %@, next = %@",device.name, next.name);
    }
}


@end
