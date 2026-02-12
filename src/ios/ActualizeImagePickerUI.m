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
    NSString *savedVideoQuality; /// The video quality preset ("low", "medium", "high", "highest", "passthrough")
    NSString *savedVideoProcessingMessage; /// The message shown during video transcoding
    SingleImagePickerCompletionBlock singleImagePickerBlock; /// The current active Single Image Picker completion block
    MultipleImagePickerCompletionBlock multipleImagePickerBlock; /// The current active Multiple Image Picker completion block

    // Progress overlay UI elements
    UIView *progressOverlayView;
    UIView *progressContainerView;
    UIActivityIndicatorView *activityIndicator;
    CAShapeLayer *progressCircleLayer;
    CAShapeLayer *progressTrackLayer;
    UILabel *progressMessageLabel;
    UILabel *progressPercentLabel;
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

/// Debug method to verify implementation is linked
- (void)debugTest {
    NSLog(@"[ActualizeImagePickerUI] debugTest: implementation is properly linked!");
}

// MARK: - GMImagePickerViewController Implementation

/// Starts an Image Picker to select just one image
/// @param configuration the desired configuration, of type ActualizeImagePickerSingleConfiguration
/// @param completion block function for handling the result (isCanceled: BOOL, imageFileUri: NSString*)
- (void) startSingleImagePicker:(ActualizeImagePickerSingleConfiguration*) configuration
                     completion:(SingleImagePickerCompletionBlock) completion {
    NSLog(@"[ActualizeImagePickerUI] startSingleImagePicker: called");
    __weak ActualizeImagePickerUI* _self = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"[ActualizeImagePickerUI] startSingleImagePicker: on main queue");
        UIViewController* viewController = [_self createSingleImagePickerViewController:configuration];
        NSLog(@"[ActualizeImagePickerUI] startSingleImagePicker: created viewController = %@", viewController);

        if (_self) {
            ((ActualizeImagePickerUI*) _self)->singleImagePickerBlock = ^void(BOOL isCanceled, NSString* imageFileUri) {
                NSLog(@"[ActualizeImagePickerUI] singleImagePickerBlock: called with isCanceled=%d, uri=%@", isCanceled, imageFileUri);
                completion(isCanceled, imageFileUri);

                ((ActualizeImagePickerUI*) _self)->singleImagePickerBlock = nil;
            };
        }

        UIViewController* rootVC = [_self rootViewController];
        NSLog(@"[ActualizeImagePickerUI] startSingleImagePicker: rootViewController = %@", rootVC);

        if (!rootVC) {
            NSLog(@"[ActualizeImagePickerUI] startSingleImagePicker: ERROR - rootViewController is nil!");
            if (completion) {
                completion(YES, nil);  // Report as canceled
            }
            return;
        }

        if (!viewController) {
            NSLog(@"[ActualizeImagePickerUI] startSingleImagePicker: ERROR - viewController is nil!");
            if (completion) {
                completion(YES, nil);  // Report as canceled
            }
            return;
        }

        NSLog(@"[ActualizeImagePickerUI] startSingleImagePicker: presenting viewController");
        [rootVC presentViewController:viewController animated:true completion:^{
            NSLog(@"[ActualizeImagePickerUI] startSingleImagePicker: viewController presented successfully");
        }];
    });
}

/// Starts an Image Picker to select multiple images
/// @param configuration the desired configuration, of type ActualizeImagePickerMultipleConfiguration
/// @param completion block function for handling the result (isCanceled: BOOL, imageFilesUris: NSArray*)
- (void) startMultipleImagePicker:(ActualizeImagePickerMultipleConfiguration*) configuration
                       completion:(MultipleImagePickerCompletionBlock) completion {
    NSLog(@"[ActualizeImagePickerUI] startMultipleImagePicker: called");

    __weak ActualizeImagePickerUI* _self = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"[ActualizeImagePickerUI] startMultipleImagePicker: on main queue");
        UIViewController* viewController = [_self createMultipleImagePickerViewController:configuration];
        NSLog(@"[ActualizeImagePickerUI] startMultipleImagePicker: created viewController = %@", viewController);

        if (_self) {
            ((ActualizeImagePickerUI*) _self)->multipleImagePickerBlock = ^void(BOOL isCanceled, NSArray* imageFilesUris) {
                NSLog(@"[ActualizeImagePickerUI] multipleImagePickerBlock: called with isCanceled=%d, count=%lu", isCanceled, (unsigned long)imageFilesUris.count);
                completion(isCanceled, imageFilesUris);

                ((ActualizeImagePickerUI*) _self)->multipleImagePickerBlock = nil;
            };
        }

        UIViewController* rootVC = [_self rootViewController];
        NSLog(@"[ActualizeImagePickerUI] startMultipleImagePicker: rootViewController = %@", rootVC);

        if (!rootVC) {
            NSLog(@"[ActualizeImagePickerUI] startMultipleImagePicker: ERROR - rootViewController is nil!");
            if (completion) {
                completion(YES, @[]);
            }
            return;
        }

        if (!viewController) {
            NSLog(@"[ActualizeImagePickerUI] startMultipleImagePicker: ERROR - viewController is nil!");
            if (completion) {
                completion(YES, @[]);
            }
            return;
        }

        NSLog(@"[ActualizeImagePickerUI] startMultipleImagePicker: presenting viewController");
        [rootVC presentViewController:viewController animated:true completion:^{
            NSLog(@"[ActualizeImagePickerUI] startMultipleImagePicker: viewController presented successfully");
        }];
    });
}

- (void)assetsPickerController:(GMImagePickerController *)picker didFinishPickingAssets:(NSArray *)assets {
    NSLog(@"[ActualizeImagePickerUI] assetsPickerController:didFinishPickingAssets: called with %lu assets (GMImagePicker - iOS < 14)", (unsigned long)assets.count);
    NSLock* lock = [[NSLock alloc] init];
    NSMutableArray* fileUrls = [[NSMutableArray alloc] init];

    dispatch_group_t group = dispatch_group_create();

    for (PHAsset *asset in assets) {
        dispatch_group_enter(group);
        [self filePathFromAsset:asset onFinish: ^(NSString* fileUrl) {
            [lock lock];
            NSLog(@"[ActualizeImagePickerUI] assetsPickerController: got fileUrl = %@", fileUrl);
            if (fileUrl && ![fileUrl isEqualToString:@""]) {
                [fileUrls addObject:fileUrl];
            }
            dispatch_group_leave(group);
            [lock unlock];
        }];
    }

    __weak ActualizeImagePickerUI *_weakSelf = self;
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        NSLog(@"[ActualizeImagePickerUI] assetsPickerController: all assets processed, fileUrls count = %lu", (unsigned long)fileUrls.count);
        ActualizeImagePickerUI *weakSelf = _weakSelf;
        if (weakSelf->singleImagePickerBlock) {
            NSLog(@"[ActualizeImagePickerUI] assetsPickerController: calling singleImagePickerBlock with firstObject");
            weakSelf->singleImagePickerBlock(false, [fileUrls firstObject]);
        }

        if (weakSelf->multipleImagePickerBlock) {
            NSLog(@"[ActualizeImagePickerUI] assetsPickerController: calling multipleImagePickerBlock");
            weakSelf->multipleImagePickerBlock(false, fileUrls);
        }

        [picker dismissViewControllerAnimated:true completion:nil];
    });
}

- (void)assetsPickerControllerDidCancel:(GMImagePickerController *)picker {
    NSLog(@"[ActualizeImagePickerUI] assetsPickerControllerDidCancel: called (GMImagePicker - iOS < 14)");
    __weak ActualizeImagePickerUI* weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!weakSelf) { return; }

        [picker dismissViewControllerAnimated:true completion:nil];

        if (self->singleImagePickerBlock) {
            NSLog(@"[ActualizeImagePickerUI] assetsPickerControllerDidCancel: calling singleImagePickerBlock(canceled)");
            self->singleImagePickerBlock(true, nil);
        }

        if (self->multipleImagePickerBlock) {
            NSLog(@"[ActualizeImagePickerUI] assetsPickerControllerDidCancel: calling multipleImagePickerBlock(canceled)");
            self->multipleImagePickerBlock(true, [[NSArray alloc] init]);
        }
    });
}

// MARK: - PHPickerViewControllerDelegate Implementation
// For iOS >= 14 we use iOS PHPicker for image picking
- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results  API_AVAILABLE(ios(14)){
    NSLog(@"[ActualizeImagePickerUI] picker:didFinishPicking: called with %lu results (PHPicker - iOS 14+)", (unsigned long)results.count);

    [picker dismissViewControllerAnimated: true completion: nil];

    // If the picker didn't return any results, the user has most probably canceled the
    // operation, so we don't even try to parse the results and return a 'canceled' state
    if (results.count == 0) {
        NSLog(@"[ActualizeImagePickerUI] picker:didFinishPicking: no results, treating as canceled");
        if (self->singleImagePickerBlock) {
            NSLog(@"[ActualizeImagePickerUI] picker:didFinishPicking: calling singleImagePickerBlock(canceled)");
            self->singleImagePickerBlock(true, nil);
        } else if (self->multipleImagePickerBlock) {
            NSLog(@"[ActualizeImagePickerUI] picker:didFinishPicking: calling multipleImagePickerBlock(canceled)");
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

    NSLog(@"[ActualizeImagePickerUI] picker:didFinishPicking: processing %lu results", (unsigned long)results.count);

    for (PHPickerResult *result in results) {
        dispatch_group_enter(group);
        __weak ActualizeImagePickerUI* _weakSelf = self;

        NSItemProvider *provider = result.itemProvider;
        NSLog(@"[ActualizeImagePickerUI] picker:didFinishPicking: processing item - registeredTypeIdentifiers: %@", provider.registeredTypeIdentifiers);

        // Check if the item is a video
        if ([provider hasItemConformingToTypeIdentifier:@"public.movie"]) {
            NSLog(@"[ActualizeImagePickerUI] picker:didFinishPicking: loading video");
            // Load video file
            [provider loadFileRepresentationForTypeIdentifier:@"public.movie" completionHandler:^(NSURL * _Nullable url, NSError * _Nullable error) {
                if (!_weakSelf) {
                    NSLog(@"[ActualizeImagePickerUI] picker:didFinishPicking: video load - weakSelf is nil");
                    dispatch_group_leave(group);
                    return;
                }

                if (url && !error) {
                    NSLog(@"[ActualizeImagePickerUI] picker:didFinishPicking: video loaded - url=%@", url);
                    // Copy video to temp directory (no transcoding)
                    NSURL *outputUrl = [_weakSelf copyVideoToTemp:url];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [lock lock];
                        if (outputUrl) {
                            NSLog(@"[ActualizeImagePickerUI] picker:didFinishPicking: video copied - outputUrl=%@", outputUrl);
                            [fileUrls addObject:[outputUrl absoluteString]];
                        } else {
                            NSLog(@"[ActualizeImagePickerUI] picker:didFinishPicking: video copy failed");
                        }
                        dispatch_group_leave(group);
                        [lock unlock];
                    });
                } else {
                    NSLog(@"[ActualizeImagePickerUI] picker:didFinishPicking: video load error: %@", error);
                    dispatch_group_leave(group);
                }
            }];
        } else if ([provider canLoadObjectOfClass:[UIImage class]]) {
            NSLog(@"[ActualizeImagePickerUI] picker:didFinishPicking: loading image");
            // Load image
            [provider loadObjectOfClass:[UIImage class] completionHandler:^(__kindof id<NSItemProviderReading> _Nullable object, NSError * _Nullable error) {
                if (!_weakSelf) {
                    NSLog(@"[ActualizeImagePickerUI] picker:didFinishPicking: image load - weakSelf is nil");
                    dispatch_group_leave(group);
                    return;
                }
                ActualizeImagePickerUI* weakSelf = _weakSelf;

                if (error) {
                    NSLog(@"[ActualizeImagePickerUI] picker:didFinishPicking: image load error: %@", error);
                }

                dispatch_async(dispatch_get_main_queue(), ^{
                    [lock lock];
                    NSLog(@"[ActualizeImagePickerUI] picker:didFinishPicking: saving image to temp");
                    NSURL* imageUrl = [weakSelf saveImageToTemp:(UIImage*) object];
                    NSLog(@"[ActualizeImagePickerUI] picker:didFinishPicking: image saved - imageUrl=%@", imageUrl);
                    [fileUrls addObject:[imageUrl absoluteString]];
                    dispatch_group_leave(group);
                    [lock unlock];
                });
            }];
        } else {
            NSLog(@"[ActualizeImagePickerUI] picker:didFinishPicking: unknown item type, skipping");
            dispatch_group_leave(group);
        }
    }

    // Returns the result using the correct callback
    __weak ActualizeImagePickerUI *_weakSelf = self;
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        NSLog(@"[ActualizeImagePickerUI] picker:didFinishPicking: all items processed, fileUrls count = %lu", (unsigned long)fileUrls.count);
        if (!_weakSelf) {
            NSLog(@"[ActualizeImagePickerUI] picker:didFinishPicking: ERROR - weakSelf is nil in notify block");
            return;
        }
        ActualizeImagePickerUI *weakSelf = _weakSelf;

        if (weakSelf->singleImagePickerBlock) {
            NSLog(@"[ActualizeImagePickerUI] picker:didFinishPicking: calling singleImagePickerBlock with firstObject = %@", [fileUrls firstObject]);
            weakSelf->singleImagePickerBlock(false, [fileUrls firstObject]);
        } else if (weakSelf->multipleImagePickerBlock) {
            NSLog(@"[ActualizeImagePickerUI] picker:didFinishPicking: calling multipleImagePickerBlock with %lu items", (unsigned long)fileUrls.count);
            weakSelf->multipleImagePickerBlock(false, fileUrls);
        } else {
            NSLog(@"[ActualizeImagePickerUI] picker:didFinishPicking: WARNING - no completion block set!");
        }
    });
}

// MARK: - ViewController(s) Creation Utility Methods
- (UIViewController*) createSingleImagePickerViewController:(ActualizeImagePickerSingleConfiguration*) configuration {
    NSLog(@"[ActualizeImagePickerUI] createSingleImagePickerViewController: mediaType=%@, imageQuality=%lu", configuration.mediaType, (unsigned long)configuration.imageQuality);

    self->savedImagesQuality = configuration.imageQuality;
    self->savedMediaType = configuration.mediaType;
    self->savedVideoQuality = configuration.videoQuality ?: @"medium";
    self->savedVideoProcessingMessage = configuration.videoProcessingMessage ?: @"Processing video...";
    UIViewController* outViewController = [self getImagePickerViewController:1 mediaType:configuration.mediaType];
    NSLog(@"[ActualizeImagePickerUI] createSingleImagePickerViewController: created viewController = %@", outViewController);
    return outViewController;
}

- (UIViewController*) createMultipleImagePickerViewController:(ActualizeImagePickerMultipleConfiguration*) configuration {
    NSLog(@"[ActualizeImagePickerUI] createMultipleImagePickerViewController: maxImages=%lu, mediaType=%@", (unsigned long)configuration.maxImages, configuration.mediaType);

    self->savedImagesQuality = configuration.imageQuality;
    self->savedMediaType = configuration.mediaType;
    self->savedVideoQuality = configuration.videoQuality ?: @"medium";
    self->savedVideoProcessingMessage = configuration.videoProcessingMessage ?: @"Processing video...";
    UIViewController* outViewController = [self getImagePickerViewController:configuration.maxImages mediaType:configuration.mediaType];
    NSLog(@"[ActualizeImagePickerUI] createMultipleImagePickerViewController: created viewController = %@", outViewController);
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
                // Copy video to temp directory (no transcoding)
                NSURL *outputUrl = [self copyVideoToTemp:sourceURL];
                if (outputUrl) {
                    completion(outputUrl.absoluteString);
                } else {
                    NSLog(@"Video copy error in filePathFromAsset");
                    completion(@"");
                }
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
    NSLog(@"[ActualizeImagePickerUI] saveImageToTemp: called with image=%@", image);
    if (!image) {
        NSLog(@"[ActualizeImagePickerUI] saveImageToTemp: ERROR - image is nil!");
        return [[NSURL alloc] initWithString:@""];
    }

    NSURL *tmpDirURL = [NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES];
    NSString *fileName = [NSString stringWithFormat:@"%lu", image.hash];
    NSURL *fileURL = [[tmpDirURL URLByAppendingPathComponent: fileName] URLByAppendingPathExtension:@"jpg"];

    CGFloat quality = self->savedImagesQuality / 100.0;
    NSLog(@"[ActualizeImagePickerUI] saveImageToTemp: saving to %@ with quality %.2f", fileURL, quality);

    NSData *imageData = UIImageJPEGRepresentation(image, quality);
    if (!imageData) {
        NSLog(@"[ActualizeImagePickerUI] saveImageToTemp: ERROR - UIImageJPEGRepresentation returned nil!");
        return [[NSURL alloc] initWithString:@""];
    }

    BOOL success = [imageData writeToFile:[fileURL path] atomically:YES];
    NSLog(@"[ActualizeImagePickerUI] saveImageToTemp: write success=%d, fileURL=%@", success, fileURL);

    return fileURL;
}

/**
 Copies a video file to the temp directory without any transcoding/processing.
 @param sourceUrl the source video URL
 @return the URL of the copied video file, or nil on failure
 */
-(NSURL*)copyVideoToTemp:(NSURL*)sourceUrl {
    NSLog(@"[ActualizeImagePickerUI] copyVideoToTemp: called with sourceUrl=%@", sourceUrl);
    if (!sourceUrl) {
        NSLog(@"[ActualizeImagePickerUI] copyVideoToTemp: ERROR - sourceUrl is nil!");
        return nil;
    }

    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *tmpDirURL = [NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES];

    // Get the original file extension
    NSString *extension = [sourceUrl pathExtension];
    if (!extension || [extension length] == 0) {
        extension = @"mp4"; // Default to mp4 if no extension
    }

    // Generate unique filename
    NSString *fileName = [NSString stringWithFormat:@"video_%lu_%d.%@",
                         (unsigned long)[[NSDate date] timeIntervalSince1970],
                         arc4random_uniform(10000),
                         extension];
    NSURL *outputUrl = [tmpDirURL URLByAppendingPathComponent:fileName];

    // Remove existing file if any
    [fileManager removeItemAtURL:outputUrl error:nil];

    // Copy the file
    NSError *copyError = nil;
    BOOL success = [fileManager copyItemAtURL:sourceUrl toURL:outputUrl error:&copyError];

    if (success) {
        NSLog(@"[ActualizeImagePickerUI] copyVideoToTemp: copied successfully to %@", outputUrl);
        return outputUrl;
    } else {
        NSLog(@"[ActualizeImagePickerUI] copyVideoToTemp: ERROR copying file: %@", copyError);
        return nil;
    }
}

// MARK: - Progress Overlay Methods

/**
 Shows a progress overlay with a radial progress indicator and message
 @param message the message to display below the progress indicator
 */
- (void)showProgressOverlayWithMessage:(NSString*)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self->progressOverlayView) {
            [self hideProgressOverlay];
        }

        UIWindow *window = [UIApplication sharedApplication].delegate.window;
        if (!window) return;

        // Create overlay background
        self->progressOverlayView = [[UIView alloc] initWithFrame:window.bounds];
        self->progressOverlayView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.7];
        self->progressOverlayView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

        // Create container for progress elements
        CGFloat containerSize = 160;
        self->progressContainerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, containerSize, containerSize + 50)];
        self->progressContainerView.center = self->progressOverlayView.center;
        self->progressContainerView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
                                                       UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
        self->progressContainerView.backgroundColor = [[UIColor darkGrayColor] colorWithAlphaComponent:0.9];
        self->progressContainerView.layer.cornerRadius = 16;

        // Create progress track (background circle)
        CGFloat circleSize = 80;
        CGFloat circleX = (containerSize - circleSize) / 2;
        CGFloat circleY = 20;
        UIBezierPath *circlePath = [UIBezierPath bezierPathWithArcCenter:CGPointMake(circleSize/2, circleSize/2)
                                                                  radius:(circleSize - 8) / 2
                                                              startAngle:-M_PI_2
                                                                endAngle:M_PI_2 * 3
                                                               clockwise:YES];

        self->progressTrackLayer = [CAShapeLayer layer];
        self->progressTrackLayer.path = circlePath.CGPath;
        self->progressTrackLayer.strokeColor = [[UIColor whiteColor] colorWithAlphaComponent:0.3].CGColor;
        self->progressTrackLayer.fillColor = [UIColor clearColor].CGColor;
        self->progressTrackLayer.lineWidth = 6;
        self->progressTrackLayer.frame = CGRectMake(circleX, circleY, circleSize, circleSize);
        [self->progressContainerView.layer addSublayer:self->progressTrackLayer];

        // Create progress circle (foreground)
        self->progressCircleLayer = [CAShapeLayer layer];
        self->progressCircleLayer.path = circlePath.CGPath;
        self->progressCircleLayer.strokeColor = [UIColor systemBlueColor].CGColor;
        self->progressCircleLayer.fillColor = [UIColor clearColor].CGColor;
        self->progressCircleLayer.lineWidth = 6;
        self->progressCircleLayer.lineCap = kCALineCapRound;
        self->progressCircleLayer.strokeEnd = 0.0;
        self->progressCircleLayer.frame = CGRectMake(circleX, circleY, circleSize, circleSize);
        [self->progressContainerView.layer addSublayer:self->progressCircleLayer];

        // Create percent label in center of circle
        self->progressPercentLabel = [[UILabel alloc] initWithFrame:CGRectMake(circleX, circleY, circleSize, circleSize)];
        self->progressPercentLabel.textAlignment = NSTextAlignmentCenter;
        self->progressPercentLabel.textColor = [UIColor whiteColor];
        self->progressPercentLabel.font = [UIFont boldSystemFontOfSize:18];
        self->progressPercentLabel.text = @"0%";
        [self->progressContainerView addSubview:self->progressPercentLabel];

        // Create message label
        self->progressMessageLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, circleY + circleSize + 15, containerSize - 20, 50)];
        self->progressMessageLabel.textAlignment = NSTextAlignmentCenter;
        self->progressMessageLabel.textColor = [UIColor whiteColor];
        self->progressMessageLabel.font = [UIFont systemFontOfSize:14];
        self->progressMessageLabel.numberOfLines = 2;
        self->progressMessageLabel.text = message ?: @"Processing video...";
        [self->progressContainerView addSubview:self->progressMessageLabel];

        [self->progressOverlayView addSubview:self->progressContainerView];
        [window addSubview:self->progressOverlayView];

        // Fade in animation
        self->progressOverlayView.alpha = 0;
        [UIView animateWithDuration:0.25 animations:^{
            self->progressOverlayView.alpha = 1;
        }];
    });
}

/**
 Updates the progress indicator with the current progress value
 @param progress the progress value from 0.0 to 1.0
 */
- (void)updateProgress:(float)progress {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self->progressCircleLayer) {
            self->progressCircleLayer.strokeEnd = progress;
        }
        if (self->progressPercentLabel) {
            self->progressPercentLabel.text = [NSString stringWithFormat:@"%d%%", (int)(progress * 100)];
        }
    });
}

/**
 Hides and removes the progress overlay
 */
- (void)hideProgressOverlay {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self->progressOverlayView) {
            [UIView animateWithDuration:0.25 animations:^{
                self->progressOverlayView.alpha = 0;
            } completion:^(BOOL finished) {
                [self->progressOverlayView removeFromSuperview];
                self->progressOverlayView = nil;
                self->progressContainerView = nil;
                self->progressCircleLayer = nil;
                self->progressTrackLayer = nil;
                self->progressMessageLabel = nil;
                self->progressPercentLabel = nil;
            }];
        }
    });
}

/**
 Returns the AVAssetExportSession preset string for a given quality setting
 @param quality the quality string ("low", "medium", "high", "highest", "passthrough")
 @return the corresponding AVAssetExportPreset string
 */
- (NSString*)exportPresetForQuality:(NSString*)quality {
    if ([quality isEqualToString:@"low"]) {
        return AVAssetExportPresetLowQuality;
    } else if ([quality isEqualToString:@"medium"]) {
        return AVAssetExportPresetMediumQuality;
    } else if ([quality isEqualToString:@"high"]) {
        return AVAssetExportPreset1280x720;
    } else if ([quality isEqualToString:@"highest"]) {
        return AVAssetExportPresetHighestQuality;
    } else if ([quality isEqualToString:@"passthrough"]) {
        return AVAssetExportPresetPassthrough;
    }
    // Default to medium quality
    return AVAssetExportPresetMediumQuality;
}

/**
 Transcodes a video to MP4 format with the specified quality preset.
 This replaces the old saveVideoToTemp: method to provide compression.
 @param sourceUrl the source video URL
 @param quality the quality preset ("low", "medium", "high", "highest", "passthrough")
 @param completion block called when transcoding completes
 */
- (void)transcodeVideoToMp4:(NSURL*)sourceUrl
                    quality:(NSString*)quality
                 completion:(VideoTranscodeCompletionBlock)completion {

    if (!sourceUrl) {
        if (completion) {
            NSError *error = [NSError errorWithDomain:@"ActualizeImagePicker"
                                                code:-1
                                            userInfo:@{NSLocalizedDescriptionKey: @"Source URL is nil"}];
            completion(nil, error);
        }
        return;
    }

    // Show progress overlay
    [self showProgressOverlayWithMessage:self->savedVideoProcessingMessage];

    // Generate output URL in temp directory
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *tmpDirURL = [NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES];
    NSString *fileName = [NSString stringWithFormat:@"video_%lu_%d.mp4",
                         (unsigned long)[[NSDate date] timeIntervalSince1970],
                         arc4random_uniform(10000)];
    NSURL *outputUrl = [tmpDirURL URLByAppendingPathComponent:fileName];

    // Remove existing file if any
    [fileManager removeItemAtURL:outputUrl error:nil];

    // Create asset from source URL
    AVAsset *asset = [AVAsset assetWithURL:sourceUrl];

    // Get the appropriate export preset
    NSString *presetName = [self exportPresetForQuality:quality];

    // Check if the preset is compatible with the asset
    NSArray *compatiblePresets = [AVAssetExportSession exportPresetsCompatibleWithAsset:asset];
    if (![compatiblePresets containsObject:presetName]) {
        NSLog(@"Preset %@ not compatible, falling back to MediumQuality", presetName);
        presetName = AVAssetExportPresetMediumQuality;
        if (![compatiblePresets containsObject:presetName]) {
            // Fall back to passthrough if nothing else works
            presetName = AVAssetExportPresetPassthrough;
        }
    }

    // Create export session
    AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:asset
                                                                          presetName:presetName];

    if (!exportSession) {
        [self hideProgressOverlay];
        if (completion) {
            NSError *error = [NSError errorWithDomain:@"ActualizeImagePicker"
                                                code:-2
                                            userInfo:@{NSLocalizedDescriptionKey: @"Could not create export session"}];
            completion(nil, error);
        }
        return;
    }

    exportSession.outputURL = outputUrl;
    exportSession.outputFileType = AVFileTypeMPEG4;
    exportSession.shouldOptimizeForNetworkUse = YES;

    NSLog(@"Starting video transcode with preset: %@", presetName);

    // Create a timer to poll export progress
    __weak ActualizeImagePickerUI *weakSelf = self;
    __block NSTimer *progressTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                                                     repeats:YES
                                                                       block:^(NSTimer * _Nonnull timer) {
        if (exportSession.status == AVAssetExportSessionStatusExporting) {
            [weakSelf updateProgress:exportSession.progress];
        } else if (exportSession.status != AVAssetExportSessionStatusWaiting) {
            [timer invalidate];
        }
    }];

    [exportSession exportAsynchronouslyWithCompletionHandler:^{
        // Stop the progress timer
        [progressTimer invalidate];

        // Hide progress overlay
        [weakSelf hideProgressOverlay];

        switch (exportSession.status) {
            case AVAssetExportSessionStatusCompleted:
                NSLog(@"Video transcode completed successfully");
                if (completion) {
                    completion(outputUrl, nil);
                }
                break;

            case AVAssetExportSessionStatusFailed:
                NSLog(@"Video transcode failed: %@", exportSession.error);
                if (completion) {
                    completion(nil, exportSession.error);
                }
                break;

            case AVAssetExportSessionStatusCancelled:
                NSLog(@"Video transcode cancelled");
                if (completion) {
                    NSError *error = [NSError errorWithDomain:@"ActualizeImagePicker"
                                                        code:-3
                                                    userInfo:@{NSLocalizedDescriptionKey: @"Export was cancelled"}];
                    completion(nil, error);
                }
                break;

            default:
                break;
        }
    }];
}

- (UIViewController*) rootViewController {
    UIViewController *rootVC = nil;

    // Try the traditional AppDelegate window approach first
    rootVC = [UIApplication sharedApplication].delegate.window.rootViewController;

    // If nil, try iOS 13+ scene-based approach
    if (!rootVC) {
        if (@available(iOS 13.0, *)) {
            for (UIWindowScene *windowScene in [UIApplication sharedApplication].connectedScenes) {
                if (windowScene.activationState == UISceneActivationStateForegroundActive) {
                    for (UIWindow *window in windowScene.windows) {
                        if (window.isKeyWindow) {
                            rootVC = window.rootViewController;
                            break;
                        }
                    }
                    if (rootVC) break;
                }
            }

            // Fallback: if still nil, try any foreground scene's first window
            if (!rootVC) {
                for (UIWindowScene *windowScene in [UIApplication sharedApplication].connectedScenes) {
                    if (windowScene.activationState == UISceneActivationStateForegroundActive) {
                        UIWindow *firstWindow = windowScene.windows.firstObject;
                        if (firstWindow) {
                            rootVC = firstWindow.rootViewController;
                            break;
                        }
                    }
                }
            }
        }
    }

    // Final fallback: try keyWindow (deprecated but still works)
    if (!rootVC) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        rootVC = [UIApplication sharedApplication].keyWindow.rootViewController;
        #pragma clang diagnostic pop
    }

    NSLog(@"[ActualizeImagePickerUI] rootViewController: returning %@", rootVC);
    return rootVC;
}

/**
 get the viewController based on the iOS versions.
 iOS 14 and above will return the native PHImageViewController
 iOS 13 and below will return a Library Class - GMIMagePickerViewController.
 @param imageSelectionLimit the maximum number of items that can be selected (0 = unlimited)
 @param mediaType the type of media to show ("image", "video", or "all")
 */
-(UIViewController*)getImagePickerViewController:(NSUInteger)imageSelectionLimit mediaType:(NSString*)mediaType {
    NSLog(@"[ActualizeImagePickerUI] getImagePickerViewController: selectionLimit=%lu, mediaType=%@", (unsigned long)imageSelectionLimit, mediaType);

    UIViewController *outViewController = nil;
    // We need two separate implementations for iOS < 14 and iOS >= 14
    // Because iOS provided new APIs for picking multiple images since iOS 14 which works with local and iCloud images very well.
    if (@available(iOS 14, *)) {
        NSLog(@"[ActualizeImagePickerUI] getImagePickerViewController: using PHPickerViewController (iOS 14+)");
        PHPickerConfiguration *config = [[PHPickerConfiguration alloc] init];
        config.selectionLimit = imageSelectionLimit;

        // Set the filter based on mediaType
        if ([mediaType isEqualToString:@"video"]) {
            NSLog(@"[ActualizeImagePickerUI] getImagePickerViewController: filter = video");
            config.filter = [PHPickerFilter videosFilter];
        } else if ([mediaType isEqualToString:@"all"]) {
            NSLog(@"[ActualizeImagePickerUI] getImagePickerViewController: filter = all (images + videos)");
            config.filter = [PHPickerFilter anyFilterMatchingSubfilters:@[
                [PHPickerFilter imagesFilter],
                [PHPickerFilter videosFilter]
            ]];
        } else {
            NSLog(@"[ActualizeImagePickerUI] getImagePickerViewController: filter = images (default)");
            // Default to images only
            config.filter = [PHPickerFilter imagesFilter];
        }

        PHPickerViewController *pickerViewController = [[PHPickerViewController alloc] initWithConfiguration:config];
        pickerViewController.delegate = self;
        NSLog(@"[ActualizeImagePickerUI] getImagePickerViewController: created PHPickerViewController, delegate set to self");

        outViewController = pickerViewController;
    } else {
        NSLog(@"[ActualizeImagePickerUI] getImagePickerViewController: using GMImagePickerController (iOS < 14)");
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
        NSLog(@"[ActualizeImagePickerUI] getImagePickerViewController: created GMImagePickerController");

        outViewController = viewController;
    }
    [outViewController setModalPresentationStyle:UIModalPresentationFullScreen];
    return outViewController;
}

@end
