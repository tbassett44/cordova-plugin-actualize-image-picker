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
    
    // Creates Single Image Picker Configuration
    NSDictionary* configuration = [self getConfigDictionary:command];
    ActualizeImagePickerSingleConfiguration* imagePickerConfiguration = [[ActualizeImagePickerSingleConfiguration alloc] init];
    
    @try {
        [ActualizeImagePickerMapper populateInstance:imagePickerConfiguration fromDictionary:configuration];
    }
    @catch (NSException* ex) {
        [self reportError:[ex reason] toCommand:command];
        return;
    }
    
    // Starts Single Image Picker and returns result
    __weak ActualizeImagePicker* _self = self;
    [[ActualizeImagePickerUI shared] startSingleImagePicker:imagePickerConfiguration
                                               completion:^(BOOL isCanceled, NSString* imageFileUri) {
        
        if (isCanceled) {
            [_self reportCanceled:command];
            return;
        }
        
        NSMutableDictionary* result = [[NSMutableDictionary alloc] init];
        if ([imageFileUri isEqualToString:@""] || [imageFileUri isEqualToString:Error_IOS_13]) {
            result[@"status"] = @"FAILED";
            result[@"message"] = @"Unable to select the image.";
        } else {
            result[@"status"] = @"OK";
            result[@"imageFileUri"] = imageFileUri;
        }
        
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary: result];
        [_self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}


- (void)pickImages:(CDVInvokedUrlCommand*)command {
    
    // Creates Multiple Image Picker Configuration
    NSDictionary* configuration = [self getConfigDictionary:command];
    ActualizeImagePickerMultipleConfiguration* imagePickerConfiguration = [[ActualizeImagePickerMultipleConfiguration alloc] init];
    
    @try {
        [ActualizeImagePickerMapper populateInstance:imagePickerConfiguration fromDictionary:configuration];
    }
    @catch (NSException* ex) {
        [self reportError:[ex reason] toCommand:command];
        return;
    }
    
    // Starts Multiple Image Picker and returns result
    __weak ActualizeImagePicker* _self = self;
    [[ActualizeImagePickerUI shared] startMultipleImagePicker:imagePickerConfiguration
                                                 completion:^(BOOL isCanceled, NSArray* imageFilesUris) {
        
        if (isCanceled) {
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
        
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:result];
        [_self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
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
