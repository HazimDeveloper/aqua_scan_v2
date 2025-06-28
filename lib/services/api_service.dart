// lib/services/api_service.dart - ENHANCED: Google Maps API + Genetic Algorithm
import 'dart:convert';
import 'dart:io';
import 'dart:math' as Math;
import 'package:http/http.dart' as http;
import '../utils/water_quality_utils.dart';
import '../models/report_model.dart';

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

// Enhanced Genetic Algorithm Parameters
class GAParameters {
  final int populationSize;
  final int maxGenerations;
  final int eliteSize;
  final double mutationRate;
  final double crossoverRate;
  final int tournamentSize;
  final int maxRouteLength;
  final double timeLimit;
  final int convergenceThreshold;
  
  GAParameters({
    this.populationSize = 100,
    this.maxGenerations = 200,
    this.eliteSize = 10,
    this.mutationRate = 0.15,
    this.crossoverRate = 0.85,
    this.tournamentSize = 5,
    this.maxRouteLength = 15,
    this.timeLimit = 45.0,
    this.convergenceThreshold = 20,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'population_size': populationSize,
      'max_generations': maxGenerations,
      'elite_size': eliteSize,
      'mutation_rate': mutationRate,
      'crossover_rate': crossoverRate,
      'tournament_size': tournamentSize,
      'max_route_length': maxRouteLength,
      'time_limit': timeLimit,
      'convergence_threshold': convergenceThreshold,
    };
  }
}

// Enhanced Route Optimization Request
class RouteOptimizationRequest {
  final String adminId;
  final GeoPoint currentLocation;
  final String destinationKeyword;
  final int maxRoutes;
  final String optimizationMethod;
  final GAParameters gaConfig;
  final bool useGoogleMaps;
  final String? googleMapsApiKey;
  
  RouteOptimizationRequest({
    required this.adminId,
    required this.currentLocation,
    required this.destinationKeyword,
    this.maxRoutes = 20,
    this.optimizationMethod = 'genetic_algorithm',
    required this.gaConfig,
    this.useGoogleMaps = true,
    this.googleMapsApiKey,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'admin_id': adminId,
      'current_location': {
        'latitude': currentLocation.latitude,
        'longitude': currentLocation.longitude,
      },
      'destination_keyword': destinationKeyword,
      'max_routes': maxRoutes,
      'optimization_method': optimizationMethod,
      'ga_config': gaConfig.toJson(),
      'use_google_maps': useGoogleMaps,
      'google_maps_api_key': googleMapsApiKey,
    };
  }
}

class ApiService {
  final String baseUrl;
  
  // Google Maps API configuration
  static const String _googleMapsApiKey = 'AIzaSyAwwgmqAxzQmdmjNQ-vklZnvVdZjkWLcTY'; // Replace with actual key
  static const String _googleMapsBaseUrl = 'https://maps.googleapis.com/maps/api';
  
  ApiService({required this.baseUrl});
  
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
  
  /// ENHANCED: Get water supply routes with Google Maps + Genetic Algorithm
  Future<Map<String, dynamic>> getOptimizedWaterSupplyRoutes(
    GeoPoint startLocation,
    String adminId, {
    int maxRoutes = 20,
    bool useGoogleMaps = true,
    bool useGeneticAlgorithm = true,
  }) async {
    try {
      print('🧬 Getting optimized water supply routes...');
      print('📍 Start: ${startLocation.latitude}, ${startLocation.longitude}');
      print('🗺️ Google Maps: $useGoogleMaps');
      print('🧬 Genetic Algorithm: $useGeneticAlgorithm');
      
      // Check backend connection
      final isConnected = await testBackendConnection();
      if (!isConnected) {
        throw Exception('Backend server not available');
      }
      
      // STEP 1: Try enhanced optimization endpoint
      if (useGeneticAlgorithm) {
        try {
          final gaResult = await _getGeneticAlgorithmRoutes(
            startLocation, 
            adminId, 
            maxRoutes: maxRoutes,
            useGoogleMaps: useGoogleMaps,
          );
          
          if (gaResult['success'] == true && 
              (gaResult['optimized_routes'] as List?)?.isNotEmpty == true) {
            print('✅ GA optimization successful');
            return gaResult;
          }
        } catch (gaError) {
          print('⚠️ GA optimization failed: $gaError');
        }
      }
      
      // STEP 2: Fallback to Google Maps API directly
      if (useGoogleMaps) {
        try {
          final mapsResult = await _getGoogleMapsRoutes(
            startLocation, 
            maxRoutes: maxRoutes,
          );
          
          if (mapsResult['success'] == true) {
            print('✅ Google Maps API successful');
            return mapsResult;
          }
        } catch (mapsError) {
          print('⚠️ Google Maps API failed: $mapsError');
        }
      }
      
      // STEP 3: Fallback to basic calculation
      print('🔄 Using fallback calculation...');
      return await _getBasicCalculatedRoutes(startLocation, adminId, maxRoutes: maxRoutes);
      
    } catch (e) {
      print('❌ Route optimization failed: $e');
      throw Exception('Failed to get optimized routes: $e');
    }
  }
  
  /// Enhanced Genetic Algorithm route optimization
  Future<Map<String, dynamic>> _getGeneticAlgorithmRoutes(
    GeoPoint startLocation,
    String adminId, {
    int maxRoutes = 20,
    bool useGoogleMaps = true,
  }) async {
    try {
      print('🧬 Starting Genetic Algorithm optimization...');
      
      final gaParams = GAParameters(
        populationSize: Math.min(100, maxRoutes * 5),
        maxGenerations: 150,
        eliteSize: Math.max(5, maxRoutes ~/ 4),
        mutationRate: 0.12,
        crossoverRate: 0.88,
        maxRouteLength: Math.min(20, maxRoutes + 5),
      );
      
      final request = RouteOptimizationRequest(
        adminId: adminId,
        currentLocation: startLocation,
        destinationKeyword: 'water_supply',
        maxRoutes: maxRoutes,
        optimizationMethod: 'genetic_algorithm',
        gaConfig: gaParams,
        useGoogleMaps: useGoogleMaps,
        googleMapsApiKey: useGoogleMaps ? _googleMapsApiKey : null,
      );
      
      print('📝 GA Request: ${json.encode(request.toJson())}');
      
      final response = await http.post(
        Uri.parse('$baseUrl/optimize-routes-genetic'),
        headers: _headers,
        body: json.encode(request.toJson()),
      ).timeout(Duration(seconds: (gaParams.timeLimit + 15).round()));
      
      print('📥 GA Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        
        if (data['success'] == true) {
          final optimizedRoutes = data['optimized_routes'] as List<dynamic>? ?? [];
          
          print('✅ GA optimization returned ${optimizedRoutes.length} routes');
          print('🎯 Best fitness: ${data['best_fitness']}');
          print('⏱️ GA runtime: ${data['optimization_time']}s');
          
          // Convert to standard format
          final formattedRoutes = _formatGARoutesToStandard(optimizedRoutes, startLocation);
          
          return {
            'success': true,
            'method': 'genetic_algorithm',
            'polyline_routes': formattedRoutes,
            'optimization_stats': {
              'fitness_score': data['best_fitness'],
              'generations_run': data['generations_run'],
              'optimization_time': data['optimization_time'],
              'convergence_achieved': data['convergence_achieved'],
            },
            'total_routes': formattedRoutes.length,
            'google_maps_used': useGoogleMaps,
          };
        }
      }
      
      throw Exception('GA optimization failed: ${response.body}');
      
    } catch (e) {
      print('❌ GA optimization error: $e');
      throw Exception('Genetic algorithm optimization failed: $e');
    }
  }
  
  /// Google Maps API integration
  Future<Map<String, dynamic>> _getGoogleMapsRoutes(
    GeoPoint startLocation, {
    int maxRoutes = 20,
  }) async {
    try {
      print('🗺️ Getting routes via Google Maps API...');
      
      if (_googleMapsApiKey == 'AIzaSyAwwgmqAxzQmdmjNQ-vklZnvVdZjkWLcTY') {
        throw Exception('Google Maps API key not configured');
      }
      
      // STEP 1: Get nearby water supply places
      final nearbyPlaces = await _findNearbyWaterSupplies(startLocation);
      
      if (nearbyPlaces.isEmpty) {
        throw Exception('No water supply points found via Google Places');
      }
      
      print('📍 Found ${nearbyPlaces.length} water supply places');
      
      // STEP 2: Get routes to each place
      final routes = <Map<String, dynamic>>[];
      
      for (int i = 0; i < Math.min(maxRoutes, nearbyPlaces.length); i++) {
        final place = nearbyPlaces[i];
        
        try {
          final route = await _getGoogleMapsRoute(
            startLocation,
            GeoPoint(
              latitude: place['geometry']['location']['lat'],
              longitude: place['geometry']['location']['lng'],
            ),
            place,
          );
          
          if (route != null) {
            routes.add(route);
          }
        } catch (e) {
          print('⚠️ Failed to get route to ${place['name']}: $e');
        }
      }
      
      // Sort routes by distance
      routes.sort((a, b) => 
        (a['distance_meters'] as int).compareTo(b['distance_meters'] as int));
      
      print('✅ Google Maps returned ${routes.length} routes');
      
      return {
        'success': true,
        'method': 'google_maps_api',
        'polyline_routes': routes,
        'total_routes': routes.length,
        'places_found': nearbyPlaces.length,
      };
      
    } catch (e) {
      print('❌ Google Maps API error: $e');
      throw Exception('Google Maps API failed: $e');
    }
  }
  
  /// Find nearby water supplies using Google Places API
  Future<List<Map<String, dynamic>>> _findNearbyWaterSupplies(GeoPoint location) async {
    final queries = [
      'water supply',
      'water treatment plant',
      'water distribution',
      'water utility',
      'water department',
    ];
    
    final allPlaces = <Map<String, dynamic>>[];
    
    for (final query in queries) {
      try {
        final uri = Uri.parse('$_googleMapsBaseUrl/place/nearbysearch/json').replace(
          queryParameters: {
            'location': '${location.latitude},${location.longitude}',
            'radius': '50000', // 50km radius
            'keyword': query,
            'key': _googleMapsApiKey,
          },
        );
        
        final response = await http.get(uri).timeout(const Duration(seconds: 10));
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          
          if (data['status'] == 'OK') {
            final places = data['results'] as List<dynamic>;
            allPlaces.addAll(places.cast<Map<String, dynamic>>());
          }
        }
      } catch (e) {
        print('⚠️ Places search failed for "$query": $e');
      }
    }
    
    // Remove duplicates and sort by distance
    final uniquePlaces = <String, Map<String, dynamic>>{};
    
    for (final place in allPlaces) {
      final placeId = place['place_id'] as String?;
      if (placeId != null) {
        uniquePlaces[placeId] = place;
      }
    }
    
    final result = uniquePlaces.values.toList();
    
    // Calculate distances and sort
    for (final place in result) {
      final lat = place['geometry']['location']['lat'] as double;
      final lng = place['geometry']['location']['lng'] as double;
      
      final distance = _calculateDistance(
        location.latitude, location.longitude,
        lat, lng,
      );
      
      place['calculated_distance'] = distance;
    }
    
    result.sort((a, b) => 
      (a['calculated_distance'] as double).compareTo(b['calculated_distance'] as double));
    
    return result;
  }
  
  /// Get route using Google Directions API
  Future<Map<String, dynamic>?> _getGoogleMapsRoute(
    GeoPoint start,
    GeoPoint end,
    Map<String, dynamic> destinationPlace,
  ) async {
    try {
      final uri = Uri.parse('$_googleMapsBaseUrl/directions/json').replace(
        queryParameters: {
          'origin': '${start.latitude},${start.longitude}',
          'destination': '${end.latitude},${end.longitude}',
          'mode': 'driving',
          'alternatives': 'false',
          'key': _googleMapsApiKey,
        },
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
          
          return {
            'route_id': 'gmap_${destinationPlace['place_id']}',
            'destination_name': destinationPlace['name'],
            'destination_address': destinationPlace['vicinity'] ?? 'Unknown Address',
            'distance': (leg['distance']['value'] as int) / 1000.0, // Convert to km
            'distance_meters': leg['distance']['value'],
            'travel_time': leg['duration']['text'],
            'travel_time_seconds': leg['duration']['value'],
            'polyline_points': polylinePoints,
            'color': '#0066CC',
            'weight': 4,
            'opacity': 0.7,
            'is_shortest': false,
            'priority_rank': 1,
            'destination_details': {
              'id': destinationPlace['place_id'],
              'latitude': end.latitude,
              'longitude': end.longitude,
              'name': destinationPlace['name'],
              'address': destinationPlace['vicinity'] ?? '',
              'rating': destinationPlace['rating'],
              'place_id': destinationPlace['place_id'],
              'types': destinationPlace['types'],
            },
            'google_maps_data': {
              'route_summary': route['summary'],
              'warnings': route['warnings'],
              'copyrights': route['copyrights'],
            },
          };
        }
      }
      
      return null;
      
    } catch (e) {
      print('❌ Google Directions API error: $e');
      return null;
    }
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
  
  /// Format GA results to standard format
  List<Map<String, dynamic>> _formatGARoutesToStandard(
    List<dynamic> gaRoutes,
    GeoPoint startLocation,
  ) {
    final formattedRoutes = <Map<String, dynamic>>[];
    
    for (int i = 0; i < gaRoutes.length; i++) {
      final route = gaRoutes[i] as Map<String, dynamic>;
      
      // Extract waypoints and create polyline
      final waypoints = route['waypoints'] as List<dynamic>? ?? [];
      final polylinePoints = <Map<String, dynamic>>[];
      
      // Add start point
      polylinePoints.add({
        'latitude': startLocation.latitude,
        'longitude': startLocation.longitude,
      });
      
      // Add waypoints
      for (final waypoint in waypoints) {
        if (waypoint is Map<String, dynamic>) {
          polylinePoints.add({
            'latitude': (waypoint['latitude'] as num?)?.toDouble() ?? 0.0,
            'longitude': (waypoint['longitude'] as num?)?.toDouble() ?? 0.0,
          });
        }
      }
      
      final destination = waypoints.isNotEmpty ? waypoints.last : null;
      
      formattedRoutes.add({
        'route_id': 'ga_route_$i',
        'destination_name': destination?['name'] ?? 'Water Supply ${i + 1}',
        'destination_address': destination?['address'] ?? 'GA Optimized Route',
        'distance': (route['total_distance'] as num?)?.toDouble() ?? 0.0,
        'travel_time': route['estimated_time'] ?? 'Unknown',
        'polyline_points': polylinePoints,
        'color': _getRouteColor(i),
        'weight': i == 0 ? 6 : 4,
        'opacity': i == 0 ? 0.9 : 0.7,
        'is_shortest': i == 0,
        'priority_rank': i + 1,
        'destination_details': destination ?? {
          'id': 'ga_dest_$i',
          'latitude': polylinePoints.last['latitude'],
          'longitude': polylinePoints.last['longitude'],
          'name': 'GA Optimized Destination ${i + 1}',
        },
        'genetic_algorithm_data': {
          'fitness_score': route['fitness_score'],
          'generation_found': route['generation_found'],
          'waypoint_count': waypoints.length,
        },
      });
    }
    
    return formattedRoutes;
  }
  
  /// Fallback basic calculation method
  Future<Map<String, dynamic>> _getBasicCalculatedRoutes(
    GeoPoint startLocation,
    String adminId, {
    int maxRoutes = 20,
  }) async {
    try {
      print('🧮 Using basic calculation fallback...');
      
      // Get CSV data
      final csvData = await getAllWaterSupplyPointsFromCSV();
      final points = csvData['points'] as List<dynamic>;
      
      if (points.isEmpty) {
        throw Exception('No water supply points in CSV data');
      }
      
      // Calculate distances and create routes
      final routes = <Map<String, dynamic>>[];
      
      for (int i = 0; i < Math.min(maxRoutes, points.length); i++) {
        final point = points[i];
        final lat = (point['latitude'] as num?)?.toDouble();
        final lng = (point['longitude'] as num?)?.toDouble();
        
        if (lat != null && lng != null) {
          final distance = _calculateDistance(
            startLocation.latitude, startLocation.longitude,
            lat, lng,
          );
          
          routes.add({
            'route_id': 'basic_route_$i',
            'destination_name': point['street_name'] ?? 'Water Supply ${i + 1}',
            'destination_address': point['address'] ?? 'Unknown Address',
            'distance': distance,
            'travel_time': _calculateTravelTime(distance),
            'polyline_points': _generateSimplePolyline(startLocation, lat, lng),
            'color': _getRouteColor(i),
            'weight': 4,
            'opacity': 0.7,
            'is_shortest': false,
            'priority_rank': i + 1,
            'destination_details': {
              'id': point['id'] ?? 'basic_dest_$i',
              'latitude': lat,
              'longitude': lng,
              'street_name': point['street_name'],
              'address': point['address'],
            },
          });
        }
      }
      
      // Sort by distance
      routes.sort((a, b) => 
        (a['distance'] as double).compareTo(b['distance'] as double));
      
      // Mark shortest route
      if (routes.isNotEmpty) {
        routes[0]['is_shortest'] = true;
        routes[0]['color'] = '#FF0000';
      }
      
      return {
        'success': true,
        'method': 'basic_calculation',
        'polyline_routes': routes,
        'total_routes': routes.length,
      };
      
    } catch (e) {
      print('❌ Basic calculation failed: $e');
      throw Exception('All route calculation methods failed: $e');
    }
  }
  
  /// Generate simple polyline between two points
  List<Map<String, dynamic>> _generateSimplePolyline(
    GeoPoint start,
    double endLat,
    double endLng,
  ) {
    const int segments = 20;
    final points = <Map<String, dynamic>>[];
    
    for (int i = 0; i <= segments; i++) {
      final ratio = i / segments;
      final lat = start.latitude + (endLat - start.latitude) * ratio;
      final lng = start.longitude + (endLng - start.longitude) * ratio;
      
      points.add({
        'latitude': lat,
        'longitude': lng,
      });
    }
    
    return points;
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
  
  String _calculateTravelTime(double distanceKm, {String mode = 'car'}) {
    final speeds = {
      'walking': 5.0,
      'bicycle': 15.0,
      'car': 60.0,
      'public_transport': 40.0,
    };
    
    final speed = speeds[mode] ?? speeds['car']!;
    final timeHours = distanceKm / speed;
    
    if (timeHours < 1) {
      return '${(timeHours * 60).round()} min';
    } else {
      final hours = timeHours.floor();
      final minutes = ((timeHours - hours) * 60).round();
      return minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';
    }
  }
  
  String _getRouteColor(int index) {
    final colors = [
      '#FF0000', '#0066CC', '#00CC66', '#CC6600', '#6600CC',
      '#CC0066', '#00CCCC', '#CCCC00', '#996633', '#FF6600',
    ];
    return colors[index % colors.length];
  }
  
  /// Legacy compatibility methods
  Future<WaterQualityState> analyzeWaterQuality(File imageFile) async {
    final result = await analyzeWaterQualityWithConfidence(imageFile);
    return result.waterQuality;
  }
  
  Future<Map<String, dynamic>> getPolylineRoutesToWaterSupplies(
    GeoPoint startLocation,
    String adminId, {
    int maxRoutes = 50,
  }) async {
    return await getOptimizedWaterSupplyRoutes(
      startLocation,
      adminId,
      maxRoutes: maxRoutes,
      useGoogleMaps: true,
      useGeneticAlgorithm: true,
    );
  }
}