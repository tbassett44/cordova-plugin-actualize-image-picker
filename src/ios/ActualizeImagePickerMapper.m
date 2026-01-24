/*
    Scanbot Image Picker Cordova Plugin
    Copyright (c) 2021 doo GmbH

    This code is licensed under MIT license (see LICENSE for details)

    Created by Marco Saia on 07.05.2021
*/

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "ActualizeImagePickerMapper.h"

@implementation ActualizeImagePickerMapper

+ (void)populateInstance:(id)instance fromDictionary:(NSDictionary *)dictionary class:(Class)cls {
    uint outCount;
    objc_property_t* properties = class_copyPropertyList(cls, &outCount);
    
    for (uint pi = 0; pi < outCount; ++pi) {
        const char *name = property_getName(properties[pi]);
        NSString* key = [NSString stringWithUTF8String:name];
        
        id value = [dictionary objectForKey:key];
        if (value) {
            [instance setValue:value forKey:key];
        }
    }
    
    free(properties);
}

+ (void)populateInstance:(id)instance
          fromDictionary:(NSDictionary*)dictionary {
    Class cls = [instance class];
    
    while (cls != nil && cls != NSObject.class) {
        [ActualizeImagePickerMapper populateInstance:instance fromDictionary:dictionary class:cls];
        cls = [cls superclass];
    }
}

@end
