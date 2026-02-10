/*
    Scanbot Image Picker Cordova Plugin
    Copyright (c) 2021 doo GmbH

    This code is licensed under MIT license (see LICENSE for details)

    Created by Marco Saia on 07.05.2021
*/

#import "ActualizeImagePickerConfiguration.h"

// MARK: - Single Image Picker Configuration
@implementation ActualizeImagePickerSingleConfiguration

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.imageQuality = 100;
        self.mediaType = @"image"; // Default to images only
        self.videoQuality = @"medium"; // Default to medium quality (good compression/quality balance)
        self.videoProcessingMessage = @"Processing video..."; // Default message for progress overlay
    }
    return self;
}

@end

// MARK: - Multiple Image Picker Configuration
@implementation ActualizeImagePickerMultipleConfiguration

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.maxImages = 0;
        self.imageQuality = 100;
        self.mediaType = @"image"; // Default to images only
        self.videoQuality = @"medium"; // Default to medium quality (good compression/quality balance)
        self.videoProcessingMessage = @"Processing video..."; // Default message for progress overlay
    }
    return self;
}

@end
