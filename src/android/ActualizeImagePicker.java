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

import androidx.exifinterface.media.ExifInterface;

import org.apache.cordova.CordovaPlugin;
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

    private static final int SINGLE_IMAGE_PICKER_REQUEST_CODE = 999001;
    private static final int MULTIPLE_IMAGE_PICKER_REQUEST_CODE = 999002;

    private CallbackContext callbackContext;
    private int imageQuality = 100;
    private int maxImages = 0;

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
     * Opens the Android Photo Picker for single-image selection
     * Uses the native Jetpack Photo Picker on Android 11+ or falls back to ACTION_OPEN_DOCUMENT
     * @param args Map of optional arguments for customisation
     */
    private void startSingleImagePicker(final JSONObject args) {
        try {
            this.imageQuality = args.getInt("imageQuality");
        } catch (Exception ignored) {}

        Intent intent;

        // Use the native photo picker on Android 11+ (API 30+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            // Android 13+ - Use MediaStore.ACTION_PICK_IMAGES
            intent = new Intent(MediaStore.ACTION_PICK_IMAGES);
            intent.setType("image/*");
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            // Android 11-12 - Photo picker may be available via backport
            intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
            intent.addCategory(Intent.CATEGORY_OPENABLE);
            intent.setType("image/*");
        } else {
            // Fallback for older Android versions
            intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
            intent.addCategory(Intent.CATEGORY_OPENABLE);
            intent.setType("image/*");
        }

        cordova.setActivityResultCallback(ActualizeImagePicker.this);
        cordova.startActivityForResult(this, intent, SINGLE_IMAGE_PICKER_REQUEST_CODE);
    }

    /**
     * Opens the Android Photo Picker for multi-image selection
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

        Intent intent;

        // Use the native photo picker on Android 13+ (API 33+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            // Android 13+ - Use MediaStore.ACTION_PICK_IMAGES with multiple selection
            intent = new Intent(MediaStore.ACTION_PICK_IMAGES);
            intent.setType("image/*");
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
            intent.setType("image/*");
            intent.putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true);
        }

        cordova.setActivityResultCallback(ActualizeImagePicker.this);
        cordova.startActivityForResult(this, intent, MULTIPLE_IMAGE_PICKER_REQUEST_CODE);
    }

    @Override
    public void onActivityResult(int requestCode, int resultCode, Intent intent) {
        super.onActivityResult(requestCode, resultCode, intent);

        final boolean isCanceled = resultCode != Activity.RESULT_OK;

        switch (requestCode) {

            case SINGLE_IMAGE_PICKER_REQUEST_CODE:
                if (isCanceled) {
                    handleSingleImagePickerResult(true, null);
                    return;
                }
                if (intent == null || intent.getData() == null) {
                    handleSingleImagePickerResult(true, null);
                    return;
                }
                handleSingleImagePickerResult(false, intent.getData().toString());
                break;

            case MULTIPLE_IMAGE_PICKER_REQUEST_CODE:
                if (isCanceled) {
                    handleMultipleImagePickerResult(true, new String[]{});
                    return;
                }

                List<String> uriList = new ArrayList<>();

                if (intent != null) {
                    // Check for multiple selection via ClipData
                    ClipData clipData = intent.getClipData();
                    if (clipData != null) {
                        int count = clipData.getItemCount();
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
                        uriList.add(intent.getData().toString());
                    }
                }

                handleMultipleImagePickerResult(false, uriList.toArray(new String[0]));
                break;
        }
    }

    /**--------------------------------
     *        RESULTS HANDLING
     *---------------------------------

     /**
     * Handles Single Image Picker's result and returns the JSON data to Cordova JS
     * @param isCanceled true if the operation was canceled by the user, false otherwise
     * @param imageFileUri the URI of the selected file
     */
    private void handleSingleImagePickerResult(final boolean isCanceled, final String imageFileUri) {
        if (isCanceled) {
            callbackContext.success(new JsonArgs().put("status", "CANCELED").jsonObj());
            return;
        }

        if (imageFileUri == null) {
            callbackContext.error("Found null 'imageFileUri' in handleSingleImagePickerResult");
            return;
        }

        // Always process the image to convert content URI to accessible local file
        final String outputImagePath = copyImageToLocal(imageFileUri, this.imageQuality);
        if (outputImagePath == null) {
            callbackContext.error("Failed to process image");
            return;
        }
        final String outputImageUri = Uri.fromFile(new File(outputImagePath)).toString();

        JsonArgs outResult = new JsonArgs();
        outResult.put("status", "OK");
        outResult.put("imageFileUri", outputImageUri);
        callbackContext.success(outResult.jsonObj());
    }

    /**
     * Handles Multiple Image Picker's result and returns the JSON data to Cordova JS
     * @param isCanceled true if the operation was canceled by the user, false otherwise
     * @param imageFilesUris an array containing the file URIs for all the images selected
     */
    private void handleMultipleImagePickerResult(final boolean isCanceled, final String[] imageFilesUris) {
        if (isCanceled) {
            callbackContext.success(new JsonArgs().put("status", "CANCELED").jsonObj());
            return;
        }

        JSONArray imageUris = new JSONArray();
        for(String path : imageFilesUris) {
            // Always process the image to convert content URI to accessible local file
            String outPath = copyImageToLocal(path, this.imageQuality);
            if (outPath == null) {
                // Skip images that failed to process
                continue;
            }
            try {
                final String imageUri = Uri.fromFile(new File(outPath)).toString();
                imageUris.put(imageUri);
            } catch(Exception e) {
                e.printStackTrace();
            }
        }

        JsonArgs outResult = new JsonArgs();

        outResult.put("status", "OK");
        outResult.put("imageFilesUris", imageUris);

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
}
