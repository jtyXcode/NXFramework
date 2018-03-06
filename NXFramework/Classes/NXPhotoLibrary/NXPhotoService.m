//
//  NXPhotoService.m
//  NXFramework
//
//  Created by liuming on 2017/11/2.
//

#import "NXPhotoService.h"
#import "PHAsset+LivePhotoCovertToMP4.h"
#import "NSString+NXCategory.h"
typedef void (^requestVideoBlock)(NSURL* _Nullable url, NSError* _Nullable error);

#define PHKitExists \
([[[UIDevice currentDevice] systemVersion] compare:@"8.0" options:NSNumericSearch] != NSOrderedAscending)

@interface NXPhotoService()
@property(nonatomic, strong) NSOperationQueue *photoLibrayQueue;
@end
@implementation NXPhotoService

+ (instancetype)shareInstanced NS_AVAILABLE_IOS(8_0)
{
    static NXPhotoService *photo_service_obj = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        if (photo_service_obj == nil)
        {
            photo_service_obj = [[NXPhotoService alloc] init];
        }
    });
    return photo_service_obj;
}
- (instancetype)init
{
    self = [super init];
    if (self)
    {
        self.photoLibrayQueue = [[NSOperationQueue alloc] init];
        self.photoLibrayQueue.maxConcurrentOperationCount = 5;
    }
    return self;
}
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_8_0
+ (BOOL)hasAlbumAuthor NS_AVAILABLE_IOS(8_0)
{
    if (!PHKitExists)
    {
        return NO;
    }
    return ([self albumPermissonStatues] == PHAuthorizationStatusAuthorized);
}
+ (void)requestAuthor:(void (^)(BOOL hasAuthor))block NS_AVAILABLE_IOS(8_0)
{
    if (!PHKitExists)
    {
        block(NO);
        return;
    }
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
        
        NXAuthorizationStatus qy_status = [self tranformAuthorStatus:status];
        if (block)
        {
            block(qy_status == NXAuthorizationStatusAuthorized);
        }
    }];
}
+ (NXAuthorizationStatus)albumPermissonStatues NS_AVAILABLE_IOS(8_0)
{
    if (!PHKitExists)
    {
        return NXAuthorizationStatusDenied;
    }
    PHAuthorizationStatus ph_authorStatus = [PHPhotoLibrary authorizationStatus];
    return [self tranformAuthorStatus:ph_authorStatus];
}

+ (NXAuthorizationStatus)tranformAuthorStatus:(PHAuthorizationStatus)status NS_AVAILABLE_IOS(8_0)
{
    NXAuthorizationStatus authorStatus;
    switch (status)
    {
        case PHAuthorizationStatusDenied:
        {
            authorStatus = NXAuthorizationStatusDenied;
        }
            break;
        case PHAuthorizationStatusAuthorized:
        {
            authorStatus = NXAuthorizationStatusAuthorized;
        }
            break;
        case PHAuthorizationStatusRestricted:
        {
            authorStatus = NXAuthorizationStatusRestricted;
        }
            break;
        case PHAuthorizationStatusNotDetermined:
        {
            authorStatus = NXAuthorizationStatusNotDetermined;
        }
            break;
        default:
        {
            authorStatus = NXAuthorizationStatusNotDetermined;
        }
            break;
    }
    return authorStatus;
}
- (void)fetchAllGroupsWithType:(NXPhotoLibarayAssertType)type completion:(fetchAlbumCompletion)completion NS_AVAILABLE_IOS(8_0)
{
    if (!PHKitExists)
    {
        completion(@[]);
        return;
    }
    [self.photoLibrayQueue addOperationWithBlock:^{
        
        NSMutableArray *photoGroups = [[NSMutableArray alloc] init];
        NSArray *allAlbums = [self AllGroupAlbums];
        
        for (PHFetchResult *album in allAlbums)
        {
            [album enumerateObjectsUsingBlock:^(id _Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
                
                if (![obj isKindOfClass:[PHAssetCollection class]]) return;
                PHAssetCollection *collection = (PHAssetCollection *)obj;
                //过滤最近删除
                if (collection.assetCollectionSubtype > 213) return;
                
                NSArray *assetArray = [self fetchAssetWithCollection:collection withFetchType:type];
                if (assetArray.count <= 0)
                {
                    return;
                }
                if (collection.localizedTitle.length > 0)
                {
                    NXGroupModel *groupModel = [[NXGroupModel alloc] init];
                    groupModel.collection = collection;
                    NSLog(@"%@", collection.localizedTitle);
                    groupModel.count = assetArray.count;
                    if (collection.assetCollectionType == PHAssetCollectionTypeSmartAlbum &&
                        collection.assetCollectionSubtype == PHAssetCollectionSubtypeSmartAlbumUserLibrary)
                    {
                        if (photoGroups.count <= 0)
                        {
                            [photoGroups addObject:groupModel];
                        }
                        else
                        {
                            [photoGroups insertObject:groupModel atIndex:0];
                        }
                    }
                    else
                    {
                        [photoGroups addObject:groupModel];
                    }
                    groupModel.asstArray = [[NSMutableArray alloc] initWithArray:assetArray];
                }
            }];
        }
        
        if (completion)
        {
            [self runMainThread:^{
                
                completion([[NSArray alloc] initWithArray:photoGroups]);
            }];
        }
    }];
}
- (void)fetchAllGroupsWithcompletion:(fetchAlbumCompletion)completion NS_AVAILABLE_IOS(8_0)
{
    [self fetchAllGroupsWithType:NXPhotoLibarayAssertTypeAll completion:completion];
}

- (void)fetchCameraRollAlbumListWithType:(NXPhotoLibarayAssertType)type completion:(fetchAlbumCompletion)completion NS_AVAILABLE_IOS(8_0)
{
    if (!PHKitExists)
    {
        completion(@[]);
    }
    [self.photoLibrayQueue addOperationWithBlock:^{
        
        PHFetchResult<PHAssetCollection *> *smartAlbums =
        [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum
                                                 subtype:PHAssetCollectionSubtypeAlbumRegular
                                                 options:nil];
        
        NSMutableArray *groups = [[NSMutableArray alloc] init];
        [smartAlbums
         enumerateObjectsUsingBlock:^(PHAssetCollection *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
             
             if (![obj isKindOfClass:[PHAssetCollection class]]) return;
             
             NXGroupModel *groupModel = [[NXGroupModel alloc] init];
             
             groupModel.collection = obj;
             
             if (obj.assetCollectionSubtype == PHAssetCollectionSubtypeSmartAlbumUserLibrary)
             {
                 if (obj.localizedTitle.length > 0)
                 {
                     NSArray *medias = [self fetchAssetWithCollection:obj withFetchType:type];
                     groupModel.asstArray = [[NSMutableArray alloc] initWithArray:medias];
                     groupModel.count = medias.count;
                     [groups addObject:groupModel];
                 }
             }
         }];
        
        if (completion)
        {
            [self runMainThread:^{
                
                completion(groups);
            }];
        }
    }];
}
- (NSArray *)fetchAssetWithCollection:(PHAssetCollection *)collection withFetchType:(NXPhotoLibarayAssertType)type NS_AVAILABLE_IOS(8_0)
{
    PHFetchOptions *fectchOptions = [self getFetchOptionWithType:type];
    return [self fectchAssetWithCollection:collection withOptions:fectchOptions];
}

- (NSArray *)fectchAssetWithCollection:(PHAssetCollection *)collection withOptions:(PHFetchOptions *)options NS_AVAILABLE_IOS(8_0)
{
    if (!PHKitExists)
    {
        return @[];
    }
    NSMutableArray *assetArray = [[NSMutableArray alloc] init];
    if (collection)
    {
        PHFetchResult<PHAsset *> *result = [PHAsset fetchAssetsInAssetCollection:collection options:options];
        if (result.count > 0)
        {
            [result enumerateObjectsUsingBlock:^(PHAsset *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
                
                if ([obj isKindOfClass:[PHAsset class]])
                {
                    if (obj.mediaType == PHAssetMediaTypeUnknown)
                    {
                        NSLog(@" ---- 图片不支持");
                    }
                    NXAssetModel *assetModel = [[NXAssetModel alloc] initWithAsset:obj];
                    [assetArray addObject:assetModel];
                }
            }];
        }
    }
    return [[NSArray alloc] initWithArray:assetArray];
}

- (NSArray *)AllGroupAlbums NS_AVAILABLE_IOS(8_0)
{
    if (!PHKitExists)
    {
        return @[];
    }
    PHFetchResult *smartAlbums = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum
                                                                          subtype:PHAssetCollectionSubtypeAny
                                                                          options:nil];
    // 我的照片流 1.6.10重新加入..
    PHFetchResult *myPhotoStreamAlbum =
    [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeAlbum
                                             subtype:PHAssetCollectionSubtypeAlbumMyPhotoStream
                                             options:nil];
    
    //用户导入的相册
    PHFetchResult *facesAlbums =
    [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeAlbum
                                             subtype:PHAssetCollectionSubtypeAlbumSyncedAlbum
                                             options:nil];
    //用户自定义相册
    PHFetchResult *topLevelUserCollections = [PHCollectionList fetchTopLevelUserCollectionsWithOptions:nil];
    NSArray *allAlbums = @[ smartAlbums, myPhotoStreamAlbum, topLevelUserCollections, facesAlbums ];
    return allAlbums;
}

- (PHFetchOptions *)getFetchOptionWithType:(NXPhotoLibarayAssertType)type NS_AVAILABLE_IOS(8_0)
{
    if (!PHKitExists)
    {
        return nil;
    }
    PHFetchOptions *options = [[PHFetchOptions alloc] init];
    switch (type)
    {
        case NXPhotoLibarayAssertTypeAll:
        {
            options.predicate = [NSPredicate
                                 predicateWithFormat:@"mediaType = %d or mediaType = %d", PHAssetMediaTypeImage, PHAssetMediaTypeVideo];
        }
            break;
        case NXPhotoLibarayAssertTypePhotos:
        {
            options.predicate = [NSPredicate predicateWithFormat:@"mediaType = %d", PHAssetMediaTypeImage];
        }
            break;
        case NXPhotoLibarayAssertTypeVideo:
        {
            options.predicate = [NSPredicate predicateWithFormat:@"mediaType = %d", PHAssetMediaTypeVideo];
        }
            break;
        case NXPhotoLibarayAssertTypePanoramas:
        {
            options.predicate =
            [NSPredicate predicateWithFormat:@"mediaType = %d and mediaSubtype == %d", PHAssetMediaTypeImage,
             PHAssetMediaSubtypePhotoPanorama];
        }
            break;
        case NXPhotoLibarayAssertTypeLivePhoto:
        {
#if __IPHONE_OS_VERSION_MAX_ALLOWED > 100300
            if (@available(iOS 9.1, *)) {
                options.predicate =
                [NSPredicate predicateWithFormat:@"mediaType = %d and mediaSubtype == %d", PHAssetMediaTypeImage,
                 PHAssetMediaSubtypePhotoLive];
            } else {
                // Fallback on earlier versions
                options.predicate = [NSPredicate predicateWithFormat:@"mediaType = %d", PHAssetMediaTypeImage];
            }
            
#else
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 90100
            float version = [[[UIDevice currentDevice] systemVersion] floatValue];
            if (version > 9.0)
            {
                options.predicate =
                [NSPredicate predicateWithFormat:@"mediaType = %d and mediaSubtype == %d", PHAssetMediaTypeImage,
                 PHAssetMediaSubtypePhotoLive];
            } else{
                
                 options.predicate = [NSPredicate predicateWithFormat:@"mediaType = %d", PHAssetMediaTypeImage];
            }
#else
            options.predicate = [NSPredicate predicateWithFormat:@"mediaType = %d", PHAssetMediaTypeImage];
#endif
#endif

        }
            break;
        case NXPhotoLibarayAssertTypeLivePhotoAndVideos:
        {
#if __IPHONE_OS_VERSION_MAX_ALLOWED > 100300
            if (@available(iOS 9.1, *)) {
                options.predicate =
                [NSPredicate predicateWithFormat:@"(mediaType = %d and mediaSubtype == %d) or mediaType = %d ", PHAssetMediaTypeImage,
                 PHAssetMediaSubtypePhotoLive,PHAssetMediaTypeVideo];
            } else {
                // Fallback on earlier versions
                    options.predicate = [NSPredicate predicateWithFormat:@"mediaType = %d", PHAssetMediaTypeVideo];
            }
            
#else
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 90100
            
            float version = [[[UIDevice currentDevice] systemVersion] floatValue];
            if (version > 9.0)
            {
                options.predicate =
                [NSPredicate predicateWithFormat:@"(mediaType = %d and mediaSubtype == %d) or mediaType = %d ", PHAssetMediaTypeImage,
                 PHAssetMediaSubtypePhotoLive,PHAssetMediaTypeVideo];
            }else {
                
                options.predicate = [NSPredicate predicateWithFormat:@"mediaType = %d", PHAssetMediaTypeImage];
            }
#else
            options.predicate = [NSPredicate predicateWithFormat:@"mediaType = %d", PHAssetMediaTypeImage];
#endif
#endif
        }
            break;
        default:
            break;
    }
    return options;
}
#pragma mark - 获取照片

- (PHImageRequestID)requestOriginalImageForAsset:(NXAssetModel *)asset
                                         success:(requestImagSuccessBlock)success
                                         failure:(requestFailBlock)failure
                                   progressBlock:(downloadProgressBlock)progressBlock NS_AVAILABLE_IOS(8_0)
{
    
    return [self requestOriginalImageForAsset:asset completion:^(UIImage * _Nullable image)
    {
        [self nx_handlerRequestImage:image success:success failure:failure];

    } progressBlock:^(double progress, NSError * _Nullable error, BOOL * _Nonnull stop, NSDictionary * _Nullable info) {
        
         [self nx_handlerRequestImageProgress:progress error:error progressBlock:progressBlock failure:failure];
    }];
}

- (PHImageRequestID)requestOriginalImageForAsset:(NXAssetModel *)asset
                                      completion:(requestImagSuccessBlock)completion
                                   progressBlock:(PHAssetImageProgressHandler)progressBlock NS_AVAILABLE_IOS(8_0)
{
    if (!PHKitExists)
    {
        return -1;
    }
    PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
    [options setDeliveryMode:PHImageRequestOptionsDeliveryModeHighQualityFormat];
    [options setResizeMode:PHImageRequestOptionsResizeModeExact];
    options.networkAccessAllowed = YES;
    options.progressHandler =
    ^(double progress, NSError *_Nullable error, BOOL *_Nonnull stop, NSDictionary *_Nullable info) {
        
        if (progressBlock)
        {
            [self runMainThread:^{
                progressBlock(progress, error,stop,info);
            }];
        }
    };
    
    return [[PHCachingImageManager defaultManager]
            requestImageDataForAsset:asset.asset
            options:options
            resultHandler:^(NSData *_Nullable imageData, NSString *_Nullable dataUTI,
                            UIImageOrientation orientation, NSDictionary *_Nullable info) {
                
                BOOL downloadFinined = ![[info objectForKey:PHImageCancelledKey] boolValue] &&
                ![info objectForKey:PHImageErrorKey] &&
                ![[info objectForKey:PHImageResultIsDegradedKey] boolValue];
                
                if (downloadFinined)
                {
                    if (completion)
                    {
                        [self runMainThread:^{
                            
                            completion([UIImage imageWithData:imageData]);
                        }];
                    }
                }
                else
                {
                    if ([[info objectForKey:PHImageCancelledKey] boolValue])
                    {
                        // PHImageCancelledKey 对应的值为真时代表用户手动取消云端下载
                        NSLog(@"PHImageCancelledKey 对应的值为真时代表用户手动取消云端下载");
                        return;
                    }
                    if (![[info objectForKey:PHImageResultIsDegradedKey] boolValue])
                    {
                        if ([info[PHImageResultIsInCloudKey] integerValue] == 1)
                        {
                            //下载失败
                            if (completion)
                            {
                                [self runMainThread:^{
                                    completion(nil);
                                    
                                }];
                            }
                        }
                        else
                        {
                            if (completion)
                            {
                                [self runMainThread:^{
                                    
                                    completion([UIImage imageWithData:imageData]);
                                }];
                            }
                        }
                    }
                }
            }];
}

- (PHImageRequestID)requestImageForAsset:(NXAssetModel *)asset
                                    size:(CGSize)size
                                 success:(requestImagSuccessBlock)success
                                 failure:(requestFailBlock)failure
                           progressBlock:(downloadProgressBlock)progressBlock NS_AVAILABLE_IOS(8_0)
{
    
    return [self requestImageForAsset:asset size:size completion:^(UIImage * _Nullable image) {
        
        [self nx_handlerRequestImage:image success:success failure:failure];
        
    } progressBlock:^(double progress, NSError * _Nullable error, BOOL * _Nonnull stop, NSDictionary * _Nullable info) {
        
        [self nx_handlerRequestImageProgress:progress error:error progressBlock:progressBlock failure:failure];
    }];
}
/**
 * @brief 根据传入size获取图片
 */
- (PHImageRequestID)requestImageForAsset:(NXAssetModel *)asset
                                    size:(CGSize)size
                              completion:(requestImagSuccessBlock)completion
                           progressBlock:(PHAssetImageProgressHandler)progressBlock NS_AVAILABLE_IOS(8_0)
{
    if (!PHKitExists)
    {
        return -1;
    }
    PHImageRequestOptions *option = [[PHImageRequestOptions alloc] init];
    option.resizeMode = PHImageRequestOptionsResizeModeFast;
    option.networkAccessAllowed = YES;
    option.progressHandler =
    ^(double progress, NSError *_Nullable error, BOOL *_Nonnull stop, NSDictionary *_Nullable info) {
        if (progressBlock)
        {
            [self runMainThread:^{
                
                progressBlock(progress, error,stop,info);
            }];
        }
    };
    
    return [self requestImageForAsset:asset.asset
                                 size:size
                           completion:^(UIImage *image, NSDictionary *info) {
                               
                               BOOL downloadFinined = ![[info objectForKey:PHImageCancelledKey] boolValue] &&
                               ![info objectForKey:PHImageErrorKey] && ![[info objectForKey:PHImageResultIsDegradedKey] boolValue];
                               //不要该判断，即如果该图片在iCloud上时候，会先显示一张模糊的预览图，待加载完毕后会显示高清图
                               // && ![[info objectForKey:PHImageResultIsDegradedKey] boolValue]
                               if (downloadFinined && completion)
                               {
                                   [self runMainThread:^{
                                       
                                       completion(image);
                                   }];
                               }
                           }];
}
/**
 * @brief 获取原图
 */
- (PHImageRequestID)requestOriginalImageForAsset:(PHAsset *)asset
                                      completion:(void (^)(UIImage *, NSDictionary *))completion NS_AVAILABLE_IOS(8_0)
{
    return [self requestImageForAsset:asset
                                 size:CGSizeMake(asset.pixelWidth, asset.pixelHeight)
                           resizeMode:PHImageRequestOptionsResizeModeNone
                           completion:completion];
}

- (PHImageRequestID)requestImageForAsset:(PHAsset *)asset
                                    size:(CGSize)size
                              completion:(void (^)(UIImage *, NSDictionary *))completion NS_AVAILABLE_IOS(8_0)
{
    return [self requestImageForAsset:asset
                                 size:size
                           resizeMode:PHImageRequestOptionsResizeModeFast
                           completion:completion];
}

- (PHImageRequestID)requestImageForAsset:(PHAsset *)asset
                                    size:(CGSize)size
                              resizeMode:(PHImageRequestOptionsResizeMode)resizeMode
                              completion:(void (^)(UIImage *, NSDictionary *))completion NS_AVAILABLE_IOS(8_0)
{
    if (!PHKitExists)
    {
        return -1;
    }
    PHImageRequestOptions *option = [[PHImageRequestOptions alloc] init];
    /**
     resizeMode：对请求的图像怎样缩放。有三种选择：None，默认加载方式；Fast，尽快地提供接近或稍微大于要求的尺寸；Exact，精准提供要求的尺寸。
     deliveryMode：图像质量。有三种值：Opportunistic，在速度与质量中均衡；HighQualityFormat，不管花费多长时间，提供高质量图像；FastFormat，以最快速度提供好的质量。
     这个属性只有在 synchronous 为 true 时有效。
     */
    option.resizeMode = resizeMode;  //控制照片尺寸
    //    option.deliveryMode = PHImageRequestOptionsDeliveryModeOpportunistic;//控制照片质量
    option.networkAccessAllowed = YES;
    
    /*
     info字典提供请求状态信息:
     PHImageResultIsInCloudKey：图像是否必须从iCloud请求
     PHImageResultIsDegradedKey：当前UIImage是否是低质量的，这个可以实现给用户先显示一个预览图
     PHImageResultRequestIDKey和PHImageCancelledKey：请求ID以及请求是否已经被取消
     PHImageErrorKey：如果没有图像，字典内的错误信息
     */
    return [self requestImageForAsset:asset size:size options:option completion:completion];
}

- (PHImageRequestID)requestImageForAsset:(PHAsset *)asset
                                    size:(CGSize)size
                                 options:(PHImageRequestOptions *)options
                              completion:(void (^)(UIImage *, NSDictionary *))completion NS_AVAILABLE_IOS(8_0)
{
    if (!PHKitExists)
    {
        return -1;
    }
    return [[PHCachingImageManager defaultManager]
            requestImageForAsset:asset
            targetSize:size
            contentMode:PHImageContentModeAspectFill
            options:options
            resultHandler:^(UIImage *_Nullable image, NSDictionary *_Nullable info) {
                BOOL downloadFinined =
                ![[info objectForKey:PHImageCancelledKey] boolValue] && ![info objectForKey:PHImageErrorKey];
                //不要该判断，即如果该图片在iCloud上时候，会先显示一张模糊的预览图，待加载完毕后会显示高清图
                // && ![[info objectForKey:PHImageResultIsDegradedKey] boolValue]
                if (downloadFinined && completion)
                {
                    completion(image, info);
                }
            }];
}
#pragma mark - 导出视频

- (PHImageRequestID)requestVideoWithAsset:(NXAssetModel *)asset
                                  success:(requestVideoSucces)success
                                  failure:(requestFailBlock)failure
                                 progress:(downloadProgressBlock)progressHandler NS_AVAILABLE_IOS(8_0){
    
    return [self requestVideoWithAsset:asset finish:^(NSURL * _Nullable url, NSError * _Nullable error)
    {
        [self nx_handlerRequestVideo:url error:error sucess:success failure:failure];
        
    } progress:^(double progress, NSError * _Nullable error, BOOL * _Nonnull stop, NSDictionary * _Nullable info) {
    
            [self nx_handlerRequestImageProgress:progress error:error progressBlock:progressHandler failure:failure];

    }];
}

- (PHImageRequestID)requestVideoWithAsset:(NXAssetModel *)asset
                                   finish:(requestVideoBlock)finishBlock
                                 progress:(PHAssetVideoProgressHandler)progressHandler NS_AVAILABLE_IOS(8_0)
{
    if (!PHKitExists)
    {
        return -1;
    }
    PHVideoRequestOptions *options = [[PHVideoRequestOptions alloc] init];
    options.networkAccessAllowed = YES;
    options.deliveryMode = PHVideoRequestOptionsDeliveryModeMediumQualityFormat;
    options.version = PHVideoRequestOptionsVersionCurrent;
    if (progressHandler)
    {
        options.progressHandler =
        ^(double progress, NSError *_Nullable error, BOOL *_Nonnull stop, NSDictionary *_Nullable info) {
            
            [self runMainThread:^{
                
                progressHandler(progress, error,stop,info);
            }];
        };
    }
    return [self requestVideoWithiAsset:asset.asset
                                options:options
                                 finish:^(NSURL *videoPath, NSError *error) {
                                     
                                     if (finishBlock)
                                     {
                                         [self runMainThread:^{
                                             finishBlock(videoPath, error);
                                         }];
                                     }
                                 }];
}

- (PHImageRequestID)requestVideoWithiAsset:(PHAsset *)asset
                                   options:(PHVideoRequestOptions *)options
                                    finish:(void (^)(NSURL *videoPath, NSError *error))finishBlock NS_AVAILABLE_IOS(8_0)
{
    if (!PHKitExists)
    {
        return -1;
    }
    __weak typeof(self) weakSelf = self;
    PHImageManager *imageManager = [PHImageManager defaultManager];
    PHImageRequestID requestId = [imageManager
                                  requestAVAssetForVideo:asset
                                  options:options
                                  resultHandler:^(AVAsset *_Nullable asset, AVAudioMix *_Nullable audioMix,
                                                  NSDictionary *_Nullable info) {
                                      
                                      __strong typeof(weakSelf) strongSelf = weakSelf;
                                      NSLog(@"video info = %@", info);
                                      
                                      if ([[info objectForKey:PHImageCancelledKey] boolValue])
                                      {
                                          // PHImageCancelledKey 对应的值为真时代表用户手动取消云端下载
                                          NSLog(@"PHImageCancelledKey 对应的值为真时代表用户手动取消云端下载");
                                          return;
                                      }
                                      
                                      if ([asset isKindOfClass:[AVURLAsset class]])
                                      {
                                          NSURL *URL = [((AVURLAsset *)asset)URL];
                                          if (finishBlock)
                                          {
                                              finishBlock(URL, nil);
                                          }
                                      }
                                      else if ([asset isKindOfClass:[AVComposition class]])
                                      {
                                          //慢动作处理
                                          NSString *fileName =
                                          [NSString stringWithFormat:@"mergeSlowMoVideo_%lld.mov",
                                           (long long)[[NSDate date] timeIntervalSince1970]];
                                          NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(
                                                                                                              NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
                                          NSString *myPathDocs = [documentsDirectory stringByAppendingPathComponent:fileName];
                                          NSURL *url = [NSURL fileURLWithPath:myPathDocs];
                                          
                                          [strongSelf exportVideoWithComposition:asset
                                                                         fileUrl:url
                                                                      completion:^(NSURL *url, NSError *error) {
                                                                          
                                                                          if (finishBlock)
                                                                          {
                                                                              finishBlock(url, error);
                                                                          }
                                                                      }];
                                      }
                                  }];
    return requestId;
}

- (void)requestVideoWithLivePhoto:(NXAssetModel *)assetModel succes:(requestVideoSucces)success failure:(requestFailBlock) failure NS_AVAILABLE_IOS(9_0){
    
    [self requestVideoWithLivePhoto:assetModel finish:^(NSURL * _Nullable url, NSError * _Nullable error) {
            
        [self nx_handlerRequestVideo:url error:error sucess:success failure:false];
    }];
}

- (void)requestVideoWithLivePhoto:(NXAssetModel *)assetModel finish:(requestVideoBlock)finishBlock NS_AVAILABLE_IOS(9_0)
{
    __weak typeof(self) weakSelf = self;
    if (assetModel.medaiType == NXPhotoAssetTypeLiviePhoto)
    {
        [assetModel.asset getLivePhotoOfMP4Data:^(NSData *data, NSString *filePath, UIImage *coverImage,NSError * error) {
            if (finishBlock) {
                
                [weakSelf runMainThread:^{
                    if (!error)
                    {
                        if (filePath.length > 0) {
                            
                            NSURL * videoUrl = [NSURL fileURLWithPath:filePath];
                            finishBlock(videoUrl,nil);
                            
                        } else {
                            
                            NSError * error = [NSError errorWithDomain:@"live photo 导出路径异常" code:-10005 userInfo:@{@"error":@"live photo 导出路径异常"}];
                            finishBlock(nil,error);
                        }
                     
                    } else {
                        
                        finishBlock(nil,error);
                    }
                }];
            }
        }];
    }
}
#pragma mark - 视频/图片元素的 save

- (void)saveImageToAblum:(UIImage *)image
         customAlbumName:(NSString *)cAlbumName
              completion:(void (^)(BOOL, NXAssetModel *))completion NS_AVAILABLE_IOS(8_0)
{
    if (!PHKitExists)
    {
        return;
    }
    void (^block)(BOOL suc, NXAssetModel *asset) = ^(BOOL suc, NXAssetModel *asset) {
        
        if (completion)
        {
            [self runMainThread:^{
                
                completion(suc, asset);
            }];
        }
    };
    PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
    if (status == PHAuthorizationStatusDenied)
    {
        block(NO, nil);
    }
    else if (status == PHAuthorizationStatusRestricted)
    {
        block(NO, nil);
    }
    else
    {
        __block PHObjectPlaceholder *placeholderAsset = nil;
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            PHAssetChangeRequest *newAssetRequest = [PHAssetChangeRequest creationRequestForAssetFromImage:image];
            placeholderAsset = newAssetRequest.placeholderForCreatedAsset;
        }
                                          completionHandler:^(BOOL success, NSError *_Nullable error) {
                                              if (!success)
                                              {
                                                  block(NO, nil);
                                                  return;
                                              }
                                              PHAsset *asset = [self getAssetFromlocalIdentifier:placeholderAsset.localIdentifier];
                                              NXAssetModel *model = [[NXAssetModel alloc] initWithAsset:asset];
                                              if (cAlbumName != nil)
                                              {
                                                  PHAssetCollection *desCollection = [self getDestinationCollectionWithName:cAlbumName];
                                                  if (!desCollection) block(NO, nil);
                                                  
                                                  [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                                                      [[PHAssetCollectionChangeRequest changeRequestForAssetCollection:desCollection]
                                                       addAssets:@[ asset ]];
                                                  }
                                                                                    completionHandler:^(BOOL success, NSError *_Nullable error) {
                                                                                        
                                                                                        block(success, model);
                                                                                    }];
                                              }
                                              else
                                              {
                                                  block(success, model);
                                              }
                                          }];
    }
}

- (void)saveImageToAblum:(UIImage *)image completion:(void (^)(BOOL, NXAssetModel *))completion NS_AVAILABLE_IOS(8_0)
{
    [self saveImageToAblum:image customAlbumName:nil completion:completion];
}

- (void)saveVideoToAblum:(NSURL *)url
         customAlbumName:(NSString *)cAlbumName
              completion:(void (^)(BOOL, NXAssetModel *))completion NS_AVAILABLE_IOS(8_0)
{
    if (!PHKitExists)
    {
        return;
    }
    void (^block)(BOOL suc, PHAsset *asset) = ^(BOOL suc, PHAsset *asset) {
        
        if (completion)
        {
            [self runMainThread:^{
                
                NXAssetModel *assetModel = [[NXAssetModel alloc] initWithAsset:asset];
                completion(suc, assetModel);
            }];
        }
    };
    
    PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
    if (status == PHAuthorizationStatusDenied)
    {
        block(NO, nil);
    }
    else if (status == PHAuthorizationStatusRestricted)
    {
        block(NO, nil);
    }
    else
    {
        __block PHObjectPlaceholder *placeholderAsset = nil;
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            PHAssetChangeRequest *newAssetRequest =
            [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:url];
            placeholderAsset = newAssetRequest.placeholderForCreatedAsset;
        }
                                          completionHandler:^(BOOL success, NSError *_Nullable error) {
                                              if (!success)
                                              {
                                                  block(NO, nil);
                                                  return;
                                              }
                                              PHAsset *asset = [self getAssetFromlocalIdentifier:placeholderAsset.localIdentifier];
                                              if (cAlbumName != nil)
                                              {
                                                  PHAssetCollection *desCollection = [self getDestinationCollectionWithName:cAlbumName];
                                                  if (!desCollection) completion(NO, nil);
                                                  
                                                  [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                                                      [[PHAssetCollectionChangeRequest changeRequestForAssetCollection:desCollection]
                                                       addAssets:@[ asset ]];
                                                  }
                                                                                    completionHandler:^(BOOL success, NSError *_Nullable error) {
                                                                                        
                                                                                        block(success, asset);
                                                                                        
                                                                                    }];
                                              }
                                              else
                                              {
                                                  block(success, asset);
                                              }
                                          }];
    }
}
- (void)saveVideoToAblum:(NSURL *)url completion:(void (^)(BOOL, NXAssetModel *))completion NS_AVAILABLE_IOS(8_0)
{
    [self saveVideoToAblum:url customAlbumName:nil completion:completion];
}

- (void)saveImageToAlblm:(NSURL *)gifUrl
         customAlbumName:(NSString *)cAlbumName
              completion:(void (^)(BOOL, NXAssetModel *))completion
{
    if (!PHKitExists)
    {
        return;
    }
    void (^block)(BOOL suc, PHAsset *asset) = ^(BOOL suc, PHAsset *asset) {
        
        if (completion)
        {
            [self runMainThread:^{
                
                NXAssetModel *assetModel = [[NXAssetModel alloc] initWithAsset:asset];
                completion(suc, assetModel);
            }];
        }
    };
    
    PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
    if (status == PHAuthorizationStatusDenied)
    {
        block(NO, nil);
    }
    else if (status == PHAuthorizationStatusRestricted)
    {
        block(NO, nil);
    }
    else
    {
        __block PHObjectPlaceholder *placeholderAsset = nil;
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            PHAssetChangeRequest *newAssetRequest =
            [PHAssetChangeRequest creationRequestForAssetFromImageAtFileURL:gifUrl];
            placeholderAsset = newAssetRequest.placeholderForCreatedAsset;
        }
                                          completionHandler:^(BOOL success, NSError *_Nullable error) {
                                              if (!success)
                                              {
                                                  block(NO, nil);
                                                  return;
                                              }
                                              PHAsset *asset = [self getAssetFromlocalIdentifier:placeholderAsset.localIdentifier];
                                              if (cAlbumName != nil)
                                              {
                                                  PHAssetCollection *desCollection = [self getDestinationCollectionWithName:cAlbumName];
                                                 if (!desCollection) block(NO, nil);
                                                  
                                                  [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                                                      [[PHAssetCollectionChangeRequest changeRequestForAssetCollection:desCollection]
                                                       addAssets:@[ asset ]];
                                                  }
                                                                                    completionHandler:^(BOOL success, NSError *_Nullable error) {
                                                                                        block(success, asset);
                                                                                    }];
                                              }
                                              else
                                              {
                                                  block(success, asset);
                                              }
                                          }];
    }
}

- (PHAsset *)getAssetFromlocalIdentifier:(NSString *)localIdentifier NS_AVAILABLE_IOS(8_0)
{
    if (!PHKitExists)
    {
        return nil;
    }
    if (localIdentifier == nil)
    {
        NSLog(@"Cannot get asset from localID because it is nil");
        return nil;
    }
    PHFetchResult *result = [PHAsset fetchAssetsWithLocalIdentifiers:@[ localIdentifier ] options:nil];
    if (result.count)
    {
        return result[0];
    }
    return nil;
}

//获取自定义相册
- (PHAssetCollection *)getDestinationCollectionWithName:(NSString *)collectionName NS_AVAILABLE_IOS(8_0)
{
    if (collectionName == nil || !PHKitExists)
    {
        return nil;
    }
    //找是否已经创建自定义相册
    PHFetchResult<PHAssetCollection *> *collectionResult =
    [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeAlbum
                                             subtype:PHAssetCollectionSubtypeAlbumRegular
                                             options:nil];
    for (PHAssetCollection *collection in collectionResult)
    {
        if ([collection.localizedTitle isEqualToString:collectionName])
        {
            return collection;
        }
    }
    //新建自定义相册
    __block NSString *collectionId = nil;
    NSError *error = nil;
    [[PHPhotoLibrary sharedPhotoLibrary] performChangesAndWait:^{
        collectionId = [PHAssetCollectionChangeRequest creationRequestForAssetCollectionWithTitle:collectionName]
        .placeholderForCreatedAssetCollection.localIdentifier;
    }
                                                         error:&error];
    if (error)
    {
        NSLog(@"创建相册：%@失败", collectionName);
        return nil;
    }
    return [PHAssetCollection fetchAssetCollectionsWithLocalIdentifiers:@[ collectionId ] options:nil].lastObject;
}

- (void)deleteMedaiWithAsset:(PHAsset *)asset
        withCunstomAlubmName:(NSString *)albumName
                  completion:(deleteAssetCompletionBlock)completion NS_AVAILABLE_IOS(8_0)
{
    if (!PHKitExists)
    {
        return;
    }
    
    void (^block)(BOOL suc, NSError *error) = ^(BOOL suc, NSError *error) {
        
        if (completion)
        {
            [self runMainThread:^{
                
                completion(suc, error);
            }];
        }
    };
    
    if (asset)
    {
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            
            [PHAssetChangeRequest deleteAssets:@[ asset ]];
            
        }
                                          completionHandler:^(BOOL success, NSError *_Nullable error) {
                                              
                                              if (albumName != nil)
                                              {
                                                  PHAssetCollection *desCollection = [self getDestinationCollectionWithName:albumName];
                                                if (!desCollection)  block(NO, nil);
                                                  
                                                  [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                                                      [[PHAssetCollectionChangeRequest changeRequestForAssetCollection:desCollection]
                                                       addAssets:@[ asset ]];
                                                  }
                                                                                    completionHandler:^(BOOL success, NSError *_Nullable error) {
                                                                                        block(success, error);
                                                                                    }];
                                              }
                                              else
                                              {
                                                  block(success, error);
                                              }
                                              
                                          }];
    }
    else
    {
        NSError *error =
        [NSError errorWithDomain:@"相册元素不存在" code:0 userInfo:@{
                                                              @"errorKey" : @"asset is nill"
                                                              }];
        block(NO, error);
    }
}

- (void)deleteMedaiWithAsset:(NXAssetModel *)asset completion:(deleteAssetCompletionBlock)completion NS_AVAILABLE_IOS(8_0)
{
    [self deleteMedaiWithAsset:asset completion:completion];
}
#pragma mark 导出视频
- (void)exportVideoWithComposition:(AVAsset *)asset
                           fileUrl:(NSURL *)fileUrl
                        completion:(void (^)(NSURL *url, NSError *error))completion NS_AVAILABLE_IOS(8_0)
{
    AVAssetExportSession *exporter =
    [[AVAssetExportSession alloc] initWithAsset:asset presetName:AVAssetExportPresetHighestQuality];
    exporter.outputURL = fileUrl;
    exporter.outputFileType = AVFileTypeQuickTimeMovie;
    exporter.shouldOptimizeForNetworkUse = YES;
    [exporter exportAsynchronouslyWithCompletionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            if (exporter.status == AVAssetExportSessionStatusCompleted)
            {
                NSURL *URL = exporter.outputURL;
                if (completion)
                {
                    completion(URL, nil);
                }
            }
            else
            {
                if (completion)
                {
                    completion(nil, exporter.error);
                }
            }
        });
    }];
}

- (void)runMainThread:(void (^)(void))block
{
    if ([NSThread isMainThread])
    {
        block();
    }
    else
    {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

- (void)cancelRequestID:(PHImageRequestID)requestId NS_AVAILABLE_IOS(8_0)
{
    if (!PHKitExists)
    {
        return;
    }
    [[PHCachingImageManager defaultManager] cancelImageRequest:requestId];
}

#pragma mark - 注册/移除 PHLibrary Observer
- (void)registerObserver:(id<PHPhotoLibraryChangeObserver>)observer NS_AVAILABLE_IOS(8_0)
{
    if (!PHKitExists || observer == nil)
    {
        return;
    }
    [[PHPhotoLibrary sharedPhotoLibrary] registerChangeObserver:observer];
}
- (void)removeRegisterObserver:(id<PHPhotoLibraryChangeObserver>)observer NS_AVAILABLE_IOS(8_0)
{
    if (!PHKitExists || observer == nil)
    {
        return;
    }
    [[PHPhotoLibrary sharedPhotoLibrary] unregisterChangeObserver:observer];
}

#pragma mark - 处理导出视频、照片的回调
-(void)nx_handlerRequestImage:(UIImage *) image success:(requestImagSuccessBlock)success failure:(requestFailBlock)failure NS_AVAILABLE_IOS(8_0)
{
    
    if (image)
    {
        if (success)
        {
            success(image);
        }
    } else {
        NSLog(@"图片获取失败");
        NSError * error = [NSError errorWithDomain:@"获取图片失败" code:-10004 userInfo:@{@"errorInfo":@"获取目标图片失败"}];
        if (failure)
        {
            failure(error);
        }
    }
}
- (void)nx_handlerRequestVideo:(NSURL *)url error:(NSError *)error sucess:(requestVideoSucces)success failure:(requestFailBlock) failureBlock NS_AVAILABLE_IOS(8_0)
{
    
    if (error) {
        if (failureBlock) {
            
            failureBlock(error);
        }
    } else {
        if (success)
        {
            success(url);
        }
    }
}
- (void)nx_handlerRequestImageProgress:(double)progress error:(NSError *)error progressBlock:(downloadProgressBlock)progressBlock failure:(requestFailBlock)failure NS_AVAILABLE_IOS(8_0)
{
    if (error) {
        
        if (failure)
        {
            failure(error);
        }
    } else {
        if (progressBlock)
        {
            progressBlock(progress);
        }
    }
}

+(void)existMediaWithUrl:(NSURL *)url resultBlock:(void(^)(BOOL result))resultBlock  NS_AVAILABLE_IOS(8_0)
{
    if (PHKitExists)
    {
        if (resultBlock)
        {
            resultBlock(![NSString nx_isBlankString:url.path]);
        }
    }
    else
    {
        PHFetchResult<PHAsset *> * result = [PHAsset fetchAssetsWithALAssetURLs:@[url] options:nil];
        if (result.count > 0)
        {
            if (resultBlock)
            {
                resultBlock(YES);
            }
        }
        else
        {
            if (resultBlock)
            {
                resultBlock(NO);
            }
        }
    }
    
}
#endif
@end
