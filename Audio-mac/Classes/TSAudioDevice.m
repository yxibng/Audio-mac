//
//  TSAudioDevice.m
//  Pods
//
//  Created by yxibng on 2020/1/6.
//

#import "TSAudioDevice.h"


@interface TSAudioDevice ()

@property (nonatomic, copy, readwrite) NSString *name;

#if TARGET_OS_IOS

@property (nonatomic, strong, readwrite) AVAudioSessionPortDescription *port;
@property (nonatomic, strong, readwrite) AVAudioSessionDataSourceDescription *dataSource;

#elif TARGET_OS_OSX

@property (nonatomic, assign, readwrite) AudioDeviceID deviceID;
@property (nonatomic, assign, readwrite) UInt32 portType;
@property (nonatomic, copy, readwrite) NSString *manufacturer;
@property (nonatomic, assign, readwrite) NSInteger inputChannelCount;
@property (nonatomic, assign, readwrite) NSInteger outputChannelCount;
@property (nonatomic, copy, readwrite) NSString *UID;

#endif

@end


#if TARGET_OS_OSX


@implementation TSAudioDeviceManager

- (void)dealloc
{
    [self removeListener];
}

- (instancetype)initWithDelegate:(id<TSAudioDeviceManagerDelegate>)delegate
{
    if (self = [super init]) {
        _delegate = delegate;
        _inputDevices = [TSAudioDevice inputDevices];
        _outputDevices = [TSAudioDevice outputDevices];
        _currentInputDevice = [TSAudioDevice currentInputDevice];
        _currentOutputDevice = [TSAudioDevice currentOutputDevice];
        [self addListener];
    }
    return self;
}

- (instancetype)init
{
    return [self initWithDelegate:nil];
}

- (void)handleInputDeviceChanges
{
    NSArray *oldInputs = self.inputDevices;
    NSArray *currentInputs = [TSAudioDevice inputDevices];

    self->_inputDevices = [TSAudioDevice inputDevices];
    self->_currentInputDevice = [TSAudioDevice currentInputDevice];

    if (oldInputs.count > currentInputs.count) {
        //old device removed
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"NOT (SELF IN %@)", currentInputs];
        NSArray *changedInputs = [oldInputs filteredArrayUsingPredicate:predicate];
        for (TSAudioDevice *removedDevice in changedInputs) {
            
            if (self.inputChangeCallback) {
                self.inputChangeCallback(removedDevice, TSAudioDeviceChangeType_Remove);
            }
            
            
            if ([self.delegate respondsToSelector:@selector(manager:inputDeviceChanged:type:)]) {
                [self.delegate manager:self inputDeviceChanged:removedDevice type:TSAudioDeviceChangeType_Remove];
            }
        }
    } else if (oldInputs.count < currentInputs.count) {
        //new device added
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"NOT (SELF IN %@)", oldInputs];
        NSArray *changedInputs = [currentInputs filteredArrayUsingPredicate:predicate];
        for (TSAudioDevice *addedDevice in changedInputs) {
            if ([self.delegate respondsToSelector:@selector(manager:inputDeviceChanged:type:)]) {
                [self.delegate manager:self inputDeviceChanged:addedDevice type:TSAudioDeviceChangeType_Add];
            }
            
            if (self.inputChangeCallback) {
                self.inputChangeCallback(addedDevice, TSAudioDeviceChangeType_Add);
            }
        }
    } else {
        //no changes
    }
}

- (void)handleOutputDeviceChanges
{
    NSArray *oldOutputs = self.outputDevices;
    NSArray *currentOutputs = [TSAudioDevice outputDevices];

    self->_outputDevices = [TSAudioDevice outputDevices];
    self->_currentOutputDevice = [TSAudioDevice currentOutputDevice];

    if (oldOutputs.count > currentOutputs.count) {
        //old device removed
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"NOT (SELF IN %@)", currentOutputs];
        NSArray *changedOutputs = [oldOutputs filteredArrayUsingPredicate:predicate];
        for (TSAudioDevice *removedDevice in changedOutputs) {
            if ([self.delegate respondsToSelector:@selector(manager:outputDeviceChanged:type:)]) {
                [self.delegate manager:self outputDeviceChanged:removedDevice type:TSAudioDeviceChangeType_Remove];
            }
            if (self.outputChangeCallback) {
                self.outputChangeCallback(removedDevice, TSAudioDeviceChangeType_Remove);
            }
            
        }
    } else if (oldOutputs.count < currentOutputs.count) {
        //new device added
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"NOT (SELF IN %@)", oldOutputs];
        NSArray *changedOutputs = [currentOutputs filteredArrayUsingPredicate:predicate];
        for (TSAudioDevice *addedDevice in changedOutputs) {
            if ([self.delegate respondsToSelector:@selector(manager:outputDeviceChanged:type:)]) {
                [self.delegate manager:self outputDeviceChanged:addedDevice type:TSAudioDeviceChangeType_Add];
            }
            if (self.outputChangeCallback) {
                self.outputChangeCallback(addedDevice, TSAudioDeviceChangeType_Add);
            }
        }
    } else {
        //no changes
    }
}


- (void)addListener
{
    AudioObjectPropertyAddress devicesAddress;
    devicesAddress.mSelector = kAudioHardwarePropertyDevices;
    devicesAddress.mScope = kAudioObjectPropertyScopeGlobal;
    devicesAddress.mElement = kAudioObjectPropertyElementMaster;

    AudioObjectPropertyAddress defaultInputAddress;
    defaultInputAddress.mSelector = kAudioHardwarePropertyDefaultInputDevice;
    defaultInputAddress.mScope = kAudioObjectPropertyScopeGlobal;
    defaultInputAddress.mElement = kAudioObjectPropertyElementMaster;

    AudioObjectPropertyAddress defaultOutputAddress;
    defaultOutputAddress.mSelector = kAudioHardwarePropertyDefaultOutputDevice;
    defaultOutputAddress.mScope = kAudioObjectPropertyScopeGlobal;
    defaultOutputAddress.mElement = kAudioObjectPropertyElementMaster;

    AudioObjectAddPropertyListener(kAudioObjectSystemObject,
                                   &devicesAddress,
                                   deviceChangeCallback, (__bridge void *_Nullable)(self));

    AudioObjectAddPropertyListener(kAudioObjectSystemObject,
                                   &defaultInputAddress,
                                   deviceChangeCallback, (__bridge void *_Nullable)(self));

    AudioObjectAddPropertyListener(kAudioObjectSystemObject,
                                   &defaultOutputAddress,
                                   deviceChangeCallback, (__bridge void *_Nullable)(self));


    AudioObjectPropertyAddress runLoopAddress = {
        kAudioHardwarePropertyRunLoop,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMaster};

    CFRunLoopRef runLoop = NULL;
    UInt32 size = sizeof(CFRunLoopRef);
    AudioObjectSetPropertyData(kAudioObjectSystemObject,
                               &runLoopAddress, 0, NULL, size, &runLoop);
}

- (void)removeListener
{
    AudioObjectPropertyAddress propertyAddress;
    propertyAddress.mScope = kAudioObjectPropertyScopeGlobal;
    propertyAddress.mElement = kAudioObjectPropertyElementMaster;

    propertyAddress.mSelector = kAudioHardwarePropertyDefaultOutputDevice;
    AudioObjectRemovePropertyListener(kAudioObjectSystemObject, &propertyAddress, deviceChangeCallback, (__bridge void *)self);

    propertyAddress.mSelector = kAudioHardwarePropertyDefaultInputDevice;
    AudioObjectRemovePropertyListener(kAudioObjectSystemObject, &propertyAddress, deviceChangeCallback, (__bridge void *)self);

    propertyAddress.mSelector = kAudioHardwarePropertyDevices;
    AudioObjectRemovePropertyListener(kAudioObjectSystemObject, &propertyAddress, deviceChangeCallback, (__bridge void *)self);
}

OSStatus deviceChangeCallback(AudioObjectID inObjectID,
                              UInt32 inNumberAddresses,
                              const AudioObjectPropertyAddress inAddresses[],
                              void *inClientData)
{
    if (!inNumberAddresses) {
        return noErr;
    }
    TSAudioDeviceManager *manager = (__bridge TSAudioDeviceManager *)(inClientData);
    AudioObjectPropertyAddress addr = inAddresses[0];
    if (addr.mSelector == kAudioHardwarePropertyDefaultInputDevice) {
        manager->_currentInputDevice = [TSAudioDevice currentInputDevice];
    } else if (addr.mSelector == kAudioHardwarePropertyDefaultOutputDevice) {
        manager->_currentOutputDevice = [TSAudioDevice currentOutputDevice];
    } else if (addr.mSelector == kAudioHardwarePropertyDevices) {
        //diff inputs & outputs
        [manager handleInputDeviceChanges];
        [manager handleOutputDeviceChanges];
    }
    return noErr;
}

@end

#endif


@implementation TSAudioDevice

- (BOOL)isEqual:(TSAudioDevice *)object
{
    if (![object isKindOfClass:TSAudioDevice.class]) {
        return NO;
    }

#if TARGET_OS_OSX
    return self.deviceID == object.deviceID;
#elif TARGET_OS_IOS
    return [self.port.UID isEqualToString:object.port.UID];
#endif
}

- (NSUInteger)hash
{
#if TARGET_OS_OSX
    return self.deviceID;
#elif TARGET_OS_IOS
    return [self.port.UID hash];
#endif
}


- (NSString *)description
{
#if TARGET_OS_OSX
    return [NSString stringWithFormat:@"id = %d, name = %@", self.deviceID, self.name];
#elif TARGET_OS_IOS
    return [NSString stringWithFormat:@"port id = %@, name = %@", self.port.UID, self.port.portName];
#endif
}


#pragma mark - TARGET_OS_IOS

#if TARGET_OS_IOS

+ (TSAudioDevice *)currentInputDevice
{
    AVAudioSession *session = [AVAudioSession sharedInstance];
    AVAudioSessionPortDescription *port = [[[session currentRoute] inputs] firstObject];
    AVAudioSessionDataSourceDescription *dataSource = [session inputDataSource];
    TSAudioDevice *device = [[TSAudioDevice alloc] init];
    device.port = port;
    device.dataSource = dataSource;
    return device;
}

+ (TSAudioDevice *)currentOutputDevice
{
    AVAudioSession *session = [AVAudioSession sharedInstance];
    AVAudioSessionPortDescription *port = [[[session currentRoute] outputs] firstObject];
    AVAudioSessionDataSourceDescription *dataSource = [session outputDataSource];
    TSAudioDevice *device = [[TSAudioDevice alloc] init];
    device.port = port;
    device.dataSource = dataSource;
    return device;
}

+ (NSArray<TSAudioDevice *> *)inputDevices
{
    NSMutableArray *inputs = [NSMutableArray array];
    [self enumerateInputDevicesUsingBlock:^(TSAudioDevice *_Nonnull device, BOOL *_Nonnull stop) {
        [inputs addObject:device];
    }];
    return inputs;
}
+ (NSArray<TSAudioDevice *> *)outputDevices
{
    NSMutableArray *outputs = [NSMutableArray array];
    [self enumerateOutputDevicesUsingBlock:^(TSAudioDevice *_Nonnull device, BOOL *_Nonnull stop) {
        [outputs addObject:device];
    }];
    return outputs;
}

+ (void)enumerateInputDevicesUsingBlock:(void (^)(TSAudioDevice *_Nonnull device, BOOL *_Nonnull))block
{
    if (!block) {
        return;
    }

    NSArray *inputs = [[AVAudioSession sharedInstance] availableInputs];
    if (!inputs) {
        return;
    }

    BOOL stop = NO;
    for (AVAudioSessionPortDescription *inputDevicePortDescription in inputs) {
        NSArray *dataSources = [inputDevicePortDescription dataSources];
        if (dataSources.count) {
            for (AVAudioSessionDataSourceDescription *inputDeviceDataSourceDescription in dataSources) {
                TSAudioDevice *device = [[TSAudioDevice alloc] init];
                device.port = inputDevicePortDescription;
                device.dataSource = inputDeviceDataSourceDescription;
                block(device, &stop);
                if (stop) {
                    break;
                }
            }
        } else {
            TSAudioDevice *device = [[TSAudioDevice alloc] init];
            device.port = inputDevicePortDescription;
            block(device, &stop);
            if (stop) {
                break;
            }
        }
    }
}

+ (void)enumerateOutputDevicesUsingBlock:(void (^)(TSAudioDevice *_Nonnull device, BOOL *_Nonnull))block
{
    if (!block) {
        return;
    }

    AVAudioSessionRouteDescription *currentRoute = [[AVAudioSession sharedInstance] currentRoute];
    NSArray *portDescriptions = [currentRoute outputs];

    BOOL stop = NO;
    for (AVAudioSessionPortDescription *outputDevicePortDescription in portDescriptions) {
        // add any additional sub-devices
        NSArray *dataSources = [outputDevicePortDescription dataSources];
        if (dataSources.count) {
            for (AVAudioSessionDataSourceDescription *outputDeviceDataSourceDescription in dataSources) {
                TSAudioDevice *device = [[TSAudioDevice alloc] init];
                device.port = outputDevicePortDescription;
                device.dataSource = outputDeviceDataSourceDescription;
                block(device, &stop);
                if (stop) {
                    break;
                }
            }
        } else {
            TSAudioDevice *device = [[TSAudioDevice alloc] init];
            device.port = outputDevicePortDescription;
            block(device, &stop);
            if (stop) {
                break;
            }
        }
    }
}

+ (void)enumerateDevicesUsingBlock:(void (^)(TSAudioDevice *_Nonnull device, BOOL *_Nonnull))block
{
    BOOL stop;
    for (TSAudioDevice *device in [self devices]) {
        block(device, &stop);
        if (stop) {
            break;
        }
    }
}

+ (NSArray<TSAudioDevice *> *)devices
{
    NSMutableArray *allDevices = [NSMutableArray array];

    [self enumerateInputDevicesUsingBlock:^(TSAudioDevice *_Nonnull device, BOOL *_Nonnull stop) {
        [allDevices addObject:device];
    }];

    [self enumerateOutputDevicesUsingBlock:^(TSAudioDevice *_Nonnull device, BOOL *_Nonnull stop) {
        [allDevices addObject:device];
    }];
    return allDevices;
}

- (NSString *)name
{
    NSMutableString *name = [NSMutableString string];
    if (self.port) {
        [name appendString:self.port.portName];
    }
    if (self.dataSource) {
        [name appendFormat:@": %@", self.dataSource.dataSourceName];
    }
    return name;
}

#elif TARGET_OS_OSX

#pragma mark - MAC

+ (TSAudioDevice *)currentInputDevice
{
    return [self deviceWithPropertySelector:kAudioHardwarePropertyDefaultInputDevice];
}

+ (TSAudioDevice *)currentOutputDevice
{
    return [self deviceWithPropertySelector:kAudioHardwarePropertyDefaultOutputDevice];
}

+ (NSArray<TSAudioDevice *> *)inputDevices
{
    NSMutableArray *devices = [NSMutableArray array];
    [self enumerateDevicesUsingBlock:^(TSAudioDevice *device, BOOL *stop) {
        if (device.inputChannelCount > 0) {
            [devices addObject:device];
        }
    }];
    return devices;
}

+ (NSArray<TSAudioDevice *> *)outputDevices
{
    __block NSMutableArray *devices = [NSMutableArray array];
    [self enumerateDevicesUsingBlock:^(TSAudioDevice *device, BOOL *stop) {
        if (device.outputChannelCount > 0) {
            [devices addObject:device];
        }
    }];
    return devices;
}

+ (void)enumerateInputDevicesUsingBlock:(void (^)(TSAudioDevice *_Nonnull, BOOL *_Nonnull))block
{
    if (!block) {
        return;
    }
    NSArray *inputs = [self inputDevices];
    BOOL stop;
    for (TSAudioDevice *device in inputs) {
        block(device, &stop);
        if (stop) {
            break;
        }
    }
}

+ (void)enumerateOutputDevicesUsingBlock:(void (^)(TSAudioDevice *_Nonnull, BOOL *_Nonnull))block
{
    if (!block) {
        return;
    }
    NSArray *outputs = [self outputDevices];
    BOOL stop;
    for (TSAudioDevice *device in outputs) {
        block(device, &stop);
        if (stop) {
            break;
        }
    }
}

+ (void)enumerateDevicesUsingBlock:(void (^)(TSAudioDevice *_Nonnull, BOOL *_Nonnull))block
{
    if (!block) {
        return;
    }

    // get the present system devices
    AudioObjectPropertyAddress address = [self addressForPropertySelector:kAudioHardwarePropertyDevices];
    UInt32 devicesDataSize;
    OSStatus status = AudioObjectGetPropertyDataSize(kAudioObjectSystemObject,
                                                     &address,
                                                     0,
                                                     NULL,
                                                     &devicesDataSize);
    NSAssert(status == noErr, @"Failed to get data size");
    if (status != noErr) {
        return;
    }
    // enumerate devices
    NSInteger count = devicesDataSize / sizeof(AudioDeviceID);
    AudioDeviceID *deviceIDs = (AudioDeviceID *)malloc(devicesDataSize);
    // fill in the devices
    status = AudioObjectGetPropertyData(kAudioObjectSystemObject,
                                        &address,
                                        0,
                                        NULL,
                                        &devicesDataSize,
                                        deviceIDs);
    NSAssert(status == noErr, @"Failed to get device IDs for available devices on OSX");
    if (status != noErr) {
        free(deviceIDs);
        return;
    }

    BOOL stop = NO;
    for (UInt32 i = 0; i < count; i++) {
        AudioDeviceID deviceID = deviceIDs[i];
        TSAudioDevice *device = [[TSAudioDevice alloc] init];
        device.deviceID = deviceID;
        device.portType = [self portTypeForDeviceID:deviceID];
        device.manufacturer = [self manufacturerForDeviceID:deviceID];
        device.name = [self namePropertyForDeviceID:deviceID];
        device.UID = [self UIDPropertyForDeviceID:deviceID];
        device.inputChannelCount = [self channelCountForScope:kAudioObjectPropertyScopeInput forDeviceID:deviceID];
        device.outputChannelCount = [self channelCountForScope:kAudioObjectPropertyScopeOutput forDeviceID:deviceID];
        block(device, &stop);
        if (stop) {
            break;
        }
    }

    free(deviceIDs);
}

+ (NSArray<TSAudioDevice *> *)devices
{
    __block NSMutableArray *devices = [NSMutableArray array];
    [self enumerateDevicesUsingBlock:^(TSAudioDevice *device, BOOL *stop) {
        [devices addObject:device];
    }];
    return devices;
}

#pragma mark - Utility

+ (AudioObjectPropertyAddress)addressForPropertySelector:(AudioObjectPropertySelector)selector
{
    AudioObjectPropertyAddress address;
    address.mScope = kAudioObjectPropertyScopeGlobal;
    address.mElement = kAudioObjectPropertyElementMaster;
    address.mSelector = selector;
    return address;
}

+ (NSString *)stringPropertyForSelector:(AudioObjectPropertySelector)selector
                           withDeviceID:(AudioDeviceID)deviceID
{
    AudioObjectPropertyAddress address = [self addressForPropertySelector:selector];
    CFStringRef string;
    UInt32 propSize = sizeof(CFStringRef);
    OSStatus status = AudioObjectGetPropertyData(deviceID,
                                                 &address,
                                                 0,
                                                 NULL,
                                                 &propSize,
                                                 &string);

    NSString *errorString = [NSString stringWithFormat:@"Failed to get device property (%u)", (unsigned int)selector];
    NSAssert(status == noErr, errorString);
    if (status) {
        return @"";
    }
    return (__bridge_transfer NSString *)string;
}


+ (UInt32)portTypeForDeviceID:(AudioDeviceID)deviceID {
    
    AudioObjectPropertyAddress address = [self addressForPropertySelector:kAudioDevicePropertyTransportType];
    
    UInt32 portType;
    UInt32 propSize = sizeof(UInt32);
    
    OSStatus status = AudioObjectGetPropertyData(deviceID,
                                                 &address,
                                                 0,
                                                 NULL,
                                                 &propSize,
                                                 &portType);

    NSString *errorString = [NSString stringWithFormat:@"Failed to get device property (%u)", (unsigned int)kAudioDevicePropertyTransportType];
    NSAssert(status == noErr, errorString);
    return portType;
}

+ (NSString *)manufacturerForDeviceID:(AudioDeviceID)deviceID
{
    return [self stringPropertyForSelector:kAudioDevicePropertyDeviceManufacturerCFString
                              withDeviceID:deviceID];
}

+ (NSString *)namePropertyForDeviceID:(AudioDeviceID)deviceID
{
    return [self stringPropertyForSelector:kAudioDevicePropertyDeviceNameCFString
                              withDeviceID:deviceID];
}

+ (NSString *)UIDPropertyForDeviceID:(AudioDeviceID)deviceID
{
    return [self stringPropertyForSelector:kAudioDevicePropertyDeviceUID
                              withDeviceID:deviceID];
}



+ (NSInteger)channelCountForScope:(AudioObjectPropertyScope)scope
                      forDeviceID:(AudioDeviceID)deviceID
{
    AudioObjectPropertyAddress address;
    address.mScope = scope;
    address.mElement = kAudioObjectPropertyElementMaster;
    address.mSelector = kAudioDevicePropertyStreamConfiguration;

    AudioBufferList streamConfiguration;
    UInt32 propSize = sizeof(streamConfiguration);
    OSStatus status = AudioObjectGetPropertyData(deviceID,
                                                 &address,
                                                 0,
                                                 NULL,
                                                 &propSize,
                                                 &streamConfiguration);
    NSAssert(status == noErr, @"Failed to get frame size");
    NSInteger channelCount = 0;
    for (NSInteger i = 0; i < streamConfiguration.mNumberBuffers; i++) {
        channelCount += streamConfiguration.mBuffers[i].mNumberChannels;
    }
    return channelCount;
}


+ (TSAudioDevice * _Nullable)deviceWithPropertySelector:(AudioObjectPropertySelector)propertySelector
{
    AudioDeviceID deviceID;
    UInt32 propSize = sizeof(AudioDeviceID);
    AudioObjectPropertyAddress address = [self addressForPropertySelector:propertySelector];
    OSStatus status = AudioObjectGetPropertyData(kAudioObjectSystemObject,
                                                 &address,
                                                 0,
                                                 NULL,
                                                 &propSize,
                                                 &deviceID);

    NSAssert(status == noErr, @"Failed to get device on OSX");
    if (deviceID == kAudioDeviceUnknown) {
        return nil;
    }
    
    TSAudioDevice *device = [[TSAudioDevice alloc] init];
    device.deviceID = deviceID;
    device.manufacturer = [self manufacturerForDeviceID:deviceID];
    device.name = [self namePropertyForDeviceID:deviceID];
    device.UID = [self UIDPropertyForDeviceID:deviceID];
    device.inputChannelCount = [self channelCountForScope:kAudioObjectPropertyScopeInput forDeviceID:deviceID];
    device.outputChannelCount = [self channelCountForScope:kAudioObjectPropertyScopeOutput forDeviceID:deviceID];
    return device;
}

#endif


@end
