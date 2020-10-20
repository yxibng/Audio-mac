//
//  RZFileUtil.m
//  Pods
//
//  Created by yxibng on 2020/10/20.
//

#import "RZFileUtil.h"

@implementation RZFileInfo
- (instancetype)initWithName:(NSString *)name dir:(NSString *)dir {
    if (self = [super init]) {
        _fileName = name;
        NSString *filePath = [dir stringByAppendingPathComponent:name];
        _filePath = filePath;
    }
    return self;
}

- (void)refreshInfo {
    NSDate *creationDate = [RZFileUtil creationDateOfFile:self.filePath];
    NSDate *latestModifyDate = [RZFileUtil latestModifyDateOfPath:self.filePath];
    NSUInteger size = [RZFileUtil sizeOfFile:self.filePath];
    
    _creationDate = creationDate;
    _latestModifyDate = latestModifyDate;
    _fileSize = size;
}

@end



@implementation RZFileUtil


+ (NSArray<RZFileInfo *> *)fileInfosInDir:(NSString *)dir {
    
    NSArray *fileNames = [self fileNamesInDir:dir];
    
    NSMutableArray *infos = @[].mutableCopy;
    
    for (NSString *name in fileNames) {
        RZFileInfo *info = [[RZFileInfo alloc] initWithName:name dir:dir];
        [infos addObject:info];
    }
    return infos;
}

+ (NSArray *)fileNamesInDir:(NSString *)dir {
    NSError *error;
    NSArray<NSString *> *fileNames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dir error:&error];
    if (error) {
        return @[];
    }
    return fileNames;
}

+ (NSArray *)filePathsInDir:(NSString *)dir {
    NSError *error;
    NSArray<NSString *> *fileNames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dir error:&error];
    if (error) {
        return @[];
    }
    NSMutableArray *filePaths = @[].mutableCopy;
    for (NSString *name in fileNames) {
        NSString *path = [dir stringByAppendingPathComponent:name];
        [filePaths addObject:path];
    }
    return filePaths;
}

+ (NSDate *)creationDateOfFile:(NSString *)filePath {
    NSDictionary *attr = [NSFileManager.defaultManager attributesOfItemAtPath:filePath error:nil];
    NSDate *date = [attr objectForKey:NSFileCreationDate];
    return date;
}

+ (NSDate *)latestModifyDateOfPath:(NSString *)filePath {
    NSDictionary *attr = [NSFileManager.defaultManager attributesOfItemAtPath:filePath error:nil];
    NSDate *date = [attr objectForKey:NSFileModificationDate];
    return date;
}

+ (NSUInteger)sizeOfFile:(NSString *)filePath {
    NSDictionary *attr = [NSFileManager.defaultManager attributesOfItemAtPath:filePath error:nil];
    NSNumber *size = [attr objectForKey:NSFileSize];
    return [size unsignedLongValue];
}

+ (NSString *)documentPath {
    return NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
}

@end
