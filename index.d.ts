/*
    Scanbot Image Picker Cordova Plugin
    Copyright (c) 2021 doo GmbH

    This code is licensed under MIT license (see LICENSE for details)

    Created by Marco Saia on 07.05.2021
*/

///// Base Cordova API
export type ActualizeImagePickerStatus = "OK" | "CANCELED";

// Configurations
export interface ActualizeImagePickerSingleConfiguration {
    /**
     * The quality of the images returned by the Image Picker, from 0 to 1 (default = 1.0)
     */
    imageQuality?: number;
}

export interface ActualizeImagePickerMultipleConfiguration {
    /**
     * Maximum selectable images. Default is 0 (unlimited).
     */
    maxImages?: number;   
    /**
     * The quality of the images returned by the Image Picker, from 0 to 1 (default = 1.0)
     */
    imageQuality?: number;
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
    pickImage(configuration?: ActualizeImagePickerSingleConfiguration): Promise ActualizeImagePickerGenericResult & ActualizeImagePickerSingleResult>;
    pickImages(configuration?: ActualizeImagePickerMultipleConfiguration): Promise ActualizeImagePickerGenericResult & ActualizeImagePickerMultipleResult>;
}

declare let ActualizeImagePicker: ActualizeImagePickerModule;

export default ActualizeImagePicker;
