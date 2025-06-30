// lib/screens/simplified/simple_admin_screen.dart - ENHANCED: Added User Reports View
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
  bool _showUserReports = true; // ADDED: Show user reports by default
  int? _selectedRouteIndex;
  String _sortBy = 'distance';
  String _routeMethod = 'basic_routes';
  
  // ADDED: Report management
  ReportModel? _selectedReport;
  bool _showReportDetails = false;
  
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
      
      // Step 3: Load simple routes
      await _loadSimpleRoutes();
      
      // Step 4: Load user reports
      await _loadUserReports();
      
      print('✅ === ADMIN DASHBOARD READY ===');
      print('📊 Routes: ${_allRoutes.length}, Reports: ${_userReports.length}');
      
    } catch (e) {
      print('❌ Admin dashboard initialization failed: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }
  
  Future<void> _loadSimpleRoutes() async {
    if (_currentLocation == null) return;
    
    setState(() {
      _isLoadingRoutes = true;
      _isLoading = false;
    });
    
    try {
      print('🗺️ Loading simple routes using direct coordinates...');
      
      final csvData = await _getCSVDataWithDirections();
      
      if (mounted) {
        setState(() {
          _allRoutes = csvData;
          _routeMethod = 'mixed_sources';
          _isLoadingRoutes = false;
          _isLoading = false;
        });
        
        print('✅ Loaded ${_allRoutes.length} routes using direct coordinates');
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
  
  Future<List<Map<String, dynamic>>> _getCSVDataWithDirections() async {
    try {
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
          final distance = _calculateDistance(
            _currentLocation!.latitude,
            _currentLocation!.longitude,
            lat,
            lng,
          );
          
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
      
      // Update shortest route flag after sorting
      for (int i = 0; i < routes.length; i++) {
        routes[i]['is_shortest'] = i == 0;
        routes[i]['priority_rank'] = i + 1;
        routes[i]['color'] = i == 0 ? '#00FF00' : '#0066CC';
        routes[i]['weight'] = i == 0 ? 6 : 4;
      }
      
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
          
          final polylinePoints = _decodePolyline(route['overview_polyline']['points']);
          
          print('✅ Google Directions success: ${polylinePoints.length} points');
          
          return {
            'polyline_points': polylinePoints,
            'travel_time': leg['duration']['text'],
            'distance_text': leg['distance']['text'],
          };
        } else {
          print('❌ Google Directions error: ${data['status']} - ${data['error_message'] ?? 'No error message'}');
        }
      } else {
        print('❌ HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Google Directions exception: $e');
    }
    
    throw Exception('Google Directions API failed');
  }
  
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
  
  List<Map<String, dynamic>> _createEnhancedPolyline(double destLat, double destLng, double distance) {
    final points = <Map<String, dynamic>>[];
    
    points.add({
      'latitude': _currentLocation!.latitude,
      'longitude': _currentLocation!.longitude,
    });
    
    final numWaypoints = Math.max(5, Math.min(20, (distance * 3).round()));
    
    print('🛣️ Creating enhanced polyline with $numWaypoints waypoints for ${distance.toStringAsFixed(1)}km route');
    
    for (int i = 1; i <= numWaypoints; i++) {
      final progress = i / (numWaypoints + 1);
      
      var lat = _currentLocation!.latitude + (destLat - _currentLocation!.latitude) * progress;
      var lng = _currentLocation!.longitude + (destLng - _currentLocation!.longitude) * progress;
      
      if (i > 1 && i < numWaypoints) {
        final mainCurve = Math.sin(progress * Math.pi) * 0.002;
        final roadVariation = Math.sin(progress * 4 * Math.pi) * 0.0005;
        final distanceFactor = Math.min(1.0, distance / 10.0);
        
        lat += (mainCurve + roadVariation) * distanceFactor * (i % 2 == 0 ? 1 : -1);
        lng += (mainCurve * 0.7 + roadVariation * 0.5) * distanceFactor * (i % 3 == 0 ? 1 : -1);
        
        if (distance > 5.0) {
          final highwayOffset = Math.sin(progress * 2 * Math.pi) * 0.003;
          lat += highwayOffset * 0.3;
          lng += highwayOffset * 0.2;
        }
        
        final randomFactor = 0.0003;
        lat += (Math.sin(i * 2.5) * randomFactor);
        lng += (Math.cos(i * 3.7) * randomFactor);
      }
      
      points.add({
        'latitude': lat,
        'longitude': lng,
      });
    }
    
    points.add({
      'latitude': destLat,
      'longitude': destLng,
    });
    
    print('✅ Enhanced polyline created with ${points.length} points');
    
    return points;
  }
  
  String _estimateTravelTime(double distance) {
    final avgSpeed = 50.0;
    final timeHours = distance / avgSpeed;
    final timeMinutes = (timeHours * 60).round();
    return '$timeMinutes min';
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
  
  // ENHANCED: Load user reports with better error handling
  Future<void> _loadUserReports() async {
    try {
      print('📋 Loading user reports...');
      
      final reports = await _databaseService.getUnresolvedReportsList();
      
      if (mounted) {
        setState(() {
          _userReports = reports;
        });
        
        print('✅ Loaded ${_userReports.length} user reports');
        for (int i = 0; i < _userReports.length; i++) {
          final report = _userReports[i];
          print('   ${i + 1}. ${report.title} by ${report.userName} (${report.waterQuality.name})');
        }
      }
    } catch (e) {
      print('⚠️ Failed to load user reports: $e');
      // Continue without reports
      if (mounted) {
        setState(() {
          _userReports = [];
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Dashboard'),
        actions: [
          // ADDED: Reports toggle
          IconButton(
            icon: Icon(_showUserReports ? Icons.report : Icons.report_outlined),
            onPressed: () {
              setState(() {
                _showUserReports = !_showUserReports;
              });
            },
            tooltip: _showUserReports ? 'Hide Reports' : 'Show Reports',
          ),
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
                reports: _userReports, // ADDED: Pass user reports to map
                selectedRouteIndex: _selectedRouteIndex,
                onRouteSelected: (index) {
                  setState(() {
                    _selectedRouteIndex = index;
                    _selectedReport = null; // Clear report selection
                    _showReportDetails = false;
                  });
                },
                onReportTap: (report) { // ADDED: Handle report tap
                  setState(() {
                    _selectedReport = report;
                    _selectedRouteIndex = null; // Clear route selection
                    _showReportDetails = true;
                  });
                },
              ),
            ),

          // ENHANCED: Overlay UI elements with conditional visibility
          if (_showUserReports && _userReports.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: _showReportDetails ? 300 : 200,
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
                child: _showReportDetails ? _buildReportDetails() : _buildReportsList(),
              ),
            )
          else if (!_showUserReports && _allRoutes.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: 200,
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
  
  // ADDED: Build reports list
  Widget _buildReportsList() {
    if (_userReports.isEmpty) {
      return Container(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.report_outlined, size: 48, color: Colors.grey.shade400),
            SizedBox(height: 16),
            Text(
              'No User Reports',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
            ),
            SizedBox(height: 8),
            Text(
              'No water quality reports have been submitted by users yet.',
              style: TextStyle(color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    
    return Column(
      children: [
        // Header
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.report, color: Colors.white, size: 20),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'User Reports',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade800,
                      ),
                    ),
                    Text(
                      '${_userReports.length} unresolved reports',
                      style: TextStyle(color: Colors.orange.shade600, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (_showReportDetails)
                IconButton(
                  icon: Icon(Icons.close, color: Colors.orange.shade600),
                  onPressed: () {
                    setState(() {
                      _showReportDetails = false;
                      _selectedReport = null;
                    });
                  },
                ),
            ],
          ),
        ),
        
        // Reports list
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(8),
            itemCount: _userReports.length,
            itemBuilder: (context, index) {
              final report = _userReports[index];
              final isSelected = _selectedReport?.id == report.id;
              
              return Container(
                margin: EdgeInsets.only(bottom: 8),
                child: Card(
                  elevation: isSelected ? 4 : 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected ? Colors.orange : Colors.transparent,
                      width: isSelected ? 2 : 0,
                    ),
                  ),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedReport = _selectedReport?.id == report.id ? null : report;
                        _showReportDetails = _selectedReport != null;
                        _selectedRouteIndex = null; // Clear route selection
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Row(
                        children: [
                          // Quality indicator
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _getWaterQualityColor(report.waterQuality),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.water_drop,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          
                          SizedBox(width: 12),
                          
                          // Report info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  report.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'By: ${report.userName}',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  report.waterQuality.name.toUpperCase(),
                                  style: TextStyle(
                                    color: _getWaterQualityColor(report.waterQuality),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Action buttons
                          Column(
                            children: [
                              Icon(
                                isSelected ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                color: Colors.grey.shade400,
                              ),
                              Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
  
  // ADDED: Build report details
  Widget _buildReportDetails() {
    if (_selectedReport == null) return _buildReportsList();
    
    return Column(
      children: [
        // Header with back button
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: Colors.orange.shade600),
                onPressed: () {
                  setState(() {
                    _showReportDetails = false;
                    _selectedReport = null;
                  });
                },
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Report Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade800,
                  ),
                ),
              ),
              // Resolve button
              ElevatedButton.icon(
                onPressed: () => _resolveReport(_selectedReport!),
                icon: Icon(Icons.check, size: 18),
                label: Text('Resolve'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
        
        // Report details content
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and quality
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: _getWaterQualityColor(_selectedReport!.waterQuality),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.water_drop,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedReport!.title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getWaterQualityColor(_selectedReport!.waterQuality),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _selectedReport!.waterQuality.name.toUpperCase(),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 16),
                
                // Description
                _buildDetailSection('Description', _selectedReport!.description),
                
                // Reporter info
                _buildDetailSection('Reporter', _selectedReport!.userName),
                
                // Location
                _buildDetailSection('Location', _selectedReport!.address),
                
                // Images count
                if (_selectedReport!.imageUrls.isNotEmpty)
                  _buildDetailSection('Images', '${_selectedReport!.imageUrls.length} photo(s) attached'),
                
                // Timestamps
                _buildDetailSection(
                  'Reported At', 
                  '${_selectedReport!.createdAt.day}/${_selectedReport!.createdAt.month}/${_selectedReport!.createdAt.year} at ${_selectedReport!.createdAt.hour}:${_selectedReport!.createdAt.minute.toString().padLeft(2, '0')}'
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildDetailSection(String title, String content) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          SizedBox(height: 4),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
  
  // ENHANCED: Routes list (existing but improved)
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
    
    return Column(
      children: [
        // Header
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.route, color: Colors.white, size: 20),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Water Supply Routes',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                    Text(
                      '${_allRoutes.length} routes found',
                      style: TextStyle(color: Colors.blue.shade600, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Routes list
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(8),
            itemCount: _allRoutes.length,
            itemBuilder: (context, index) {
              final route = _allRoutes[index];
              final isSelected = _selectedRouteIndex == index;
              final isShortest = route['is_shortest'] == true;
              
              return Container(
                margin: EdgeInsets.only(bottom: 8),
                child: Card(
                  elevation: isSelected ? 4 : 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected ? Colors.blue : (isShortest ? Colors.green : Colors.transparent),
                      width: isSelected ? 2 : (isShortest ? 1 : 0),
                    ),
                  ),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedRouteIndex = _selectedRouteIndex == index ? null : index;
                        _selectedReport = null; // Clear report selection
                        _showReportDetails = false;
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              // Rank badge with special styling for shortest
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: isShortest ? Colors.green : Colors.blue,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Center(
                                  child: isShortest ? 
                                    Icon(Icons.star, color: Colors.white, size: 14) :
                                    Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                ),
                              ),
                              
                              SizedBox(width: 8),
                              
                              // Special badges
                              if (isShortest) ...[
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'SHORTEST',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 4),
                              ],
                              
                              if (isSelected) ...[
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'SELECTED',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                              
                              Spacer(),
                              
                              // Distance
                              Text(
                                '${route['distance']?.toStringAsFixed(1) ?? '?'} km',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isShortest ? Colors.green : Colors.blue,
                                ),
                              ),
                            ],
                          ),
                          
                          SizedBox(height: 8),
                          
                          // Destination name
                          Text(
                            route['destination_name'] ?? 'Water Supply ${index + 1}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          
                          SizedBox(height: 4),
                          
                          // Travel time
                          Row(
                            children: [
                              Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                              SizedBox(width: 4),
                              Text(
                                route['travel_time'] ?? '? min',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
  
  // ADDED: Resolve report function
  Future<void> _resolveReport(ReportModel report) async {
    try {
      await _databaseService.resolveReport(report.id);
      
      // Remove from list
      setState(() {
        _userReports.removeWhere((r) => r.id == report.id);
        _selectedReport = null;
        _showReportDetails = false;
      });
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Report resolved successfully!'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Text('Failed to resolve report: $e'),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }
  
  Color _getWaterQualityColor(WaterQualityState quality) {
    switch (quality) {
      case WaterQualityState.optimum:
        return Colors.blue;
      case WaterQualityState.lowTemp:
        return Colors.green;
      case WaterQualityState.highPh:
      case WaterQualityState.lowPh:
        return Colors.orange;
      case WaterQualityState.highPhTemp:
        return Colors.red;
      case WaterQualityState.lowTempHighPh:
        return Colors.purple;
      case WaterQualityState.unknown:
      default:
        return Colors.grey;
    }
  }
  
  Widget _buildFloatingActions() {
    return Positioned(
      bottom: _showUserReports && _userReports.isNotEmpty ? 220 : 20,
      right: 20,
      child: Column(
        children: [
          // Refresh button
          FloatingActionButton(
            heroTag: "refresh",
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
          
          SizedBox(height: 12),
          
          // Add report button
          FloatingActionButton(
            heroTag: "add_report",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SimpleReportScreen(isAdmin: true),
                ),
              );
            },
            child: Icon(Icons.add),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ],
      ),
    );
  }
}