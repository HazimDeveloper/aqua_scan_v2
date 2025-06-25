// lib/services/storage_service.dart - LOCAL STORAGE VERSION
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

class StorageService {
  final bool _debugMode = true;
  
  void _logDebug(String message) {
    if (_debugMode) {
      print('📁 LocalStorage: $message');
    }
  }
  
  /// Get local storage directory for images
  Future<Directory> _getImageStorageDirectory() async {
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final Directory imageDir = Directory(path.join(appDocDir.path, 'aquascan_images'));
    
    // Create directory if it doesn't exist
    if (!await imageDir.exists()) {
      await imageDir.create(recursive: true);
      _logDebug('Created image directory: ${imageDir.path}');
    }
    
    return imageDir;
  }
  
  /// Upload image to local storage - returns local file path
  Future<String> uploadImage(File file, String folder) async {
    try {
      _logDebug('=== STARTING LOCAL IMAGE SAVE ===');
      _logDebug('Source file: ${file.path}');
      _logDebug('Folder: $folder');
      
      // STEP 1: Validate source file
      if (!await file.exists()) {
        throw Exception('Source file does not exist: ${file.path}');
      }
      
      final fileSize = await file.length();
      _logDebug('File size: ${(fileSize / 1024).toStringAsFixed(2)} KB');
      
      if (fileSize <= 0) {
        throw Exception('File is empty: ${file.path}');
      }
      
      // STEP 2: Get storage directory
      final imageDir = await _getImageStorageDirectory();
      final folderDir = Directory(path.join(imageDir.path, folder));
      
      if (!await folderDir.exists()) {
        await folderDir.create(recursive: true);
        _logDebug('Created folder: ${folderDir.path}');
      }
      
      // STEP 3: Generate unique filename
      final uuid = Uuid();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = path.extension(file.path).toLowerCase();
      final validExtension = ['.jpg', '.jpeg', '.png'].contains(extension) ? extension : '.jpg';
      final fileName = 'water_${timestamp}_${uuid.v4()}$validExtension';
      
      _logDebug('Generated filename: $fileName');
      
      // STEP 4: Copy file to local storage
      final destinationPath = path.join(folderDir.path, fileName);
      final destinationFile = File(destinationPath);
      
      _logDebug('Copying to: $destinationPath');
      
      // Copy file
      await file.copy(destinationPath);
      
      // STEP 5: Verify the copied file
      if (!await destinationFile.exists()) {
        throw Exception('Failed to save file to local storage');
      }
      
      final savedFileSize = await destinationFile.length();
      if (savedFileSize != fileSize) {
        throw Exception('File size mismatch after copy');
      }
      
      _logDebug('✅ File saved successfully!');
      _logDebug('Local path: $destinationPath');
      _logDebug('File size verified: ${(savedFileSize / 1024).toStringAsFixed(2)} KB');
      _logDebug('=== SAVE COMPLETE ===');
      
      return destinationPath; // Return local file path instead of URL
      
    } catch (e) {
      _logDebug('❌ Local save failed: $e');
      throw Exception('Failed to save image locally: ${e.toString()}');
    }
  }
  
  /// Upload image data directly from bytes to local storage
  Future<String> uploadImageData(Uint8List imageData, String folder) async {
    try {
      _logDebug('=== STARTING LOCAL DATA SAVE ===');
      _logDebug('Data size: ${(imageData.length / 1024).toStringAsFixed(2)} KB');
      
      if (imageData.isEmpty) {
        throw Exception('Image data is empty');
      }
      
      // Get storage directory
      final imageDir = await _getImageStorageDirectory();
      final folderDir = Directory(path.join(imageDir.path, folder));
      
      if (!await folderDir.exists()) {
        await folderDir.create(recursive: true);
      }
      
      // Generate filename
      final uuid = Uuid();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'water_data_${timestamp}_${uuid.v4()}.jpg';
      
      _logDebug('Generated filename: $fileName');
      
      // Save data to file
      final destinationPath = path.join(folderDir.path, fileName);
      final destinationFile = File(destinationPath);
      
      _logDebug('Saving data to: $destinationPath');
      await destinationFile.writeAsBytes(imageData);
      
      // Verify
      if (!await destinationFile.exists()) {
        throw Exception('Failed to save data to local storage');
      }
      
      _logDebug('✅ Data saved successfully!');
      _logDebug('Local path: $destinationPath');
      
      return destinationPath;
      
    } catch (e) {
      _logDebug('❌ Local data save failed: $e');
      throw Exception('Data save failed: ${e.toString()}');
    }
  }
  
  /// Upload multiple images to local storage
  Future<List<String>> uploadImages(List<File> files, String folder) async {
    _logDebug('=== UPLOADING ${files.length} IMAGES TO LOCAL STORAGE ===');
    
    if (files.isEmpty) return [];
    
    final List<String> successfulPaths = [];
    final List<String> failedFiles = [];
    
    for (int i = 0; i < files.length; i++) {
      final file = files[i];
      _logDebug('Processing image ${i + 1}/${files.length}: ${file.path}');
      
      try {
        final localPath = await uploadImage(file, folder);
        successfulPaths.add(localPath);
        _logDebug('✅ Image ${i + 1} saved to local storage');
      } catch (e) {
        _logDebug('❌ Image ${i + 1} failed: $e');
        failedFiles.add(path.basename(file.path));
      }
    }
    
    _logDebug('=== LOCAL SAVE SUMMARY ===');
    _logDebug('Successful: ${successfulPaths.length}/${files.length}');
    _logDebug('Failed: ${failedFiles.length}');
    
    if (failedFiles.isNotEmpty) {
      _logDebug('Failed files: ${failedFiles.join(', ')}');
    }
    
    return successfulPaths;
  }
  
  /// Check if local file exists
  Future<bool> fileExists(String localPath) async {
    try {
      final file = File(localPath);
      return await file.exists();
    } catch (e) {
      _logDebug('Error checking file existence: $e');
      return false;
    }
  }
  
  /// Get file from local path
  File? getLocalFile(String localPath) {
    try {
      final file = File(localPath);
      return file;
    } catch (e) {
      _logDebug('Error getting local file: $e');
      return null;
    }
  }
  
  /// Delete local image file
  Future<void> deleteImage(String localPath) async {
    try {
      _logDebug('Deleting local image: $localPath');
      final file = File(localPath);
      
      if (await file.exists()) {
        await file.delete();
        _logDebug('✅ Local image deleted successfully');
      } else {
        _logDebug('⚠️ File does not exist: $localPath');
      }
    } catch (e) {
      _logDebug('❌ Error deleting local image: $e');
      throw Exception('Failed to delete local image: $e');
    }
  }
  
  /// Get all saved images in a folder
  Future<List<String>> getAllImagesInFolder(String folder) async {
    try {
      final imageDir = await _getImageStorageDirectory();
      final folderDir = Directory(path.join(imageDir.path, folder));
      
      if (!await folderDir.exists()) {
        return [];
      }
      
      final files = await folderDir.list().toList();
      final imagePaths = files
          .where((file) => file is File)
          .map((file) => file.path)
          .where((filePath) {
            final ext = path.extension(filePath).toLowerCase();
            return ['.jpg', '.jpeg', '.png'].contains(ext);
          })
          .toList();
      
      _logDebug('Found ${imagePaths.length} images in folder: $folder');
      return imagePaths;
      
    } catch (e) {
      _logDebug('Error getting images from folder: $e');
      return [];
    }
  }
  
  /// Clean up old images (optional - for storage management)
  Future<void> cleanupOldImages(String folder, {int maxAgeInDays = 30}) async {
    try {
      final imageDir = await _getImageStorageDirectory();
      final folderDir = Directory(path.join(imageDir.path, folder));
      
      if (!await folderDir.exists()) {
        return;
      }
      
      final cutoffDate = DateTime.now().subtract(Duration(days: maxAgeInDays));
      final files = await folderDir.list().toList();
      
      int deletedCount = 0;
      for (final file in files) {
        if (file is File) {
          final stat = await file.stat();
          if (stat.modified.isBefore(cutoffDate)) {
            await file.delete();
            deletedCount++;
          }
        }
      }
      
      _logDebug('Cleanup complete: deleted $deletedCount old files from $folder');
      
    } catch (e) {
      _logDebug('Error during cleanup: $e');
    }
  }
  
  /// Get storage info
  Future<Map<String, dynamic>> getStorageInfo() async {
    try {
      final imageDir = await _getImageStorageDirectory();
      final folders = ['reports', 'admin_reports'];
      
      int totalFiles = 0;
      int totalSizeBytes = 0;
      Map<String, int> folderCounts = {};
      
      for (final folder in folders) {
        final folderDir = Directory(path.join(imageDir.path, folder));
        if (await folderDir.exists()) {
          final files = await folderDir.list().toList();
          int folderFileCount = 0;
          
          for (final file in files) {
            if (file is File) {
              final stat = await file.stat();
              totalSizeBytes += stat.size;
              folderFileCount++;
            }
          }
          
          folderCounts[folder] = folderFileCount;
          totalFiles += folderFileCount;
        } else {
          folderCounts[folder] = 0;
        }
      }
      
      return {
        'total_files': totalFiles,
        'total_size_mb': (totalSizeBytes / (1024 * 1024)).toStringAsFixed(2),
        'folder_counts': folderCounts,
        'storage_path': imageDir.path,
      };
      
    } catch (e) {
      _logDebug('Error getting storage info: $e');
      return {
        'total_files': 0,
        'total_size_mb': '0.00',
        'folder_counts': {},
        'storage_path': 'Unknown',
      };
    }
  }
}