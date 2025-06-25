// lib/services/database_service.dart - FINAL CHECK - 100% LOCAL STORAGE
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/report_model.dart';

class DatabaseService {
  final bool _debugMode = true;
  
  void _logDebug(String message) {
    if (_debugMode) {
      print('🗄️ LocalDB: $message');
    }
  }
  
  // Get local database directory
  Future<Directory> _getDatabaseDirectory() async {
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final Directory dbDir = Directory(path.join(appDocDir.path, 'aquascan_database'));
    
    if (!await dbDir.exists()) {
      await dbDir.create(recursive: true);
      _logDebug('Created database directory: ${dbDir.path}');
    }
    
    return dbDir;
  }
  
  // Get reports file path
  Future<File> _getReportsFile() async {
    final dbDir = await _getDatabaseDirectory();
    return File(path.join(dbDir.path, 'reports.json'));
  }
  
  // Load all reports from local storage
  Future<List<ReportModel>> _loadAllReports() async {
    try {
      final file = await _getReportsFile();
      
      if (!await file.exists()) {
        _logDebug('Reports file does not exist, returning empty list');
        return [];
      }
      
      final contents = await file.readAsString();
      if (contents.isEmpty) {
        return [];
      }
      
      final List<dynamic> jsonList = json.decode(contents);
      final reports = jsonList.map((json) {
        try {
          return ReportModel.fromJson(json);
        } catch (e) {
          _logDebug('Error parsing report: $e');
          return null;
        }
      }).where((report) => report != null).cast<ReportModel>().toList();
      
      _logDebug('Loaded ${reports.length} reports from local storage');
      return reports;
      
    } catch (e) {
      _logDebug('Error loading reports: $e');
      return [];
    }
  }
  
  // Save all reports to local storage
  Future<void> _saveAllReports(List<ReportModel> reports) async {
    try {
      final file = await _getReportsFile();
      final jsonList = reports.map((report) {
        try {
          return report.toJson();
        } catch (e) {
          _logDebug('Error converting report to JSON: $e');
          return null;
        }
      }).where((json) => json != null).toList();
      
      await file.writeAsString(json.encode(jsonList));
      
      _logDebug('Saved ${reports.length} reports to local storage');
    } catch (e) {
      _logDebug('Error saving reports: $e');
      throw Exception('Failed to save reports: $e');
    }
  }
  
  // Create a new report with local storage
  Future<String> createReport(ReportModel report) async {
    try {
      _logDebug('Creating new report: ${report.title}');
      
      // Generate unique ID using timestamp and random suffix
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final randomSuffix = (timestamp % 10000).toString().padLeft(4, '0');
      final reportId = 'local_${timestamp}_$randomSuffix';
      
      // Load existing reports
      final allReports = await _loadAllReports();
      
      // Create report with ID and ensure proper timestamps
      final reportWithId = report.copyWith(
        id: reportId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      // Add to list
      allReports.add(reportWithId);
      
      // Save back to storage
      await _saveAllReports(allReports);
      
      _logDebug('✅ Report created successfully with ID: $reportId');
      _logDebug('   Title: ${reportWithId.title}');
      _logDebug('   User: ${reportWithId.userName}');
      _logDebug('   Images: ${reportWithId.imageUrls.length}');
      _logDebug('   Location: ${reportWithId.location.latitude}, ${reportWithId.location.longitude}');
      
      return reportId;
      
    } catch (e, stackTrace) {
      _logDebug('❌ Error creating report: $e');
      _logDebug('Stack trace: $stackTrace');
      throw Exception('Failed to create report: $e');
    }
  }
  
  // Get a specific report
  Future<ReportModel> getReport(String reportId) async {
    try {
      _logDebug('Getting report: $reportId');
      final allReports = await _loadAllReports();
      
      final report = allReports.firstWhere(
        (r) => r.id == reportId,
        orElse: () => throw Exception('Report not found'),
      );
      
      _logDebug('Report found: ${report.title}');
      return report;
      
    } catch (e) {
      _logDebug('Error getting report: $e');
      throw Exception('Failed to get report: $e');
    }
  }
  
  // Get unresolved reports
  Future<List<ReportModel>> getUnresolvedReportsList() async {
    try {
      _logDebug('Getting unresolved reports');
      final allReports = await _loadAllReports();
      
      final unresolvedReports = allReports
          .where((report) => !report.isResolved)
          .toList();
      
      // Sort by creation date (newest first)
      unresolvedReports.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      _logDebug('Found ${unresolvedReports.length} unresolved reports');
      return unresolvedReports;
      
    } catch (e) {
      _logDebug('Error getting unresolved reports: $e');
      throw Exception('Failed to get unresolved reports: $e');
    }
  }
  
  // Get resolved reports
  Future<List<ReportModel>> getResolvedReportsList() async {
    try {
      _logDebug('Getting resolved reports');
      final allReports = await _loadAllReports();
      
      final resolvedReports = allReports
          .where((report) => report.isResolved)
          .toList();
      
      // Sort by creation date (newest first)
      resolvedReports.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      _logDebug('Found ${resolvedReports.length} resolved reports');
      return resolvedReports;
      
    } catch (e) {
      _logDebug('Error getting resolved reports: $e');
      throw Exception('Failed to get resolved reports: $e');
    }
  }
  
  // Mark report as resolved
  Future<void> resolveReport(String reportId) async {
    try {
      _logDebug('Resolving report: $reportId');
      final allReports = await _loadAllReports();
      
      final reportIndex = allReports.indexWhere((r) => r.id == reportId);
      if (reportIndex == -1) {
        throw Exception('Report not found');
      }
      
      // Update report
      allReports[reportIndex] = allReports[reportIndex].copyWith(
        isResolved: true,
        updatedAt: DateTime.now(),
      );
      
      // Save back
      await _saveAllReports(allReports);
      
      _logDebug('Report resolved successfully');
    } catch (e) {
      _logDebug('Error resolving report: $e');
      throw Exception('Failed to resolve report: $e');
    }
  }
  
  // Update report
  Future<void> updateReport(String reportId, Map<String, dynamic> data) async {
    try {
      _logDebug('Updating report: $reportId');
      final allReports = await _loadAllReports();
      
      final reportIndex = allReports.indexWhere((r) => r.id == reportId);
      if (reportIndex == -1) {
        throw Exception('Report not found');
      }
      
      // Get current report and update fields
      final currentReport = allReports[reportIndex];
      
      final updatedReport = currentReport.copyWith(
        userId: data['userId'] ?? currentReport.userId,
        userName: data['userName'] ?? currentReport.userName,
        title: data['title'] ?? currentReport.title,
        description: data['description'] ?? currentReport.description,
        address: data['address'] ?? currentReport.address,
        imageUrls: data['imageUrls'] ?? currentReport.imageUrls,
        waterQuality: data['waterQuality'] ?? currentReport.waterQuality,
        isResolved: data['isResolved'] ?? currentReport.isResolved,
        updatedAt: DateTime.now(),
      );
      
      allReports[reportIndex] = updatedReport;
      await _saveAllReports(allReports);
      
      _logDebug('Report updated successfully');
    } catch (e) {
      _logDebug('Error updating report: $e');
      throw Exception('Failed to update report: $e');
    }
  }
  
  // Delete report
  Future<void> deleteReport(String reportId, {bool deleteLocalFiles = false}) async {
    try {
      _logDebug('Deleting report: $reportId');
      final allReports = await _loadAllReports();
      
      final reportIndex = allReports.indexWhere((r) => r.id == reportId);
      if (reportIndex == -1) {
        throw Exception('Report not found');
      }
      
      // Optionally delete local image files
      if (deleteLocalFiles) {
        final report = allReports[reportIndex];
        for (final imagePath in report.imageUrls) {
          if (imagePath.startsWith('/')) {
            try {
              final file = File(imagePath);
              if (await file.exists()) {
                await file.delete();
                _logDebug('Deleted local file: $imagePath');
              }
            } catch (e) {
              _logDebug('Error deleting local file: $e');
            }
          }
        }
      }
      
      // Remove from list
      allReports.removeAt(reportIndex);
      
      // Save back
      await _saveAllReports(allReports);
      
      _logDebug('Report deleted successfully');
    } catch (e) {
      _logDebug('Error deleting report: $e');
      throw Exception('Failed to delete report: $e');
    }
  }
  
  // Get storage statistics
  Future<Map<String, dynamic>> getLocalStorageStats() async {
    try {
      final allReports = await _loadAllReports();
      
      int totalReports = allReports.length;
      int reportsWithLocalImages = 0;
      int totalLocalImages = 0;
      int existingLocalImages = 0;
      int missingLocalImages = 0;
      
      for (final report in allReports) {
        bool hasLocalImages = false;
        
        for (final imagePath in report.imageUrls) {
          if (imagePath.startsWith('/')) {
            totalLocalImages++;
            hasLocalImages = true;
            
            final file = File(imagePath);
            if (await file.exists()) {
              existingLocalImages++;
            } else {
              missingLocalImages++;
            }
          }
        }
        
        if (hasLocalImages) reportsWithLocalImages++;
      }
      
      return {
        'total_reports': totalReports,
        'reports_with_local_images': reportsWithLocalImages,
        'total_local_images': totalLocalImages,
        'existing_local_images': existingLocalImages,
        'missing_local_images': missingLocalImages,
        'local_image_integrity': totalLocalImages > 0 
            ? (existingLocalImages / totalLocalImages * 100).toStringAsFixed(1)
            : '100.0',
        'storage_method': 'local_json_file',
        'database_location': (await _getReportsFile()).path,
      };
      
    } catch (e) {
      _logDebug('Error getting storage stats: $e');
      return {
        'total_reports': 0,
        'error': e.toString(),
      };
    }
  }
  
  // Stream methods for compatibility (return Stream from stored data)
  Stream<List<ReportModel>> getReports() async* {
    try {
      final reports = await _loadAllReports();
      yield reports;
    } catch (e) {
      _logDebug('Error in getReports stream: $e');
      yield [];
    }
  }
  
  Stream<List<ReportModel>> getUserReports(String userId) async* {
    try {
      final allReports = await _loadAllReports();
      final userReports = allReports.where((r) => r.userId == userId).toList();
      yield userReports;
    } catch (e) {
      _logDebug('Error in getUserReports stream: $e');
      yield [];
    }
  }
  
  Stream<List<ReportModel>> getUnresolvedReports() async* {
    try {
      final reports = await getUnresolvedReportsList();
      yield reports;
    } catch (e) {
      _logDebug('Error in getUnresolvedReports stream: $e');
      yield [];
    }
  }
}