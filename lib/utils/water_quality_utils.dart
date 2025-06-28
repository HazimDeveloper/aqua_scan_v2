// lib/utils/water_quality_utils.dart - ENHANCED: Better error handling and detection status
import '../models/report_model.dart';
import 'package:flutter/material.dart';

/// Enhanced utility class for water quality related functions
class WaterQualityUtils {
  /// Returns a user-friendly text representation of the water quality state
  static String getWaterQualityText(WaterQualityState quality) {
    switch (quality) {
      case WaterQualityState.optimum:
        return 'Optimum';
      case WaterQualityState.highPh:
        return 'High pH';
      case WaterQualityState.highPhTemp:
        return 'High pH & Temperature';
      case WaterQualityState.lowPh:
        return 'Low pH';
      case WaterQualityState.lowTemp:
        return 'Low Temperature';
      case WaterQualityState.lowTempHighPh:
        return 'Low Temp & High pH';
      case WaterQualityState.unknown:
      default:
        return 'Contaminated';
    }
  }
  
  /// Returns a color representing the water quality state
  static Color getWaterQualityColor(WaterQualityState quality) {
    switch (quality) {
      case WaterQualityState.optimum:
        return Colors.blue;
      case WaterQualityState.lowTemp:
        return Colors.green;
      case WaterQualityState.highPh:
        return Colors.orange;
      case WaterQualityState.lowPh:
        return Colors.orange.shade700;
      case WaterQualityState.highPhTemp:
        return Colors.red;
      case WaterQualityState.lowTempHighPh:
        return Colors.purple;
      case WaterQualityState.unknown:
      default:
        return Colors.red;
    }
  }
  
  /// Returns a detailed description of the water quality state
  static String getWaterQualityDescription(WaterQualityState quality) {
    switch (quality) {
      case WaterQualityState.optimum:
        return 'The water has optimal pH and temperature levels for general use.';
      case WaterQualityState.highPh:
        return 'The water has high pH levels and may be alkaline. May cause skin irritation or affect taste.';
      case WaterQualityState.highPhTemp:
        return 'The water has both high pH and temperature. Not recommended for direct use.';
      case WaterQualityState.lowPh:
        return 'The water has low pH levels and may be acidic. May cause corrosion or affect taste.';
      case WaterQualityState.lowTemp:
        return 'The water has lower than optimal temperature but otherwise may be suitable for use.';
      case WaterQualityState.lowTempHighPh:
        return 'The water has low temperature and high pH levels. Use with caution.';
      case WaterQualityState.unknown:
      default:
        return 'The water appears to be heavily contaminated. Do not use for drinking or cooking. Seek alternative water source immediately.';
    }
  }
  
  /// ENHANCED: Maps backend API water quality classes to the app's WaterQualityState enum
  static WaterQualityState mapWaterQualityClass(String waterQualityClass) {
    // Trim and standardize the input
    final className = waterQualityClass.trim().toLowerCase();
    
    print('🔍 Mapping water quality class: "$className"');
    
    // Handle special backend response classes first
    if (className == 'no_water_detected' || className == 'water_not_detected') {
      print('⚠️ Special case: No water detected');
      return WaterQualityState.unknown;
    }
    
    if (className == 'error' || className == 'analysis_failed') {
      print('❌ Special case: Analysis error');
      return WaterQualityState.unknown;
    }
    
    // EXACT MATCHES FIRST for backend classes
    switch (className) {
      case 'heavily_contaminated':
      case 'moderately_contaminated':
      case 'lightly_contaminated':
      case 'severely_contaminated':
        print('⚠️ Mapped contaminated water ($className) to: unknown (will show as Contaminated)');
        return WaterQualityState.unknown;
      
      case 'optimum':
      case 'good':
      case 'clean':
        print('✅ Mapped to: optimum');
        return WaterQualityState.optimum;
        
      case 'high_ph':
        print('✅ Mapped to: highPh');
        return WaterQualityState.highPh;
        
      case 'low_ph':
        print('✅ Mapped to: lowPh');
        return WaterQualityState.lowPh;
        
      case 'low_temp':
        print('✅ Mapped to: lowTemp');
        return WaterQualityState.lowTemp;
        
      case 'high_ph_high_temp':
        print('✅ Mapped to: highPhTemp');
        return WaterQualityState.highPhTemp;
        
      case 'low_temp_high_ph':
        print('✅ Mapped to: lowTempHighPh');
        return WaterQualityState.lowTempHighPh;
    }
    
    // PARTIAL MATCHES for fallback
    if (className.contains('contaminated') || 
        className.contains('polluted') || 
        className.contains('dirty') ||
        className.contains('unsafe') ||
        className.contains('poor') ||
        className.contains('bad')) {
      print('⚠️ Mapped contaminated water to: unknown (will show as Contaminated)');
      return WaterQualityState.unknown;
    } 
    else if (className.contains('optimum') || className.contains('good') || className.contains('clean')) {
      print('✅ Mapped to: optimum');
      return WaterQualityState.optimum;
    } 
    else if (className.contains('high_ph') && className.contains('high_temp')) {
      print('✅ Mapped to: highPhTemp');
      return WaterQualityState.highPhTemp;
    } 
    else if (className.contains('low_temp') && className.contains('high_ph')) {
      print('✅ Mapped to: lowTempHighPh');
      return WaterQualityState.lowTempHighPh;
    } 
    else if (className.contains('high_ph') || className.contains('alkaline')) {
      print('✅ Mapped to: highPh');
      return WaterQualityState.highPh;
    } 
    else if (className.contains('low_ph') || className.contains('acidic')) {
      print('✅ Mapped to: lowPh');
      return WaterQualityState.lowPh;
    } 
    else if (className.contains('low_temp') || className.contains('cold')) {
      print('✅ Mapped to: lowTemp');
      return WaterQualityState.lowTemp;
    }
    else {
      print('❓ No mapping found, defaulting to: unknown');
      return WaterQualityState.unknown;
    }
  }
  
  /// Returns an icon for the water quality state
  static IconData getWaterQualityIcon(WaterQualityState quality) {
    switch (quality) {
      case WaterQualityState.optimum:
        return Icons.check_circle;
      case WaterQualityState.lowTemp:
        return Icons.ac_unit;
      case WaterQualityState.highPh:
      case WaterQualityState.lowPh:
        return Icons.science;
      case WaterQualityState.highPhTemp:
        return Icons.whatshot;
      case WaterQualityState.lowTempHighPh:
        return Icons.warning;
      case WaterQualityState.unknown:
      default:
        return Icons.dangerous;
    }
  }
  
  /// ADDED: Get confidence level description
  static String getConfidenceLevelDescription(double confidence) {
    if (confidence >= 95) return 'Extremely High Confidence - Results are very reliable';
    if (confidence >= 90) return 'Very High Confidence - Results are highly reliable';
    if (confidence >= 80) return 'High Confidence - Results are reliable';
    if (confidence >= 70) return 'Good Confidence - Results are generally reliable';
    if (confidence >= 60) return 'Moderate Confidence - Results should be verified';
    if (confidence >= 50) return 'Low Confidence - Consider retaking photo';
    return 'Very Low Confidence - Please retake photo with better conditions';
  }
  
  /// ADDED: Get water detection status message
  static String getWaterDetectionMessage(bool waterDetected, double? confidence, String? errorMessage) {
    if (!waterDetected) {
      if (errorMessage != null && errorMessage.isNotEmpty) {
        return 'No water detected: $errorMessage';
      }
      return 'No water detected in image. Please take a photo showing clear water.';
    }
    
    if (confidence != null) {
      if (confidence >= 80) {
        return 'Water detected successfully with high confidence!';
      } else if (confidence >= 60) {
        return 'Water detected with moderate confidence. Consider retaking for better results.';
      } else {
        return 'Water detected but with low confidence. Please retake photo with better lighting.';
      }
    }
    
    return 'Water detected successfully!';
  }
  
  /// ADDED: Get analysis status for UI display
  static Map<String, dynamic> getAnalysisStatus({
    required bool analysisCompleted,
    required bool waterDetected,
    double? confidence,
    String? errorMessage,
    WaterQualityState? quality,
  }) {
    if (!analysisCompleted) {
      return {
        'status': 'pending',
        'icon': Icons.hourglass_empty,
        'color': Colors.orange,
        'title': 'Analysis Pending',
        'message': 'Waiting for analysis to complete',
      };
    }
    
    if (errorMessage != null && errorMessage.isNotEmpty) {
      return {
        'status': 'error',
        'icon': Icons.error,
        'color': Colors.red,
        'title': 'Analysis Error',
        'message': errorMessage,
      };
    }
    
    if (!waterDetected) {
      return {
        'status': 'no_water',
        'icon': Icons.warning_amber,
        'color': Colors.orange,
        'title': 'No Water Detected',
        'message': 'Please take a photo that clearly shows water',
      };
    }
    
    if (confidence != null && confidence > 0) {
      Color confidenceColor;
      String confidenceLevel;
      
      if (confidence >= 80) {
        confidenceColor = Colors.green;
        confidenceLevel = 'High';
      } else if (confidence >= 60) {
        confidenceColor = Colors.lightGreen;
        confidenceLevel = 'Moderate';
      } else {
        confidenceColor = Colors.orange;
        confidenceLevel = 'Low';
      }
      
      return {
        'status': 'success',
        'icon': Icons.check_circle,
        'color': confidenceColor,
        'title': 'Water Quality Analyzed',
        'message': '$confidenceLevel confidence (${confidence.toStringAsFixed(1)}%)',
        'quality': quality,
        'confidence': confidence,
      };
    }
    
    return {
      'status': 'unknown',
      'icon': Icons.help,
      'color': Colors.grey,
      'title': 'Unknown Status',
      'message': 'Unable to determine analysis status',
    };
  }
  
  /// ADDED: Get troubleshooting tips for no water detection
  static List<String> getWaterDetectionTips() {
    return [
      'Take photo showing clear water surface',
      'Ensure good lighting conditions',
      'Avoid photos with only containers or pipes',
      'Include actual water body in the frame',
      'Try different angles if water is not clear',
      'Clean camera lens for better image quality',
      'Take multiple photos from different positions',
    ];
  }
  
  /// ADDED: Get photo quality assessment
  static String assessPhotoQuality(int fileSize, int? width, int? height) {
    if (fileSize < 50000) { // Less than 50KB
      return 'Photo quality is very low. Consider retaking with higher quality.';
    }
    
    if (fileSize < 200000) { // Less than 200KB
      return 'Photo quality is low. Results may be less accurate.';
    }
    
    if (width != null && height != null) {
      final totalPixels = width * height;
      if (totalPixels < 100000) { // Less than 100k pixels
        return 'Image resolution is low. Consider using higher resolution.';
      }
    }
    
    if (fileSize > 5000000) { // More than 5MB
      return 'Photo quality is very high. Good for analysis.';
    }
    
    return 'Photo quality is good for analysis.';
  }
}