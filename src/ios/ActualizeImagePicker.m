/*
 Scanbot Image Picker Cordova Plugin
 Copyright (c) 2021 doo GmbH
 
 This code is licensed under MIT license (see LICENSE for details)
 
 Created by Marco Saia on 07.05.2021
 */
#import <Cordova/CDV.h>
//#import <GMImagePickerWithCloudMediaDownloading/GMImagePickerController.h>
#import <Foundation/Foundation.h>
#import "ActualizeImagePickerMapper.h"
#import "ActualizeImagePickerConfiguration.h"
#import "ActualizeImagePickerUI.h"

@interface ActualizeImagePicker : CDVPlugin //<GMImagePickerControllerDelegate>
/**pick single image from photo gallery*/
- (void)pickImage:(CDVInvokedUrlCommand*)command;
/**pick multiple images from photo gallery*/
- (void)pickImages:(CDVInvokedUrlCommand*)command;
@end

@implementation ActualizeImagePicker

- (void)pickImage:(CDVInvokedUrlCommand*)command {
    NSLog(@"[ActualizeImagePicker] pickImage: called");

    // Creates Single Image Picker Configuration
    NSDictionary* configuration = [self getConfigDictionary:command];
    NSLog(@"[ActualizeImagePicker] pickImage: configuration = %@", configuration);

    ActualizeImagePickerSingleConfiguration* imagePickerConfiguration = [[ActualizeImagePickerSingleConfiguration alloc] init];

    @try {
        [ActualizeImagePickerMapper populateInstance:imagePickerConfiguration fromDictionary:configuration];
        NSLog(@"[ActualizeImagePicker] pickImage: configuration parsed successfully");
    }
    @catch (NSException* ex) {
        NSLog(@"[ActualizeImagePicker] pickImage: ERROR parsing configuration: %@", [ex reason]);
        [self reportError:[ex reason] toCommand:command];
        return;
    }

    // Starts Single Image Picker and returns result
    NSLog(@"[ActualizeImagePicker] pickImage: starting single image picker");

    ActualizeImagePickerUI* pickerUI = [ActualizeImagePickerUI shared];
    NSLog(@"[ActualizeImagePicker] pickImage: got shared instance = %@", pickerUI);

    if (!pickerUI) {
        NSLog(@"[ActualizeImagePicker] pickImage: ERROR - shared instance is nil!");
        [self reportError:@"Image picker UI instance is nil" toCommand:command];
        return;
    }

    // Debug test to verify implementation is linked
    [pickerUI debugTest];
    NSLog(@"[ActualizeImagePicker] pickImage: debugTest called, now calling startSingleImagePicker");

    __weak ActualizeImagePicker* _self = self;
    [pickerUI startSingleImagePicker:imagePickerConfiguration
                          completion:^(BOOL isCanceled, NSString* imageFileUri) {
        NSLog(@"[ActualizeImagePicker] pickImage: completion callback - isCanceled=%d, imageFileUri=%@", isCanceled, imageFileUri);

        if (isCanceled) {
            NSLog(@"[ActualizeImagePicker] pickImage: user canceled");
            [_self reportCanceled:command];
            return;
        }

        NSMutableDictionary* result = [[NSMutableDictionary alloc] init];
        if ([imageFileUri isEqualToString:@""] || [imageFileUri isEqualToString:Error_IOS_13]) {
            NSLog(@"[ActualizeImagePicker] pickImage: FAILED - empty or error URI");
            result[@"status"] = @"FAILED";
            result[@"message"] = @"Unable to select the image.";
        } else {
            NSLog(@"[ActualizeImagePicker] pickImage: SUCCESS - converting URI for WKWebView");
            // Convert file:// URL to data: URL for WKWebView compatibility
            NSString *convertedUri = [_self convertFileUriToDataUri:imageFileUri];
            result[@"status"] = @"OK";
            result[@"imageFileUri"] = convertedUri;
        }

        NSLog(@"[ActualizeImagePicker] pickImage: sending result = %@", result);
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary: result];
        [_self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
    NSLog(@"[ActualizeImagePicker] pickImage: startSingleImagePicker called");
}


- (void)pickImages:(CDVInvokedUrlCommand*)command {
    NSLog(@"[ActualizeImagePicker] pickImages: called");

    // Creates Multiple Image Picker Configuration
    NSDictionary* configuration = [self getConfigDictionary:command];
    NSLog(@"[ActualizeImagePicker] pickImages: configuration = %@", configuration);

    ActualizeImagePickerMultipleConfiguration* imagePickerConfiguration = [[ActualizeImagePickerMultipleConfiguration alloc] init];

    @try {
        [ActualizeImagePickerMapper populateInstance:imagePickerConfiguration fromDictionary:configuration];
        NSLog(@"[ActualizeImagePicker] pickImages: configuration parsed successfully");
    }
    @catch (NSException* ex) {
        NSLog(@"[ActualizeImagePicker] pickImages: ERROR parsing configuration: %@", [ex reason]);
        [self reportError:[ex reason] toCommand:command];
        return;
    }

    // Starts Multiple Image Picker and returns result
    NSLog(@"[ActualizeImagePicker] pickImages: starting multiple image picker");
    __weak ActualizeImagePicker* _self = self;
    [[ActualizeImagePickerUI shared] startMultipleImagePicker:imagePickerConfiguration
                                                 completion:^(BOOL isCanceled, NSArray* imageFilesUris) {
        NSLog(@"[ActualizeImagePicker] pickImages: completion callback - isCanceled=%d, count=%lu", isCanceled, (unsigned long)imageFilesUris.count);

        if (isCanceled) {
            NSLog(@"[ActualizeImagePicker] pickImages: user canceled");
            [_self reportCanceled:command];
            return;
        }

        NSMutableDictionary* result = [[NSMutableDictionary alloc] init];
        NSMutableArray *filteredUris = [[NSMutableArray alloc] init];
        BOOL isError = false;
        for (NSString *uri in imageFilesUris) {
            if ([uri isEqualToString:Error_IOS_13] || [uri isEqualToString:@""]){
                isError = true;
            } else {
                // Convert file:// URL to data: URL for WKWebView compatibility
                NSString *convertedUri = [_self convertFileUriToDataUri:uri];
                [filteredUris addObject:convertedUri];
            }
        }

        result[@"status"] = @"OK";
        result[@"imageFilesUris"] = filteredUris;
        if (isError) {
            result[@"message"] = @"Unable to select at least one of the images.";
        }

        NSLog(@"[ActualizeImagePicker] pickImages: sending result with %lu URIs", (unsigned long)filteredUris.count);
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:result];
        [_self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
    NSLog(@"[ActualizeImagePicker] pickImages: startMultipleImagePicker called");
}

- (NSDictionary*) getConfigDictionary:(CDVInvokedUrlCommand*)command {
    NSDictionary* arguments = command.arguments.count > 0 ? [command.arguments objectAtIndex: 0] : NULL;
    if (!arguments) {
        arguments = @{};
    }
    return arguments;
}

- (void)reportError:(NSString*)errorString toCommand:(CDVInvokedUrlCommand*)command {
    CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errorString];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

- (void)reportCanceled:(CDVInvokedUrlCommand*)command {
    CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:@{
        @"status": @"CANCELED"
    }];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

/// Converts a file:// URL to a base64 data URL for WKWebView compatibility
/// @param fileUri the file:// URL string
/// @return a data:image/jpeg;base64,... URL string, or the original URI if conversion fails
- (NSString*)convertFileUriToDataUri:(NSString*)fileUri {
    if (!fileUri || fileUri.length == 0) {
        return fileUri;
    }

    // Check if it's a file URL
    if (![fileUri hasPrefix:@"file://"]) {
        return fileUri; // Return as-is if not a file URL
    }

    // Check if it's a video file (don't convert videos to base64)
    NSString *lowercaseUri = [fileUri lowercaseString];
    if ([lowercaseUri hasSuffix:@".mp4"] || [lowercaseUri hasSuffix:@".mov"] ||
        [lowercaseUri hasSuffix:@".m4v"] || [lowercaseUri hasSuffix:@".avi"]) {
        return fileUri; // Return video URLs as-is
    }

    @try {
        NSURL *fileURL = [NSURL URLWithString:fileUri];
        if (!fileURL) {
            NSLog(@"[ActualizeImagePicker] convertFileUriToDataUri: failed to create URL from %@", fileUri);
            return fileUri;
        }

        NSData *imageData = [NSData dataWithContentsOfURL:fileURL];
        if (!imageData) {
            NSLog(@"[ActualizeImagePicker] convertFileUriToDataUri: failed to read data from %@", fileUri);
            return fileUri;
        }

        NSString *base64String = [imageData base64EncodedStringWithOptions:0];
        NSString *mimeType = @"image/jpeg"; // Default to JPEG

        // Check file extension for mime type
        if ([lowercaseUri hasSuffix:@".png"]) {
            mimeType = @"image/png";
        } else if ([lowercaseUri hasSuffix:@".gif"]) {
            mimeType = @"image/gif";
        } else if ([lowercaseUri hasSuffix:@".heic"] || [lowercaseUri hasSuffix:@".heif"]) {
            mimeType = @"image/heic";
        }

        NSString *dataUri = [NSString stringWithFormat:@"data:%@;base64,%@", mimeType, base64String];
        NSLog(@"[ActualizeImagePicker] convertFileUriToDataUri: converted to data URI (length=%lu)", (unsigned long)dataUri.length);
        return dataUri;
    }
    @catch (NSException *exception) {
        NSLog(@"[ActualizeImagePicker] convertFileUriToDataUri: exception - %@", exception.reason);
        return fileUri;
    }
}

@end
