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
    NSMutableArray* imageFileUrls = [[NSMutableArray alloc] init];
    
    dispatch_group_t group = dispatch_group_create();
    
    for (PHAsset *asset in assets) {
        dispatch_group_enter(group);
        [self imagePathFromAsset:asset onFinish: ^(NSString* imageFileUrl) {
            [lock lock];
            [imageFileUrls addObject:imageFileUrl];
            dispatch_group_leave(group);
            [lock unlock];
        }];
    }
    
    __weak ActualizeImagePickerUI *_weakSelf = self;
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        ActualizeImagePickerUI *weakSelf = _weakSelf;
        if (weakSelf->singleImagePickerBlock) {
            weakSelf->singleImagePickerBlock(false, [imageFileUrls firstObject]);
        }
        
        if (weakSelf->multipleImagePickerBlock) {
            weakSelf->multipleImagePickerBlock(false, imageFileUrls);
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
    // the results and populate imageFileUrls, handling
    // threads concurrency and waiting for all the threads to complete
    NSLock* lock = [[NSLock alloc] init];
    dispatch_group_t group = dispatch_group_create();
    NSMutableArray* imageFileUrls = [[NSMutableArray alloc] init];
    
    for (PHPickerResult *result in results) {
        dispatch_group_enter(group);
        __weak ActualizeImagePickerUI* _weakSelf = self;
        
        // We have to use this ugly piece of trash to parse the result
        [result.itemProvider loadObjectOfClass:[UIImage class] completionHandler:^(__kindof id<NSItemProviderReading> _Nullable object, NSError * _Nullable error) {
            if (!_weakSelf) { return; }
            ActualizeImagePickerUI* weakSelf = _weakSelf;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [lock lock];
                NSURL* imageUrl = [weakSelf saveImageToTemp:(UIImage*) object];
                
                [imageFileUrls addObject:[imageUrl absoluteString]];
                dispatch_group_leave(group);
                [lock unlock];
            });
            
        }];
    }
    
    // Returns the result using the correct callback
    __weak ActualizeImagePickerUI *_weakSelf = self;
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        if (!_weakSelf) { return; }
        ActualizeImagePickerUI *weakSelf = _weakSelf;
        
        if (weakSelf->singleImagePickerBlock) {
            weakSelf->singleImagePickerBlock(false, [imageFileUrls firstObject]);
        } else if (weakSelf->multipleImagePickerBlock) {
            weakSelf->multipleImagePickerBlock(false, imageFileUrls);
        }
    });
}

// MARK: - ViewController(s) Creation Utility Methods
- (UIViewController*) createSingleImagePickerViewController:(ActualizeImagePickerSingleConfiguration*) configuration {
    
    UIViewController* outViewController = [self getImagePickerViewController:1];
    self->savedImagesQuality = configuration.imageQuality;
    return outViewController;
}

- (UIViewController*) createMultipleImagePickerViewController:(ActualizeImagePickerMultipleConfiguration*) configuration {
    UIViewController* outViewController = [self getImagePickerViewController:configuration.maxImages];
    self->savedImagesQuality = configuration.imageQuality;
    return outViewController;
}

// MARK: - Private Utility Functions
/**
 Used by GMImagePicker implementation for getting imagePath from the PHAsset picked file from the photo library.
 */
- (void) imagePathFromAsset:(PHAsset*)asset onFinish:(void(^_Nonnull)(NSString*))completion {
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

/**
 Common Function to save Imageon local path
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

- (UIViewController*) rootViewController {
    return [UIApplication sharedApplication].delegate.window.rootViewController;
}

/**
 get the viewController based on the iOS versions.
 iOS 14 and above will return the native PHImageViewController
 iOS 13 and below will return a Library Class - GMIMagePickerViewController.
 */
-(UIViewController*)getImagePickerViewController:(NSUInteger)imageSelectionLimit {
    UIViewController *outViewController = nil;
    // We need two separate implementations for iOS < 14 and iOS >= 14
    // Because iOS provided new APIs for picking multiple images since iOS 14 which works with local and iCloud images very well.
    if (@available(iOS 14, *)) {
        PHPickerConfiguration *config = [[PHPickerConfiguration alloc] init];
        config.selectionLimit = imageSelectionLimit;
        config.filter = [PHPickerFilter imagesFilter];
        
        PHPickerViewController *pickerViewController = [[PHPickerViewController alloc] initWithConfiguration:config];
        pickerViewController.delegate = self;
        
        outViewController = pickerViewController;
    } else {
        GMImagePickerController* viewController = [[GMImagePickerController alloc] init];
        
        viewController.delegate = self;
        viewController.allowsMultipleSelection = imageSelectionLimit > 1;
        viewController.mediaTypes = @[@(PHAssetMediaTypeImage)];
        viewController.displayAlbumsNumberOfAssets = YES;
        
        outViewController = viewController;
    }
    [outViewController setModalPresentationStyle:UIModalPresentationFullScreen];
    return outViewController;
}

@end
