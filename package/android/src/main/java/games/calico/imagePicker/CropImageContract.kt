package games.calico.imagepicker

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import androidx.activity.result.contract.ActivityResultContract
import com.yalantis.ucrop.UCrop
import java.io.File
import java.io.Serializable

internal class CropImageContract : ActivityResultContract<CropImageContractOptions, CropImageContractResult>() {
    override fun createIntent(context: Context, input: CropImageContractOptions): Intent {
        val outputFile = File(context.cacheDir, "cropped_image_${System.currentTimeMillis()}.${input.extension}")
        outputFile.parentFile?.let { parent ->
            if (!parent.exists()) {
                parent.mkdirs()
            }
        }
        val outputUri = Uri.fromFile(outputFile)
        
        val uCrop = UCrop.of(input.sourceUri, outputUri)
        
        // Set aspect ratio if provided
        if (input.width > 0 && input.height > 0) {
            uCrop.withAspectRatio(input.width.toFloat(), input.height.toFloat())
        }
        
        // Configure uCrop options
        val options = UCrop.Options().apply {
            setHideBottomControls(true)
            setFreeStyleCropEnabled(false) // Keep aspect ratio locked
            setMaxScaleMultiplier(4f) // Max zoom 4x
            setShowCropFrame(false)
            setShowCropGrid(false)
            setCircleDimmedLayer(input.isCropCircular)
            setImageToCropBoundsAnimDuration(300)
            setCropFrameColor(Color.BLACK)
            setDimmedLayerColor(Color.argb(204, 0, 0, 0)) // 80% opacity black
            setStatusBarColor(Color.BLACK)
            setToolbarColor(Color.WHITE)
            setToolbarWidgetColor(Color.BLACK)
            setRootViewBackgroundColor(Color.WHITE)
        }
        
        uCrop.withOptions(options)

        // Get intent and override activity class to use custom ImagePickerCropActivity for safe area handling
        val intent = uCrop.getIntent(context)
        intent.setClass(context, ImagePickerCropActivity::class.java)
        return intent
    }
    
    override fun parseResult(resultCode: Int, intent: Intent?): CropImageContractResult {
        return when (resultCode) {
            Activity.RESULT_OK -> {
                val resultUri = intent?.let { UCrop.getOutput(it) }
                if (resultUri != null) {
                    CropImageContractResult.Success(resultUri)
                } else {
                    CropImageContractResult.Error(Exception("Failed to get crop result"))
                }
            }
            UCrop.RESULT_ERROR -> {
                val cropError = intent?.let { UCrop.getError(it) }
                val exception = if (cropError is Exception) cropError else Exception(cropError?.message ?: "Unknown crop error")
                CropImageContractResult.Error(exception)
            }
            else -> {
                CropImageContractResult.Cancelled
            }
        }
    }
}

internal data class CropImageContractOptions(
    val sourceUri: Uri,
    val width: Int,
    val height: Int,
    val extension: String,
    val isCropCircular: Boolean
) : Serializable

internal sealed class CropImageContractResult {
    data class Success(val uri: Uri) : CropImageContractResult()
    object Cancelled : CropImageContractResult()
    data class Error(val exception: Exception) : CropImageContractResult()
}