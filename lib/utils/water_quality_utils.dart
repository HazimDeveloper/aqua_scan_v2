// lib/utils/water_quality_utils.dart - BACKWARD COMPATIBLE: Updated meanings, same enum names
import '../models/report_model.dart';
import 'package:flutter/material.dart';

/// Enhanced utility class for water quality - keeping existing enum structure but updated meanings
class WaterQualityUtils {
  /// Returns a user-friendly text representation of the water quality state
  static String getWaterQualityText(WaterQualityState quality) {
    switch (quality) {
      case WaterQualityState.optimum:
        return 'Optimum';
      case WaterQualityState.highPh:
        return 'High pH';
      case WaterQualityState.highPhTemp:  // CHANGED MEANING: Now "High pH & Low Temp"
        return 'High pH & Low Temperature';
      case WaterQualityState.lowPh:
        return 'Low pH';
      case WaterQualityState.lowTemp:
        return 'Low Temperature';
      case WaterQualityState.lowTempHighPh:
        return 'Low Temp & High pH';
      case WaterQualityState.unknown:
      default:
        return 'Optimum'; // Treat unknown as optimum for display
    }
  }
  
  /// Returns a color representing the water quality state
  static Color getWaterQualityColor(WaterQualityState quality) {
    switch (quality) {
      case WaterQualityState.optimum:
        return Colors.green.shade600;    // Best quality
      case WaterQualityState.highPh:
        return Colors.orange.shade600;   // Moderate issue
      case WaterQualityState.highPhTemp: // CHANGED: High pH + Low Temp = serious issue
        return Colors.red.shade600;      // Multiple parameters affected
      case WaterQualityState.lowPh:
        return Colors.orange.shade700;   // Moderate issue
      case WaterQualityState.lowTemp:
        return Colors.blue.shade600;     // Minor temperature issue
      case WaterQualityState.lowTempHighPh:
        return Colors.purple.shade600;   // Multiple parameters affected
      case WaterQualityState.unknown:
      default:
        return Colors.green.shade600;    // Treat as optimum
    }
  }
  
  /// Returns a detailed description of the water quality state
  static String getWaterQualityDescription(WaterQualityState quality) {
    switch (quality) {
      case WaterQualityState.optimum:
        return 'The water has optimal pH and temperature levels for general use.';
      case WaterQualityState.highPh:
        return 'The water has high pH levels and may be alkaline. May cause skin irritation or affect taste.';
      case WaterQualityState.highPhTemp: // CHANGED MEANING: High pH + Low Temp
        return 'The water has high pH combined with low temperature. This combination may indicate specific treatment needs.';
      case WaterQualityState.lowPh:
        return 'The water has low pH levels and may be acidic. May cause corrosion or affect taste.';
      case WaterQualityState.lowTemp:
        return 'The water has lower than optimal temperature but otherwise may be suitable for use.';
      case WaterQualityState.lowTempHighPh:
        return 'The water has low temperature and high pH levels. Use with caution.';
      case WaterQualityState.unknown:
      default:
        return 'Water quality is within acceptable ranges for general use.'; // Positive message for unknown
    }
  }
  
  /// Maps backend API water quality classes to the app's WaterQualityState enum
  static WaterQualityState mapWaterQualityClass(String waterQualityClass) {
    // Trim and standardize the input
    final className = waterQualityClass.trim().toLowerCase();
    
    print('🔍 Mapping water quality class: "$className"');
    
    // Handle special backend response classes
    if (className == 'no_water_detected' || 
        className == 'water_not_detected' ||
        className == 'error' || 
        className == 'analysis_failed' ||
        className.isEmpty) {
      print('⚠️ Special case: Defaulting to optimum');
      return WaterQualityState.optimum;
    }
    
    // EXACT MATCHES for your 6 classes
    switch (className) {
      case 'optimum':
      case 'good':
      case 'clean':
        print('✅ Mapped to: optimum');
        return WaterQualityState.optimum;
        
      case 'high_ph':
        print('✅ Mapped to: highPh');
        return WaterQualityState.highPh;
        
      case 'high_ph; low_temp':          // YOUR NEW MAPPING
      case 'high_ph;low_temp':
      case 'high_ph_low_temp':
      case 'highph_lowtemp':
        print('✅ Mapped to: highPhTemp (now means High pH + Low Temp)');
        return WaterQualityState.highPhTemp;  // Reusing existing enum
        
      case 'low_ph':
        print('✅ Mapped to: lowPh');
        return WaterQualityState.lowPh;
        
      case 'low_temp':
        print('✅ Mapped to: lowTemp');
        return WaterQualityState.lowTemp;
        
      case 'low_temp; high_ph':
      case 'low_temp;high_ph':
      case 'low_temp_high_ph':
      case 'lowtemp_highph':
        print('✅ Mapped to: lowTempHighPh');
        return WaterQualityState.lowTempHighPh;
    }
    
    // Handle legacy contaminated cases - map to optimum
    if (className.contains('contaminated') || 
        className.contains('polluted') || 
        className.contains('dirty') ||
        className.contains('unsafe') ||
        className.contains('poor') ||
        className.contains('bad')) {
      print('⚠️ Legacy contaminated case - mapped to: optimum');
      return WaterQualityState.optimum;
    }
    
    // Handle old HIGH_PH; HIGH_TEMP mapping - now maps to optimum
    if (className.contains('high_ph') && className.contains('high_temp')) {
      print('⚠️ Legacy high pH + high temp - mapped to: optimum');
      return WaterQualityState.optimum;
    }
    
    // PARTIAL MATCHES for fallback
    if (className.contains('high_ph') && (className.contains('low_temp') || className.contains('cold'))) {
      print('✅ Partial match - mapped to: highPhTemp');
      return WaterQualityState.highPhTemp;
    } 
    else if (className.contains('low_temp') && (className.contains('high_ph') || className.contains('alkaline'))) {
      print('✅ Partial match - mapped to: lowTempHighPh');
      return WaterQualityState.lowTempHighPh;
    } 
    else if (className.contains('high_ph') || className.contains('alkaline')) {
      print('✅ Partial match - mapped to: highPh');
      return WaterQualityState.highPh;
    } 
    else if (className.contains('low_ph') || className.contains('acidic')) {
      print('✅ Partial match - mapped to: lowPh');
      return WaterQualityState.lowPh;
    } 
    else if (className.contains('low_temp') || className.contains('cold')) {
      print('✅ Partial match - mapped to: lowTemp');
      return WaterQualityState.lowTemp;
    }
    else {
      print('❓ No mapping found, defaulting to: optimum');
      return WaterQualityState.optimum;
    }
  }
  
  /// Returns an icon for the water quality state
  static IconData getWaterQualityIcon(WaterQualityState quality) {
    switch (quality) {
      case WaterQualityState.optimum:
        return Icons.check_circle;
      case WaterQualityState.highPh:
        return Icons.science;
      case WaterQualityState.highPhTemp: // CHANGED: Now represents High pH + Low Temp
        return Icons.warning;
      case WaterQualityState.lowPh:
        return Icons.science;
      case WaterQualityState.lowTemp:
        return Icons.ac_unit;
      case WaterQualityState.lowTempHighPh:
        return Icons.warning_amber;
      case WaterQualityState.unknown:
      default:
        return Icons.check_circle; // Treat as good
    }
  }
  
  /// Get confidence level description
  static String getConfidenceLevelDescription(double confidence) {
    if (confidence >= 95) return 'Extremely High Confidence - Results are very reliable';
    if (confidence >= 90) return 'Very High Confidence - Results are highly reliable';
    if (confidence >= 80) return 'High Confidence - Results are reliable';
    if (confidence >= 70) return 'Good Confidence - Results are generally reliable';
    if (confidence >= 60) return 'Moderate Confidence - Results should be verified';
    if (confidence >= 50) return 'Low Confidence - Consider retaking photo';
    return 'Very Low Confidence - Please retake photo with better conditions';
  }
  
  /// Get water detection status message
  static String getWaterDetectionMessage(bool waterDetected, double? confidence, String? errorMessage) {
    if (!waterDetected) {
      if (errorMessage != null && errorMessage.isNotEmpty) {
        return 'No water detected: $errorMessage. Quality defaulted to optimum.';
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
  
  /// Get analysis status for UI display
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
        'status': 'info',
        'icon': Icons.info,
        'color': Colors.blue,
        'title': 'Analysis Complete',
        'message': 'Quality assessment completed with default optimum rating',
      };
    }
    
    if (!waterDetected) {
      return {
        'status': 'no_water',
        'icon': Icons.info_outline,
        'color': Colors.blue,
        'title': 'No Water Detected',
        'message': 'Please retake photo showing water clearly',
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
      'status': 'complete',
      'icon': Icons.check_circle,
      'color': Colors.green,
      'title': 'Analysis Complete',
      'message': 'Water quality assessment completed',
    };
  }
  
  /// Get troubleshooting tips for better water detection
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
  
  /// Get photo quality assessment
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
  
  /// BACKWARD COMPATIBILITY: Handle unknown states
  static WaterQualityState normalizeQualityState(WaterQualityState quality) {
    if (quality == WaterQualityState.unknown) {
      return WaterQualityState.optimum;
    }
    return quality;
  }
  
  /// Get priority level (0 = lowest, 3 = highest)
  static int getQualitySeverityLevel(WaterQualityState quality) {
    switch (quality) {
      case WaterQualityState.optimum:
        return 0; // Best - no issues
      case WaterQualityState.lowTemp:
        return 1; // Minor issue
      case WaterQualityState.highPh:
      case WaterQualityState.lowPh:
        return 2; // Moderate issue
      case WaterQualityState.highPhTemp:    // High pH + Low Temp = serious
      case WaterQualityState.lowTempHighPh: // Low Temp + High pH = serious
        return 3; // Multiple issues - highest priority
      case WaterQualityState.unknown:
      default:
        return 0; // Treat as good
    }
  }
  
  /// Check if quality state needs urgent attention
  static bool isUrgentQuality(WaterQualityState quality) {
    return getQualitySeverityLevel(quality) >= 3;
  }
  
  /// Get user-friendly severity description
  static String getSeverityDescription(WaterQualityState quality) {
    switch (getQualitySeverityLevel(quality)) {
      case 0: return 'No issues detected';
      case 1: return 'Minor parameter variation';
      case 2: return 'Moderate attention needed';
      case 3: return 'Multiple parameters affected';
      default: return 'Normal quality';
    }
  }
}