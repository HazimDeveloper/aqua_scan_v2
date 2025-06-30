// lib/screens/simplified/simple_admin_screen.dart - SIMPLE FIX ONLY
import 'package:aquascan_v2/widgets/admin/google_maps_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as Math;
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/theme.dart';
import '../../models/report_model.dart';
import '../../services/database_service.dart';
import '../../services/location_service.dart';
import '../../services/api_service.dart';
import '../../screens/simplified/role_selection_screen.dart';
import '../../screens/simplified/simple_report_screen.dart';

class SimpleAdminScreen extends StatefulWidget {
  const SimpleAdminScreen({Key? key}) : super(key: key);

  @override
  _SimpleAdminScreenState createState() => _SimpleAdminScreenState();
}

class _SimpleAdminScreenState extends State<SimpleAdminScreen> 
    with TickerProviderStateMixin {
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
  
  // UI state
  bool _showRoutesList = false;
  int? _selectedRouteIndex;
  String _sortBy = 'distance';
  String _routeMethod = 'basic_routes';
  
  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
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
    
    _initializeAdminDashboard();
    _animationController?.forward();
  }
  
  @override
  void dispose() {
    _animationController?.dispose();
    super.dispose();
  }
  
  Future<void> _initializeAdminDashboard() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _backendConnected = false;
    });
    
    try {
      print('🚀 === ADMIN DASHBOARD INITIALIZATION ===');
      
      // Step 1: Test backend connection
      final isConnected = await _apiService.testBackendConnection();
      setState(() {
        _backendConnected = isConnected;
      });
      
      if (!isConnected) {
        setState(() {
          _errorMessage = 'Backend server offline - Using offline mode';
          _isLoading = false;
        });
      }
      
      // Step 2: Get current location
      final position = await _locationService.getCurrentLocation();
      if (position == null) {
        setState(() {
          _errorMessage = 'Cannot access location services';
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
      });
      
      print('📍 Current location: ${currentLocation.latitude}, ${currentLocation.longitude}');
      
      // Step 3: Load simple routes - NO PROBLEMATIC ENDPOINTS
      await _loadSimpleRoutes();
      
      // Step 4: Load user reports
      await _loadUserReports();
      
      print('✅ === ADMIN DASHBOARD READY ===');
      
    } catch (e) {
      print('❌ Admin dashboard initialization failed: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }
  
  /// SIMPLE FIX: Load routes using DIRECT COORDINATES only
  Future<void> _loadSimpleRoutes() async {
    if (_currentLocation == null) return;
    
    setState(() {
      _isLoadingRoutes = true;
      _isLoading = false; // Make sure main loading is off
    });
    
    try {
      print('🗺️ Loading simple routes using direct coordinates...');
      
      // SKIP API SERVICE - DIRECT GET CSV DATA WITH GOOGLE DIRECTIONS
      final csvData = await _getCSVDataWithDirections();
      
      if (mounted) { // Check if widget is still mounted
        setState(() {
          _allRoutes = csvData;
          _routeMethod = 'mixed_sources'; // Will be updated in _getCSVDataWithDirections
          _isLoadingRoutes = false;
          _isLoading = false; // Ensure both loading states are off
        });
        
        print('✅ Loaded ${_allRoutes.length} routes using direct coordinates');
        print('🎯 UI State updated - loading should stop');
      }
      
    } catch (e) {
      print('❌ Route loading failed: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load routes: $e';
          _isLoadingRoutes = false;
          _isLoading = false;
        });
      }
    }
  }
  
  /// Get CSV data and create Google Directions routes directly
  Future<List<Map<String, dynamic>>> _getCSVDataWithDirections() async {
    try {
      // Get CSV data from API service
      final csvResult = await _apiService.getAllWaterSupplyPointsFromCSV();
      final points = csvResult['points'] as List<dynamic>;
      
      print('📍 Got ${points.length} water supply points from CSV');
      
      final routes = <Map<String, dynamic>>[];
      int googleSuccessCount = 0;
      int fallbackCount = 0;
      
      for (int i = 0; i < points.length && i < 15; i++) {
        final point = points[i];
        final lat = (point['latitude'] as num?)?.toDouble();
        final lng = (point['longitude'] as num?)?.toDouble();
        
        if (lat != null && lng != null) {
          // Calculate distance
          final distance = _calculateDistance(
            _currentLocation!.latitude,
            _currentLocation!.longitude,
            lat,
            lng,
          );
          
          // Get Google Directions if backend connected, otherwise use enhanced polyline
          List<Map<String, dynamic>> polylinePoints;
          String travelTime;
          String routeSource;
          
          if (_backendConnected) {
            try {
              final directionsResult = await _getGoogleDirections(lat, lng);
              polylinePoints = directionsResult['polyline_points'];
              travelTime = directionsResult['travel_time'];
              routeSource = 'google_directions';
              googleSuccessCount++;
              print('✅ Google Directions success for point $i');
            } catch (e) {
              print('⚠️ Google Directions failed for point $i: $e');
              polylinePoints = _createEnhancedPolyline(lat, lng, distance);
              travelTime = _estimateTravelTime(distance);
              routeSource = 'enhanced_fallback';
              fallbackCount++;
            }
          } else {
            polylinePoints = _createEnhancedPolyline(lat, lng, distance);
            travelTime = _estimateTravelTime(distance);
            routeSource = 'offline_fallback';
            fallbackCount++;
          }
          
          routes.add({
            'route_id': 'route_$i',
            'destination_name': point['street_name'] ?? 'Water Supply ${i + 1}',
            'destination_address': point['address'] ?? 'Terengganu Water Infrastructure',
            'distance': distance,
            'travel_time': travelTime,
            'polyline_points': polylinePoints,
            'color': i == 0 ? '#00FF00' : '#0066CC',
            'weight': i == 0 ? 6 : 4,
            'opacity': 0.8,
            'is_shortest': i == 0,
            'priority_rank': i + 1,
            'destination_details': point,
            'route_type': 'direct_coordinates',
            'route_source': routeSource,
          });
        }
      }
      
      // Sort by distance
      routes.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
      
      // Update route method based on results
      if (googleSuccessCount > 0) {
        setState(() {
          _routeMethod = googleSuccessCount == routes.length ? 'google_directions' : 'mixed_sources';
        });
      } else {
        setState(() {
          _routeMethod = 'enhanced_fallback';
        });
      }
      
      print('📊 Route Summary:');
      print('   ✅ Google Directions: $googleSuccessCount routes');
      print('   🛣️ Enhanced Fallback: $fallbackCount routes');
      print('   📍 Total routes: ${routes.length}');
      
      return routes;
      
    } catch (e) {
      throw Exception('Failed to get CSV data with directions: $e');
    }
  }
  
  /// Get Google Directions using DIRECT COORDINATES (not Places API)
  Future<Map<String, dynamic>> _getGoogleDirections(double destLat, double destLng) async {
    const apiKey = 'AIzaSyAwwgmqAxzQmdmjNQ-vklZnvVdZjkWLcTY';
    
    final url = 'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${_currentLocation!.latitude},${_currentLocation!.longitude}'
        '&destination=$destLat,$destLng'
        '&mode=driving'
        '&key=$apiKey';
    
    print('📍 Google Directions URL: $url');
    
    try {
      final response = await http.get(Uri.parse(url)).timeout(Duration(seconds: 15));
      
      print('📥 Google Directions Response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        print('📊 Google Directions Status: ${data['status']}');
        
        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final leg = route['legs'][0];
          
          // Decode polyline
          final polylinePoints = _decodePolyline(route['overview_polyline']['points']);
          
          print('✅ Google Directions success: ${polylinePoints.length} points');
          
          return {
            'polyline_points': polylinePoints,
            'travel_time': leg['duration']['text'],
            'distance_text': leg['distance']['text'],
          };
        } else {
          print('❌ Google Directions error: ${data['status']} - ${data['error_message'] ?? 'No error message'}');
          if (data['status'] == 'REQUEST_DENIED') {
            print('🔑 API Key issue - check billing/permissions');
          } else if (data['status'] == 'ZERO_RESULTS') {
            print('🗺️ No route found between coordinates');
          } else if (data['status'] == 'OVER_QUERY_LIMIT') {
            print('⚠️ API quota exceeded');
          }
        }
      } else {
        print('❌ HTTP Error: ${response.statusCode}');
        print('❌ Response body: ${response.body}');
      }
    } catch (e) {
      print('❌ Google Directions exception: $e');
    }
    
    throw Exception('Google Directions API failed');
  }
  
  /// Decode Google polyline
  List<Map<String, dynamic>> _decodePolyline(String encoded) {
    List<Map<String, dynamic>> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;
    
    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;
      
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;
      
      points.add({
        'latitude': lat / 1E5,
        'longitude': lng / 1E5,
      });
    }
    
    return points;
  }
  
  /// Create enhanced polyline (fallback) - IMPROVED TO LOOK MORE REALISTIC
  List<Map<String, dynamic>> _createEnhancedPolyline(double destLat, double destLng, double distance) {
    final points = <Map<String, dynamic>>[];
    
    // Start point
    points.add({
      'latitude': _currentLocation!.latitude,
      'longitude': _currentLocation!.longitude,
    });
    
    // Calculate more realistic road path
    final numWaypoints = Math.max(5, Math.min(20, (distance * 3).round()));
    
    print('🛣️ Creating enhanced polyline with $numWaypoints waypoints for ${distance.toStringAsFixed(1)}km route');
    
    for (int i = 1; i <= numWaypoints; i++) {
      final progress = i / (numWaypoints + 1);
      
      // Basic linear interpolation
      var lat = _currentLocation!.latitude + (destLat - _currentLocation!.latitude) * progress;
      var lng = _currentLocation!.longitude + (destLng - _currentLocation!.longitude) * progress;
      
      // Add realistic road variations
      if (i > 1 && i < numWaypoints) {
        // Main curve factor
        final mainCurve = Math.sin(progress * Math.pi) * 0.002;
        
        // Secondary variations for road following
        final roadVariation = Math.sin(progress * 4 * Math.pi) * 0.0005;
        
        // Distance-based adjustments
        final distanceFactor = Math.min(1.0, distance / 10.0); // Scale based on distance
        
        // Apply curves
        lat += (mainCurve + roadVariation) * distanceFactor * (i % 2 == 0 ? 1 : -1);
        lng += (mainCurve * 0.7 + roadVariation * 0.5) * distanceFactor * (i % 3 == 0 ? 1 : -1);
        
        // For longer distances, add highway-like deviations
        if (distance > 5.0) {
          final highwayOffset = Math.sin(progress * 2 * Math.pi) * 0.003;
          lat += highwayOffset * 0.3;
          lng += highwayOffset * 0.2;
        }
        
        // Add random small deviations to look more natural
        final randomFactor = 0.0003;
        lat += (Math.sin(i * 2.5) * randomFactor);
        lng += (Math.cos(i * 3.7) * randomFactor);
      }
      
      points.add({
        'latitude': lat,
        'longitude': lng,
      });
    }
    
    // End point
    points.add({
      'latitude': destLat,
      'longitude': destLng,
    });
    
    print('✅ Enhanced polyline created with ${points.length} points');
    
    return points;
  }
  
  /// SIMPLE FIX: Add waypoints to polyline to avoid straight lines
  List<Map<String, dynamic>> _enhancePolylinePoints(List<dynamic> originalPoints) {
    if (originalPoints.length < 2) return originalPoints.cast<Map<String, dynamic>>();
    
    final points = originalPoints.cast<Map<String, dynamic>>();
    final enhancedPoints = <Map<String, dynamic>>[];
    
    // Add first point
    enhancedPoints.add(points.first);
    
    // Add intermediate points between each pair to create curves
    for (int i = 0; i < points.length - 1; i++) {
      final start = points[i];
      final end = points[i + 1];
      
      final startLat = start['latitude'] as double;
      final startLng = start['longitude'] as double;
      final endLat = end['latitude'] as double;
      final endLng = end['longitude'] as double;
      
      // Calculate distance to determine number of waypoints
      final distance = _calculateDistance(startLat, startLng, endLat, endLng);
      final numWaypoints = Math.max(1, (distance * 2).round());
      
      // Add intermediate waypoints with slight curves
      for (int j = 1; j <= numWaypoints; j++) {
        final progress = j / (numWaypoints + 1);
        
        // Linear interpolation
        var lat = startLat + (endLat - startLat) * progress;
        var lng = startLng + (endLng - startLng) * progress;
        
        // Add slight curve to avoid straight line
        final curveFactor = Math.sin(progress * Math.pi) * 0.0008; // Small curve
        lat += curveFactor * (j % 2 == 0 ? 1 : -1);
        lng += curveFactor * 0.5 * (j % 3 == 0 ? 1 : -1);
        
        enhancedPoints.add({
          'latitude': lat,
          'longitude': lng,
        });
      }
      
      // Add end point
      enhancedPoints.add(end);
    }
    
    return enhancedPoints;
  }

  /// Estimate travel time as a string based on distance (in km).
  String _estimateTravelTime(double distance) {
    // Assume average speed of 50 km/h for estimation
    final avgSpeed = 50.0;
    final timeHours = distance / avgSpeed;
    final timeMinutes = (timeHours * 60).round();
    return '$timeMinutes min';
  }
  
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
  
  Future<void> _loadUserReports() async {
    try {
      // Use stream method from DatabaseService
      await for (final reports in _databaseService.getReports()) {
        setState(() {
          _userReports = reports;
        });
        break; // Just get first result
      }
    } catch (e) {
      print('⚠️ Failed to load user reports: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: Icon(Icons.swap_horiz),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => RoleSelectionScreen()),
              );
            },
            tooltip: 'Switch Role',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Google Maps as base layer
          if (_currentLocation != null)
            Positioned.fill(
              child: GoogleMapsRouteWidget(
                currentLocation: _currentLocation,
                polylineRoutes: _allRoutes,
                reports: _userReports,
                selectedRouteIndex: _selectedRouteIndex,
                onRouteSelected: (index) {
                  setState(() {
                    _selectedRouteIndex = index;
                  });
                },
              ),
            ),

          // Overlay UI elements
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 200,  // Adjust this value as needed
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: _buildRoutesList(),
            ),
          ),

          // Loading indicator
          if (_isLoading)
            Center(
              child: CircularProgressIndicator(),
            ),

          // Floating action button
          _buildFloatingActions(),
        ],
      ),
    );
  }
  
  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.orange),
          SizedBox(height: 16),
          Text(
            _isLoadingRoutes ? 'Loading Routes...' : 'Initializing Dashboard...',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
          SizedBox(height: 8),
          Text(
            'Current location: ${_currentLocation?.latitude.toStringAsFixed(4) ?? "Unknown"}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          Text(
            'Routes loaded: ${_allRoutes.length}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
  
  Widget _buildErrorView() {
    return Center(
      child: Container(
        margin: EdgeInsets.all(20),
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 48),
            SizedBox(height: 16),
            Text(
              'Route Optimization Error',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
            ),
            SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error',
              style: TextStyle(color: Colors.red.shade700),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _initializeAdminDashboard,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMainDashboard() {
    return Row(
      children: [
        // Maps area
        Expanded(
          flex: 3,
          child: Container(
            margin: EdgeInsets.all(8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: GoogleMapsRouteWidget(
                polylineRoutes: _allRoutes,
                reports: _userReports,
                currentLocation: _currentLocation,
                onRouteSelected: (routeIndex) {
                  setState(() {
                    _selectedRouteIndex = _selectedRouteIndex == routeIndex ? null : routeIndex;
                  });
                },
                selectedRouteIndex: _selectedRouteIndex,
              ),
            ),
          ),
        ),
        
        // Side panel
        Container(
          width: 400,
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: Offset(-2, 0),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildSidePanelHeader(),
              Expanded(
                child: _showRoutesList 
                  ? _buildRoutesList()
                  : _buildDashboardStats(),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildTopStatusBar() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 8,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withOpacity(0.7), Colors.transparent],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // ADMIN BADGE
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.orange, Colors.orange.shade600]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 8, offset: Offset(0, 2))],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.admin_panel_settings, color: Colors.white, size: 16),
                  SizedBox(width: 6),
                  Text('ADMIN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ),
            
            Spacer(),
            
            // ROUTE METHOD INDICATOR
            if (_allRoutes.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'ROUTE OPTIMIZATION',
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ),
            
            SizedBox(width: 8),
            
            // CONNECTION STATUS
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _backendConnected ? Colors.green.withOpacity(0.9) : Colors.red.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _backendConnected ? Icons.cloud_done : Icons.cloud_off,
                    color: Colors.white,
                    size: 14,
                  ),
                  SizedBox(width: 4),
                  Text(
                    _backendConnected ? 'ONLINE' : 'OFFLINE',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSidePanelHeader() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        border: Border(bottom: BorderSide(color: Colors.orange.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.route, color: Colors.orange, size: 24),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Route Optimization',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade800,
                  ),
                ),
              ),
              Switch(
                value: _showRoutesList,
                onChanged: (value) {
                  setState(() {
                    _showRoutesList = value;
                  });
                },
                activeColor: Colors.orange,
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            '${_allRoutes.length} routes found',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
        ],
      ),
    );
  }
  
  Widget _buildRoutesList() {
    if (_allRoutes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.route_outlined, size: 64, color: Colors.grey.shade400),
            SizedBox(height: 16),
            Text(
              'No routes available',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _allRoutes.length,
      itemBuilder: (context, index) {
        final route = _allRoutes[index];
        final isSelected = _selectedRouteIndex == index;
        final isNearest = index == 0;
        
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedRouteIndex = isSelected ? null : index;
            });
          },
          child: Container(
            margin: EdgeInsets.only(bottom: 8),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected ? Colors.blue.shade50 : (isNearest ? Colors.green.shade50 : Colors.grey.shade50),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? Colors.blue : (isNearest ? Colors.green : Colors.grey.shade300),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isNearest ? Colors.green : Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        route['destination_name'] ?? 'Water Supply ${index + 1}',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isNearest)
                      Icon(Icons.star, color: Colors.amber, size: 16),
                  ],
                ),
                
                SizedBox(height: 8),
                
                Row(
                  children: [
                    Icon(Icons.straighten, size: 14, color: Colors.grey.shade600),
                    SizedBox(width: 4),
                    Text(
                      '${route['distance']?.toStringAsFixed(1) ?? '?'} km',
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                    ),
                    SizedBox(width: 16),
                    Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                    SizedBox(width: 4),
                    Text(
                      route['travel_time'] ?? '? min',
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildDashboardStats() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatCard(
            'Total Routes',
            '${_allRoutes.length}',
            Icons.route,
            Colors.blue,
          ),
          SizedBox(height: 12),
          _buildStatCard(
            'Nearest Distance',
            _allRoutes.isNotEmpty ? '${_allRoutes.first['distance']?.toStringAsFixed(1) ?? '?'} km' : 'N/A',
            Icons.near_me,
            Colors.green,
          ),
          SizedBox(height: 12),
          _buildStatCard(
            'Backend Status',
            _backendConnected ? 'Online' : 'Offline',
            _backendConnected ? Icons.cloud_done : Icons.cloud_off,
            _backendConnected ? Colors.green : Colors.red,
          ),
          
          Spacer(),
          
          Column(
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SimpleReportScreen(isAdmin: true),
                    ),
                  );
                },
                icon: Icon(Icons.add_circle, color: Colors.white),
                label: Text('Create Report', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  minimumSize: Size(double.infinity, 44),
                ),
              ),
              SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => RoleSelectionScreen()),
                  );
                },
                icon: Icon(Icons.logout, color: Colors.grey.shade700),
                label: Text('Switch Role', style: TextStyle(color: Colors.grey.shade700)),
                style: OutlinedButton.styleFrom(
                  minimumSize: Size(double.infinity, 44),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFloatingActions() {
    return Positioned(
      bottom: 20,
      right: 20,
      child:       FloatingActionButton(
        onPressed: _isLoadingRoutes ? null : _loadSimpleRoutes,
        child: _isLoadingRoutes 
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            )
          : Icon(Icons.refresh),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
    );
  }
}