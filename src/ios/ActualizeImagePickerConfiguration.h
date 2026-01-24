/*
    Scanbot Image Picker Cordova Plugin
    Copyright (c) 2021 doo GmbH

    This code is licensed under MIT license (see LICENSE for details)

    Created by Marco Saia on 07.05.2021
*/

#ifndef ActualizeImagePickerConfiguration_h
#define ActualizeImagePickerConfiguration_h

// MARK: - Single Image Picker Configuration
@interface ActualizeImagePickerSingleConfiguration: NSObject
    @property (nonatomic, assign) NSUInteger imageQuality;
@end

// MARK: - Multiple Image Picker Configuration
@interface ActualizeImagePickerMultipleConfiguration: NSObject
    @property (nonatomic, assign) NSUInteger maxImages;
    @property (nonatomic, assign) NSUInteger imageQuality;
@end

#endif
