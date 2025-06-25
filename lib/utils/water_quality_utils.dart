// lib/utils/water_quality_utils.dart
// FIXED: Added mapping for all backend water quality classes

import '../models/report_model.dart';
import 'package:flutter/material.dart';

/// Utility class for water quality related functions
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
        return 'Contaminated'; // CHANGED: Show "Contaminated" instead of "Unknown"
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
        return Colors.red; // CHANGED: Red for contaminated water
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
        return 'The water appears to be heavily contaminated. Do not use for drinking or cooking. Seek alternative water source immediately.'; // CHANGED: More specific description
    }
  }
  
  /// FIXED: Maps backend API water quality classes to the app's WaterQualityState enum
  static WaterQualityState mapWaterQualityClass(String waterQualityClass) {
    // Trim and standardize the input
    final className = waterQualityClass.trim().toLowerCase();
    
    print('🔍 Mapping water quality class: "$className"'); // Debug print
    
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
        return Icons.dangerous; // CHANGED: Use "dangerous" icon for contaminated water
    }
  }
}