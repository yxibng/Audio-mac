//
//  DbyAudioDevice.h
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
@class DbyAudioDevice, DbyAudioDeviceManager;

typedef NS_ENUM(NSUInteger, DbyAudioDeviceChangeType) {
    DbyAudioDeviceChangeType_Add = 0,
    DbyAudioDeviceChangeType_Remove = 1
};


@protocol DbyAudioDeviceManagerDelegate <NSObject>

@optional

- (void)manager:(DbyAudioDeviceManager *)manager inputDeviceChanged:(DbyAudioDevice *)device type:(DbyAudioDeviceChangeType)type;
- (void)manager:(DbyAudioDeviceManager *)manager outputDeviceChanged:(DbyAudioDevice *)device type:(DbyAudioDeviceChangeType)type;

@end


@interface DbyAudioDeviceManager : NSObject

- (instancetype)initWithDelegate:(_Nullable id<DbyAudioDeviceManagerDelegate>)delegate NS_DESIGNATED_INITIALIZER;

@property (nonatomic, copy) void(^inputChangeCallback)(DbyAudioDevice *device, DbyAudioDeviceChangeType type);
@property (nonatomic, copy) void(^outputChangeCallback)(DbyAudioDevice *device, DbyAudioDeviceChangeType type);


@property (nonatomic, weak) id<DbyAudioDeviceManagerDelegate> delegate;

@property (nonatomic, strong, readonly) DbyAudioDevice *currentInputDevice;
@property (nonatomic, strong, readonly) DbyAudioDevice *currentOutputDevice;

@property (nonatomic, strong, readonly) NSArray<DbyAudioDevice *> *inputDevices;
@property (nonatomic, strong, readonly) NSArray<DbyAudioDevice *> *outputDevices;

@end

#endif


@interface DbyAudioDevice : NSObject

+ (DbyAudioDevice *)currentInputDevice;
+ (DbyAudioDevice *)currentOutputDevice;

+ (NSArray<DbyAudioDevice *> *)inputDevices;
+ (NSArray<DbyAudioDevice *> *)outputDevices;

+ (void)enumerateInputDevicesUsingBlock:(void (^)(DbyAudioDevice *device, BOOL *stop))block;
+ (void)enumerateOutputDevicesUsingBlock:(void (^)(DbyAudioDevice *device, BOOL *stop))block;
+ (void)enumerateDevicesUsingBlock:(void (^)(DbyAudioDevice *device, BOOL *stop))block;

+ (NSArray<DbyAudioDevice *> *)devices;

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
