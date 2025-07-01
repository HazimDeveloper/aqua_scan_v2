// lib/services/api_service.dart - COMPLETE VERSION with Enhanced Driving Mode
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

// Driving Preferences Class
class DrivingPreferences {
  final bool avoidTolls;
  final bool avoidHighways;
  final bool avoidFerries;
  final String optimizeFor; // 'time' or 'distance'
  final bool useRealTimeTraffic;
  final String units; // 'metric' or 'imperial'
  final double fuelEfficiencyKmPerLiter;
  final double fuelPricePerLiter;
  
  DrivingPreferences({
    this.avoidTolls = false,
    this.avoidHighways = false,
    this.avoidFerries = true,
    this.optimizeFor = 'time',
    this.useRealTimeTraffic = true,
    this.units = 'metric',
    this.fuelEfficiencyKmPerLiter = 12.0,
    this.fuelPricePerLiter = 2.50,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'avoid_tolls': avoidTolls,
      'avoid_highways': avoidHighways,
      'avoid_ferries': avoidFerries,
      'optimize_for': optimizeFor,
      'use_real_time_traffic': useRealTimeTraffic,
      'units': units,
      'fuel_efficiency': fuelEfficiencyKmPerLiter,
      'fuel_price': fuelPricePerLiter,
    };
  }
}

class ApiService {
  final String baseUrl;
  
  // Google Maps API configuration
  static const String _googleMapsApiKey = 'AIzaSyAwwgmqAxzQmdmjNQ-vklZnvVdZjkWLcTY';
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
  
  // Add new method to get actual driving routes:
Future<Map<String, dynamic>> getActualDrivingRoutes(
  GeoPoint currentLocation,
  String adminId, {
  int maxRoutes = 20,
}) async {
  try {
    print('🚗 Getting actual routes from backend...');
    
    final response = await http.get(
      Uri.parse('$baseUrl/water-supply-points-with-routes').replace(
        queryParameters: {
          'current_lat': currentLocation.latitude.toString(),
          'current_lng': currentLocation.longitude.toString(),
          'api_key': _googleMapsApiKey,
          'limit': maxRoutes.toString(),
        },
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
          'polyline_routes': routes,
          'total_routes': routes.length,
          'method': 'google_directions_api',
        };
      }
    }
    
    throw Exception('Failed to get  routes: ${response.body}');
    
  } catch (e) {
    print('❌ Actual  routes error: $e');
    throw Exception('Failed to get actual  routes: $e');
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
  
  /// ENHANCED: Get water supply routes with Google Maps + Genetic Algorithm + Driving Mode
  Future<Map<String, dynamic>> getOptimizedWaterSupplyRoutes(
    GeoPoint startLocation,
    String adminId, {
    int maxRoutes = 20,
    bool useGoogleMaps = true,
    bool useGeneticAlgorithm = true,
    DrivingPreferences? drivingPrefs,
  }) async {
    try {
      final preferences = drivingPrefs ?? DrivingPreferences();
      
      print('🧬 Getting optimized water supply routes...');
      print('📍 Start: ${startLocation.latitude}, ${startLocation.longitude}');
      print('🗺️ Google Maps: $useGoogleMaps');
      print('🧬 Genetic Algorithm: $useGeneticAlgorithm');
      print('🚗 Driving preferences: ${preferences.toJson()}');
      
      // Check backend connection
      final isConnected = await testBackendConnection();
      if (!isConnected) {
        throw Exception('Backend server not available');
      }
      
      // STEP 1: Try enhanced optimization endpoint with driving mode
      if (useGeneticAlgorithm) {
        try {
          final gaResult = await _getGeneticAlgorithmRoutes(
            startLocation, 
            adminId, 
            maxRoutes: maxRoutes,
            useGoogleMaps: useGoogleMaps,
            drivingPrefs: preferences,
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
      
      // STEP 2: Fallback to Google Maps API with driving mode
      if (useGoogleMaps) {
        try {
          final mapsResult = await _getGoogleMapsRoutes(
            startLocation, 
            maxRoutes: maxRoutes,
            drivingPrefs: preferences,
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
      return await _getBasicCalculatedRoutes(
        startLocation, 
        adminId, 
        maxRoutes: maxRoutes,
        drivingPrefs: preferences,
      );
      
    } catch (e) {
      print('❌ Route optimization failed: $e');
      throw Exception('Failed to get optimized routes: $e');
    }
  }
  
  /// Enhanced Genetic Algorithm route optimization with driving mode
  Future<Map<String, dynamic>> _getGeneticAlgorithmRoutes(
    GeoPoint startLocation,
    String adminId, {
    int maxRoutes = 20,
    bool useGoogleMaps = true,
    required DrivingPreferences drivingPrefs,
  }) async {
    try {
      print('🧬 Starting Genetic Algorithm optimization with driving mode...');
      
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
        optimizationMethod: 'genetic_algorithm_driving',
        gaConfig: gaParams,
        useGoogleMaps: useGoogleMaps,
        googleMapsApiKey: useGoogleMaps ? _googleMapsApiKey : null,
      );
      
      // Add driving preferences to the request
      final enhancedRequest = request.toJson();
      enhancedRequest['driving_preferences'] = drivingPrefs.toJson();
      enhancedRequest['travel_mode'] = 'driving';
      
      print('📝 GA Request: ${json.encode(enhancedRequest)}');
      
      final response = await http.post(
        Uri.parse('$baseUrl/optimize-routes-genetic-driving'),
        headers: _headers,
        body: json.encode(enhancedRequest),
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
          final formattedRoutes = _formatGARoutesToStandard(
            optimizedRoutes, 
            startLocation,
            drivingPrefs: drivingPrefs,
          );
          
          return {
            'success': true,
            'method': 'genetic_algorithm_driving',
            'polyline_routes': formattedRoutes,
            'optimization_stats': {
              'fitness_score': data['best_fitness'],
              'generations_run': data['generations_run'],
              'optimization_time': data['optimization_time'],
              'convergence_achieved': data['convergence_achieved'],
            },
            'total_routes': formattedRoutes.length,
            'google_maps_used': useGoogleMaps,
            'driving_preferences': drivingPrefs.toJson(),
          };
        }
      }
      
      throw Exception('GA optimization failed: ${response.body}');
      
    } catch (e) {
      print('❌ GA optimization error: $e');
      throw Exception('Genetic algorithm optimization failed: $e');
    }
  }
  
  /// Google Maps API integration with enhanced driving mode
  Future<Map<String, dynamic>> _getGoogleMapsRoutes(
    GeoPoint startLocation, {
    int maxRoutes = 20,
    required DrivingPreferences drivingPrefs,
  }) async {
    try {
      print('🗺️ Getting routes via Google Maps API with driving mode...');
      
      if (_googleMapsApiKey == 'AIzaSyAwwgmqAxzQmdmjNQ-vklZnvVdZjkWLcTY') {
        throw Exception('Google Maps API key not configured');
      }
      
      // STEP 1: Get nearby water supply places (car-accessible)
      final nearbyPlaces = await _findNearbyWaterSupplies(
        startLocation,
        prioritizeAccessible: true,
      );
      
      if (nearbyPlaces.isEmpty) {
        throw Exception('No water supply points found via Google Places');
      }
      
      print('📍 Found ${nearbyPlaces.length} water supply places');
      
      // STEP 2: Get driving routes to each place
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
            drivingPrefs: drivingPrefs,
          );
          
          if (route != null) {
            routes.add(route);
          }
        } catch (e) {
          print('⚠️ Failed to get route to ${place['name']}: $e');
        }
      }
      
      // Sort routes based on optimization preference
      if (drivingPrefs.optimizeFor == 'time') {
        routes.sort((a, b) => 
          (a['travel_time_seconds'] as int).compareTo(b['travel_time_seconds'] as int));
      } else {
        routes.sort((a, b) => 
          (a['distance_meters'] as int).compareTo(b['distance_meters'] as int));
      }
      
      print('✅ Google Maps returned ${routes.length} routes');
      
      return {
        'success': true,
        'method': 'google_maps_driving_api',
        'polyline_routes': routes,
        'total_routes': routes.length,
        'places_found': nearbyPlaces.length,
        'driving_preferences': drivingPrefs.toJson(),
      };
      
    } catch (e) {
      print('❌ Google Maps API error: $e');
      throw Exception('Google Maps API failed: $e');
    }
  }
  
  /// Find nearby water supplies using Google Places API with driving filters
  Future<List<Map<String, dynamic>>> _findNearbyWaterSupplies(
    GeoPoint location, {
    int radiusMeters = 50000,
    bool prioritizeAccessible = true,
  }) async {
    final queries = [
      'water supply',
      'water treatment plant',
      'water distribution center',
      'water utility company',
      'municipal water department',
      'water pumping station',
    ];
    
    final allPlaces = <Map<String, dynamic>>[];
    
    for (final query in queries) {
      try {
        final uri = Uri.parse('$_googleMapsBaseUrl/place/nearbysearch/json').replace(
          queryParameters: {
            'location': '${location.latitude},${location.longitude}',
            'radius': radiusMeters.toString(),
            'keyword': query,
            'key': _googleMapsApiKey,
            'type': 'establishment',
          },
        );
        
        final response = await http.get(uri).timeout(const Duration(seconds: 10));
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          
          if (data['status'] == 'OK') {
            final places = data['results'] as List<dynamic>;
            
            // Filter places that are accessible by car
            for (final place in places) {
              if (_isPlaceAccessibleByCar(place)) {
                allPlaces.add(place);
              }
            }
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
    
    // Calculate distances and add driving metadata
    for (final place in result) {
      final lat = place['geometry']['location']['lat'] as double;
      final lng = place['geometry']['location']['lng'] as double;
      
      final distance = _calculateDistance(
        location.latitude, location.longitude,
        lat, lng,
      );
      
      place['calculated_distance'] = distance;
      place['accessible_by_car'] = _isPlaceAccessibleByCar(place);
      place['has_parking'] = _placeHasParking(place);
    }
    
    // Sort by distance, prioritizing car-accessible places
    result.sort((a, b) {
      if (prioritizeAccessible) {
        final aAccessible = a['accessible_by_car'] as bool? ?? false;
        final bAccessible = b['accessible_by_car'] as bool? ?? false;
        
        if (aAccessible && !bAccessible) return -1;
        if (!aAccessible && bAccessible) return 1;
      }
      
      return (a['calculated_distance'] as double).compareTo(b['calculated_distance'] as double);
    });
    
    return result;
  }
  
  /// Check if a place is accessible by car
  bool _isPlaceAccessibleByCar(Map<String, dynamic> place) {
    final types = place['types'] as List<dynamic>? ?? [];
    final name = (place['name'] as String? ?? '').toLowerCase();
    
    // Exclude places that are typically not accessible by car
    final inaccessibleTypes = [
      'hiking_area',
      'park',
      'natural_feature',
      'campground',
      'trail',
    ];
    
    final inaccessibleKeywords = [
      'hiking',
      'trail',
      'mountain',
      'forest',
      'remote',
      'foot access only',
    ];
    
    // Check for inaccessible types
    for (final type in inaccessibleTypes) {
      if (types.contains(type)) return false;
    }
    
    // Check for inaccessible keywords in name
    for (final keyword in inaccessibleKeywords) {
      if (name.contains(keyword)) return false;
    }
    
    return true;
  }
  
  /// Check if a place has parking information
  bool _placeHasParking(Map<String, dynamic> place) {
    final types = place['types'] as List<dynamic>? ?? [];
    
    // These types typically have parking
    final parkingLikelyTypes = [
      'establishment',
      'point_of_interest',
      'local_government_office',
      'utility',
    ];
    
    return parkingLikelyTypes.any((type) => types.contains(type));
  }
  
  /// Get route using Google Directions API with enhanced driving mode
  Future<Map<String, dynamic>?> _getGoogleMapsRoute(
    GeoPoint start,
    GeoPoint end,
    Map<String, dynamic> destinationPlace, {
    required DrivingPreferences drivingPrefs,
  }) async {
    try {
      print('🚗 Getting driving route from Google Maps API...');
      
      // Build avoid string
      List<String> avoidOptions = [];
      if (drivingPrefs.avoidTolls) avoidOptions.add('tolls');
      if (drivingPrefs.avoidHighways) avoidOptions.add('highways');
      if (drivingPrefs.avoidFerries) avoidOptions.add('ferries');
      
      final queryParams = {
        'origin': '${start.latitude},${start.longitude}',
        'destination': '${end.latitude},${end.longitude}',
        'mode': 'driving', // DRIVING MODE
        'alternatives': 'false',
        'units': drivingPrefs.units,
        'key': _googleMapsApiKey,
        'departure_time': drivingPrefs.useRealTimeTraffic ? 'now' : '',
      };
      
      // Add avoid parameters if any
      if (avoidOptions.isNotEmpty) {
        queryParams['avoid'] = avoidOptions.join('|');
      }
      
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
          final fuelCost = _calculateEstimatedFuelCost(
            distanceKm,
            drivingPrefs.fuelEfficiencyKmPerLiter,
            drivingPrefs.fuelPricePerLiter,
          );
          
          return {
            'route_id': 'gmap_driving_${destinationPlace['place_id']}',
            'destination_name': destinationPlace['name'],
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
            'is_shortest': false,
            'priority_rank': 1,
            'driving_mode': 'driving',
            'avoid_options': avoidOptions,
            'optimization': drivingPrefs.optimizeFor,
            'estimated_fuel_cost': fuelCost,
            'destination_details': {
              'id': destinationPlace['place_id'],
              'latitude': end.latitude,
              'longitude': end.longitude,
              'name': destinationPlace['name'],
              'address': destinationPlace['vicinity'] ?? '',
              'rating': destinationPlace['rating'],
              'place_id': destinationPlace['place_id'],
              'types': destinationPlace['types'],
              'accessible_by_car': true,
              'has_parking': _placeHasParking(destinationPlace),
            },
            'google_maps_data': {
              'route_summary': route['summary'],
              'warnings': route['warnings'],
              'copyrights': route['copyrights'],
              'bounds': route['bounds'],
              'fare': route['fare'],
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
  
  /// Format GA results to standard format with driving preferences
  List<Map<String, dynamic>> _formatGARoutesToStandard(
    List<dynamic> gaRoutes,
    GeoPoint startLocation, {
    required DrivingPreferences drivingPrefs,
  }) {
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
      final distanceKm = (route['total_distance'] as num?)?.toDouble() ?? 0.0;
      
      formattedRoutes.add({
        'route_id': 'ga_driving_route_$i',
        'destination_name': destination?['name'] ?? 'Water Supply ${i + 1}',
        'destination_address': destination?['address'] ?? 'GA Optimized Driving Route',
        'distance': distanceKm,
        'travel_time': _calculateDrivingTime(
          distanceKm,
          considerTraffic: drivingPrefs.useRealTimeTraffic,
        ),
        'polyline_points': polylinePoints,
        'color': _getDrivingRouteColor(i),
        'weight': i == 0 ? 6 : 4,
        'opacity': i == 0 ? 0.9 : 0.7,
        'is_shortest': i == 0,
        'priority_rank': i + 1,
        'driving_mode': 'driving',
        'estimated_fuel_cost': _calculateEstimatedFuelCost(
          distanceKm,
          drivingPrefs.fuelEfficiencyKmPerLiter,
          drivingPrefs.fuelPricePerLiter,
        ),
        'destination_details': destination ?? {
          'id': 'ga_driving_dest_$i',
          'latitude': polylinePoints.last['latitude'],
          'longitude': polylinePoints.last['longitude'],
          'name': 'GA Optimized Driving Destination ${i + 1}',
          'accessible_by_car': true,
        },
        'genetic_algorithm_data': {
          'fitness_score': route['fitness_score'],
          'generation_found': route['generation_found'],
          'waypoint_count': waypoints.length,
          'optimization_method': 'driving_focused',
        },
        'driving_preferences': drivingPrefs.toJson(),
      });
    }
    
    return formattedRoutes;
  }
  
  /// Fallback basic calculation method with driving considerations
  Future<Map<String, dynamic>> _getBasicCalculatedRoutes(
  GeoPoint startLocation,
  String adminId, {
  int maxRoutes = 20,
  required DrivingPreferences drivingPrefs,
}) async {
  try {
    print('🧮 Getting enhanced calculated routes with road simulation...');
    
    // Get CSV data
    final csvData = await getAllWaterSupplyPointsFromCSV();
    final points = csvData['points'] as List<dynamic>;
    
    if (points.isEmpty) {
      throw Exception('No water supply points in CSV data');
    }
    
    // Calculate distances and create SIMULATED ROAD routes
    final routes = <Map<String, dynamic>>[];
    
    for (int i = 0; i < Math.min(maxRoutes, points.length); i++) {
      final point = points[i];
      final lat = (point['latitude'] as num?)?.toDouble();
      final lng = (point['longitude'] as num?)?.toDouble();
      
      if (lat != null && lng != null) {
        final destinationLocation = GeoPoint(latitude: lat, longitude: lng);
        
        // Calculate straight-line distance
        final straightDistance = _calculateDistance(
          startLocation.latitude, 
          startLocation.longitude,
          lat, 
          lng
        );
        
        // ENHANCED: Simulate realistic road routes
        final simulatedRoute = _simulateRoadRoute(
          startLocation, 
          destinationLocation,
          straightDistance
        );
        
        routes.add({
          'route_id': 'enhanced_route_$i',
          'destination_name': point['street_name'] ?? 'Water Supply ${i + 1}',
          'destination_address': point['address'] ?? 'Unknown Address',
          'distance': simulatedRoute['distance'],
          'travel_time': simulatedRoute['travel_time'],
          'polyline_points': simulatedRoute['polyline_points'], // ENHANCED POINTS
          'color': i == 0 ? '#00FF00' : '#0066CC',
          'weight': i == 0 ? 6 : 4,
          'opacity': 0.8,
          'is_shortest': i == 0,
          'priority_rank': i + 1,
          'destination_details': {
            'id': 'csv_dest_$i',
            'latitude': lat,
            'longitude': lng,
            'street_name': point['street_name'] ?? 'Water Supply ${i + 1}',
            'address': point['address'] ?? 'Unknown Address',
            'point_of_interest': point['point_of_interest'] ?? '',
            'additional_info': point['additional_info'] ?? '',
          },
          'route_type': 'simulated_road_route',
        });
      }
    }
    
    // Sort by distance
    routes.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
    
    print('✅ Generated ${routes.length} enhanced simulated road routes');
    
    return {
      'success': true,
      'polyline_routes': routes,
      'total_routes': routes.length,
      'method': 'enhanced_simulation',
    };
    
  } catch (e) {
    print('❌ Enhanced calculation error: $e');
    throw Exception('Enhanced route calculation failed: $e');
  }
}

Map<String, dynamic> _simulateRoadRoute(
  GeoPoint start, 
  GeoPoint end, 
  double straightDistance
) {
  // Simulate realistic road route with waypoints
  final polylinePoints = <Map<String, dynamic>>[];
  
  // Start point
  polylinePoints.add({
    'latitude': start.latitude,
    'longitude': start.longitude,
  });
  
  // Calculate intermediate points to simulate road curves
  final numWaypoints = Math.max(3, (straightDistance * 2).round());
  
  for (int i = 1; i <= numWaypoints; i++) {
    final progress = i / (numWaypoints + 1);
    
    // Linear interpolation with road-like curves
    var lat = start.latitude + (end.latitude - start.latitude) * progress;
    var lng = start.longitude + (end.longitude - start.longitude) * progress;
    
    // Add realistic road deviations
    if (i > 1 && i < numWaypoints) {
      // Simulate road curves and avoiding obstacles
      final curveFactor = Math.sin(progress * Math.pi) * 0.001; // Small deviation
      lat += curveFactor * (i % 2 == 0 ? 1 : -1);
      lng += curveFactor * 0.5 * (i % 3 == 0 ? 1 : -1);
      
      // Simulate following major roads (rough approximation)
      if (straightDistance > 5.0) {
        // For longer distances, simulate highway-like routes
        final roadOffset = 0.002 * Math.sin(progress * 2 * Math.pi);
        lat += roadOffset;
      }
    }
    
    polylinePoints.add({
      'latitude': lat,
      'longitude': lng,
    });
  }
  
  // End point
  polylinePoints.add({
    'latitude': end.latitude,
    'longitude': end.longitude,
  });
  
  // Calculate realistic road distance (typically 1.2-1.5x straight distance)
  final roadFactor = 1.3 + (straightDistance > 10 ? 0.1 : 0); // Longer routes have more curves
  final roadDistance = straightDistance * roadFactor;
  
  // Calculate travel time (assuming average speed)
  final averageSpeedKmh = straightDistance > 20 ? 60 : (straightDistance > 5 ? 40 : 25);
  final travelTimeHours = roadDistance / averageSpeedKmh;
  final travelTimeMinutes = (travelTimeHours * 60).round();
  
  String travelTimeText;
  if (travelTimeMinutes >= 60) {
    final hours = travelTimeMinutes ~/ 60;
    final minutes = travelTimeMinutes % 60;
    travelTimeText = '${hours}h ${minutes}m';
  } else {
    travelTimeText = '${travelTimeMinutes}m';
  }
  
  return {
    'distance': roadDistance,
    'travel_time': travelTimeText,
    'polyline_points': polylinePoints,
    'simulation_method': 'road_curve_simulation',
    'waypoints_count': polylinePoints.length,
  };
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
  
  /// Calculate estimated fuel cost for driving
  double _calculateEstimatedFuelCost(
    double distanceKm,
    double fuelEfficiencyKmPerLiter,
    double fuelPricePerLiter,
  ) {
    final litersNeeded = distanceKm / fuelEfficiencyKmPerLiter;
    return litersNeeded * fuelPricePerLiter;
  }
  
  /// Calculate driving time with traffic considerations
  String _calculateDrivingTime(
    double distanceKm, {
    bool considerTraffic = true,
    double baseSpeedKmh = 60.0,
  }) {
    double effectiveSpeed = baseSpeedKmh;
    
    if (considerTraffic) {
      final currentHour = DateTime.now().hour;
      
      // Adjust speed based on typical traffic patterns
      if (currentHour >= 7 && currentHour <= 9) {
        // Morning rush hour
        effectiveSpeed = baseSpeedKmh * 0.6; // 40% slower
      } else if (currentHour >= 17 && currentHour <= 19) {
        // Evening rush hour
        effectiveSpeed = baseSpeedKmh * 0.65; // 35% slower
      } else if (currentHour >= 12 && currentHour <= 14) {
        // Lunch time
        effectiveSpeed = baseSpeedKmh * 0.8; // 20% slower
      } else if (currentHour >= 22 || currentHour <= 6) {
        // Night time - potentially faster
        effectiveSpeed = baseSpeedKmh * 1.1; // 10% faster
      }
    }
    
    final timeHours = distanceKm / effectiveSpeed;
    
    if (timeHours < 1) {
      return '${(timeHours * 60).round()} min';
    } else {
      final hours = timeHours.floor();
      final minutes = ((timeHours - hours) * 60).round();
      return minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';
    }
  }
  
  /// Parse time string to minutes
  int _parseTimeToMinutes(String timeStr) {
    final parts = timeStr.toLowerCase().split(' ');
    int totalMinutes = 0;
    
    for (int i = 0; i < parts.length; i++) {
      if (parts[i].contains('h')) {
        final hours = int.tryParse(parts[i].replaceAll('h', '')) ?? 0;
        totalMinutes += hours * 60;
      } else if (parts[i].contains('m')) {
        final minutes = int.tryParse(parts[i].replaceAll('m', '').replaceAll('in', '')) ?? 0;
        totalMinutes += minutes;
      }
    }
    
    return totalMinutes;
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
  
  String _getDrivingRouteColor(int index) {
    final drivingColors = [
      '#2E7D32', // Dark green for best route
      '#1976D2', // Blue for good routes
      '#F57C00', // Orange for alternative routes
      '#D32F2F', // Red for longer routes
      '#7B1FA2', // Purple
      '#00796B', // Teal
      '#5D4037', // Brown
      '#616161', // Grey
    ];
    return drivingColors[index % drivingColors.length];
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
      drivingPrefs: DrivingPreferences(),
    );
  }
  
  /// Enhanced method with driving preferences
  Future<Map<String, dynamic>> getOptimizedDrivingRoutes(
    GeoPoint startLocation,
    String adminId, {
    int maxRoutes = 20,
    bool avoidTolls = false,
    bool avoidHighways = false,
    bool avoidFerries = true,
    String optimizeFor = 'time',
    bool useRealTimeTraffic = true,
    bool useGeneticAlgorithm = true,
    double fuelEfficiencyKmPerLiter = 12.0,
    double fuelPricePerLiter = 2.50,
  }) async {
    final drivingPrefs = DrivingPreferences(
      avoidTolls: avoidTolls,
      avoidHighways: avoidHighways,
      avoidFerries: avoidFerries,
      optimizeFor: optimizeFor,
      useRealTimeTraffic: useRealTimeTraffic,
      fuelEfficiencyKmPerLiter: fuelEfficiencyKmPerLiter,
      fuelPricePerLiter: fuelPricePerLiter,
    );
    
    return await getOptimizedWaterSupplyRoutes(
      startLocation,
      adminId,
      maxRoutes: maxRoutes,
      useGoogleMaps: true,
      useGeneticAlgorithm: useGeneticAlgorithm,
      drivingPrefs: drivingPrefs,
    );
  }
}