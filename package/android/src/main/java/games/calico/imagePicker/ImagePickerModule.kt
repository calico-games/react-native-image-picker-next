package games.calico.imagepicker

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.ExifInterface
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.core.app.ActivityCompat
import androidx.core.content.FileProvider
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts.PickVisualMedia
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import com.facebook.react.bridge.ActivityEventListener
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.bridge.WritableMap
import com.facebook.react.modules.core.PermissionAwareActivity
import com.facebook.react.modules.core.PermissionListener
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.io.InputStream
import java.util.UUID
import android.os.Handler
import android.os.Looper

class ImagePickerModule(reactContext: ReactApplicationContext) :
  ReactContextBaseJavaModule(reactContext), ActivityEventListener {

  companion object {
    private const val IMAGE_PICKER_REQUEST = 61110
    private const val CAMERA_CAPTURE_REQUEST = 61111
    private const val CROP_IMAGE_REQUEST = 61112
    private const val DEFAULT_SIZE = 200.0
    private const val DEFAULT_COMPRESSION_QUALITY = 0.5
    private val DEFAULT_OPTIONS: () -> WritableMap = {
        val options = Arguments.createMap()
        options.putBoolean("isCropping", true)
        options.putDouble("width", DEFAULT_SIZE)
        options.putDouble("height", DEFAULT_SIZE)
        options.putDouble("compressionQuality", DEFAULT_COMPRESSION_QUALITY)
        options.putBoolean("useWebP", true)
        options.putBoolean("shouldResize", true)
        options.putBoolean("useFrontCamera", true)
        options.putBoolean("isCropCircular", true)
        options.putBoolean("isTemp", true)
        options
    }
  }

  init {
    reactContext.addActivityEventListener(this)
  }

  override fun getName(): String {
    return "ImagePickerModule"
  }

  private var options: ReadableMap = DEFAULT_OPTIONS()
  private var isCropping: Boolean = true
  private var width: Double = DEFAULT_SIZE
  private var height: Double = DEFAULT_SIZE
  private var compressionQuality: Double = DEFAULT_COMPRESSION_QUALITY
  private var useWebP: Boolean = true
  private var shouldResize: Boolean = true
  private var useFrontCamera: Boolean = true
  private var isCropCircular: Boolean = true
  private var isTemp: Boolean = true

  private var currentPhotoPath: String? = null
  private var imagePickerPromise: Promise? = null
  private val cropImageContract = CropImageContract()

  @ReactMethod
  fun openGallery(options: ReadableMap, promise: Promise) {
    val activity = reactApplicationContext.currentActivity
    if (activity == null) {
      promise.reject("ACTIVITY_NULL", "Activity is null")
      return
    }

    setConfiguration(options)
    this.imagePickerPromise = promise
    
    // Only need WRITE_EXTERNAL_STORAGE for API 29 and below
    // API 30+ uses scoped storage, and the system picker handles permissions
    if (Build.VERSION.SDK_INT <= Build.VERSION_CODES.Q) {
      val permissions = listOf(Manifest.permission.WRITE_EXTERNAL_STORAGE)
      permissionsCheck(
        activity, 
        promise,
        permissions
      ) {
        initiateGallery(activity)
      }
    } else {
      // No permissions needed for API 30+ with ACTION_GET_CONTENT or PickVisualMedia
      initiateGallery(activity)
    }
  }

  private fun initiateGallery(activity: Activity) {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
       val request = PickVisualMediaRequest.Builder()
        .setMediaType(PickVisualMedia.ImageOnly)
        .setOrderedSelection(false)
        .setDefaultTab(ActivityResultContracts.PickVisualMedia.DefaultTab.PhotosTab)
        .build()

        val intent = PickVisualMedia().createIntent(activity.applicationContext, request)
        activity.startActivityForResult(intent, IMAGE_PICKER_REQUEST)
    } else {
      try {
        val intent = Intent(Intent.ACTION_GET_CONTENT)
        intent.type = "image/*"
        intent.putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("image/*"))
        intent.flags = Intent.FLAG_ACTIVITY_CLEAR_TOP
        intent.putExtra(Intent.EXTRA_ALLOW_MULTIPLE, false)
        intent.addCategory(Intent.CATEGORY_OPENABLE)

        val chooserIntent = Intent.createChooser(intent, "Pick an image")
        activity.startActivityForResult(chooserIntent, IMAGE_PICKER_REQUEST)
      } catch (e: Exception) {
        imagePickerPromise?.reject("IMAGE_PICKER_ERROR", "Failed to show image picker: ${e.message}")
      }
    }
  }

  @ReactMethod
  fun openCamera(options: ReadableMap, promise: Promise) {
    val activity = reactApplicationContext.currentActivity
    if (activity == null) {
      promise.reject("ACTIVITY_NULL", "Activity is null")
      return
    }

    if (!isCameraAvailable(activity)) {
      promise.reject("CAMERA_NOT_AVAILABLE", "Camera is not available on this device")
      return
    }

    setConfiguration(options)
    this.imagePickerPromise = promise

    val permissions = if (Build.VERSION.SDK_INT <= Build.VERSION_CODES.Q) {
      listOf(Manifest.permission.CAMERA, Manifest.permission.WRITE_EXTERNAL_STORAGE)
    } else {
      listOf(Manifest.permission.CAMERA)
    }
    
    permissionsCheck(
      activity, 
      promise, 
      permissions
    ) {
      initiateCamera(activity)
    }
  }

  private fun initiateCamera(activity: Activity) {
    try {
      val intent = Intent(MediaStore.ACTION_IMAGE_CAPTURE)
      // Create a file to save the image that should not be temporary when using the camera
      val photoFile = createImageFile(false)

      val photoUri =
        FileProvider.getUriForFile(
          activity,
          "${activity.packageName}.fileprovider",
          photoFile
        )

      intent.putExtra(MediaStore.EXTRA_OUTPUT, photoUri)

      if (useFrontCamera) {
        intent.putExtra("android.intent.extras.LENS_FACING_FRONT", 1)
        intent.putExtra("android.intent.extras.CAMERA_FACING", 1)
        intent.putExtra("android.intent.extra.USE_FRONT_CAMERA", true)
      } else {
        intent.putExtra("android.intent.extras.LENS_FACING_BACK", 1)
        intent.putExtra("android.intent.extras.CAMERA_FACING", 0)
        intent.putExtra("android.intent.extra.USE_FRONT_CAMERA", false)
      }

      activity.startActivityForResult(intent, CAMERA_CAPTURE_REQUEST)

      if (intent.resolveActivity(activity.packageManager) == null) {
        imagePickerPromise?.reject("CAMERA_INTENT_ERROR", "Failed to create camera intent")
      }
    } catch (e: Exception) {
      imagePickerPromise?.reject("IMAGE_FILE_ERROR", "Failed to create image file: ${e.message}")
    }
  }

  @Throws(IOException::class)
  private fun createImageFile(createTempFile: Boolean = true): File {
    val imageFileName = "image-${UUID.randomUUID()}"

    val extension = if (useWebP) ".webp" else ".jpg"

    val image = if (createTempFile) {
      File.createTempFile(imageFileName, extension)
    } else {
        val appName = reactApplicationContext.applicationInfo.loadLabel(reactApplicationContext.packageManager).toString()
        val path = File(
          Environment.getExternalStoragePublicDirectory(
            Environment.DIRECTORY_PICTURES
          ), appName
        )
        path.run {
          if (!exists()) {
            mkdirs()
          }
        }

      File(path, "$imageFileName$extension").apply {
        createNewFile()
      }
    }

    currentPhotoPath = image.absolutePath
    
    return image
  }

  private fun isCameraAvailable(activity: Activity): Boolean {
    val pm = activity.packageManager
    return pm.hasSystemFeature(PackageManager.FEATURE_CAMERA_ANY)
  }

  private fun permissionsCheck(
    activity: Activity,
    promise: Promise,
    requiredPermissions: List<String>,
    callback: () -> Unit
  ) {
    val missingPermissions = mutableListOf<String>()
    val supportedPermissions = requiredPermissions.toMutableList()

    // android 11 introduced scoped storage, and WRITE_EXTERNAL_STORAGE no longer works there
    if (Build.VERSION.SDK_INT > Build.VERSION_CODES.Q) {
      supportedPermissions.remove(Manifest.permission.WRITE_EXTERNAL_STORAGE)
    }

    for (permission in supportedPermissions) {
      val status = ActivityCompat.checkSelfPermission(activity, permission)
      if (status != PackageManager.PERMISSION_GRANTED) {
        missingPermissions.add(permission)
      }
    }

    if (missingPermissions.isNotEmpty()) {
      (activity as PermissionAwareActivity).requestPermissions(
        missingPermissions.toTypedArray(),
        1,
        object : PermissionListener {
          override fun onRequestPermissionsResult(
            requestCode: Int,
            permissions: Array<String>,
            grantResults: IntArray
          ): Boolean {
            if (requestCode == 1) {
              for (permissionIndex in permissions.indices) {
                val permission = permissions[permissionIndex]
                val grantResult = grantResults[permissionIndex]

                if (grantResult == PackageManager.PERMISSION_DENIED) {
                  when (permission) {
                    Manifest.permission.CAMERA -> promise.reject("CAMERA_PERMISSION_ERROR", "User did not grant camera permission")
                    Manifest.permission.WRITE_EXTERNAL_STORAGE -> promise.reject("LIBRARY_PERMISSION_ERROR", "User did not grant library permission")
                    else -> promise.reject("NO_LIBRARY_PERMISSION_ERROR", "Required permission missing")
                  }
                  return true
                }
              }
              try {
                callback()
              } catch (e: Exception) {
                promise.reject("CALLBACK_ERROR", e.message, e)
              }
            }
            return true
          }
        })
      return
    }

    // All permissions granted
    try {
      callback()
    } catch (e: Exception) {
      promise.reject("CALLBACK_ERROR", e.message, e)
    }
  }

  override fun onNewIntent(intent: Intent) {}

  override fun onActivityResult(
    activity: Activity,
    requestCode: Int,
    resultCode: Int,
    data: Intent?
  ) {
    if (imagePickerPromise == null) {
      return
    }

    when (requestCode) {
      IMAGE_PICKER_REQUEST -> {
        if (resultCode == Activity.RESULT_OK) {
          if (data == null) {
            imagePickerPromise?.reject("IMAGE_PICKER_ERROR", "Failed to get image picker result")
            return
          }
          val selectedImageUri = data.data.also { uri ->
            if (uri == null) {
              imagePickerPromise?.reject("IMAGE_URI_NULL", "Image uri is null")
              return
            }
          }
          selectedImageUri?.let { uri ->
            try {
              val inputStream = activity.contentResolver.openInputStream(uri)
              if (inputStream == null) {
                imagePickerPromise?.reject("FILE_NOT_FOUND", "Unable to open image file. The file may have been moved or deleted.")
                return
              }
              
              var bitmap = BitmapFactory.decodeStream(inputStream)
              inputStream.close()
              
              if (bitmap == null) {
                imagePickerPromise?.reject("DECODE_ERROR", "Failed to decode image. The file may be corrupted or in an unsupported format.")
                return
              }

              if (isCropping) {
                launchCropImage(uri, bitmap, 200)
                return // Don't clear promise yet, wait for crop result
              } else if (shouldResize) {
                bitmap = resizeImage(activity, uri)

                val finalUri = compressImage(bitmap, useWebP)
                imagePickerPromise?.resolve(finalUri.toString())
              }
            } catch (e: IOException) {
              imagePickerPromise?.reject("FILE_ACCESS_ERROR", "Failed to access image file: ${e.message}")
            } catch (e: SecurityException) {
              imagePickerPromise?.reject("PERMISSION_ERROR", "Permission denied to access image file: ${e.message}")
            } catch (e: Exception) {
              imagePickerPromise?.reject("UNKNOWN_ERROR", "An unexpected error occurred: ${e.message}")
            }
          } ?: run {
            imagePickerPromise?.reject("IMAGE_URI_NULL", "Image uri is null")
          }
        } else {
          imagePickerPromise?.reject("PICKER_CANCELLED_ERROR", "Image picker canceled")
        }
      }
      CAMERA_CAPTURE_REQUEST -> {
        if (resultCode == Activity.RESULT_OK) {
          val resultUri = Uri.fromFile(File(currentPhotoPath))
          resultUri?.let { uri ->
            try {
              val inputStream = activity.contentResolver.openInputStream(uri)
              if (inputStream == null) {
                imagePickerPromise?.reject("FILE_NOT_FOUND", "Unable to open captured image file.")
                return
              }
              
              var bitmap = BitmapFactory.decodeStream(inputStream)
              inputStream.close()
              
              if (bitmap == null) {
                imagePickerPromise?.reject("DECODE_ERROR", "Failed to decode captured image.")
                return
              }

              if (isCropping) {
                launchCropImage(uri, bitmap, 0)
                return // Don't clear promise yet, wait for crop result
              } else if (shouldResize) {
                bitmap = resizeImage(activity, uri)

                val finalUri = compressImage(bitmap, useWebP)
                imagePickerPromise?.resolve(finalUri.toString())
              }
            } catch (e: IOException) {
              imagePickerPromise?.reject("FILE_ACCESS_ERROR", "Failed to access captured image: ${e.message}")
            } catch (e: SecurityException) {
              imagePickerPromise?.reject("PERMISSION_ERROR", "Permission denied to access captured image: ${e.message}")
            } catch (e: Exception) {
              imagePickerPromise?.reject("UNKNOWN_ERROR", "An unexpected error occurred: ${e.message}")
            }
          } ?: run {
            imagePickerPromise?.reject("IMAGE_URI_NULL", "Image uri is null")
          }
        } else if (resultCode == Activity.RESULT_CANCELED) {
          imagePickerPromise?.reject("PICKER_CANCELLED_ERROR", "Image capture canceled")
        } else {
          imagePickerPromise?.reject("IMAGE_CAPTURE_ERROR", "Image capture failed")
        }
      }
      CROP_IMAGE_REQUEST -> {
        val resultIntent = data
        val result = cropImageContract.parseResult(resultCode, resultIntent)
        when (result) {
          is CropImageContractResult.Success -> {
            val bitmap = resizeImage(activity, result.uri)

            val finalUri = compressImage(bitmap, useWebP)
            imagePickerPromise?.resolve(finalUri.toString())
          }
          is CropImageContractResult.Cancelled -> {
            imagePickerPromise?.reject("PICKER_CANCELLED_ERROR", "Image cropping cancelled")
          }
          is CropImageContractResult.Error -> {
            imagePickerPromise?.reject("IMAGE_CROP_ERROR", "Image cropping failed", result.exception)
          }
        }
      }
    }

    imagePickerPromise = null
  }

  private fun resizeImage(activity: Activity, imageUri: Uri): Bitmap {
    val inputStream: InputStream? = activity.contentResolver.openInputStream(imageUri)
    val exif = inputStream?.let { ExifInterface(it) }
    inputStream?.close()

    val orientation = exif?.getAttributeInt(
      ExifInterface.TAG_ORIENTATION,
      ExifInterface.ORIENTATION_UNDEFINED
    )

    val bitmapStream = activity.contentResolver.openInputStream(imageUri)
      ?: throw IOException("Unable to open image for resizing")
    val bitmap = BitmapFactory.decodeStream(bitmapStream)
      ?: throw IOException("Failed to decode bitmap for resizing")
    bitmapStream.close()
    val rotatedBitmap = when (orientation) {
      ExifInterface.ORIENTATION_ROTATE_90 -> rotateImage(bitmap, 90f)
      ExifInterface.ORIENTATION_ROTATE_180 -> rotateImage(bitmap, 180f)
      ExifInterface.ORIENTATION_ROTATE_270 -> rotateImage(bitmap, 270f)
      ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> flipImage(bitmap, horizontal = true, vertical = false)
      ExifInterface.ORIENTATION_FLIP_VERTICAL -> flipImage(bitmap, horizontal = false, vertical = true)
      else -> bitmap
    }

    val aspectRatio = rotatedBitmap.width.toFloat() / rotatedBitmap.height.toFloat()
    val targetWidth = width.toInt()
    val targetHeight = height.toInt()

    val scaledBitmap: Bitmap
    val cropX: Int
    val cropY: Int

    if (aspectRatio > targetWidth.toFloat() / targetHeight.toFloat()) {
      // Image is wider than the target aspect ratio, scale height to fit and crop width
      val scaledWidth = (targetHeight * aspectRatio).toInt()
      scaledBitmap = Bitmap.createScaledBitmap(rotatedBitmap, scaledWidth, targetHeight, true)

      cropX = (scaledWidth - targetWidth) / 2
      cropY = 0
    } else {
      // Image is taller than the target aspect ratio, scale width to fit and crop height
      val scaledHeight = (targetWidth / aspectRatio).toInt()
      scaledBitmap = Bitmap.createScaledBitmap(rotatedBitmap, targetWidth, scaledHeight, true)

      cropX = 0
      cropY = (scaledHeight - targetHeight) / 2
    }

    println("Cropping image to $targetWidth x $targetHeight")

    return Bitmap.createBitmap(scaledBitmap, cropX, cropY, targetWidth, targetHeight)
  }

  private fun rotateImage(bitmap: Bitmap, degree: Float): Bitmap {
    val matrix = Matrix()
    matrix.postRotate(degree)
    return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
  }

  private fun flipImage(bitmap: Bitmap, horizontal: Boolean, vertical: Boolean): Bitmap {
    val matrix = Matrix()
    matrix.postScale(
      if (horizontal) -1f else 1f,
      if (vertical) -1f else 1f
    )
    return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
  }

  private fun compressImage(bitmap: Bitmap, useWebP: Boolean): Uri {
    val outputFile = createImageFile(isTemp)
    val outputStream = FileOutputStream(outputFile)
    val quality = (compressionQuality * 100).toInt()

    if (useWebP) {
      bitmap.compress(Bitmap.CompressFormat.WEBP, quality, outputStream)
    } else {
      bitmap.compress(Bitmap.CompressFormat.JPEG, quality, outputStream)
    }

    outputStream.flush()
    outputStream.close()

    return Uri.fromFile(outputFile)
  }

  private fun launchCropImage(uri: Uri, bitmap: Bitmap, delayMs: Long) {
    val extension = uri.lastPathSegment?.substringAfterLast('.') ?: "jpg"

    val options = CropImageContractOptions(
      sourceUri = uri,
      width = width.toInt(),
      height = height.toInt(),
      extension = extension,
      isCropCircular = isCropCircular
    )
  
    try {
      // Instead of using the crop launcher, directly start the crop activity
      val activity = reactApplicationContext.currentActivity
      if (activity != null) {
        val intent = cropImageContract.createIntent(activity, options)

        if (delayMs >= 0) {
          // Add a small delay to allow the picker to dismiss smoothly
          Handler(Looper.getMainLooper()).postDelayed({
            activity.startActivityForResult(intent, CROP_IMAGE_REQUEST)
          }, delayMs)
        } else {
          activity.startActivityForResult(intent, CROP_IMAGE_REQUEST)
        }
      } else {
        imagePickerPromise?.reject("CROP_LAUNCH_ERROR", "Activity is null")
      }
    } catch (e: Exception) {
      imagePickerPromise?.reject("CROP_LAUNCH_ERROR", "Failed to launch crop activity: ${e.message}")
    }
  }

  private fun setConfiguration(options: ReadableMap) {
    isCropping = getBooleanOption(options, "isCropping")
    width = getDoubleOption(options, "width")
    height = getDoubleOption(options, "height")
    compressionQuality = getDoubleOption(options, "compressionQuality")
    useWebP = getBooleanOption(options, "useWebP")
    shouldResize = getBooleanOption(options, "shouldResize")
    useFrontCamera = getBooleanOption(options, "useFrontCamera")
    isCropCircular = getBooleanOption(options, "isCropCircular")
    isTemp = getBooleanOption(options, "isTemp")
    this.options = options
  }

  private fun getStringOption(options: ReadableMap, key: String, defaultValue: String?): String? {
    return if (options.hasKey(key)) options.getString(key) else defaultValue
  }

  private fun getIntOption(options: ReadableMap, key: String): Int {
    return if (options.hasKey(key)) options.getInt(key) else 0
  }

  private fun getDoubleOption(options: ReadableMap, key: String): Double {
    return if (options.hasKey(key)) options.getDouble(key) else 0.0
  }

  private fun getBooleanOption(options: ReadableMap, key: String): Boolean {
    return options.hasKey(key) && options.getBoolean(key)
  }
}