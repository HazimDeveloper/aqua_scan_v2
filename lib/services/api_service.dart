// lib/services/api_service.dart - COMPLETE VERSION (Handle Any Distance)
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
  
  WaterAnalysisResult({
    required this.waterQuality,
    required this.originalClass,
    required this.confidence,
  });
}

class GAOptimizationRequest {
  final String adminId;
  final GeoPoint currentLocation;
  final String destinationKeyword;
  final int maxRoutes;
  final int maxHops;
  final String optimizationMethod;
  final GAParameters gaConfig;
  
  GAOptimizationRequest({
    required this.adminId,
    required this.currentLocation,
    required this.destinationKeyword,
    this.maxRoutes = 10,
    this.maxHops = 8,
    this.optimizationMethod = 'genetic',
    required this.gaConfig,
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
      'max_hops': maxHops,
      'optimization_method': optimizationMethod,
      'ga_config': gaConfig.toJson(),
    };
  }
}

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
    this.populationSize = 50,
    this.maxGenerations = 100,
    this.eliteSize = 5,
    this.mutationRate = 0.1,
    this.crossoverRate = 0.8,
    this.tournamentSize = 3,
    this.maxRouteLength = 8,
    this.timeLimit = 30.0,
    this.convergenceThreshold = 15,
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

class ApiService {
  final String baseUrl;
  
  ApiService({required this.baseUrl});
  
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
  };
  
  /// Test backend connection
  Future<bool> testBackendConnection() async {
    try {
      print('🔗 Testing backend connection to: $baseUrl');
      
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Backend connected successfully');
        print('📊 Components: ${data['components']}');
        return true;
      }
      
      // Try root endpoint if health fails
      final rootResponse = await http.get(Uri.parse(baseUrl))
          .timeout(const Duration(seconds: 5));
      
      return rootResponse.statusCode == 200;
      
    } catch (e) {
      print('❌ Backend connection failed: $e');
      return false;
    }
  }
  
  /// Get ALL water supply points from CSV - NO DISTANCE FILTER
  Future<Map<String, dynamic>> getAllWaterSupplyPointsFromCSV() async {
    try {
      print('🗂️ Fetching ALL water supply points from CSV...');
      
      // Check backend connection first
      final isConnected = await testBackendConnection();
      if (!isConnected) {
        throw Exception('Backend not available. Please start the Python server at $baseUrl');
      }
      
      // Get ALL points - no limit
      final uri = Uri.parse('$baseUrl/water-supply-points').replace(
        queryParameters: {
          'limit': '1000', // High limit to get all
        },
      );
      
      print('📡 Calling: $uri');
      
      final response = await http.get(uri, headers: _headers)
          .timeout(const Duration(seconds: 30));
      
      print('📥 Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        
        if (data['success'] == true) {
          final points = data['points'] as List<dynamic>;
          print('✅ Got ${points.length} water supply points from CSV');
          print('📍 Data source: ${data['data_source']}');
          
          // Log sample points for verification
          if (points.isNotEmpty) {
            print('📍 Sample points:');
            for (int i = 0; i < Math.min(3, points.length); i++) {
              final point = points[i];
              print('   ${i + 1}. ${point['street_name']} at (${point['latitude']}, ${point['longitude']})');
            }
          }
          
          return data;
        } else {
          throw Exception('Backend returned success=false: ${data['message']}');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
      
    } catch (e) {
      print('❌ Failed to get water supply data: $e');
      throw Exception('Cannot get water supply data: $e');
    }
  }
  
  /// Calculate routes manually from CSV data - HANDLE ANY DISTANCE
  Future<Map<String, dynamic>> calculateRoutesManually(
    GeoPoint startLocation,
    String adminId, {
    int maxRoutes = 50,
  }) async {
    try {
      print('🧮 Calculating routes manually (any distance)...');
      print('📍 From: ${startLocation.latitude}, ${startLocation.longitude}');
      
      // Get ALL water supplies
      final allSupplies = await getAllWaterSupplyPointsFromCSV();
      final points = allSupplies['points'] as List<dynamic>;
      
      if (points.isEmpty) {
        throw Exception('No water supply points found in CSV');
      }
      
      print('📊 Calculating distances to ${points.length} water supplies...');
      
      // Calculate distances to ALL points
      List<Map<String, dynamic>> routesWithDistance = [];
      
      for (int i = 0; i < points.length; i++) {
        final point = points[i];
        final lat = (point['latitude'] as num?)?.toDouble();
        final lng = (point['longitude'] as num?)?.toDouble();
        
        if (lat != null && lng != null) {
          final distance = _calculateDistance(
            startLocation.latitude, startLocation.longitude,
            lat, lng,
          );
          
          // Accept ANY distance - no filtering
          print('📏 ${point['street_name']}: ${distance.toStringAsFixed(1)} km');
          
          // Generate polyline points
          final polylinePoints = _generatePolylinePoints(
            startLocation.latitude, startLocation.longitude,
            lat, lng,
            distance > 100 ? 30 : 20, // More points for longer routes
          );
          
          final routeData = {
            'route_id': 'route-${i + 1}',
            'destination_name': point['street_name'] ?? 'Water Supply ${i + 1}',
            'destination_address': point['address'] ?? 'Unknown Address',
            'distance': distance,
            'travel_time': _calculateTravelTime(distance),
            'polyline_points': polylinePoints,
            'color': _getRouteColor(i),
            'weight': i == 0 ? 6 : 4,
            'opacity': i == 0 ? 0.8 : 0.6,
            'is_shortest': false, // Will be set after sorting
            'priority_rank': i + 1,
            'destination_details': {
              'id': point['id'] ?? 'supply-$i',
              'latitude': lat,
              'longitude': lng,
              'street_name': point['street_name'] ?? 'Water Supply ${i + 1}',
              'address': point['address'] ?? 'Unknown Address',
              'point_of_interest': point['point_of_interest'] ?? 'Water Access Point',
              'additional_info': point['additional_info'] ?? '',
            },
          };
          
          routesWithDistance.add(routeData);
        }
      }
      
      if (routesWithDistance.isEmpty) {
        throw Exception('No valid routes could be calculated');
      }
      
      // Sort by distance (shortest first)
      routesWithDistance.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
      
      // Mark shortest route
      routesWithDistance[0]['is_shortest'] = true;
      routesWithDistance[0]['color'] = '#FF0000'; // Red for shortest
      
      // Limit results if needed
      if (routesWithDistance.length > maxRoutes) {
        routesWithDistance = routesWithDistance.sublist(0, maxRoutes);
      }
      
      final shortestDistance = routesWithDistance[0]['distance'];
      final longestDistance = routesWithDistance.last['distance'];
      
      print('✅ Calculated ${routesWithDistance.length} routes manually');
      print('📊 Distance range: ${shortestDistance.toStringAsFixed(1)} - ${longestDistance.toStringAsFixed(1)} km');
      print('📍 Shortest route: ${routesWithDistance[0]['destination_name']}');
      
      return {
        'success': true,
        'message': 'Calculated ${routesWithDistance.length} routes (any distance)',
        'polyline_routes': routesWithDistance,
        'shortest_route_id': routesWithDistance[0]['route_id'],
        'total_routes': routesWithDistance.length,
        'total_available_supplies': points.length,
        'distance_range': {
          'shortest': shortestDistance,
          'longest': longestDistance,
        },
        'method': 'manual_calculation_any_distance',
      };
      
    } catch (e) {
      print('❌ Manual route calculation failed: $e');
      throw Exception('Failed to calculate routes manually: $e');
    }
  }
  
  /// Try backend endpoint first, fallback to manual calculation
  Future<Map<String, dynamic>> getPolylineRoutesToWaterSupplies(
    GeoPoint startLocation,
    String adminId, {
    int maxRoutes = 50,
    double maxDistance = 999999.0, // Very high limit
  }) async {
    try {
      print('🗺️ Getting polyline routes (any distance allowed)...');
      print('📍 Start: ${startLocation.latitude}, ${startLocation.longitude}');
      
      // Verify backend connection
      final isConnected = await testBackendConnection();
      if (!isConnected) {
        throw Exception('Backend server not running');
      }
      
      // STEP 1: Try all available backend endpoints
      final endpoints = [
        '/get-polyline-routes',
        '/find-multiple-water-routes',
        '/optimize-route',
      ];
      
      for (String endpoint in endpoints) {
        try {
          print('🔄 Trying endpoint: $baseUrl$endpoint');
          
          final requestData = {
            'admin_id': adminId,
            'current_location': {
              'latitude': startLocation.latitude,
              'longitude': startLocation.longitude,
            },
            'max_routes': maxRoutes,
            'max_distance': maxDistance,
            'route_type': 'all',
            'include_polyline': true,
            'optimization_method': 'distance',
          };
          
          print('📝 Request: ${json.encode(requestData)}');
          
          final response = await http.post(
            Uri.parse('$baseUrl$endpoint'),
            headers: _headers,
            body: json.encode(requestData),
          ).timeout(const Duration(seconds: 60));
          
          print('📥 Response status: ${response.statusCode}');
          
          if (response.statusCode == 200) {
            final data = json.decode(response.body) as Map<String, dynamic>;
            
            print('🔍 Response structure:');
            print('   success: ${data['success']}');
            print('   message: ${data['message']}');
            print('   keys: ${data.keys.toList()}');
            
            if (data['success'] == true) {
              // Check for different possible route keys
              List<dynamic>? routes;
              
              if (data.containsKey('polyline_routes')) {
                routes = data['polyline_routes'] as List<dynamic>?;
              } else if (data.containsKey('routes')) {
                routes = data['routes'] as List<dynamic>?;
              }
              
              if (routes != null && routes.isNotEmpty) {
                print('✅ Backend endpoint $endpoint returned ${routes.length} routes');
                
                // If it's the routes format, convert to polyline format
                if (endpoint.contains('find-multiple') && routes.isNotEmpty) {
                  routes = _convertToPolylineFormat(routes, startLocation);
                }
                
                return {
                  ...data,
                  'polyline_routes': routes,
                  'method': 'backend_endpoint_$endpoint',
                };
              } else {
                print('⚠️ Backend endpoint $endpoint returned 0 routes');
              }
            } else {
              print('❌ Backend endpoint $endpoint failed: ${data['message']}');
            }
          } else {
            print('❌ Backend endpoint $endpoint HTTP error: ${response.statusCode}');
          }
          
        } catch (endpointError) {
          print('⚠️ Endpoint $endpoint failed: $endpointError');
          continue; // Try next endpoint
        }
      }
      
      // STEP 2: All backend endpoints failed, use manual calculation
      print('🔄 All backend endpoints failed, calculating routes manually...');
      return await calculateRoutesManually(startLocation, adminId, maxRoutes: maxRoutes);
      
    } catch (e) {
      print('❌ All route methods failed: $e');
      
      // STEP 3: Final fallback - try manual calculation anyway
      try {
        print('🆘 Final fallback: attempting manual calculation...');
        return await calculateRoutesManually(startLocation, adminId, maxRoutes: maxRoutes);
      } catch (finalError) {
        throw Exception('All route calculation methods failed: $finalError');
      }
    }
  }
  
  /// Convert routes format to polyline format
  List<dynamic> _convertToPolylineFormat(List<dynamic> routes, GeoPoint startLocation) {
    return routes.map((route) {
      final destination = route['destination'] as Map<String, dynamic>? ?? {};
      final waypoints = route['waypoints'] as List<dynamic>? ?? [];
      
      // Generate polyline points from waypoints or create simple line
      List<Map<String, dynamic>> polylinePoints;
      
      if (waypoints.isNotEmpty) {
        polylinePoints = waypoints.map((wp) => {
          'latitude': (wp['latitude'] as num?)?.toDouble() ?? 0.0,
          'longitude': (wp['longitude'] as num?)?.toDouble() ?? 0.0,
        }).toList().cast<Map<String, dynamic>>();
      } else {
        polylinePoints = [
          {
            'latitude': startLocation.latitude,
            'longitude': startLocation.longitude,
          },
          {
            'latitude': (destination['latitude'] as num?)?.toDouble() ?? 0.0,
            'longitude': (destination['longitude'] as num?)?.toDouble() ?? 0.0,
          },
        ];
      }
      
      return {
        'route_id': route['route_id'] ?? 'converted-route',
        'destination_name': destination['name'] ?? destination['street_name'] ?? 'Water Supply',
        'destination_address': destination['address'] ?? 'Unknown Address',
        'distance': (route['distance'] as num?)?.toDouble() ?? 0.0,
        'travel_time': route['travel_time']?['recommended'] ?? 
                      route['estimated_time'] ?? 
                      _calculateTravelTime((route['distance'] as num?)?.toDouble() ?? 0.0),
        'polyline_points': polylinePoints,
        'color': '#0066CC',
        'weight': 4,
        'opacity': 0.7,
        'is_shortest': false,
        'priority_rank': 1,
        'destination_details': destination,
      };
    }).toList();
  }
  
  /// Generate polyline points between two coordinates
  List<Map<String, dynamic>> _generatePolylinePoints(
    double startLat, double startLng,
    double endLat, double endLng,
    int numPoints,
  ) {
    List<Map<String, dynamic>> points = [];
    
    for (int i = 0; i <= numPoints; i++) {
      final ratio = i / numPoints;
      final lat = startLat + (endLat - startLat) * ratio;
      final lng = startLng + (endLng - startLng) * ratio;
      
      points.add({
        'latitude': lat,
        'longitude': lng,
      });
    }
    
    return points;
  }
  
  /// Find nearest water supplies - ANY DISTANCE
  Future<Map<String, dynamic>> findNearestWaterSupplies(
    GeoPoint currentLocation, {
    int maxPoints = 50,
    double maxDistance = 999999.0, // Allow any distance
  }) async {
    try {
      print('📍 Finding nearest water supplies (any distance)...');
      
      // Get all water supplies
      final allSupplies = await getAllWaterSupplyPointsFromCSV();
      final points = allSupplies['points'] as List<dynamic>;
      
      if (points.isEmpty) {
        throw Exception('No water supply points found');
      }
      
      // Calculate distances to ALL points
      List<Map<String, dynamic>> pointsWithDistance = [];
      
      for (final point in points) {
        final lat = (point['latitude'] as num?)?.toDouble();
        final lng = (point['longitude'] as num?)?.toDouble();
        
        if (lat != null && lng != null) {
          final distance = _calculateDistance(
            currentLocation.latitude, currentLocation.longitude,
            lat, lng,
          );
          
          final pointWithDistance = Map<String, dynamic>.from(point);
          pointWithDistance['distance'] = distance;
          pointWithDistance['travel_time'] = _calculateTravelTime(distance);
          pointWithDistance['walking_time'] = _calculateTravelTime(distance, mode: 'walking');
          
          pointsWithDistance.add(pointWithDistance);
        }
      }
      
      // Sort by distance
      pointsWithDistance.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
      
      // Apply maxPoints limit
      if (pointsWithDistance.length > maxPoints) {
        pointsWithDistance = pointsWithDistance.sublist(0, maxPoints);
      }
      
      print('✅ Found ${pointsWithDistance.length} water supplies (any distance)');
      if (pointsWithDistance.isNotEmpty) {
        print('📍 Closest: ${pointsWithDistance[0]['street_name']} at ${pointsWithDistance[0]['distance'].toStringAsFixed(1)} km');
        print('📍 Furthest shown: ${pointsWithDistance.last['street_name']} at ${pointsWithDistance.last['distance'].toStringAsFixed(1)} km');
      }
      
      return {
        'success': true,
        'nearest_points': pointsWithDistance,
        'total_found': pointsWithDistance.length,
        'total_available': points.length,
        'message': 'Found ${pointsWithDistance.length} points (any distance)',
      };
      
    } catch (e) {
      print('❌ Failed to find nearest water supplies: $e');
      throw Exception('Cannot find nearest water supplies: $e');
    }
  }
  
  /// Water supply points wrapper
  Future<Map<String, dynamic>> getWaterSupplyPoints({
    int limit = 1000,
    String? region,
  }) async {
    return await getAllWaterSupplyPointsFromCSV();
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
      'emergency': 80.0,
    };
    
    final speed = speeds[mode] ?? speeds['car']!;
    final timeHours = distanceKm / speed;
    
    if (timeHours < 1) {
      return '${(timeHours * 60).round()} min';
    } else {
      final hours = timeHours.floor();
      final minutes = ((timeHours - hours) * 60).round();
      if (minutes > 0) {
        return '${hours}h ${minutes}m';
      } else {
        return '${hours}h';
      }
    }
  }
  
  String _getRouteColor(int index) {
    final colors = [
      '#FF0000', // Red for shortest
      '#0066CC', // Blue
      '#00CC66', // Green
      '#CC6600', // Orange
      '#6600CC', // Purple
      '#CC0066', // Pink
      '#00CCCC', // Cyan
      '#CCCC00', // Yellow
      '#996633', // Brown
      '#FF6600', // Dark Orange
    ];
    return colors[index % colors.length];
  }
  
  // Water quality analysis methods
  Future<WaterAnalysisResult> analyzeWaterQualityWithConfidence(File imageFile) async {
    try {
      print('🔬 Sending image for water quality analysis to $baseUrl/analyze');
      
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
      
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      
      if (response.statusCode == 200) {
        final data = json.decode(responseBody);
        
          print('🔬 Full backend response: $data');
  print('🔬 Backend success: ${data['success']}');
  print('🔬 Backend water_quality_class: ${data['water_quality_class']}');
  print('🔬 Backend confidence: ${data['confidence']}');
  
        WaterQualityState qualityState = WaterQualityState.unknown;
        double confidenceScore = 0.0;
        String originalClass = "UNKNOWN";
        
        if (data['success'] == true) {
          if (data.containsKey('confidence') && data['confidence'] != null) {
            confidenceScore = double.tryParse(data['confidence'].toString()) ?? 0.0;
          }
          
          if (data.containsKey('water_quality_class') && data['water_quality_class'] != null) {
            originalClass = data['water_quality_class'].toString();
            qualityState = WaterQualityUtils.mapWaterQualityClass(originalClass);
          } 
          else if (data.containsKey('water_quality_index')) {
            final qualityIndex = int.tryParse(data['water_quality_index'].toString()) ?? 4;
            if (qualityIndex >= 0 && qualityIndex < WaterQualityState.values.length) {
              qualityState = WaterQualityState.values[qualityIndex];
              originalClass = qualityState.toString().split('.').last.toUpperCase();
            }
          }
        }
        
        return WaterAnalysisResult(
          waterQuality: qualityState,
          originalClass: originalClass,
          confidence: confidenceScore,
        );
      } else {
        throw Exception('Failed to analyze image: ${responseBody}');
      }
    } catch (e) {
      print('❌ Error analyzing water quality: $e');
      return WaterAnalysisResult(
        waterQuality: WaterQualityState.unknown,
        originalClass: "ERROR",
        confidence: 0.0,
      );
    }
  }
  
  Future<WaterQualityState> analyzeWaterQuality(File imageFile) async {
    final result = await analyzeWaterQualityWithConfidence(imageFile);
    return result.waterQuality;
  }
  
  // Legacy GA optimization methods for compatibility
  Future<Map<String, dynamic>> getOptimizedRoute(
    List<ReportModel> reports,
    GeoPoint startLocation,
    String adminId,
  ) async {
    final defaultGAParams = GAParameters();
    return await getOptimizedRouteWithGA(reports, startLocation, adminId, defaultGAParams);
  }
  
  Future<Map<String, dynamic>> getOptimizedRouteWithGA(
    List<ReportModel> reports,
    GeoPoint startLocation,
    String adminId,
    GAParameters gaParams,
  ) async {
    try {
      print('🚀 GA route optimization...');
      
      if (reports.isEmpty) {
        throw Exception('No reports provided');
      }
      
      // Create GA optimization request
      final gaRequest = GAOptimizationRequest(
        adminId: adminId,
        currentLocation: startLocation,
        destinationKeyword: 'water',
        maxRoutes: 1,
        maxHops: gaParams.maxRouteLength,
        optimizationMethod: 'genetic',
        gaConfig: gaParams,
      );
      
      // Try GA endpoint
      final response = await http.post(
        Uri.parse('$baseUrl/optimize-route-genetic'),
        headers: _headers,
        body: json.encode(gaRequest.toJson()),
      ).timeout(Duration(seconds: (gaParams.timeLimit + 10).round()));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return data;
        }
      }
      
      throw Exception('GA optimization failed');
      
    } catch (e) {
      print('❌ GA route optimization error: $e');
      throw Exception('Failed to optimize route with GA: $e');
    }
  }
}