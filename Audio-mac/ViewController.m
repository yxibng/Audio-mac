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

static NSString *cellMark = @"TableCell";

@interface ViewController ()<NSTableViewDelegate,NSTableViewDataSource, RZAudioRecorderDelegate>

@property (weak) IBOutlet NSTableView *tableView;
@property (nonatomic, strong) NSArray<DbyAudioDevice *> *devices;
@property (nonatomic, strong) RZAudioRecorder *audioRecorder;


@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    _devices = [DbyAudioDevice inputDevices];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    
    NSNib *nib = [[NSNib alloc] initWithNibNamed:cellMark bundle:nil];
    [self.tableView registerNib:nib forIdentifier:cellMark];
    [self.tableView reloadData];
    
    RZAudioConfig config = (RZAudioConfig){1, 16000, 20};
    _audioRecorder = [[RZAudioRecorder alloc] initWithConfig:config delegate:self];
    
}
- (IBAction)startRecord:(id)sender {
    [_audioRecorder start];
}
- (IBAction)stopRecord:(id)sender {
    [_audioRecorder stop];
}


- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}

#pragma mark -
- (IBAction)tableViewSelectionChange:(NSTableView *)sender {
    NSInteger selectedRow = [self.tableView selectedRow];
    NSLog(@"selectedRow = %d",selectedRow);

    
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
 
    
    NSLog(@"size = %d, sampleRate = %f", size, sampleRate);
    
    
}


@end
