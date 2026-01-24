# Actualize Image Picker for Cordova
Simple plugin that implements a very straight-forward native iOS & Android Image Picker, which features:

- Multiple Images Selection

- Customizable Parameters

- Typescript definitions

- Promisified API interface

# Installation

```bash
cordova plugin add cordova-plugin-actualize-image-picker
```

# Usage

## Pick Single Image
Opens the native single image picker, and returns the selected image file URI.


**Example**

```typescript
const result = await ActualizeImagePicker.pickImage();

if (result.status == "OK") {
    let image = result.imageFileUri;
}
```

**Optional Parameters**

```typescript
export interface ActualizeImagePickerSingleConfiguration {
    /**
    * The quality of the images returned by the Image Picker, from 0 to 100 (default = 100)
    */
    imageQuality?:  number;
}
```

**Result**
```typescript
export interface ActualizeImagePickerSingleResult {
    status: "OK"  |  "CANCELED";
    imageFileUri?:  string;
}
```

## Pick Multiple Images

Opens the multiple image picker, and returns the selected image files URIs.

**Example**

```typescript
const result = await ActualizeImagePicker.pickImages();

if (result.status  ==  "OK") {
    let images = result.imageFilesUris;
}
```

**Optional Parameters**

```typescript
export interface ActualizeImagePickerMultipleConfiguration {
    /**
    * Maximum selectable images. Default is 0 (unlimited).
    */
    maxImages?:  number;
    /**
    * The quality of the images returned by the Image Picker, from 0 to 100 (default = 100).
    */
    imageQuality?:  number;
}
```

**Result**

```typescript
export interface ActualizeImagePickerMultipleResult {
    status: "OK"  |  "CANCELED";
    imageFilesUris: string[];
}
```

### Contributing
Contributions in the form of **issues**, **pull requests** and **suggestions** are very welcome. 

### Disclaimer
This package is still in beta and should be used with that in mind.

### Credit
Forked from [Scanbot Image Picker for Cordova](https://github.com/scanbot/cordova-plugin-scanbot-image-picker)

### Modifications
- Added support for Android 11 and 12
- Changed Android Image Picker to use the native Android Photo Picker

### License

[MIT](LICENSE)
