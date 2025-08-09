// lib/services/gemini_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:aquascan_v2/services/api_service.dart';
import 'package:http/http.dart' as http;
import '../utils/water_quality_utils.dart' show WaterAnalysisResult, WaterQualityState, WaterQualityState;
import '../models/report_model.dart';

class GeminiAnalysisResult {
  final bool waterDetected;
  final String waterQualityAssessment;
  final String safetyRecommendation;
  final double confidence;
  final String detailedAnalysis;
  final bool isSafe;
  
  GeminiAnalysisResult({
    required this.waterDetected,
    required this.waterQualityAssessment,
    required this.safetyRecommendation,
    required this.confidence,
    required this.detailedAnalysis,
    required this.isSafe,
  });
}


class GeminiService {
  static const String _apiKey = 'AIzaSyD-fyQrplkhY8wSGTojz7Bqmbrp1Wj1lFo';
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';
  
  /// Analyze water quality using Gemini AI
  Future<GeminiAnalysisResult> analyzeWaterQuality(File imageFile) async {
    try {
      print('🔬 Starting Gemini water quality analysis...');
      
      // Validate image file
      if (!await imageFile.exists()) {
        throw Exception('Image file does not exist');
      }
      
      final fileSize = await imageFile.length();
      if (fileSize == 0) {
        throw Exception('Image file is empty');
      }
      
      print('📏 Image size: ${fileSize} bytes');
      
      // Convert image to base64
      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);
      
      // Create the prompt for water quality analysis
      final prompt = '''
Analyze this water image for quality and safety assessment. Please provide:

1. Water Detection: Is water clearly visible in the image?
2. Quality Assessment: Based on visual indicators (color, clarity, presence of contaminants, etc.)
3. Safety Recommendation: Is this water safe for consumption or use?
4. Confidence Level: How confident are you in your assessment (0-100)?
5. Detailed Analysis: Provide specific observations about water appearance, potential issues, and recommendations.

Focus on:
- Water clarity and color
- Presence of visible contaminants or particles
- Surface conditions (foam, oil, debris)
- Overall water body condition
- Safety implications

Please respond in JSON format with these fields:
{
  "water_detected": boolean,
  "quality_assessment": "string",
  "safety_recommendation": "string", 
  "confidence": number (0-100),
  "detailed_analysis": "string",
  "is_safe": boolean
}
''';

      final requestBody = {
        'contents': [
          {
            'parts': [
              {
                'text': prompt
              },
              {
                'inline_data': {
                  'mime_type': 'image/jpeg',
                  'data': base64Image
                }
              }
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.3,
          'topK': 40,
          'topP': 0.95,
          'maxOutputTokens': 1024,
        }
      };

      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['candidates'] != null && data['candidates'].isNotEmpty) {
          final candidate = data['candidates'][0];
          final content = candidate['content'];
          
          if (content['parts'] != null && content['parts'].isNotEmpty) {
            final text = content['parts'][0]['text'];
            print('📄 Gemini response: $text');
            
            return _parseGeminiResponse(text);
          }
        }
        
        throw Exception('Invalid response format from Gemini API');
      } else {
        print('❌ Gemini API error: ${response.statusCode} - ${response.body}');
        throw Exception('Gemini API request failed: ${response.statusCode}');
      }
      
    } catch (e) {
      print('❌ Gemini analysis error: $e');
      
      // Return a safe default result
      return GeminiAnalysisResult(
        waterDetected: false,
        waterQualityAssessment: 'Analysis unavailable',
        safetyRecommendation: 'Unable to assess safety',
        confidence: 0.0,
        detailedAnalysis: 'Gemini analysis failed: $e',
        isSafe: false,
      );
    }
  }
  
  /// Parse Gemini response and extract structured data
  GeminiAnalysisResult _parseGeminiResponse(String responseText) {
    try {
      // Try to extract JSON from the response
      final jsonMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(responseText);
      
      if (jsonMatch != null) {
        final jsonStr = jsonMatch.group(0) ?? '{}';
        final data = jsonDecode(jsonStr);
        
        return GeminiAnalysisResult(
          waterDetected: data['water_detected'] ?? false,
          waterQualityAssessment: data['quality_assessment'] ?? 'Unknown',
          safetyRecommendation: data['safety_recommendation'] ?? 'Unable to assess',
          confidence: (data['confidence'] ?? 0.0).toDouble(),
          detailedAnalysis: data['detailed_analysis'] ?? 'No detailed analysis available',
          isSafe: data['is_safe'] ?? false,
        );
      }
      
      // Fallback: parse text response
      return _parseTextResponse(responseText);
      
    } catch (e) {
      print('❌ Error parsing Gemini response: $e');
      return _parseTextResponse(responseText);
    }
  }
  
  /// Parse text response when JSON parsing fails
  GeminiAnalysisResult _parseTextResponse(String responseText) {
    bool waterDetected = false;
    bool isSafe = false;
    double confidence = 50.0;
    String qualityAssessment = 'Unknown';
    String safetyRecommendation = 'Unable to assess';
    String detailedAnalysis = responseText;
    
    final lowerText = responseText.toLowerCase();
    
    // Detect water presence
    if (lowerText.contains('water') || lowerText.contains('liquid')) {
      waterDetected = true;
    }
    
    // Detect safety indicators
    if (lowerText.contains('safe') || lowerText.contains('clean') || lowerText.contains('clear')) {
      isSafe = true;
    }
    if (lowerText.contains('unsafe') || lowerText.contains('contaminated') || lowerText.contains('polluted')) {
      isSafe = false;
    }
    
    // Extract confidence if mentioned
    final confidenceMatch = RegExp(r'confidence[:\s]*(\d+)').firstMatch(lowerText);
    if (confidenceMatch != null) {
      confidence = double.tryParse(confidenceMatch.group(1) ?? '50') ?? 50.0;
    }
    
    // Extract quality assessment
    if (lowerText.contains('clear') || lowerText.contains('clean')) {
      qualityAssessment = 'Clear and clean';
    } else if (lowerText.contains('cloudy') || lowerText.contains('turbid')) {
      qualityAssessment = 'Cloudy or turbid';
    } else if (lowerText.contains('contaminated') || lowerText.contains('polluted')) {
      qualityAssessment = 'Contaminated or polluted';
    }
    
    return GeminiAnalysisResult(
      waterDetected: waterDetected,
      waterQualityAssessment: qualityAssessment,
      safetyRecommendation: safetyRecommendation,
      confidence: confidence,
      detailedAnalysis: detailedAnalysis,
      isSafe: isSafe,
    );
  }
  
  /// Get combined analysis result from both API and Gemini
  Future<Map<String, dynamic>> getCombinedAnalysis(
    WaterAnalysisResult apiResult,
    GeminiAnalysisResult geminiResult,
  ) async {
    final combinedResult = <String, dynamic>{
      'api_result': apiResult,
      'gemini_result': geminiResult,
      'combined_confidence': 0.0,
      'final_safety_assessment': 'Unknown',
      'agreement_level': 'Unknown',
      'recommendation': '',
    };
    
    // Calculate combined confidence
    final apiConfidence = apiResult.confidence;
    final geminiConfidence = geminiResult.confidence;
    final combinedConfidence = (apiConfidence + geminiConfidence) / 2;
    
    combinedResult['combined_confidence'] = combinedConfidence;
    
    // Determine agreement level
    String agreementLevel = 'Unknown';
    if (apiResult.waterDetected == geminiResult.waterDetected) {
      agreementLevel = 'High Agreement';
    } else {
      agreementLevel = 'Disagreement';
    }
    
    combinedResult['agreement_level'] = agreementLevel;
    
    // Determine final safety assessment
    String finalSafety = 'Unknown';
    String recommendation = '';
    
    if (apiResult.waterDetected && geminiResult.waterDetected) {
      if (apiResult.waterQuality == WaterQualityState.optimum && geminiResult.isSafe) {
        finalSafety = 'Likely Safe';
        recommendation = 'Both analyses indicate safe water quality.';
      } else if (apiResult.waterQuality != WaterQualityState.optimum && !geminiResult.isSafe) {
        finalSafety = 'Likely Unsafe';
        recommendation = 'Both analyses indicate potential water quality issues.';
      } else {
        finalSafety = 'Needs Further Assessment';
        recommendation = 'Conflicting results between analyses. Manual verification recommended.';
      }
    } else if (!apiResult.waterDetected && !geminiResult.waterDetected) {
      finalSafety = 'No Water Detected';
      recommendation = 'No water detected in image. Please retake photo showing water clearly.';
    } else {
      finalSafety = 'Partial Detection';
      recommendation = 'One analysis detected water while the other did not. Manual verification recommended.';
    }
    
    combinedResult['final_safety_assessment'] = finalSafety;
    combinedResult['recommendation'] = recommendation;
    
    return combinedResult;
  }
} 