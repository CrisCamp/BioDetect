package com.biodetect.mobile

import android.content.ContentValues
import android.os.Build
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "biodetect/mediastore"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveImage" -> {
                        try {
                            saveImageToMediaStore(call, result)
                        } catch (e: Exception) {
                            result.error("SAVE_ERROR", e.message, null)
                        }
                    }
                    "saveDocument" -> {
                        try {
                            saveDocumentToMediaStore(call, result)
                        } catch (e: Exception) {
                            result.error("SAVE_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun saveImageToMediaStore(call: MethodCall, result: MethodChannel.Result) {
        val bytes = call.argument<ByteArray>("bytes")!!
        val fileName = call.argument<String>("fileName")!!
        val mimeType = call.argument<String>("mimeType")!!
        val collection = call.argument<String>("collection") ?: "DCIM"

        val contentValues = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, fileName)
            put(MediaStore.Images.Media.MIME_TYPE, mimeType)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.Images.Media.RELATIVE_PATH, collection)
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }
        }

        val uri = contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, contentValues)
        
        uri?.let { imageUri ->
            contentResolver.openOutputStream(imageUri)?.use { outputStream ->
                outputStream.write(bytes)
            }
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                contentValues.clear()
                contentValues.put(MediaStore.Images.Media.IS_PENDING, 0)
                contentResolver.update(imageUri, contentValues, null, null)
            }
            
            result.success("Imagen guardada exitosamente en $collection")
        } ?: run {
            result.error("SAVE_ERROR", "No se pudo crear la imagen en MediaStore", null)
        }
    }

    private fun saveDocumentToMediaStore(call: MethodCall, result: MethodChannel.Result) {
        val content = call.argument<String>("content")!!
        val fileName = call.argument<String>("fileName")!!
        val mimeType = call.argument<String>("mimeType")!!
        val collection = call.argument<String>("collection") ?: "Documents"
        val isBase64 = call.argument<Boolean>("isBase64") ?: false

        val contentValues = ContentValues().apply {
            put(MediaStore.Files.FileColumns.DISPLAY_NAME, fileName)
            put(MediaStore.Files.FileColumns.MIME_TYPE, mimeType)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.Files.FileColumns.RELATIVE_PATH, collection)
            }
        }

        val uri = contentResolver.insert(MediaStore.Files.getContentUri("external"), contentValues)
        
        uri?.let { docUri ->
            contentResolver.openOutputStream(docUri)?.use { outputStream ->
                if (isBase64) {
                    // Para PDFs en base64, decodificar primero
                    val decodedBytes = android.util.Base64.decode(content, android.util.Base64.DEFAULT)
                    outputStream.write(decodedBytes)
                } else {
                    // Para texto plano, escribir como bytes UTF-8
                    outputStream.write(content.toByteArray())
                }
            }
            result.success("Documento guardado exitosamente en $collection")
        } ?: run {
            result.error("SAVE_ERROR", "No se pudo crear el documento en MediaStore", null)
        }
    }
}