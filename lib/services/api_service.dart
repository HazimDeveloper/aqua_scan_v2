// lib/services/api_service.dart - FIXED: Google API Key Logic
import 'dart:convert';
import 'dart:io';
import 'dart:math' as Math;
import 'package:http/http.dart' as http;
import '../utils/water_quality_utils.dart';
import '../models/report_model.dart';
import 'gemini_service.dart';

class WaterQualityResult {
  final WaterQualityState quality;
  final double confidence;
  
  WaterQualityResult({
    required this.quality,
    required this.confidence,
  });
}

class WaterAnalysisResult {
  final WaterQualityState waterQuality;
  final String originalClass;
  final double confidence;
  final bool waterDetected;
  final String? errorMessage;
  final bool isLowConfidence;
  
  WaterAnalysisResult({
    required this.waterQuality,
    required this.originalClass,
    required this.confidence,
    this.waterDetected = true,
    this.errorMessage,
    this.isLowConfidence = false,
  });
}

class ApiService {
  final String baseUrl;
  late GeminiService _geminiService;
  
  // FIXED: Google Maps API configuration - Set to null if you don't have a real key
  // static const String? _googleMapsApiKey = null; // Change to your real API key or keep as null
  
  // Alternative: If you have a real key, replace null with your key:
  static const String _googleMapsApiKey = 'AIzaSyBAu5LXTH6xw4BrThroxWxngNunfgh27bg';
  
  ApiService({required this.baseUrl}) {
    _geminiService = GeminiService();
  }
  
  static const String _googleMapsBaseUrl = 'https://maps.googleapis.com/maps/api';
  
  
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
  
  /// Test backend connection with enhanced health check
  Future<bool> testBackendConnection() async {
    try {
      print('🔗 Testing enhanced backend connection to: $baseUrl');
      
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Backend connected successfully');
        print('📊 Components: ${data['components']}');
        print('🧬 GA Support: ${data['genetic_algorithm_enabled'] ?? 'Unknown'}');
        print('🗺️ Maps Support: ${data['google_maps_enabled'] ?? 'Unknown'}');
        print('🚗 Driving Support: ${data['driving_mode_enabled'] ?? 'Unknown'}');
        return true;
      }
      
      // Try root endpoint as fallback
      final rootResponse = await http.get(Uri.parse(baseUrl))
          .timeout(const Duration(seconds: 5));
      
      return rootResponse.statusCode == 200;
      
    } catch (e) {
      print('❌ Backend connection failed: $e');
      return false;
    }
  }
  
  /// ENHANCED: Water quality analysis with robust error handling
  Future<WaterAnalysisResult> analyzeWaterQualityWithConfidence(File imageFile) async {
    try {
      print('🔬 Starting enhanced water quality analysis...');
      
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/analyze'));
      
      final fileStream = http.ByteStream(imageFile.openRead());
      final fileLength = await imageFile.length();
      
      final multipartFile = http.MultipartFile(
        'image',
        fileStream,
        fileLength,
        filename: 'water_image.jpg',
      );
      
      request.files.add(multipartFile);
      request.fields['enable_low_confidence'] = 'true';
      request.fields['confidence_threshold'] = '0.1'; // Very low threshold
      
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      
      print('📥 Backend response status: ${response.statusCode}');
      print('📄 Response body: $responseBody');
      
      if (response.statusCode == 200) {
        final data = json.decode(responseBody);
        
        // Initialize with safe defaults
        WaterQualityState qualityState = WaterQualityState.unknown;
        double confidenceScore = 0.0;
        String originalClass = "UNKNOWN";
        bool waterDetected = false;
        String? errorMessage;
        bool isLowConfidence = false;
        
        // Parse response safely
        if (data.containsKey('water_detected')) {
          waterDetected = data['water_detected'] == true;
        }
        
        if (data.containsKey('confidence') && data['confidence'] != null) {
          confidenceScore = double.tryParse(data['confidence'].toString()) ?? 0.0;
        }
        
        if (data.containsKey('water_quality_class') && data['water_quality_class'] != null) {
          originalClass = data['water_quality_class'].toString();
          qualityState = WaterQualityUtils.mapWaterQualityClass(originalClass);
        }
        
        if (data.containsKey('low_confidence_result')) {
          isLowConfidence = data['low_confidence_result'] == true;
        }
        
        if (data.containsKey('message')) {
          errorMessage = data['message'].toString();
        }
        
        return WaterAnalysisResult(
          waterQuality: qualityState,
          originalClass: originalClass,
          confidence: confidenceScore,
          waterDetected: waterDetected,
          isLowConfidence: isLowConfidence,
          errorMessage: errorMessage,
        );
        
      } else {
        // Handle HTTP errors gracefully
        return WaterAnalysisResult(
          waterQuality: WaterQualityState.unknown,
          originalClass: "HTTP_ERROR",
          confidence: 0.0,
          waterDetected: false,
          errorMessage: "Server error (${response.statusCode})",
          isLowConfidence: false,
        );
      }
      
    } catch (e) {
      print('❌ Analysis error: $e');
      
      return WaterAnalysisResult(
        waterQuality: WaterQualityState.unknown,
        originalClass: "ERROR",
        confidence: 0.0,
        waterDetected: false,
        errorMessage: "Analysis failed: ${e.toString()}",
        isLowConfidence: false,
      );
    }
  }
  
  /// ENHANCED: Combined analysis using both API and Gemini for double verification
  Future<Map<String, dynamic>> analyzeWaterQualityWithDoubleVerification(File imageFile) async {
    try {
      print('🔬 Starting double verification analysis...');
      
      // Run API analysis first
      final apiResult = await analyzeWaterQualityWithConfidence(imageFile);
      print('✅ API analysis completed');
      
      // Run Gemini analysis in parallel
      final geminiResult = await _geminiService.analyzeWaterQuality(imageFile);
      print('✅ Gemini analysis completed');
      
      // Get combined analysis
      final combinedResult = await _geminiService.getCombinedAnalysis(apiResult, geminiResult);
      
      print('📊 Combined analysis results:');
      print('   API Confidence: ${apiResult.confidence}%');
      print('   Gemini Confidence: ${geminiResult.confidence}%');
      print('   Combined Confidence: ${combinedResult['combined_confidence']}%');
      print('   Final Safety: ${combinedResult['final_safety_assessment']}');
      print('   Agreement: ${combinedResult['agreement_level']}');
      
      return combinedResult;
      
    } catch (e) {
      print('❌ Double verification analysis failed: $e');
      
      // Fallback to API-only analysis
      final apiResult = await analyzeWaterQualityWithConfidence(imageFile);
      
      return {
        'api_result': apiResult,
        'gemini_result': null,
        'combined_confidence': apiResult.confidence,
        'final_safety_assessment': 'API Only',
        'agreement_level': 'Single Analysis',
        'recommendation': 'Gemini analysis failed, using API results only.',
        'error': e.toString(),
      };
    }
  }
  
  // FIXED: Get actual driving routes with proper Google API handling
  Future<Map<String, dynamic>> getActualDrivingRoutes(
    GeoPoint currentLocation,
    String adminId, {
    int maxRoutes = 20,
  }) async {
    try {
      print('🚗 Getting actual routes from backend...');
      
      // Build query parameters based on available API key
      final queryParams = {
        'current_lat': currentLocation.latitude.toString(),
        'current_lng': currentLocation.longitude.toString(),
        'limit': maxRoutes.toString(),
      };
      
      // Only add API key if we have a real one
      if (_googleMapsApiKey != null && _googleMapsApiKey!.isNotEmpty) {
        queryParams['api_key'] = _googleMapsApiKey!;
        print('🔑 Using configured Google Maps API key');
      } else {
        print('⚠️ No Google Maps API key configured - backend will use alternatives');
      }
      
      final response = await http.get(
        Uri.parse('$baseUrl/water-supply-points-with-routes').replace(
          queryParameters: queryParams,
        ),
        headers: _headers,
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == true) {
          final routes = data['routes'] as List<dynamic>;
          
          print('✅ Got ${routes.length} actual routes');
          
          return {
            'success': true,
            'routes': routes, // Changed key name for consistency
            'total_routes': routes.length,
            'method': _googleMapsApiKey != null ? 'backend_with_google_api' : 'backend_fallback',
          };
        }
      }
      
      throw Exception('Failed to get routes: ${response.body}');
      
    } catch (e) {
      print('❌ Actual routes error: $e');
      throw Exception('Failed to get actual routes: $e');
    }
  }
  
  /// Get ALL water supply points from CSV
  Future<Map<String, dynamic>> getAllWaterSupplyPointsFromCSV() async {
    try {
      print('🗂️ Fetching water supply points from CSV...');
      
      final isConnected = await testBackendConnection();
      if (!isConnected) {
        throw Exception('Backend not available');
      }
      
      final uri = Uri.parse('$baseUrl/water-supply-points').replace(
        queryParameters: {'limit': '1000'},
      );
      
      final response = await http.get(uri, headers: _headers)
          .timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        
        if (data['success'] == true) {
          final points = data['points'] as List<dynamic>;
          print('✅ Got ${points.length} water supply points');
          return data;
        } else {
          throw Exception('Backend returned success=false: ${data['message']}');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
      
    } catch (e) {
      print('❌ Failed to get CSV data: $e');
      throw Exception('Cannot get water supply data: $e');
    }
  }
  
  /// FIXED: Get Google Maps route with proper API key check
  Future<Map<String, dynamic>?> getGoogleMapsRoute(
    GeoPoint start,
    GeoPoint end,
    Map<String, dynamic> destinationPlace, {
    int index = 0,
  }) async {
    try {
      print('🗺️ Getting driving route from Google Maps API...');
      
      // Check if API key is properly configured
      if (_googleMapsApiKey == null || _googleMapsApiKey!.isEmpty) {
        print('⚠️ Google Maps API key not configured, using simulation');
        return await _createSimulatedRoute(start, end, destinationPlace, index);
      }
      
      final queryParams = {
        'origin': '${start.latitude},${start.longitude}',
        'destination': '${end.latitude},${end.longitude}',
        'mode': 'driving', // DRIVING MODE
        'alternatives': 'false',
        'units': 'metric',
        'key': _googleMapsApiKey!,
        'departure_time': 'now',
        'avoid': 'tolls', // Avoid tolls by default
      };
      
      final uri = Uri.parse('$_googleMapsBaseUrl/directions/json').replace(
        queryParameters: queryParams,
      );
      
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK' && 
            (data['routes'] as List).isNotEmpty) {
          
          final route = data['routes'][0];
          final leg = route['legs'][0];
          
          // Decode polyline
          final polylinePoints = _decodeGooglePolyline(route['overview_polyline']['points']);
          
          // Calculate metrics
          final distanceKm = (leg['distance']['value'] as int) / 1000.0;
          
          return {
            'route_id': 'gmap_driving_${destinationPlace['place_id'] ?? index}',
            'destination_name': destinationPlace['name'] ?? 'Water Supply ${index + 1}',
            'destination_address': destinationPlace['vicinity'] ?? 'Unknown Address',
            'distance': distanceKm,
            'distance_meters': leg['distance']['value'],
            'travel_time': leg['duration']['text'],
            'travel_time_seconds': leg['duration']['value'],
            'travel_time_in_traffic': leg['duration_in_traffic']?['text'],
            'travel_time_in_traffic_seconds': leg['duration_in_traffic']?['value'],
            'polyline_points': polylinePoints,
            'color': '#0066CC',
            'weight': 4,
            'opacity': 0.7,
            'is_shortest': index == 0,
            'priority_rank': index + 1,
            'driving_mode': 'driving',
            'optimization': 'time',
            'destination_details': {
              'id': destinationPlace['place_id'] ?? 'google_dest_$index',
              'latitude': end.latitude,
              'longitude': end.longitude,
              'name': destinationPlace['name'] ?? 'Water Supply ${index + 1}',
              'address': destinationPlace['vicinity'] ?? '',
              'rating': destinationPlace['rating'],
              'place_id': destinationPlace['place_id'],
              'types': destinationPlace['types'],
              'accessible_by_car': true,
            },
            'google_maps_data': {
              'route_summary': route['summary'],
              'warnings': route['warnings'],
              'copyrights': route['copyrights'],
              'bounds': route['bounds'],
            },
          };
        } else {
          print('⚠️ Google API returned: ${data['status']}');
          if (data['error_message'] != null) {
            print('⚠️ Error message: ${data['error_message']}');
          }
        }
      } else {
        print('⚠️ Google API HTTP error: ${response.statusCode}');
      }
      
      // Fallback to simulation if Google API fails
      return await _createSimulatedRoute(start, end, destinationPlace, index);
      
    } catch (e) {
      print('❌ Google API call failed: $e');
      // Fallback to simulation
      return await _createSimulatedRoute(start, end, destinationPlace, index);
    }
  }
  
  /// Create simulated route as fallback
  Future<Map<String, dynamic>> _createSimulatedRoute(
    GeoPoint start,
    GeoPoint end,
    Map<String, dynamic> destination,
    int index,
  ) async {
    final distance = _calculateDistance(start.latitude, start.longitude, end.latitude, end.longitude);
    
    // Create realistic road route
    final roadPolyline = _generateRoadPolyline(start, end, distance);
    
    // Calculate realistic metrics
    final roadDistance = distance * _getRoadFactor(distance);
    final drivingTime = _calculateDrivingTime(roadDistance);
    
    return {
      'route_id': 'simulated_$index',
      'destination_name': destination['name'] ?? destination['street_name'] ?? 'Water Supply ${index + 1}',
      'destination_address': destination['address'] ?? destination['vicinity'] ?? 'Simulated Route',
      'distance': roadDistance,
      'travel_time': drivingTime,
      'polyline_points': roadPolyline,
      'color': index == 0 ? '#FF6600' : '#0099FF',
      'weight': index == 0 ? 5 : 3,
      'opacity': 0.8,
      'is_shortest': index == 0,
      'priority_rank': index + 1,
      'destination_details': {
        'id': 'sim_dest_$index',
        'latitude': end.latitude,
        'longitude': end.longitude,
        'name': destination['name'] ?? destination['street_name'] ?? 'Water Supply ${index + 1}',
        'address': destination['address'] ?? destination['vicinity'] ?? 'Unknown Address',
        'accessible_by_car': true,
      },
      'route_type': 'simulation',
      'route_source': 'simulation',
    };
  }
  
  /// Generate road-following polyline
  List<Map<String, dynamic>> _generateRoadPolyline(GeoPoint start, GeoPoint end, double distance) {
    final points = <Map<String, dynamic>>[];
    
    points.add({
      'latitude': start.latitude,
      'longitude': start.longitude,
    });
    
    final numWaypoints = Math.max(8, Math.min(20, (distance * 2).round()));
    
    for (int i = 1; i <= numWaypoints; i++) {
      final progress = i / (numWaypoints + 1);
      
      var lat = start.latitude + (end.latitude - start.latitude) * progress;
      var lng = start.longitude + (end.longitude - start.longitude) * progress;
      
      // Add road curves
      if (i > 1 && i < numWaypoints) {
        final curveFactor = Math.sin(progress * Math.pi) * 0.001;
        lat += curveFactor * (i % 2 == 0 ? 1 : -1);
        lng += curveFactor * 0.5 * (i % 3 == 0 ? 1 : -1);
      }
      
      points.add({
        'latitude': lat,
        'longitude': lng,
      });
    }
    
    points.add({
      'latitude': end.latitude,
      'longitude': end.longitude,
    });
    
    return points;
  }
  
  /// Decode Google polyline format
  List<Map<String, dynamic>> _decodeGooglePolyline(String encoded) {
    List<Map<String, dynamic>> points = [];
    int index = 0;
    int lat = 0;
    int lng = 0;
    
    while (index < encoded.length) {
      int shift = 0;
      int result = 0;
      
      int byte;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);
      
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;
      
      shift = 0;
      result = 0;
      
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);
      
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;
      
      points.add({
        'latitude': lat / 1E5,
        'longitude': lng / 1E5,
      });
    }
    
    return points;
  }
  
  /// Helper methods
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // km
    
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);
    
    final double a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos(_toRadians(lat1)) * Math.cos(_toRadians(lat2)) *
        Math.sin(dLon / 2) * Math.sin(dLon / 2);
    
    final double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    
    return earthRadius * c;
  }
  
  double _toRadians(double degrees) {
    return degrees * (Math.pi / 180);
  }
  
  double _getRoadFactor(double straightDistance) {
    if (straightDistance < 5) return 1.3;
    if (straightDistance < 15) return 1.4;
    if (straightDistance < 30) return 1.5;
    return 1.6;
  }
  
  String _calculateDrivingTime(double roadDistance) {
    double avgSpeed = 50.0; // km/h
    
    if (roadDistance < 10) {
      avgSpeed = 40.0;
    } else if (roadDistance > 25) avgSpeed = 70.0;
    
    final timeHours = roadDistance / avgSpeed;
    final timeMinutes = (timeHours * 60).round();
    
    if (timeMinutes >= 60) {
      final hours = timeMinutes ~/ 60;
      final minutes = timeMinutes % 60;
      return minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';
    }
    
    return '${timeMinutes}m';
  }
  
  /// Legacy compatibility methods
  Future<WaterQualityState> analyzeWaterQuality(File imageFile) async {
    final result = await analyzeWaterQualityWithConfidence(imageFile);
    return result.waterQuality;
  }
  
  /// Get basic routes (simplified version)
  Future<Map<String, dynamic>> getPolylineRoutesToWaterSupplies(
    GeoPoint startLocation,
    String adminId, {
    int maxRoutes = 50,
  }) async {
    try {
      print('🗺️ Getting basic polyline routes...');
      
      // Try backend first
      try {
        return await getActualDrivingRoutes(startLocation, adminId, maxRoutes: maxRoutes);
      } catch (e) {
        print('⚠️ Backend routes failed: $e');
      }
      
      // Fallback to CSV + simulation
      final csvData = await getAllWaterSupplyPointsFromCSV();
      final points = csvData['points'] as List<dynamic>;
      
      if (points.isEmpty) {
        throw Exception('No water supply points available');
      }
      
      final routes = <Map<String, dynamic>>[];
      final maxPoints = Math.min(maxRoutes, points.length);
      
      for (int i = 0; i < maxPoints; i++) {
        final point = points[i];
        final lat = (point['latitude'] as num?)?.toDouble();
        final lng = (point['longitude'] as num?)?.toDouble();
        
        if (lat != null && lng != null) {
          final destinationLocation = GeoPoint(latitude: lat, longitude: lng);
          
          final route = await _createSimulatedRoute(
            startLocation, 
            destinationLocation,
            point,
            i,
          );
          
          routes.add(route);
        }
      }
      
      // Sort by distance
      routes.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
      
      print('✅ Generated ${routes.length} fallback routes');
      
      return {
        'success': true,
        'polyline_routes': routes,
        'total_routes': routes.length,
        'method': 'csv_simulation_fallback',
      };
      
    } catch (e) {
      print('❌ Failed to get routes: $e');
      throw Exception('Failed to get routes: $e');
    }
  }
}