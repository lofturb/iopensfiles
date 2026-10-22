#import <Foundation/Foundation.h>

// Papelera interna: los borrados del navegador se mueven aqui para poder
// deshacerlos. Nada se borra de verdad hasta vaciarla.
@interface IOTrash : NSObject

+ (instancetype)shared;

@property (nonatomic, readonly) NSString *directory;
@property (nonatomic, readonly) BOOL hasItems;
@property (nonatomic, readonly) NSUInteger count;

- (NSArray<NSString *> *)itemNames;
- (NSString *)originalPathForItemNamed:(NSString *)name;

- (BOOL)moveItemAtPath:(NSString *)path error:(NSError **)error;
- (BOOL)restoreItemNamed:(NSString *)name error:(NSError **)error;
- (BOOL)deleteItemNamed:(NSString *)name error:(NSError **)error;
- (BOOL)emptyWithError:(NSError **)error;

- (unsigned long long)totalSize;

@end
