/*
 Scanbot Image Picker Cordova Plugin
 Copyright (c) 2021 doo GmbH
 
 This code is licensed under MIT license (see LICENSE for details)
 
 Created by Marco Saia on 07.05.2021
 */

#import "ActualizeImagePickerUI.h"
#import <GMImagePickerWithCloudMediaDownloading/GMImagePickerController.h>

@implementation ActualizeImagePickerUI {
    NSUInteger savedImagesQuality; /// The quality of the returned selected images, from 0 to 100
    NSString *savedMediaType; /// The media type filter ("image", "video", or "all")
    SingleImagePickerCompletionBlock singleImagePickerBlock; /// The current active Single Image Picker completion block
    MultipleImagePickerCompletionBlock multipleImagePickerBlock; /// The current active Multiple Image Picker completion block
}

// MARK: - ActualizeImagePickerUI SharedInstance
static ActualizeImagePickerUI *_sharedInstance;

/// Returns shared ActualizeImagePickerUI instance
+ (ActualizeImagePickerUI *)shared {
    @synchronized([ActualizeImagePickerUI class]) {
        if (!_sharedInstance) {
            _sharedInstance = [[self alloc] init];
        }
        return _sharedInstance;
    }
}

// MARK: - GMImagePickerViewController Implementation

/// Starts an Image Picker to select just one image
/// @param configuration the desired configuration, of type ActualizeImagePickerSingleConfiguration
/// @param completion block function for handling the result (isCanceled: BOOL, imageFileUri: NSString*)
- (void) startSingleImagePicker:(ActualizeImagePickerSingleConfiguration*) configuration
                     completion:(SingleImagePickerCompletionBlock) completion {
    __weak ActualizeImagePickerUI* _self = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController* viewController = [_self createSingleImagePickerViewController:configuration];
        if (_self) {
            ((ActualizeImagePickerUI*) _self)->singleImagePickerBlock = ^void(BOOL isCanceled, NSString* imageFileUri) {
                completion(isCanceled, imageFileUri);
                
                ((ActualizeImagePickerUI*) _self)->singleImagePickerBlock = nil;
            };
        }
        [[_self rootViewController] presentViewController:viewController animated:true completion:nil];
    });
}

/// Starts an Image Picker to select multiple images
/// @param configuration the desired configuration, of type ActualizeImagePickerMultipleConfiguration
/// @param completion block function for handling the result (isCanceled: BOOL, imageFilesUris: NSArray*)
- (void) startMultipleImagePicker:(ActualizeImagePickerMultipleConfiguration*) configuration
                       completion:(MultipleImagePickerCompletionBlock) completion {
    
    __weak ActualizeImagePickerUI* _self = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController* viewController = [_self createMultipleImagePickerViewController:configuration];
        if (_self) {
            ((ActualizeImagePickerUI*) _self)->multipleImagePickerBlock = ^void(BOOL isCanceled, NSArray* imageFilesUris) {
                completion(isCanceled, imageFilesUris);
                
                ((ActualizeImagePickerUI*) _self)->multipleImagePickerBlock = nil;
            };
        }
        [[_self rootViewController] presentViewController:viewController animated:true completion:nil];
    });
}

- (void)assetsPickerController:(GMImagePickerController *)picker didFinishPickingAssets:(NSArray *)assets {
    NSLock* lock = [[NSLock alloc] init];
    NSMutableArray* fileUrls = [[NSMutableArray alloc] init];

    dispatch_group_t group = dispatch_group_create();

    for (PHAsset *asset in assets) {
        dispatch_group_enter(group);
        [self filePathFromAsset:asset onFinish: ^(NSString* fileUrl) {
            [lock lock];
            if (fileUrl && ![fileUrl isEqualToString:@""]) {
                [fileUrls addObject:fileUrl];
            }
            dispatch_group_leave(group);
            [lock unlock];
        }];
    }

    __weak ActualizeImagePickerUI *_weakSelf = self;
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        ActualizeImagePickerUI *weakSelf = _weakSelf;
        if (weakSelf->singleImagePickerBlock) {
            weakSelf->singleImagePickerBlock(false, [fileUrls firstObject]);
        }

        if (weakSelf->multipleImagePickerBlock) {
            weakSelf->multipleImagePickerBlock(false, fileUrls);
        }

        [picker dismissViewControllerAnimated:true completion:nil];
    });
}

- (void)assetsPickerControllerDidCancel:(GMImagePickerController *)picker {
    __weak ActualizeImagePickerUI* weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!weakSelf) { return; }
        
        [picker dismissViewControllerAnimated:true completion:nil];
        
        if (self->singleImagePickerBlock) {
            self->singleImagePickerBlock(true, nil);
        }
        
        if (self->multipleImagePickerBlock) {
            self->multipleImagePickerBlock(true, [[NSArray alloc] init]);
        }
    });
}

// MARK: - PHPickerViewControllerDelegate Implementation
// For iOS >= 14 we use iOS PHPicker for image picking
- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results  API_AVAILABLE(ios(14)){

    [picker dismissViewControllerAnimated: true completion: nil];

    // If the picker didn't return any results, the user has most probably canceled the
    // operation, so we don't even try to parse the results and return a 'canceled' state
    if (results.count == 0) {
        if (self->singleImagePickerBlock) {
            self->singleImagePickerBlock(true, nil);
        } else if (self->multipleImagePickerBlock) {
            self->multipleImagePickerBlock(true, [[NSArray alloc] init]);
        }
        return;
    }

    // We use a lock and a dispatch group to asynchronously parse
    // the results and populate fileUrls, handling
    // threads concurrency and waiting for all the threads to complete
    NSLock* lock = [[NSLock alloc] init];
    dispatch_group_t group = dispatch_group_create();
    NSMutableArray* fileUrls = [[NSMutableArray alloc] init];

    for (PHPickerResult *result in results) {
        dispatch_group_enter(group);
        __weak ActualizeImagePickerUI* _weakSelf = self;

        NSItemProvider *provider = result.itemProvider;

        // Check if the item is a video
        if ([provider hasItemConformingToTypeIdentifier:@"public.movie"]) {
            // Load video file
            [provider loadFileRepresentationForTypeIdentifier:@"public.movie" completionHandler:^(NSURL * _Nullable url, NSError * _Nullable error) {
                if (!_weakSelf) { dispatch_group_leave(group); return; }
                ActualizeImagePickerUI* weakSelf = _weakSelf;

                if (url && !error) {
                    NSURL* videoUrl = [weakSelf saveVideoToTemp:url];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [lock lock];
                        [fileUrls addObject:[videoUrl absoluteString]];
                        dispatch_group_leave(group);
                        [lock unlock];
                    });
                } else {
                    dispatch_group_leave(group);
                }
            }];
        } else if ([provider canLoadObjectOfClass:[UIImage class]]) {
            // Load image
            [provider loadObjectOfClass:[UIImage class] completionHandler:^(__kindof id<NSItemProviderReading> _Nullable object, NSError * _Nullable error) {
                if (!_weakSelf) { dispatch_group_leave(group); return; }
                ActualizeImagePickerUI* weakSelf = _weakSelf;

                dispatch_async(dispatch_get_main_queue(), ^{
                    [lock lock];
                    NSURL* imageUrl = [weakSelf saveImageToTemp:(UIImage*) object];
                    [fileUrls addObject:[imageUrl absoluteString]];
                    dispatch_group_leave(group);
                    [lock unlock];
                });
            }];
        } else {
            dispatch_group_leave(group);
        }
    }

    // Returns the result using the correct callback
    __weak ActualizeImagePickerUI *_weakSelf = self;
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        if (!_weakSelf) { return; }
        ActualizeImagePickerUI *weakSelf = _weakSelf;

        if (weakSelf->singleImagePickerBlock) {
            weakSelf->singleImagePickerBlock(false, [fileUrls firstObject]);
        } else if (weakSelf->multipleImagePickerBlock) {
            weakSelf->multipleImagePickerBlock(false, fileUrls);
        }
    });
}

// MARK: - ViewController(s) Creation Utility Methods
- (UIViewController*) createSingleImagePickerViewController:(ActualizeImagePickerSingleConfiguration*) configuration {

    self->savedImagesQuality = configuration.imageQuality;
    self->savedMediaType = configuration.mediaType;
    UIViewController* outViewController = [self getImagePickerViewController:1 mediaType:configuration.mediaType];
    return outViewController;
}

- (UIViewController*) createMultipleImagePickerViewController:(ActualizeImagePickerMultipleConfiguration*) configuration {
    self->savedImagesQuality = configuration.imageQuality;
    self->savedMediaType = configuration.mediaType;
    UIViewController* outViewController = [self getImagePickerViewController:configuration.maxImages mediaType:configuration.mediaType];
    return outViewController;
}

// MARK: - Private Utility Functions
/**
 Used by GMImagePicker implementation for getting file path from the PHAsset picked file from the photo library.
 Handles both images and videos.
 */
- (void) filePathFromAsset:(PHAsset*)asset onFinish:(void(^_Nonnull)(NSString*))completion {
    if (asset.mediaType == PHAssetMediaTypeVideo) {
        // Handle video asset
        PHVideoRequestOptions *options = [[PHVideoRequestOptions alloc] init];
        options.version = PHVideoRequestOptionsVersionOriginal;
        options.networkAccessAllowed = NO;

        [[PHImageManager defaultManager] requestAVAssetForVideo:asset options:options resultHandler:^(AVAsset * _Nullable avAsset, AVAudioMix * _Nullable audioMix, NSDictionary * _Nullable info) {
            if ([avAsset isKindOfClass:[AVURLAsset class]]) {
                AVURLAsset *urlAsset = (AVURLAsset *)avAsset;
                NSURL *sourceURL = urlAsset.URL;
                NSURL *tmpVideoURL = [self saveVideoToTemp:sourceURL];
                completion(tmpVideoURL.absoluteString);
            } else {
                completion(@"");
            }
        }];
    } else {
        // Handle image asset
        PHContentEditingInputRequestOptions* options = [[PHContentEditingInputRequestOptions alloc] init];
        options.networkAccessAllowed = NO;

        [asset requestContentEditingInputWithOptions:options completionHandler:^(PHContentEditingInput * _Nullable contentEditingInput, NSDictionary * _Nonnull info) {
            if(contentEditingInput == nil || contentEditingInput.fullSizeImageURL == nil) {
                completion(Error_IOS_13);
                return;
            }

            NSData* data = [NSData dataWithContentsOfURL:contentEditingInput.fullSizeImageURL];
            UIImage* image = [[UIImage alloc] initWithData:data];
            NSURL* tmpImageURL = [self saveImageToTemp: image];
            completion(tmpImageURL.absoluteString);
        }];
    }
}

/**
 Common Function to save Image on local path
 */
-(NSURL*)saveImageToTemp:(UIImage*)image {
    if (!image) { return [[NSURL alloc] initWithString:@""]; }

    NSURL *tmpDirURL = [NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES];
    NSString *fileName = [NSString stringWithFormat:@"%lu", image.hash];
    NSURL *fileURL = [[tmpDirURL URLByAppendingPathComponent: fileName] URLByAppendingPathExtension:@"jpg"];

    CGFloat quality = self->savedImagesQuality / 100.0;
    [UIImageJPEGRepresentation(image, quality) writeToFile:[fileURL path] atomically:YES];

    return fileURL;
}

/**
 Common Function to save Video on local path
 Copies the video file from the temporary URL provided by the picker to the app's temp directory
 */
-(NSURL*)saveVideoToTemp:(NSURL*)sourceUrl {
    if (!sourceUrl) { return [[NSURL alloc] initWithString:@""]; }

    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *tmpDirURL = [NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES];

    // Use the original filename or generate one based on hash
    NSString *originalFilename = [sourceUrl lastPathComponent];
    NSString *extension = [sourceUrl pathExtension];
    if (!extension || [extension length] == 0) {
        extension = @"mp4"; // Default to mp4
    }

    // Generate a unique filename using timestamp and random number
    NSString *fileName = [NSString stringWithFormat:@"video_%lu_%d.%@",
                         (unsigned long)[[NSDate date] timeIntervalSince1970],
                         arc4random_uniform(10000),
                         extension];
    NSURL *destUrl = [tmpDirURL URLByAppendingPathComponent:fileName];

    NSError *error;
    // Remove existing file if any
    [fileManager removeItemAtURL:destUrl error:nil];

    // Copy the video file
    BOOL success = [fileManager copyItemAtURL:sourceUrl toURL:destUrl error:&error];
    if (!success) {
        NSLog(@"Error copying video file: %@", error);
        return [[NSURL alloc] initWithString:@""];
    }

    return destUrl;
}

- (UIViewController*) rootViewController {
    return [UIApplication sharedApplication].delegate.window.rootViewController;
}

/**
 get the viewController based on the iOS versions.
 iOS 14 and above will return the native PHImageViewController
 iOS 13 and below will return a Library Class - GMIMagePickerViewController.
 @param imageSelectionLimit the maximum number of items that can be selected (0 = unlimited)
 @param mediaType the type of media to show ("image", "video", or "all")
 */
-(UIViewController*)getImagePickerViewController:(NSUInteger)imageSelectionLimit mediaType:(NSString*)mediaType {
    UIViewController *outViewController = nil;
    // We need two separate implementations for iOS < 14 and iOS >= 14
    // Because iOS provided new APIs for picking multiple images since iOS 14 which works with local and iCloud images very well.
    if (@available(iOS 14, *)) {
        PHPickerConfiguration *config = [[PHPickerConfiguration alloc] init];
        config.selectionLimit = imageSelectionLimit;

        // Set the filter based on mediaType
        if ([mediaType isEqualToString:@"video"]) {
            config.filter = [PHPickerFilter videosFilter];
        } else if ([mediaType isEqualToString:@"all"]) {
            config.filter = [PHPickerFilter anyFilterMatchingSubfilters:@[
                [PHPickerFilter imagesFilter],
                [PHPickerFilter videosFilter]
            ]];
        } else {
            // Default to images only
            config.filter = [PHPickerFilter imagesFilter];
        }

        PHPickerViewController *pickerViewController = [[PHPickerViewController alloc] initWithConfiguration:config];
        pickerViewController.delegate = self;

        outViewController = pickerViewController;
    } else {
        GMImagePickerController* viewController = [[GMImagePickerController alloc] init];

        viewController.delegate = self;
        viewController.allowsMultipleSelection = imageSelectionLimit > 1;

        // Set media types based on mediaType
        if ([mediaType isEqualToString:@"video"]) {
            viewController.mediaTypes = @[@(PHAssetMediaTypeVideo)];
        } else if ([mediaType isEqualToString:@"all"]) {
            viewController.mediaTypes = @[@(PHAssetMediaTypeImage), @(PHAssetMediaTypeVideo)];
        } else {
            // Default to images only
            viewController.mediaTypes = @[@(PHAssetMediaTypeImage)];
        }
        viewController.displayAlbumsNumberOfAssets = YES;

        outViewController = viewController;
    }
    [outViewController setModalPresentationStyle:UIModalPresentationFullScreen];
    return outViewController;
}

@end
