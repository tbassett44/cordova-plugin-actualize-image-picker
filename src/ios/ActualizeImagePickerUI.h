/*
    Scanbot Image Picker Cordova Plugin
    Copyright (c) 2021 doo GmbH

    This code is licensed under MIT license (see LICENSE for details)

    Created by Marco Saia on 07.05.2021
*/

#ifndef ActualizeImagePickerUI_h
#define ActualizeImagePickerUI_h
#import <GMImagePickerWithCloudMediaDownloading/GMImagePickerController.h>
#import <Photos/Photos.h>
#import <PhotosUI/PhotosUI.h>
@import UIKit;
@import Foundation;
@import AVFoundation;

#import "ActualizeImagePickerConfiguration.h"

typedef void (^SingleImagePickerCompletionBlock)(BOOL, NSString*);
typedef void (^MultipleImagePickerCompletionBlock)(BOOL, NSArray*);
typedef void (^VideoTranscodeCompletionBlock)(NSURL* _Nullable outputUrl, NSError* _Nullable error);
static NSString *const Error_IOS_13 = @"iOS13_ImageManager_returned_nil";

@interface ActualizeImagePickerUI: NSObject<GMImagePickerControllerDelegate, PHPickerViewControllerDelegate>

/// Returns shared ActualizeImagePickerUI instance
+ (ActualizeImagePickerUI *)shared;

/// Debug method to verify implementation is linked
- (void)debugTest;

/// Starts an Image Picker to select just one image
/// @param configuration the desired configuration, of type ActualizeImagePickerSingleConfiguration
/// @param completion block function for handling the result (isCanceled: BOOL, imageFileUri: NSString*)
- (void) startSingleImagePicker:(ActualizeImagePickerSingleConfiguration*) configuration
                     completion:(SingleImagePickerCompletionBlock) completion;

/// Starts an Image Picker to select multiple images
/// @param configuration the desired configuration, of type ActualizeImagePickerMultipleConfiguration
/// @param completion block function for handling the result (isCanceled: BOOL, imageFilesUris: NSArray*)
- (void) startMultipleImagePicker:(ActualizeImagePickerMultipleConfiguration*) configuration
                       completion:(MultipleImagePickerCompletionBlock) completion;

/// Get the imagePicker viewController instance based on iOS version.
/// @param imageSelectionLimit the maximum number of items that can be selected (0 = unlimited)
/// @param mediaType the type of media to show ("image", "video", or "all")
- (UIViewController*)getImagePickerViewController:(NSUInteger)imageSelectionLimit mediaType:(NSString*)mediaType;

/// Transcode a video to MP4 format with compression
/// @param sourceUrl the source video URL
/// @param quality the quality preset ("low", "medium", "high", "highest", "passthrough")
/// @param completion block called when transcoding completes with output URL or error
- (void)transcodeVideoToMp4:(NSURL*)sourceUrl
                    quality:(NSString*)quality
                 completion:(VideoTranscodeCompletionBlock)completion;
@end

#endif
