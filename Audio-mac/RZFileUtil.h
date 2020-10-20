//
//  RZFileUtil.h
//  Pods
//
//  Created by yxibng on 2020/10/20.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RZFileInfo : NSObject
@property (nonatomic, copy, readonly) NSString *fileName;
//文件路径
@property (nonatomic, copy, readonly) NSString *filePath;
//文件大小 byte
@property (nonatomic, assign, readonly) NSUInteger fileSize;
//创建时间
@property (nonatomic, strong, readonly) NSDate *creationDate;
//上次修改时间
@property (nonatomic, strong, readonly) NSDate *latestModifyDate;

- (instancetype)initWithName:(NSString *)name dir:(NSString *)dir;

- (void)refreshInfo;

@end


@interface RZFileUtil : NSObject

+ (NSArray<RZFileInfo *> *)fileInfosInDir:(NSString *)dir;

+ (NSArray *)fileNamesInDir:(NSString *)dir;
+ (NSArray *)filePathsInDir:(NSString *)dir;

+ (NSDate *)creationDateOfFile:(NSString *)filePath;
+ (NSDate *)latestModifyDateOfPath:(NSString *)filePath;
+ (NSUInteger)sizeOfFile:(NSString *)filePath;

+ (NSString *)documentPath;



@end

NS_ASSUME_NONNULL_END
