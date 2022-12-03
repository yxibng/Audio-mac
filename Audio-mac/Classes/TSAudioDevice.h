//
//  TSAudioDevice.h
//  Pods
//
//  Created by yxibng on 2020/1/6.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

#if TARGET_OS_IOS
#import <AVFoundation/AVFoundation.h>
#elif TARGET_OS_OSX
#endif

NS_ASSUME_NONNULL_BEGIN


#if TARGET_OS_OSX
@class TSAudioDevice, TSAudioDeviceManager;

typedef NS_ENUM(NSUInteger, TSAudioDeviceChangeType) {
    TSAudioDeviceChangeType_Add = 0,
    TSAudioDeviceChangeType_Remove = 1
};


@protocol TSAudioDeviceManagerDelegate <NSObject>

@optional

- (void)manager:(TSAudioDeviceManager *)manager inputDeviceChanged:(TSAudioDevice *)device type:(TSAudioDeviceChangeType)type;
- (void)manager:(TSAudioDeviceManager *)manager outputDeviceChanged:(TSAudioDevice *)device type:(TSAudioDeviceChangeType)type;

@end


@interface TSAudioDeviceManager : NSObject

- (instancetype)initWithDelegate:(_Nullable id<TSAudioDeviceManagerDelegate>)delegate NS_DESIGNATED_INITIALIZER;

@property (nonatomic, copy) void(^inputChangeCallback)(TSAudioDevice *device, TSAudioDeviceChangeType type);
@property (nonatomic, copy) void(^outputChangeCallback)(TSAudioDevice *device, TSAudioDeviceChangeType type);


@property (nonatomic, weak) id<TSAudioDeviceManagerDelegate> delegate;

@property (nonatomic, strong, readonly) TSAudioDevice *currentInputDevice;
@property (nonatomic, strong, readonly) TSAudioDevice *currentOutputDevice;

@property (nonatomic, strong, readonly) NSArray<TSAudioDevice *> *inputDevices;
@property (nonatomic, strong, readonly) NSArray<TSAudioDevice *> *outputDevices;

@end

#endif


@interface TSAudioDevice : NSObject

+ (TSAudioDevice *)currentInputDevice;
+ (TSAudioDevice *)currentOutputDevice;

+ (NSArray<TSAudioDevice *> *)inputDevices;
+ (NSArray<TSAudioDevice *> *)outputDevices;

+ (void)enumerateInputDevicesUsingBlock:(void (^)(TSAudioDevice *device, BOOL *stop))block;
+ (void)enumerateOutputDevicesUsingBlock:(void (^)(TSAudioDevice *device, BOOL *stop))block;
+ (void)enumerateDevicesUsingBlock:(void (^)(TSAudioDevice *device, BOOL *stop))block;

+ (NSArray<TSAudioDevice *> *)devices;

@property (nonatomic, copy, readonly) NSString *name;

#if TARGET_OS_IOS

/**
 An AVAudioSessionPortDescription describing an input or output hardware port.
    - iOS only
 */
@property (nonatomic, strong, readonly) AVAudioSessionPortDescription *port;

//------------------------------------------------------------------------------

/**
 An AVAudioSessionDataSourceDescription describing a specific data source for the `port` provided.
    - iOS only
 */
@property (nonatomic, strong, readonly) AVAudioSessionDataSourceDescription *dataSource;

#elif TARGET_OS_OSX

/**
 An AudioDeviceID representing the device in the AudioHardware API.
    - OSX only
 */
@property (nonatomic, assign, readonly) AudioDeviceID deviceID;

//------------------------------------------------------------------------------

@property (nonatomic, assign, readonly) UInt32 portType;

/**
 An NSString representing the name of the manufacturer of the device.
    - OSX only
 */
@property (nonatomic, copy, readonly) NSString *manufacturer;

//------------------------------------------------------------------------------

/**
 An NSInteger representing the number of input channels available.
    - OSX only
 */
@property (nonatomic, assign, readonly) NSInteger inputChannelCount;

//------------------------------------------------------------------------------

/**
 An NSInteger representing the number of output channels available.
    - OSX only
 */
@property (nonatomic, assign, readonly) NSInteger outputChannelCount;

//------------------------------------------------------------------------------

/**
 An NSString representing the persistent identifier for the AudioDevice.
    - OSX only
 */
@property (nonatomic, copy, readonly) NSString *UID;

#endif


@end

NS_ASSUME_NONNULL_END
