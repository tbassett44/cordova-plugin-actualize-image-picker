# Actualize Image Picker for Cordova
Simple plugin that implements a very straight-forward native iOS & Android Image/Video Picker, which features:

- Multiple Images/Videos Selection

- Video Picking Support (iOS 14+ and Android 13+)

- Customizable Parameters

- Typescript definitions

- Promisified API interface

# Installation

```bash
cordova plugin add cordova-plugin-actualize-image-picker
```

# Usage

## Pick Single Image/Video
Opens the native single image/video picker, and returns the selected file URI.


**Example**

```typescript
// Pick a single image (default)
const result = await ActualizeImagePicker.pickImage();

if (result.status == "OK") {
    let image = result.imageFileUri;
}

// Pick a single video
const videoResult = await ActualizeImagePicker.pickImage({ mediaType: 'video' });

if (videoResult.status == "OK") {
    let video = videoResult.imageFileUri;
}
```

**Optional Parameters**

```typescript
export interface ActualizeImagePickerSingleConfiguration {
    /**
    * The quality of the images returned by the Image Picker, from 0 to 100 (default = 100)
    */
    imageQuality?: number;
    /**
    * The type of media to pick: "image", "video", or "all" (default = "image")
    */
    mediaType?: "image" | "video" | "all";
}
```

**Result**
```typescript
export interface ActualizeImagePickerSingleResult {
    status: "OK" | "CANCELED";
    imageFileUri?: string;
}
```

## Pick Multiple Images/Videos

Opens the multiple image/video picker, and returns the selected file URIs.

**Example**

```typescript
// Pick multiple images (default)
const result = await ActualizeImagePicker.pickImages();

if (result.status == "OK") {
    let images = result.imageFilesUris;
}

// Pick multiple videos
const videoResult = await ActualizeImagePicker.pickImages({ mediaType: 'video', maxImages: 5 });

if (videoResult.status == "OK") {
    let videos = videoResult.imageFilesUris;
}

// Pick both images and videos
const mixedResult = await ActualizeImagePicker.pickImages({ mediaType: 'all' });

if (mixedResult.status == "OK") {
    let media = mixedResult.imageFilesUris;
}
```

**Optional Parameters**

```typescript
export interface ActualizeImagePickerMultipleConfiguration {
    /**
    * Maximum selectable items. Default is 0 (unlimited).
    */
    maxImages?: number;
    /**
    * The quality of the images returned by the Image Picker, from 0 to 100 (default = 100).
    * Note: This only applies to images, not videos.
    */
    imageQuality?: number;
    /**
    * The type of media to pick: "image", "video", or "all" (default = "image")
    */
    mediaType?: "image" | "video" | "all";
}
```

**Result**

```typescript
export interface ActualizeImagePickerMultipleResult {
    status: "OK" | "CANCELED";
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
- Added video picking support via `mediaType` option (iOS 14+ and Android 13+)

### License

[MIT](LICENSE)
