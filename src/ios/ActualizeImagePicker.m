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
    __weak ActualizeImagePicker* _self = self;
    [[ActualizeImagePickerUI shared] startSingleImagePicker:imagePickerConfiguration
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
            NSLog(@"[ActualizeImagePicker] pickImage: SUCCESS - returning URI");
            result[@"status"] = @"OK";
            result[@"imageFileUri"] = imageFileUri;
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
                [filteredUris addObject:uri];
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

@end
