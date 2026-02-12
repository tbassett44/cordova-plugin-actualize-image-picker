/*
    Scanbot Image Picker Cordova Plugin
    Copyright (c) 2021 doo GmbH

    This code is licensed under MIT license (see LICENSE for details)

    Created by Marco Saia on 07.05.2021
*/

#ifndef ActualizeImagePickerConfiguration_h
#define ActualizeImagePickerConfiguration_h

#import <Foundation/Foundation.h>

// Video quality presets for transcoding
// - "low": Highly compressed, suitable for messaging (AVAssetExportPresetLowQuality)
// - "medium": Balanced quality/size (AVAssetExportPreset960x540 or AVAssetExportPresetMediumQuality)
// - "high": High quality (AVAssetExportPreset1280x720)
// - "highest": Maximum quality (AVAssetExportPresetHighestQuality)
// - "passthrough": No transcoding, just copy the file (AVAssetExportPresetPassthrough)

// MARK: - Single Image Picker Configuration
@interface ActualizeImagePickerSingleConfiguration: NSObject
    @property (nonatomic, assign) NSUInteger imageQuality;
    @property (nonatomic, strong) NSString *mediaType; // "image" (default), "video", or "all"
    @property (nonatomic, strong) NSString *videoQuality; // "low", "medium", "high", "highest", "passthrough" (default: "medium") - only used when mediaType includes video
    @property (nonatomic, strong) NSString *videoProcessingMessage; // Message shown during video transcoding (default: "Processing video...") - only used when mediaType includes video
@end

// MARK: - Multiple Image Picker Configuration
@interface ActualizeImagePickerMultipleConfiguration: NSObject
    @property (nonatomic, assign) NSUInteger maxImages;
    @property (nonatomic, assign) NSUInteger imageQuality;
    @property (nonatomic, strong) NSString *mediaType; // "image" (default), "video", or "all"
    @property (nonatomic, strong) NSString *videoQuality; // "low", "medium", "high", "highest", "passthrough" (default: "medium") - only used when mediaType includes video
    @property (nonatomic, strong) NSString *videoProcessingMessage; // Message shown during video transcoding (default: "Processing video...") - only used when mediaType includes video
@end

#endif
