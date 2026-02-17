/*
    Scanbot Image Picker Cordova Plugin
    Copyright (c) 2021 doo GmbH

    This code is licensed under MIT license (see LICENSE for details)

    Created by Marco Saia on 07.05.2021
    Updated 2026 to use Android Jetpack Photo Picker
*/
package earth.actualize.cordova.plugin;

import android.app.Activity;
import android.content.ClipData;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Matrix;
import android.net.Uri;
import android.os.Build;
import android.provider.MediaStore;

import androidx.activity.result.ActivityResult;
import androidx.activity.result.ActivityResultCallback;
import androidx.activity.result.ActivityResultLauncher;
import androidx.activity.result.contract.ActivityResultContracts;
import androidx.appcompat.app.AppCompatActivity;
import androidx.exifinterface.media.ExifInterface;

import org.apache.cordova.CordovaInterface;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CordovaWebView;
import org.apache.cordova.CallbackContext;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

import earth.actualize.cordova.plugin.utils.JsonArgs;

public class ActualizeImagePicker extends CordovaPlugin {

    private CallbackContext callbackContext;
    private int imageQuality = 100;
    private int maxImages = 0;
    private String mediaType = "image"; // "image", "video", or "all"
    private String videoQuality = "medium"; // "low", "medium", "high", "highest", "passthrough"
    private String videoProcessingMessage = "Processing video..."; // Message for progress overlay (reserved for future use)

    // ActivityResultLaunchers for the modern activity result API
    private ActivityResultLauncher<Intent> singleImageLauncher;
    private ActivityResultLauncher<Intent> multipleImageLauncher;

    @Override
    public void initialize(CordovaInterface cordova, CordovaWebView webView) {
        super.initialize(cordova, webView);

        android.util.Log.d("ActualizeImagePicker", "initialize: registering ActivityResultLaunchers");

        // Get the activity and cast to AppCompatActivity (required for registerForActivityResult)
        Activity activity = cordova.getActivity();
        if (!(activity instanceof AppCompatActivity)) {
            android.util.Log.e("ActualizeImagePicker", "Activity is not an AppCompatActivity, ActivityResultLauncher may not work");
            return;
        }

        AppCompatActivity appCompatActivity = (AppCompatActivity) activity;

        // Register single image picker launcher
        singleImageLauncher = appCompatActivity.registerForActivityResult(
            new ActivityResultContracts.StartActivityForResult(),
            new ActivityResultCallback<ActivityResult>() {
                @Override
                public void onActivityResult(ActivityResult result) {
                    android.util.Log.d("ActualizeImagePicker", "singleImageLauncher callback: resultCode=" + result.getResultCode());
                    handleSingleImageResult(result);
                }
            }
        );

        // Register multiple image picker launcher
        multipleImageLauncher = appCompatActivity.registerForActivityResult(
            new ActivityResultContracts.StartActivityForResult(),
            new ActivityResultCallback<ActivityResult>() {
                @Override
                public void onActivityResult(ActivityResult result) {
                    android.util.Log.d("ActualizeImagePicker", "multipleImageLauncher callback: resultCode=" + result.getResultCode());
                    handleMultipleImageResult(result);
                }
            }
        );

        android.util.Log.d("ActualizeImagePicker", "initialize: ActivityResultLaunchers registered successfully");
    }

    @Override
    public boolean execute(String action, JSONArray args, CallbackContext callbackContext) throws JSONException {

        final JSONObject jsonArgs = (args.length() > 0 ? args.getJSONObject(0) : new JSONObject());

        this.callbackContext = callbackContext;

        switch(action) {
            case "pickImage":
                startSingleImagePicker(jsonArgs);
                break;

            case "pickImages":
                startMultipleImagePicker(jsonArgs);
                break;

            default:
                return false;
        }

        return true;
    }

    /**
     * Opens the Android Photo Picker for single-image/video selection
     * Uses the native Jetpack Photo Picker on Android 11+ or falls back to ACTION_OPEN_DOCUMENT
     * @param args Map of optional arguments for customisation
     */
    private void startSingleImagePicker(final JSONObject args) {
        try {
            this.imageQuality = args.getInt("imageQuality");
        } catch (Exception ignored) {}

        try {
            this.mediaType = args.getString("mediaType");
        } catch (Exception ignored) {
            this.mediaType = "image";
        }

        try {
            this.videoQuality = args.getString("videoQuality");
        } catch (Exception ignored) {
            this.videoQuality = "medium";
        }

        try {
            this.videoProcessingMessage = args.getString("videoProcessingMessage");
        } catch (Exception ignored) {
            this.videoProcessingMessage = "Processing video...";
        }

        String mimeType = getMimeTypeForMediaType(this.mediaType);
        Intent intent;

        android.util.Log.d("ActualizeImagePicker", "startSingleImagePicker: mediaType=" + this.mediaType + ", mimeType=" + mimeType);
        android.util.Log.d("ActualizeImagePicker", "startSingleImagePicker: SDK_INT=" + Build.VERSION.SDK_INT);

        // Use the native photo picker on Android 11+ (API 30+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            // Android 13+ - Use MediaStore.ACTION_PICK_IMAGES
            android.util.Log.d("ActualizeImagePicker", "startSingleImagePicker: using ACTION_PICK_IMAGES (Android 13+)");
            intent = new Intent(MediaStore.ACTION_PICK_IMAGES);
            intent.setType(mimeType);
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            // Android 11-12 - Photo picker may be available via backport
            android.util.Log.d("ActualizeImagePicker", "startSingleImagePicker: using ACTION_OPEN_DOCUMENT (Android 11-12)");
            intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
            intent.addCategory(Intent.CATEGORY_OPENABLE);
            intent.setType(mimeType);
        } else {
            // Fallback for older Android versions
            android.util.Log.d("ActualizeImagePicker", "startSingleImagePicker: using ACTION_OPEN_DOCUMENT (older Android)");
            intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
            intent.addCategory(Intent.CATEGORY_OPENABLE);
            intent.setType(mimeType);
        }

        android.util.Log.d("ActualizeImagePicker", "startSingleImagePicker: launching with ActivityResultLauncher");
        if (singleImageLauncher != null) {
            singleImageLauncher.launch(intent);
        } else {
            android.util.Log.e("ActualizeImagePicker", "singleImageLauncher is null - plugin may not have been initialized properly");
            callbackContext.error("Image picker not initialized. Please ensure the plugin is properly configured.");
        }
    }

    /**
     * Opens the Android Photo Picker for multi-image/video selection
     * Uses the native Jetpack Photo Picker on Android 13+ or falls back to ACTION_OPEN_DOCUMENT with EXTRA_ALLOW_MULTIPLE
     * @param args Map of optional arguments for customisation
     */
    private void startMultipleImagePicker(final JSONObject args) {
        try {
            this.maxImages = args.getInt("maxImages");
        } catch (Exception ignored) {
            this.maxImages = 0;
        }

        try {
            this.imageQuality = args.getInt("imageQuality");
        } catch (Exception ignored) {}

        try {
            this.mediaType = args.getString("mediaType");
        } catch (Exception ignored) {
            this.mediaType = "image";
        }

        try {
            this.videoQuality = args.getString("videoQuality");
        } catch (Exception ignored) {
            this.videoQuality = "medium";
        }

        try {
            this.videoProcessingMessage = args.getString("videoProcessingMessage");
        } catch (Exception ignored) {
            this.videoProcessingMessage = "Processing video...";
        }

        String mimeType = getMimeTypeForMediaType(this.mediaType);
        Intent intent;

        // Use the native photo picker on Android 13+ (API 33+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            // Android 13+ - Use MediaStore.ACTION_PICK_IMAGES with multiple selection
            intent = new Intent(MediaStore.ACTION_PICK_IMAGES);
            intent.setType(mimeType);
            // Set max selection limit if specified
            if (maxImages > 0) {
                intent.putExtra(MediaStore.EXTRA_PICK_IMAGES_MAX, Math.min(maxImages, MediaStore.getPickImagesMaxLimit()));
            }else{
                intent.putExtra(MediaStore.EXTRA_PICK_IMAGES_MAX, MediaStore.getPickImagesMaxLimit());
            }
        } else {
            // Fallback for older Android versions - use ACTION_OPEN_DOCUMENT with EXTRA_ALLOW_MULTIPLE
            intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
            intent.addCategory(Intent.CATEGORY_OPENABLE);
            intent.setType(mimeType);
            intent.putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true);
        }

        android.util.Log.d("ActualizeImagePicker", "startMultipleImagePicker: launching with ActivityResultLauncher");
        if (multipleImageLauncher != null) {
            multipleImageLauncher.launch(intent);
        } else {
            android.util.Log.e("ActualizeImagePicker", "multipleImageLauncher is null - plugin may not have been initialized properly");
            callbackContext.error("Image picker not initialized. Please ensure the plugin is properly configured.");
        }
    }

    /**
     * Handles the result from the single image picker ActivityResultLauncher.
     * @param result the ActivityResult from the launcher
     */
    private void handleSingleImageResult(ActivityResult result) {
        int resultCode = result.getResultCode();
        Intent intent = result.getData();

        android.util.Log.d("ActualizeImagePicker", "handleSingleImageResult: resultCode=" + resultCode + ", intent=" + intent);

        // Check if we have a valid callback context
        if (this.callbackContext == null) {
            android.util.Log.e("ActualizeImagePicker", "handleSingleImageResult: callbackContext is null!");
            return;
        }

        final boolean isCanceled = resultCode != Activity.RESULT_OK;
        android.util.Log.d("ActualizeImagePicker", "handleSingleImageResult: isCanceled=" + isCanceled);

        if (isCanceled) {
            android.util.Log.d("ActualizeImagePicker", "Single picker canceled");
            handleSingleImagePickerResult(true, null);
            return;
        }
        if (intent == null || intent.getData() == null) {
            android.util.Log.d("ActualizeImagePicker", "Single picker: intent or data is null");
            handleSingleImagePickerResult(true, null);
            return;
        }
        android.util.Log.d("ActualizeImagePicker", "Single picker success: " + intent.getData().toString());
        handleSingleImagePickerResult(false, intent.getData().toString());
    }

    /**
     * Handles the result from the multiple image picker ActivityResultLauncher.
     * @param result the ActivityResult from the launcher
     */
    private void handleMultipleImageResult(ActivityResult result) {
        int resultCode = result.getResultCode();
        Intent intent = result.getData();

        android.util.Log.d("ActualizeImagePicker", "handleMultipleImageResult: resultCode=" + resultCode + ", intent=" + intent);

        // Check if we have a valid callback context
        if (this.callbackContext == null) {
            android.util.Log.e("ActualizeImagePicker", "handleMultipleImageResult: callbackContext is null!");
            return;
        }

        final boolean isCanceled = resultCode != Activity.RESULT_OK;
        android.util.Log.d("ActualizeImagePicker", "handleMultipleImageResult: isCanceled=" + isCanceled);

        if (isCanceled) {
            android.util.Log.d("ActualizeImagePicker", "Multiple picker canceled");
            handleMultipleImagePickerResult(true, new String[]{});
            return;
        }

        List<String> uriList = new ArrayList<>();

        if (intent != null) {
            // Check for multiple selection via ClipData
            ClipData clipData = intent.getClipData();
            if (clipData != null) {
                int count = clipData.getItemCount();
                android.util.Log.d("ActualizeImagePicker", "Multiple picker: clipData count=" + count);
                // Apply maxImages limit if set
                if (maxImages > 0 && count > maxImages) {
                    count = maxImages;
                }
                for (int i = 0; i < count; i++) {
                    Uri uri = clipData.getItemAt(i).getUri();
                    if (uri != null) {
                        uriList.add(uri.toString());
                    }
                }
            } else if (intent.getData() != null) {
                // Single selection fallback
                android.util.Log.d("ActualizeImagePicker", "Multiple picker: single data=" + intent.getData().toString());
                uriList.add(intent.getData().toString());
            }
        }

        android.util.Log.d("ActualizeImagePicker", "Multiple picker success: " + uriList.size() + " items");
        handleMultipleImagePickerResult(false, uriList.toArray(new String[0]));
    }

    /**--------------------------------
     *        RESULTS HANDLING
     *---------------------------------

     /**
     * Handles Single Image/Video Picker's result and returns the JSON data to Cordova JS
     * @param isCanceled true if the operation was canceled by the user, false otherwise
     * @param mediaFileUri the URI of the selected file
     */
    private void handleSingleImagePickerResult(final boolean isCanceled, final String mediaFileUri) {
        if (isCanceled) {
            callbackContext.success(new JsonArgs().put("status", "CANCELED").jsonObj());
            return;
        }

        if (mediaFileUri == null) {
            callbackContext.error("Found null 'mediaFileUri' in handleSingleImagePickerResult");
            return;
        }

        // Always process the media to convert content URI to accessible local file
        final String outputPath = copyMediaToLocal(mediaFileUri, this.imageQuality);
        if (outputPath == null) {
            callbackContext.error("Failed to process media file");
            return;
        }
        final String outputUri = Uri.fromFile(new File(outputPath)).toString();

        JsonArgs outResult = new JsonArgs();
        outResult.put("status", "OK");
        outResult.put("imageFileUri", outputUri);
        callbackContext.success(outResult.jsonObj());
    }

    /**
     * Handles Multiple Image/Video Picker's result and returns the JSON data to Cordova JS
     * @param isCanceled true if the operation was canceled by the user, false otherwise
     * @param mediaFilesUris an array containing the file URIs for all the media selected
     */
    private void handleMultipleImagePickerResult(final boolean isCanceled, final String[] mediaFilesUris) {
        if (isCanceled) {
            callbackContext.success(new JsonArgs().put("status", "CANCELED").jsonObj());
            return;
        }

        JSONArray mediaUris = new JSONArray();
        for(String path : mediaFilesUris) {
            // Always process the media to convert content URI to accessible local file
            String outPath = copyMediaToLocal(path, this.imageQuality);
            if (outPath == null) {
                // Skip media files that failed to process
                continue;
            }
            try {
                final String mediaUri = Uri.fromFile(new File(outPath)).toString();
                mediaUris.put(mediaUri);
            } catch(Exception e) {
                e.printStackTrace();
            }
        }

        JsonArgs outResult = new JsonArgs();

        outResult.put("status", "OK");
        outResult.put("imageFilesUris", mediaUris);

        callbackContext.success(outResult.jsonObj());
    }

    /**--------------------------------
     *    PRIVATE UTILITY FUNCTIONS
     *---------------------------------
    /**
     * Copies the image from a content URI to a local file path, applying the specified quality.
     * This is necessary because content URIs from the photo picker may not be directly accessible
     * by Cordova's FileTransfer plugin.
     *
     * @param imagePath the content URI or path of the original image
     * @param quality the desired quality for the output image (from 0 to 100)
     * @return the path of the local image file, or null in case of failure
     */
    private String copyImageToLocal(final String imagePath, final int quality) {
        try {
            // Retrieves Bitmap
            final Uri imageUri = Uri.parse(imagePath);
            Bitmap originalBitmap = null;

            if (imagePath.startsWith("content:/")) {
                originalBitmap = MediaStore.Images.Media.getBitmap(this.cordova.getContext().getContentResolver(), imageUri);
            } else {
                originalBitmap = BitmapFactory.decodeFile(imageUri.getPath(), new BitmapFactory.Options());
            }

            if (originalBitmap == null) {
                throw new IOException("Could not load image. Bitmap is null");
            }

            // Compresses Bitmap
            final ByteArrayOutputStream decodeStream = new ByteArrayOutputStream();
            originalBitmap.compress(Bitmap.CompressFormat.JPEG, quality, decodeStream);

            // Decides Output Path
            final String outputFileName = String.format(Locale.US, "%d.jpg", imagePath.hashCode());
            final File outputDir = cordova.getActivity().getCacheDir();
            final String outputPath = outputDir + "/" + outputFileName;

            // Saves File
            final OutputStream tmpStream = new FileOutputStream(outputPath);
            decodeStream.writeTo(tmpStream);
            decodeStream.close();
            tmpStream.close();

            // Corrects the image rotation using bitmap metadata, if necessary
            final Bitmap bitmap = handleImageRotation(imagePath, originalBitmap);
            final OutputStream outputStream = new FileOutputStream(outputPath);
            bitmap.compress(Bitmap.CompressFormat.JPEG, 100, outputStream);
            outputStream.close();

            return outputPath;
        } catch (Exception e) {
            e.printStackTrace();
            return null;
        }
    }

    private Bitmap handleImageRotation(String imagePath, Bitmap bitmap) {

        Bitmap rotatedBitmap = null;
        try {

            ExifInterface ei;

            if (imagePath.startsWith("content:/")) {
                InputStream inputStream = cordova
                        .getContext()
                        .getContentResolver()
                        .openInputStream(Uri.parse(imagePath));

                ei = new ExifInterface(inputStream);
            } else {
                ei = new ExifInterface(imagePath);
            }

            int orientation = ei.getAttributeInt(ExifInterface.TAG_ORIENTATION,
                    ExifInterface.ORIENTATION_UNDEFINED);

            switch (orientation) {

                case ExifInterface.ORIENTATION_ROTATE_90:
                    rotatedBitmap = rotateImage(bitmap, 90);
                    break;

                case ExifInterface.ORIENTATION_ROTATE_180:
                    rotatedBitmap = rotateImage(bitmap, 180);
                    break;

                case ExifInterface.ORIENTATION_ROTATE_270:
                    rotatedBitmap = rotateImage(bitmap, 270);
                    break;

                case ExifInterface.ORIENTATION_NORMAL:
                default:
                    rotatedBitmap = bitmap;
            }
        } catch(IOException e) {
            e.printStackTrace();
            return bitmap;
        }

        return rotatedBitmap;
    }

    private static Bitmap rotateImage(Bitmap source, float angle) {
        Matrix matrix = new Matrix();
        matrix.postRotate(angle);
        return Bitmap.createBitmap(source, 0, 0, source.getWidth(), source.getHeight(),
                matrix, true);
    }

    /**
     * Returns the MIME type filter string for the photo picker based on the mediaType setting.
     * @param mediaType "image", "video", or "all"
     * @return the MIME type string for the intent
     */
    private String getMimeTypeForMediaType(String mediaType) {
        if ("video".equals(mediaType)) {
            return "video/*";
        } else if ("all".equals(mediaType)) {
            return "*/*";
        } else {
            return "image/*";
        }
    }

    /**
     * Checks if the given URI points to a video file.
     * @param uri the content URI to check
     * @return true if the URI is a video, false otherwise
     */
    private boolean isVideoUri(String uri) {
        if (uri == null) return false;

        try {
            String mimeType = cordova.getContext().getContentResolver().getType(Uri.parse(uri));
            return mimeType != null && mimeType.startsWith("video/");
        } catch (Exception e) {
            return false;
        }
    }

    /**
     * Copies a video from a content URI to a local file path.
     * @param videoUri the content URI of the video
     * @return the path of the local video file, or null in case of failure
     */
    private String copyVideoToLocal(final String videoUri) {
        try {
            Uri uri = Uri.parse(videoUri);

            // Get the MIME type to determine the extension
            String mimeType = cordova.getContext().getContentResolver().getType(uri);
            String extension = "mp4"; // Default extension
            if (mimeType != null) {
                if (mimeType.contains("mp4")) {
                    extension = "mp4";
                } else if (mimeType.contains("3gp")) {
                    extension = "3gp";
                } else if (mimeType.contains("webm")) {
                    extension = "webm";
                } else if (mimeType.contains("mkv")) {
                    extension = "mkv";
                } else if (mimeType.contains("avi")) {
                    extension = "avi";
                } else if (mimeType.contains("mov") || mimeType.contains("quicktime")) {
                    extension = "mov";
                }
            }

            // Generate output path
            final String outputFileName = String.format(Locale.US, "video_%d_%d.%s",
                System.currentTimeMillis(), videoUri.hashCode(), extension);
            final File outputDir = cordova.getActivity().getCacheDir();
            final String outputPath = outputDir + "/" + outputFileName;

            // Copy the video file
            InputStream inputStream = cordova.getContext().getContentResolver().openInputStream(uri);
            if (inputStream == null) {
                throw new IOException("Could not open input stream for video");
            }

            OutputStream outputStream = new FileOutputStream(outputPath);
            byte[] buffer = new byte[8192];
            int bytesRead;
            while ((bytesRead = inputStream.read(buffer)) != -1) {
                outputStream.write(buffer, 0, bytesRead);
            }

            inputStream.close();
            outputStream.close();

            return outputPath;
        } catch (Exception e) {
            e.printStackTrace();
            return null;
        }
    }

    /**
     * Copies a media file (image or video) from a content URI to a local file path.
     * @param mediaUri the content URI of the media
     * @param quality the quality setting for images (ignored for videos)
     * @return the path of the local file, or null in case of failure
     */
    private String copyMediaToLocal(final String mediaUri, final int quality) {
        if (isVideoUri(mediaUri)) {
            return copyVideoToLocal(mediaUri);
        } else {
            return copyImageToLocal(mediaUri, quality);
        }
    }
}
