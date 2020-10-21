//
//  RZPlaybackViewController.m
//  Audio-mac
//
//  Created by yxibng on 2020/10/20.
//

#import "RZPlaybackViewController.h"
#import "TableCell.h"
#import "DbyAudioDevice.h"
#import "RZAudioPlayer.h"
#import "RZAudioUtil.h"
#import "AudioFileReader.h"
#import "RZFileUtil.h"

static NSString *cellMark = @"TableCell";

@interface RZPlaybackViewController ()<NSTableViewDelegate,NSTableViewDataSource, RZAudioPlayerDelegate,DbyAudioDeviceManagerDelegate>
@property (weak) IBOutlet NSTableView *tableView;
@property (nonatomic, strong) NSArray<DbyAudioDevice *> *devices;
@property (weak) IBOutlet NSSlider *sliderBar;
@property (nonatomic, strong) RZAudioPlayer *audioPlayer;
@property (nonatomic, strong) AudioFileReader *fileReader;

@property (nonatomic, strong) DbyAudioDeviceManager *deviceManager;

@property (weak) IBOutlet NSButton *muteBox;

@end

@implementation RZPlaybackViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _deviceManager = [[DbyAudioDeviceManager alloc] initWithDelegate:self];
    
    _devices = [DbyAudioDevice outputDevices];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    
    NSNib *nib = [[NSNib alloc] initWithNibNamed:cellMark bundle:nil];
    [self.tableView registerNib:nib forIdentifier:cellMark];
    [self.tableView reloadData];
    
    _audioPlayer = [[RZAudioPlayer alloc] init];
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
        DbyAudioDevice *device = _devices[i];
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
        DbyAudioDevice *device = _devices[selectedRow];
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
    DbyAudioDevice *device = self.devices[row];
    cell.label.stringValue = device.name;
    return cell;
}

#pragma mark -
- (void)audioPlayer:(RZAudioPlayer *)audioPlayer didStartwithError:(RZAudioPlayerStartError)error {
    
}

- (void)auidoPlayer:(RZAudioPlayer *)audioPlayer didOccurError:(NSDictionary *)userInfo {
    
}

- (void)audioPlayerDidStop:(RZAudioPlayer *)audioPlayer {
    
}

- (void)audioPlayer:(RZAudioPlayer *)audioPlayer fillAudioBufferList:(AudioBufferList *)list inNumberOfFrames:(UInt32)inNumberOfFrames {
 
    UInt32 size = 0;
    BOOL eof = NO;
    [_fileReader readFrames:inNumberOfFrames audioBufferList:list bufferSize:&size eof:&eof];
    if (eof) {
        [_fileReader seekToFrame:0];
    }
}


#pragma mark -
- (void)manager:(DbyAudioDeviceManager *)manager inputDeviceChanged:(DbyAudioDevice *)device type:(DbyAudioDeviceChangeType)type {
    
    /*
     设备断开,如果断开的是当前正在使用的设备。采集器需要重新 选择使用的设备
     */

    
}
- (void)manager:(DbyAudioDeviceManager *)manager outputDeviceChanged:(DbyAudioDevice *)device type:(DbyAudioDeviceChangeType)type {
    /*
     TODO:设备断开,如果断开的是当前正在使用的设备。者播放器需要重新 选择使用的设备
     */
    if (type == DbyAudioDeviceChangeType_Remove && device.deviceID == self.audioPlayer.deviceID) {
        //切换播放设备
        DbyAudioDevice *next = [DbyAudioDevice currentOutputDevice];
        [self.audioPlayer setDeviceID:next.deviceID];
        NSLog(@"disconnect is %@, next = %@",device.name, next.name);
    }
}


@end
