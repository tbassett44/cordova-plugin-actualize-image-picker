/*
    Scanbot Image Picker Cordova Plugin
    Copyright (c) 2021 doo GmbH

    This code is licensed under MIT license (see LICENSE for details)

    Created by Marco Saia on 07.05.2021
*/

///// Base Cordova API
export type ActualizeImagePickerStatus = "OK" | "CANCELED";

// Media type for the picker
export type ActualizeImagePickerMediaType = "image" | "video" | "all";

// Video quality preset for transcoding
// - "low": Highly compressed, suitable for messaging
// - "medium": Balanced quality/size (default)
// - "high": High quality (720p)
// - "highest": Maximum quality
// - "passthrough": No transcoding, just copy the file
export type ActualizeImagePickerVideoQuality = "low" | "medium" | "high" | "highest" | "passthrough";

// Configurations
export interface ActualizeImagePickerSingleConfiguration {
    /**
     * The quality of the images returned by the Image Picker, from 0 to 100 (default = 100)
     */
    imageQuality?: number;
    /**
     * The type of media to pick: "image", "video", or "all" (default = "image")
     */
    mediaType?: ActualizeImagePickerMediaType;
    /**
     * The quality preset for video transcoding (default = "medium")
     * - "low": Highly compressed, suitable for messaging
     * - "medium": Balanced quality/size
     * - "high": High quality (720p)
     * - "highest": Maximum quality
     * - "passthrough": No transcoding, just copy the file
     */
    videoQuality?: ActualizeImagePickerVideoQuality;
    /**
     * The message shown in the progress overlay during video transcoding (default = "Processing video...")
     * Only applies to iOS. On Android, videos are currently copied without transcoding.
     */
    videoProcessingMessage?: string;
}

export interface ActualizeImagePickerMultipleConfiguration {
    /**
     * Maximum selectable items. Default is 0 (unlimited).
     */
    maxImages?: number;
    /**
     * The quality of the images returned by the Image Picker, from 0 to 100 (default = 100)
     */
    imageQuality?: number;
    /**
     * The type of media to pick: "image", "video", or "all" (default = "image")
     */
    mediaType?: ActualizeImagePickerMediaType;
    /**
     * The quality preset for video transcoding (default = "medium")
     * - "low": Highly compressed, suitable for messaging
     * - "medium": Balanced quality/size
     * - "high": High quality (720p)
     * - "highest": Maximum quality
     * - "passthrough": No transcoding, just copy the file
     */
    videoQuality?: ActualizeImagePickerVideoQuality;
    /**
     * The message shown in the progress overlay during video transcoding (default = "Processing video...")
     * Only applies to iOS. On Android, videos are currently copied without transcoding.
     */
    videoProcessingMessage?: string;
}

// Results
export interface ActualizeImagePickerGenericResult {
    status: ActualizeImagePickerStatus;
    message?: string;
}

export interface ActualizeImagePickerSingleResult {
    imageFileUri?: string;
}

export interface ActualizeImagePickerMultipleResult {
    imageFilesUris: string[];
}

export interface ActualizeImagePickerModule {
    pickImage(configuration?: ActualizeImagePickerSingleConfiguration): Promise<ActualizeImagePickerGenericResult & ActualizeImagePickerSingleResult>;
    pickImages(configuration?: ActualizeImagePickerMultipleConfiguration): Promise<ActualizeImagePickerGenericResult & ActualizeImagePickerMultipleResult>;
}

declare let ActualizeImagePicker: ActualizeImagePickerModule;

export default ActualizeImagePicker;
