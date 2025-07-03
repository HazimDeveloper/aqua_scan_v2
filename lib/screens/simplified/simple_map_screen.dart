// lib/screens/simplified/simple_map_screen.dart - FIXED: Google API Key Logic
import 'dart:io';
import 'package:aquascan_v2/widgets/admin/google_maps_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as Math;
import '../../config/theme.dart';
import '../../models/report_model.dart';
import '../../services/database_service.dart';
import '../../services/location_service.dart';
import '../../services/api_service.dart';
import '../../screens/simplified/simple_admin_screen.dart';
import '../../screens/simplified/simple_report_screen.dart';
import '../../screens/simplified/role_selection_screen.dart';

class SimpleMapScreen extends StatefulWidget {
  const SimpleMapScreen({Key? key}) : super(key: key);

  @override
  _SimpleMapScreenState createState() => _SimpleMapScreenState();
}

class _SimpleMapScreenState extends State<SimpleMapScreen> 
    with TickerProviderStateMixin {
  
  // 🔑 GOOGLE MAPS API KEY - Set to null if you don't have a real key
  // static const String? _googleMapsApiKey = null; // Set to your real API key or keep as null
  
  // Alternative: If you have a real key, replace null with your key:
  static const String? _googleMapsApiKey = 'AIzaSyBAu5LXTH6xw4BrThroxWxngNunfgh27bg';

  AnimationController? _animationController;
  Animation<double>? _fadeAnimation;
  
  bool _isLoading = false;
  bool _isLoadingRoutes = false;
  bool _backendConnected = false;
  
  GeoPoint? _currentLocation;
  List<Map<String, dynamic>> _allRoutes = [];
  List<ReportModel> _userReports = [];
  String? _errorMessage;
  
  late LocationService _locationService;
  late ApiService _apiService;
  late DatabaseService _databaseService;
  
  // UI State
  int? _selectedRouteIndex;
  int? _nearestRouteIndex;
  ReportModel? _selectedReport;
  String _routeLoadingStatus = 'Initializing...';
  bool _showControls = true;
  
  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController!,
      curve: Curves.easeInOut,
    ));
    
    _locationService = Provider.of<LocationService>(context, listen: false);
    _apiService = Provider.of<ApiService>(context, listen: false);
    _databaseService = Provider.of<DatabaseService>(context, listen: false);
    
    _initializeMapRoutes();
    _animationController?.forward();
  }
  
  @override
  void dispose() {
    _animationController?.dispose();
    super.dispose();
  }
  
  Future<void> _initializeMapRoutes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _backendConnected = false;
      _routeLoadingStatus = 'Connecting to backend...';
    });
    
    try {
      print('🚗 === MAP ROUTES INITIALIZATION ===');
      
      // STEP 1: Test backend connection
      setState(() => _routeLoadingStatus = 'Testing AI backend...');
      final isConnected = await _apiService.testBackendConnection();
      setState(() {
        _backendConnected = isConnected;
        _routeLoadingStatus = isConnected ? 'AI backend online!' : 'Using offline mode';
      });
      
      // STEP 2: Get location
      setState(() => _routeLoadingStatus = 'Getting your location...');
      final position = await _locationService.getCurrentLocation();
      if (position == null) {
        setState(() {
          _errorMessage = 'Location access denied. Please enable GPS.';
          _isLoading = false;
        });
        return;
      }
      
      final currentLocation = GeoPoint(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      
      setState(() {
        _currentLocation = currentLocation;
        _routeLoadingStatus = 'Location found! Loading routes...';
      });
      
      // STEP 3: Load reports
      await _loadUserReports();
      
      // STEP 4: Get routes with improved logic
      await _loadOptimizedRoutes();
      
      print('✅ === MAP ROUTES READY ===');
      
    } catch (e) {
      print('❌ Initialization failed: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }
  
  Future<void> _loadUserReports() async {
    try {
      final reports = await _databaseService.getUnresolvedReportsList();
      if (mounted) {
        setState(() {
          _userReports = reports;
        });
        print('✅ Loaded ${_userReports.length} reports');
      }
    } catch (e) {
      print('⚠️ Failed to load user reports: $e');
      if (mounted) {
        setState(() {
          _userReports = [];
        });
      }
    }
  }
  
  Future<void> _loadOptimizedRoutes() async {
    if (_currentLocation == null) return;
    
    setState(() {
      _isLoadingRoutes = true;
      _routeLoadingStatus = 'Getting optimized routes...';
    });
    
    try {
      print('🗺️ Loading optimized routes...');
      
      List<Map<String, dynamic>> routeData = [];
      String method = 'unknown';
      
      // PRIORITY 1: Backend + Google Maps (if backend available and API key configured)
      if (_backendConnected) {
        setState(() => _routeLoadingStatus = 'Using AI + Google Maps...');
        try {
          final result = await _apiService.getActualDrivingRoutes(
            _currentLocation!,
            'google_driving_admin',
            maxRoutes: 10,
          ).timeout(Duration(seconds: 35));
          
          if (result['success'] == true && 
              (result['routes'] as List?)?.isNotEmpty == true) {
            
            routeData = await _processGoogleRoutesSimple(result['routes']);
            method = 'AI + Google Maps API';
            print('✅ SUCCESS: AI + Google routes');
          }
        } catch (e) {
          print('⚠️ Backend + Google failed: $e');
        }
      }
      
      // PRIORITY 2: Direct Google Maps Directions API (only if we have a real API key)
      if (routeData.isEmpty && _googleMapsApiKey != null && _googleMapsApiKey!.isNotEmpty) {
        setState(() => _routeLoadingStatus = 'Using Google Directions API...');
        try {
          routeData = await _getDirectGoogleDirections();
          method = 'Google Directions API';
          print('✅ SUCCESS: Direct Google directions');
        } catch (e) {
          print('⚠️ Google Directions failed: $e');
        }
      }
      
      // PRIORITY 3: Enhanced simulation (always available as fallback)
      if (routeData.isEmpty) {
        setState(() => _routeLoadingStatus = 'Using enhanced simulation...');
        try {
          routeData = await _getEnhancedSimulationRoutes();
          method = 'Enhanced Route Simulation';
          print('✅ SUCCESS: Enhanced simulation routes');
        } catch (e) {
          print('⚠️ Enhanced simulation failed: $e');
          // Final fallback: Basic simulation
          routeData = await _getBasicSimulationRoutes();
          method = 'Basic Simulation';
          print('✅ FALLBACK: Basic simulation routes');
        }
      }
      
      // Process routes and find nearest
      if (routeData.isNotEmpty) {
        _findAndMarkNearestRoute(routeData);
      }
      
      if (mounted) {
        setState(() {
          _allRoutes = routeData;
          _isLoadingRoutes = false;
          _isLoading = false;
          _routeLoadingStatus = '${routeData.length} routes loaded via $method';
        });
        
        // Show success message with nearest route info
        if (routeData.isNotEmpty && _nearestRouteIndex != null) {
          final nearestRoute = routeData[_nearestRouteIndex!];
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Nearest: ${nearestRoute['destination_name']} (${(nearestRoute['distance'] as double).toStringAsFixed(1)}km)'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              margin: EdgeInsets.only(bottom: 100, left: 20, right: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
      
    } catch (e) {
      print('❌ Route loading failed: $e');
      if (mounted) {
        setState(() {
          _allRoutes = [];
          _isLoadingRoutes = false;
          _isLoading = false;
          _routeLoadingStatus = 'Failed to load routes';
        });
      }
    }
  }
  
  // FIXED: Process Google routes with simple data structure
  Future<List<Map<String, dynamic>>> _processGoogleRoutesSimple(List<dynamic> backendRoutes) async {
    final processedRoutes = <Map<String, dynamic>>[];
    
    for (int i = 0; i < backendRoutes.length; i++) {
      final route = backendRoutes[i] as Map<String, dynamic>;
      
      // Extract Google polyline if available
      final googlePolyline = route['google_polyline'] as List<dynamic>? ?? [];
      final polylinePoints = <Map<String, dynamic>>[];
      
      if (googlePolyline.isNotEmpty) {
        for (final point in googlePolyline) {
          if (point is Map<String, dynamic>) {
            polylinePoints.add({
              'latitude': (point['lat'] as num?)?.toDouble() ?? 0.0,
              'longitude': (point['lng'] as num?)?.toDouble() ?? 0.0,
            });
          }
        }
      }
      
      if (polylinePoints.isNotEmpty) {
        processedRoutes.add({
          'route_id': 'google_backend_$i',
          'destination_name': route['destination_name'] ?? 'Water Supply ${i + 1}',
          'destination_address': route['destination_address'] ?? 'Google Route',
          'distance': (route['distance_km'] as num?)?.toDouble() ?? 0.0,
          'travel_time': route['duration_text'] ?? '? min',
          'polyline_points': polylinePoints,
          'color': i == 0 ? '#00CC00' : '#0066FF',
          'weight': i == 0 ? 5 : 3,
          'opacity': 0.8,
          'is_shortest': i == 0,
          'priority_rank': i + 1,
          'destination_details': route['destination_details'] ?? {},
          'route_type': 'google_maps_backend',
          'route_source': 'backend_google',
        });
      }
    }
    
    return processedRoutes;
  }
  
  // FIXED: Direct Google Directions API (only if API key is available)
  Future<List<Map<String, dynamic>>> _getDirectGoogleDirections() async {
    if (_googleMapsApiKey == null || _googleMapsApiKey!.isEmpty) {
      throw Exception('Google Maps API key not configured');
    }
    
    try {
      print('🗺️ Using Direct Google Directions API...');
      
      // Get water supply destinations
      final csvResult = await _apiService.getAllWaterSupplyPointsFromCSV();
      final points = csvResult['points'] as List<dynamic>;
      
      if (points.isEmpty) return [];
      
      // Get nearest points
      final nearestPoints = _findNearestPoints(points, 8);
      final routes = <Map<String, dynamic>>[];
      
      for (int i = 0; i < nearestPoints.length; i++) {
        final point = nearestPoints[i];
        final lat = (point['latitude'] as num?)?.toDouble();
        final lng = (point['longitude'] as num?)?.toDouble();
        
        if (lat != null && lng != null) {
          setState(() => _routeLoadingStatus = 'Getting Google route ${i + 1}/${nearestPoints.length}...');
          
          try {
            final googleRoute = await _callGoogleDirectionsAPI(
              _currentLocation!,
              GeoPoint(latitude: lat, longitude: lng),
              point,
              i,
            );
            
            if (googleRoute != null) {
              routes.add(googleRoute);
            }
            
            // Delay to avoid rate limiting
            await Future.delayed(Duration(milliseconds: 500));
            
          } catch (e) {
            print('⚠️ Google route $i failed: $e');
          }
        }
      }
      
      return routes;
      
    } catch (e) {
      print('❌ Google Directions failed: $e');
      return [];
    }
  }
  
  // FIXED: Call Google Directions API with proper key check
  Future<Map<String, dynamic>?> _callGoogleDirectionsAPI(
    GeoPoint start,
    GeoPoint end,
    Map<String, dynamic> destination,
    int index,
  ) async {
    try {
      print('🗺️ Calling Google Directions API for route $index...');
      
      // Check if API key is properly configured
      if (_googleMapsApiKey == null || _googleMapsApiKey!.isEmpty) {
        print('⚠️ Google API key not configured, using simulation');
        return await _createSimulatedRoute(start, end, destination, index);
      }
      
      final String directionsUrl = 'https://maps.googleapis.com/maps/api/directions/json'
          '?origin=${start.latitude},${start.longitude}'
          '&destination=${end.latitude},${end.longitude}'
          '&mode=driving'
          '&avoid=tolls'
          '&key=$_googleMapsApiKey';
      
      // Make HTTP request to Google Directions API
      final response = await http.get(Uri.parse(directionsUrl)).timeout(Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK' && data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final leg = route['legs'][0];
          
          // Decode Google polyline
          final polylinePoints = _decodeGooglePolyline(route['overview_polyline']['points']);
          
          if (polylinePoints.isNotEmpty) {
            return {
              'route_id': 'google_real_$index',
              'destination_name': destination['street_name'] ?? 'Water Supply ${index + 1}',
              'destination_address': destination['address'] ?? 'Google Directions Route',
              'distance': (leg['distance']['value'] as int) / 1000.0, // Convert to km
              'travel_time': leg['duration']['text'],
              'polyline_points': polylinePoints,
              'color': index == 0 ? '#00DD00' : '#0077FF',
              'weight': index == 0 ? 5 : 3,
              'opacity': 0.85,
              'is_shortest': index == 0,
              'priority_rank': index + 1,
              'destination_details': {
                'id': 'google_real_dest_$index',
                'latitude': end.latitude,
                'longitude': end.longitude,
                'name': destination['street_name'] ?? 'Water Supply ${index + 1}',
                'address': destination['address'] ?? 'Unknown Address',
                'accessible_by_car': true,
              },
              'route_type': 'google_directions_real',
              'route_source': 'google_directions_api_real',
            };
          }
        } else {
          print('⚠️ Google API returned: ${data['status']}');
        }
      } else {
        print('⚠️ Google API HTTP error: ${response.statusCode}');
      }
      
      // Fallback to simulation if Google API fails
      return await _createSimulatedRoute(start, end, destination, index);
      
    } catch (e) {
      print('❌ Google API call failed: $e');
      // Fallback to simulation
      return await _createSimulatedRoute(start, end, destination, index);
    }
  }
  
  // Enhanced simulation routes as improved fallback
  Future<List<Map<String, dynamic>>> _getEnhancedSimulationRoutes() async {
    try {
      print('🧮 Getting enhanced simulation routes...');
      
      final csvData = await _apiService.getAllWaterSupplyPointsFromCSV();
      final points = csvData['points'] as List<dynamic>;
      
      if (points.isEmpty) {
        throw Exception('No water supply points in CSV data');
      }
      
      final routes = <Map<String, dynamic>>[];
      final maxRoutes = Math.min(12, points.length);
      
      for (int i = 0; i < maxRoutes; i++) {
        final point = points[i];
        final lat = (point['latitude'] as num?)?.toDouble();
        final lng = (point['longitude'] as num?)?.toDouble();
        
        if (lat != null && lng != null) {
          setState(() => _routeLoadingStatus = 'Creating enhanced route ${i + 1}/$maxRoutes...');
          
          final destinationLocation = GeoPoint(latitude: lat, longitude: lng);
          
          final route = await _createEnhancedSimulatedRoute(
            _currentLocation!, 
            destinationLocation,
            point,
            i,
          );
          
          routes.add(route);
        }
      }
      
      // Sort by distance
      routes.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
      
      print('✅ Generated ${routes.length} enhanced simulation routes');
      
      return routes;
      
    } catch (e) {
      print('❌ Enhanced simulation error: $e');
      throw Exception('Enhanced route simulation failed: $e');
    }
  }
  
  // Basic simulation as final fallback
  Future<List<Map<String, dynamic>>> _getBasicSimulationRoutes() async {
    try {
      print('🔄 Using basic simulation as final fallback...');
      
      final routes = <Map<String, dynamic>>[];
      
      // Create some basic routes around current location
      final baseDistance = 5.0; // 5km radius
      
      for (int i = 0; i < 6; i++) {
        final angle = (i * 60.0) * (Math.pi / 180); // 60 degrees apart
        final distance = baseDistance + (i * 2.0);
        
        final lat = _currentLocation!.latitude + (distance / 111.0) * Math.cos(angle);
        final lng = _currentLocation!.longitude + (distance / (111.0 * Math.cos(_currentLocation!.latitude * Math.pi / 180))) * Math.sin(angle);
        
        final destination = GeoPoint(latitude: lat, longitude: lng);
        
        final route = await _createSimulatedRoute(
          _currentLocation!,
          destination,
          {
            'street_name': 'Water Station ${String.fromCharCode(65 + i)}',
            'address': 'Simulated Location ${i + 1}',
          },
          i,
        );
        
        routes.add(route);
      }
      
      print('✅ Generated ${routes.length} basic simulation routes');
      return routes;
      
    } catch (e) {
      print('❌ Basic simulation error: $e');
      return [];
    }
  }
  
  // Create enhanced simulated route with better road simulation
  Future<Map<String, dynamic>> _createEnhancedSimulatedRoute(
    GeoPoint start,
    GeoPoint end,
    Map<String, dynamic> destination,
    int index,
  ) async {
    final distance = _calculateDistance(start.latitude, start.longitude, end.latitude, end.longitude);
    
    // Create realistic road route with multiple waypoints
    final roadPolyline = _generateEnhancedRoadPolyline(start, end, distance);
    
    // Calculate realistic metrics
    final roadDistance = distance * _getRoadFactor(distance);
    final drivingTime = _calculateEnhancedDrivingTime(roadDistance);
    
    return {
      'route_id': 'enhanced_sim_$index',
      'destination_name': destination['street_name'] ?? 'Water Supply ${index + 1}',
      'destination_address': destination['address'] ?? 'Enhanced Simulated Route',
      'distance': roadDistance,
      'travel_time': drivingTime,
      'polyline_points': roadPolyline,
      'color': index == 0 ? '#FF6600' : '#0099FF',
      'weight': index == 0 ? 5 : 3,
      'opacity': 0.8,
      'is_shortest': index == 0,
      'priority_rank': index + 1,
      'destination_details': {
        'id': 'enhanced_sim_dest_$index',
        'latitude': end.latitude,
        'longitude': end.longitude,
        'name': destination['street_name'] ?? 'Water Supply ${index + 1}',
        'address': destination['address'] ?? 'Unknown Address',
        'accessible_by_car': true,
      },
      'route_type': 'enhanced_simulation',
      'route_source': 'enhanced_simulation',
    };
  }
  
  // Generate enhanced road-following polyline
  List<Map<String, dynamic>> _generateEnhancedRoadPolyline(GeoPoint start, GeoPoint end, double distance) {
    final points = <Map<String, dynamic>>[];
    
    points.add({
      'latitude': start.latitude,
      'longitude': start.longitude,
    });
    
    final numWaypoints = Math.max(12, Math.min(25, (distance * 3).round()));
    
    for (int i = 1; i <= numWaypoints; i++) {
      final progress = i / (numWaypoints + 1);
      
      var lat = start.latitude + (end.latitude - start.latitude) * progress;
      var lng = start.longitude + (end.longitude - start.longitude) * progress;
      
      // Add realistic road curves and major road following
      if (i > 1 && i < numWaypoints) {
        // Simulate following major roads
        final roadCurveFactor = Math.sin(progress * Math.pi * 2) * 0.0015;
        final majorRoadOffset = Math.cos(progress * Math.pi * 3) * 0.001;
        
        lat += roadCurveFactor * (i % 2 == 0 ? 1 : -1);
        lng += (roadCurveFactor * 0.7 + majorRoadOffset) * (i % 3 == 0 ? 1 : -1);
        
        // Simulate avoiding obstacles and following street patterns
        if (distance > 10.0) {
          final streetPatternOffset = Math.sin(progress * Math.pi * 4) * 0.0008;
          lat += streetPatternOffset;
        }
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
  
  // Create simulated route (basic version)
  Future<Map<String, dynamic>> _createSimulatedRoute(
    GeoPoint start,
    GeoPoint end,
    Map<String, dynamic> destination,
    int index,
  ) async {
    final distance = _calculateDistance(start.latitude, start.longitude, end.latitude, end.longitude);
    
    // Create basic road route
    final roadPolyline = _generateBasicRoadPolyline(start, end, distance);
    
    // Calculate realistic metrics
    final roadDistance = distance * _getRoadFactor(distance);
    final drivingTime = _calculateDrivingTime(roadDistance);
    
    return {
      'route_id': 'simulated_$index',
      'destination_name': destination['street_name'] ?? 'Water Supply ${index + 1}',
      'destination_address': destination['address'] ?? 'Simulated Route',
      'distance': roadDistance,
      'travel_time': drivingTime,
      'polyline_points': roadPolyline,
      'color': index == 0 ? '#FF3366' : '#0099FF',
      'weight': index == 0 ? 5 : 3,
      'opacity': 0.75,
      'is_shortest': index == 0,
      'priority_rank': index + 1,
      'destination_details': {
        'id': 'sim_dest_$index',
        'latitude': end.latitude,
        'longitude': end.longitude,
        'name': destination['street_name'] ?? 'Water Supply ${index + 1}',
        'address': destination['address'] ?? 'Unknown Address',
        'accessible_by_car': true,
      },
      'route_type': 'basic_simulation',
      'route_source': 'basic_simulation',
    };
  }
  
  // Generate basic road-following polyline
  List<Map<String, dynamic>> _generateBasicRoadPolyline(GeoPoint start, GeoPoint end, double distance) {
    final points = <Map<String, dynamic>>[];
    
    points.add({
      'latitude': start.latitude,
      'longitude': start.longitude,
    });
    
    final numWaypoints = Math.max(8, Math.min(15, (distance * 2).round()));
    
    for (int i = 1; i <= numWaypoints; i++) {
      final progress = i / (numWaypoints + 1);
      
      var lat = start.latitude + (end.latitude - start.latitude) * progress;
      var lng = start.longitude + (end.longitude - start.longitude) * progress;
      
      // Add basic road curves
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
  
  // Decode Google polyline format
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
  
  void _findAndMarkNearestRoute(List<Map<String, dynamic>> routes) {
    if (routes.isEmpty || _currentLocation == null) return;
    
    double nearestDistance = double.infinity;
    int nearestIndex = -1;
    
    for (int i = 0; i < routes.length; i++) {
      final route = routes[i];
      final distance = (route['distance'] as num?)?.toDouble() ?? double.infinity;
      
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestIndex = i;
      }
    }
    
    if (nearestIndex >= 0) {
      _nearestRouteIndex = nearestIndex;
      
      // Mark nearest route
      routes[nearestIndex]['is_nearest'] = true;
      routes[nearestIndex]['color'] = '#FF3366';
      routes[nearestIndex]['weight'] = 6;
      routes[nearestIndex]['opacity'] = 1.0;
      
      print('🎯 Nearest route: ${routes[nearestIndex]['destination_name']} (${nearestDistance.toStringAsFixed(1)}km)');
    }
  }
  
  List<Map<String, dynamic>> _findNearestPoints(List<dynamic> points, int maxCount) {
    final nearestPoints = <Map<String, dynamic>>[];
    
    for (final point in points) {
      final lat = (point['latitude'] as num?)?.toDouble();
      final lng = (point['longitude'] as num?)?.toDouble();
      
      if (lat != null && lng != null) {
        final distance = _calculateDistance(
          _currentLocation!.latitude,
          _currentLocation!.longitude,
          lat,
          lng,
        );
        
        final pointWithDistance = Map<String, dynamic>.from(point);
        pointWithDistance['calculated_distance'] = distance;
        nearestPoints.add(pointWithDistance);
      }
    }
    
    nearestPoints.sort((a, b) => 
      (a['calculated_distance'] as double).compareTo(b['calculated_distance'] as double));
    
    return nearestPoints.take(maxCount).toList();
  }
  
  double _getRoadFactor(double straightDistance) {
    if (straightDistance < 5) return 1.3;
    if (straightDistance < 15) return 1.4;
    if (straightDistance < 30) return 1.5;
    return 1.6;
  }
  
  String _calculateDrivingTime(double roadDistance) {
    double avgSpeed = 50.0; // km/h
    
    if (roadDistance < 10) avgSpeed = 40.0;
    else if (roadDistance > 25) avgSpeed = 70.0;
    
    final timeHours = roadDistance / avgSpeed;
    final timeMinutes = (timeHours * 60).round();
    
    if (timeMinutes >= 60) {
      final hours = timeMinutes ~/ 60;
      final minutes = timeMinutes % 60;
      return minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';
    }
    
    return '${timeMinutes}m';
  }
  
  String _calculateEnhancedDrivingTime(double roadDistance) {
    // More realistic time calculation considering traffic patterns
    final currentHour = DateTime.now().hour;
    double baseSpeed = 50.0; // km/h
    
    // Adjust for time of day
    if (currentHour >= 7 && currentHour <= 9) {
      baseSpeed = 35.0; // Morning rush
    } else if (currentHour >= 17 && currentHour <= 19) {
      baseSpeed = 30.0; // Evening rush
    } else if (currentHour >= 22 || currentHour <= 6) {
      baseSpeed = 65.0; // Night time
    }
    
    // Adjust for distance
    if (roadDistance < 5) baseSpeed *= 0.8; // Urban areas
    else if (roadDistance > 20) baseSpeed *= 1.2; // Highway speeds
    
    final timeHours = roadDistance / baseSpeed;
    final timeMinutes = (timeHours * 60).round();
    
    if (timeMinutes >= 60) {
      final hours = timeMinutes ~/ 60;
      final minutes = timeMinutes % 60;
      return minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';
    }
    
    return '${timeMinutes}m';
  }
  
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371;
    
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
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isLoading ? _buildLoadingView() : _buildMapContent(),
    );
  }
  
  Widget _buildLoadingView() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.blue.shade800, Colors.blue.shade600],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Loading Routes',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _routeLoadingStatus,
                style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 20),
            if (_backendConnected)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.smart_toy, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text('AI Backend Online', style: TextStyle(color: Colors.white, fontSize: 12)),
                ],
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.offline_bolt, color: Colors.orange, size: 16),
                  SizedBox(width: 8),
                  Text('Offline Mode', style: TextStyle(color: Colors.orange, fontSize: 12)),
                ],
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMapContent() {
    return Stack(
      children: [
        // Google Maps widget
        if (_currentLocation != null && _allRoutes.isNotEmpty)
          Positioned.fill(
            child: GoogleMapsRouteWidget(
              currentLocation: _currentLocation,
              polylineRoutes: _allRoutes,
              reports: _userReports,
              selectedRouteIndex: _selectedRouteIndex,
              onRouteSelected: (index) {
                setState(() {
                  _selectedRouteIndex = index >= 0 ? index : null;
                  _selectedReport = null;
                });
              },
              onReportTap: (report) {
                setState(() {
                  _selectedReport = report;
                  _selectedRouteIndex = null;
                });
              },
            ),
          ),
        
        // Show empty state if no routes
        if (_currentLocation != null && _allRoutes.isEmpty && !_isLoading)
          _buildNoRoutesView(),
        
        // Status bar
        if (_showControls && _allRoutes.isNotEmpty)
          _buildStatusBar(),
        
        // Nearest route indicator
        if (_nearestRouteIndex != null && _allRoutes.isNotEmpty)
          _buildNearestRouteIndicator(),
        
        // Action buttons
        _buildActionButtons(),
        
        // Error overlay
        if (_errorMessage != null)
          _buildErrorOverlay(),
      ],
    );
  }
  
  Widget _buildStatusBar() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 16,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.75),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blue.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: _backendConnected ? Colors.green : Colors.orange,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: 8),
            Text(
              '${_allRoutes.length} routes',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (_userReports.isNotEmpty) ...[
              Text(
                ' • ${_userReports.length} reports',
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildNearestRouteIndicator() {
    final nearestRoute = _allRoutes[_nearestRouteIndex!];
    
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      right: 16,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.pink.shade600, Colors.red.shade500],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.pink.withOpacity(0.3),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.near_me, color: Colors.white, size: 14),
            SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'NEAREST',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${(nearestRoute['distance'] as double).toStringAsFixed(1)}km',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildActionButtons() {
    return Positioned(
      right: 16,
      bottom: 30,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Dashboard
          _buildActionButton(
            Icons.dashboard,
            Colors.orange,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SimpleAdminScreen()),
              );
            },
          ),
          
          SizedBox(height: 12),
          
          // Add report
          _buildActionButton(
            Icons.add_circle,
            Colors.blue,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SimpleReportScreen(isAdmin: true)),
              );
            },
          ),
          
          SizedBox(height: 12),
          
          // Refresh
          _buildActionButton(
            _isLoadingRoutes ? Icons.hourglass_empty : Icons.refresh,
            Colors.green,
            _isLoadingRoutes ? null : () {
              _initializeMapRoutes();
            },
          ),
          
          SizedBox(height: 20),
          
          // Exit
          _buildActionButton(
            Icons.close,
            Colors.red,
            () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => RoleSelectionScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildActionButton(IconData icon, Color color, VoidCallback? onPressed) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            width: 48,
            height: 48,
            child: Icon(
              icon,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildErrorOverlay() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 60,
      left: 16,
      right: 16,
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.error, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                _errorMessage!,
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _errorMessage = null),
              child: Icon(Icons.close, color: Colors.white, size: 20),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildNoRoutesView() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.grey.shade800, Colors.grey.shade600],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.route_outlined,
                  size: 64,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
              SizedBox(height: 24),
              Text(
                'No Routes Available',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _backendConnected 
                    ? 'Unable to load routes from any source'
                    : 'Backend offline and no fallback data available',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  _initializeMapRoutes();
                },
                icon: Icon(Icons.refresh),
                label: Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              SizedBox(height: 16),
              TextButton.icon(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => RoleSelectionScreen()),
                  );
                },
                icon: Icon(Icons.arrow_back, color: Colors.white70),
                label: Text(
                  'Back to Role Selection',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}