// lib/screens/simplified/simple_map_screen.dart - REDESIGNED: Routes & Map Visualization Focus
import 'package:aquascan_v2/widgets/admin/google_maps_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  
  // Enhanced UI state
  int? _selectedRouteIndex;
  ReportModel? _selectedReport;
  bool _showReportDetails = false;
  String _viewMode = 'routes'; // 'routes', 'reports', 'both'
  bool _showRoutesList = true;
  bool _optimizeRoutes = true;
  
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
    
    _initializeMapDashboard();
    _animationController?.forward();
  }
  
  @override
  void dispose() {
    _animationController?.dispose();
    super.dispose();
  }
  
  Future<void> _initializeMapDashboard() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _backendConnected = false;
    });
    
    try {
      print('🗺️ === MAP DASHBOARD INITIALIZATION ===');
      
      // Test backend connection
      final isConnected = await _apiService.testBackendConnection();
      setState(() {
        _backendConnected = isConnected;
      });
      
      // Get current location
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
      
      // Load routes and reports concurrently
      await Future.wait([
        _loadOptimizedRoutes(),
        _loadUserReports(),
      ]);
      
      print('✅ === MAP DASHBOARD READY ===');
      
    } catch (e) {
      print('❌ Map dashboard initialization failed: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }
  
  Future<void> _loadOptimizedRoutes() async {
    if (_currentLocation == null) return;
    
    setState(() {
      _isLoadingRoutes = true;
    });
    
    try {
      print('🛣️ Loading water supply routes...');
      
      // Only try to get routes if backend is connected
      if (!_backendConnected) {
        print('⚠️ Backend not connected - skipping route loading');
        if (mounted) {
          setState(() {
            _allRoutes = [];
            _isLoadingRoutes = false;
          });
        }
        return;
      }
      
      List<Map<String, dynamic>> routeData = [];
      
      if (_optimizeRoutes) {
        try {
          // Try to get optimized routes with genetic algorithm
          final result = await _apiService.getOptimizedWaterSupplyRoutes(
            _currentLocation!,
            'admin_map_view',
            maxRoutes: 20,
            useGoogleMaps: true,
            useGeneticAlgorithm: true,
          );
          routeData = result['polyline_routes'] ?? [];
          print('✅ Loaded ${routeData.length} optimized routes from backend');
        } catch (e) {
          print('⚠️ Backend optimization failed: $e');
          // Try CSV fallback
          try {
            routeData = await _getCSVDataWithDirections();
            print('✅ Loaded ${routeData.length} routes from CSV fallback');
          } catch (csvError) {
            print('⚠️ CSV fallback also failed: $csvError');
            routeData = [];
          }
        }
      } else {
        // Try CSV routes directly
        try {
          routeData = await _getCSVDataWithDirections();
          print('✅ Loaded ${routeData.length} routes from CSV');
        } catch (e) {
          print('⚠️ CSV loading failed: $e');
          routeData = [];
        }
      }
      
      if (mounted) {
        setState(() {
          _allRoutes = routeData;
          _isLoadingRoutes = false;
        });
      }
      
    } catch (e) {
      print('❌ Route loading failed: $e');
      if (mounted) {
        setState(() {
          _allRoutes = [];
          _isLoadingRoutes = false;
        });
      }
    }
  }
  
  Future<List<Map<String, dynamic>>> _getCSVDataWithDirections() async {
    try {
      final csvResult = await _apiService.getAllWaterSupplyPointsFromCSV();
      final points = csvResult['points'] as List<dynamic>;
      
      final routes = <Map<String, dynamic>>[];
      
      for (int i = 0; i < points.length && i < 20; i++) {
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
          
          List<Map<String, dynamic>> polylinePoints = _createEnhancedPolyline(lat, lng, distance);
          String travelTime = _estimateTravelTime(distance);
          
          routes.add({
            'route_id': 'csv_route_$i',
            'destination_name': point['street_name'] ?? 'Water Supply ${i + 1}',
            'destination_address': point['address'] ?? 'Water Infrastructure Point',
            'distance': distance,
            'travel_time': travelTime,
            'polyline_points': polylinePoints,
            'color': i == 0 ? '#00FF00' : '#0066CC',
            'weight': i == 0 ? 6 : 4,
            'opacity': 0.8,
            'is_shortest': i == 0,
            'priority_rank': i + 1,
            'destination_details': point,
            'route_type': 'csv_enhanced_route',
          });
        }
      }
      
      // Sort by distance (shortest first)
      routes.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
      
      for (int i = 0; i < routes.length; i++) {
        routes[i]['is_shortest'] = i == 0;
        routes[i]['priority_rank'] = i + 1;
        routes[i]['color'] = i == 0 ? '#00FF00' : '#0066CC';
      }
      
      return routes;
      
    } catch (e) {
      throw Exception('Failed to get CSV route data: $e');
    }
  }
  
  List<Map<String, dynamic>> _createEnhancedPolyline(double destLat, double destLng, double distance) {
    final points = <Map<String, dynamic>>[];
    
    points.add({
      'latitude': _currentLocation!.latitude,
      'longitude': _currentLocation!.longitude,
    });
    
    final numWaypoints = Math.max(8, Math.min(25, (distance * 4).round()));
    
    for (int i = 1; i <= numWaypoints; i++) {
      final progress = i / (numWaypoints + 1);
      
      var lat = _currentLocation!.latitude + (destLat - _currentLocation!.latitude) * progress;
      var lng = _currentLocation!.longitude + (destLng - _currentLocation!.longitude) * progress;
      
      // Add realistic road curves
      if (i > 1 && i < numWaypoints) {
        final mainCurve = Math.sin(progress * Math.pi) * 0.002;
        final roadVariation = Math.sin(progress * 6 * Math.pi) * 0.0008;
        final distanceFactor = Math.min(1.0, distance / 15.0);
        
        lat += (mainCurve + roadVariation) * distanceFactor * (i % 2 == 0 ? 1 : -1);
        lng += (mainCurve * 0.7 + roadVariation * 0.5) * distanceFactor * (i % 3 == 0 ? 1 : -1);
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
    
    return points;
  }
  
  String _estimateTravelTime(double distance) {
    final avgSpeed = 45.0; // km/h
    final timeHours = distance / avgSpeed;
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
  
  Future<void> _loadUserReports() async {
    try {
      print('📋 Loading user reports for map...');
      
      final reports = await _databaseService.getUnresolvedReportsList();
      
      if (mounted) {
        setState(() {
          _userReports = reports;
          _isLoading = false;
        });
        
        print('✅ Loaded ${_userReports.length} user reports for map');
      }
    } catch (e) {
      print('⚠️ Failed to load user reports: $e');
      if (mounted) {
        setState(() {
          _userReports = [];
          _isLoading = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: _buildAppBar(),
      body: _isLoading ? _buildLoadingScreen() : _buildMainContent(),
      floatingActionButton: _buildFloatingActionButtons(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
  
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.map, color: Colors.white, size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Routes & Map', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                Text('Water Supply Network Navigation', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.9))),
              ],
            ),
          ),
        ],
      ),
      backgroundColor: Colors.green,
      elevation: 0,
      actions: [
        // Route count badge
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          margin: EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.route, color: Colors.white, size: 14),
              SizedBox(width: 4),
              Text('${_allRoutes.length}', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        
        // Menu
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: Colors.white),
          onSelected: (value) {
            switch (value) {
              case 'refresh':
                _initializeMapDashboard();
                break;
              case 'toggle_optimization':
                setState(() {
                  _optimizeRoutes = !_optimizeRoutes;
                });
                _loadOptimizedRoutes();
                break;
              case 'reports_dashboard':
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SimpleAdminScreen()),
                );
                break;
              case 'add_report':
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SimpleReportScreen(isAdmin: true)),
                );
                break;
              case 'switch_role':
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => RoleSelectionScreen()),
                );
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(value: 'refresh', child: Row(children: [Icon(Icons.refresh, color: Colors.green, size: 16), SizedBox(width: 8), Text('Refresh Routes')])),
            PopupMenuItem(value: 'toggle_optimization', child: Row(children: [Icon(_optimizeRoutes ? Icons.smart_toy : Icons.grid_view, color: Colors.blue, size: 16), SizedBox(width: 8), Text(_optimizeRoutes ? 'Disable Optimization' : 'Enable Optimization')])),
            PopupMenuItem(value: 'reports_dashboard', child: Row(children: [Icon(Icons.dashboard, color: Colors.orange, size: 16), SizedBox(width: 8), Text('Reports Dashboard')])),
            PopupMenuItem(value: 'add_report', child: Row(children: [Icon(Icons.add_circle, color: Colors.purple, size: 16), SizedBox(width: 8), Text('Add Report')])),
            PopupMenuItem(value: 'switch_role', child: Row(children: [Icon(Icons.swap_horiz, color: Colors.grey, size: 16), SizedBox(width: 8), Text('Switch Role')])),
          ],
        ),
      ],
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.green, Colors.green.shade600],
          ),
        ),
      ),
    );
  }
  
  Widget _buildLoadingScreen() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.green.shade50, Colors.white],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                strokeWidth: 3,
              ),
            ),
            SizedBox(height: 24),
            Text('Loading Map & Routes...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.green.shade800)),
            SizedBox(height: 8),
            Text(_isLoadingRoutes ? 'Optimizing water supply routes...' : 'Preparing map visualization...', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMainContent() {
    return Column(
      children: [
        // Enhanced Header
        _buildEnhancedHeader(),
        
        // Main Content Area
        Expanded(
          child: Stack(
            children: [
              // Google Maps Background
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
                        _selectedReport = null;
                        _showReportDetails = false;
                      });
                    },
                    onReportTap: (report) {
                      setState(() {
                        _selectedReport = report;
                        _selectedRouteIndex = null;
                        _showReportDetails = true;
                      });
                    },
                  ),
                ),
              
              // Side Panel for Routes List
              if (_showRoutesList)
                _buildRoutesListPanel(),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildEnhancedHeader() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Top Row
            Row(
              children: [
                // Icon
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Colors.green, Colors.green.shade600]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.route, color: Colors.white, size: 24),
                ),
                
                SizedBox(width: 12),
                
                // Title Section
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Water Supply Routes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                      Text(
                        _optimizeRoutes 
                          ? 'AI-optimized routing with ${_backendConnected ? 'live data' : 'offline mock data'}'
                          : _backendConnected 
                            ? 'Standard CSV-based routing'
                            : 'Offline mock data (backend unavailable)',
                        style: TextStyle(fontSize: 12, color: Colors.green.shade600),
                      ),
                    ],
                  ),
                ),
                
                // View Mode Toggle
                _buildViewModeToggle(),
                
                SizedBox(width: 8),
                
                // Routes List Toggle
                IconButton(
                  onPressed: () {
                    setState(() {
                      _showRoutesList = !_showRoutesList;
                    });
                  },
                  icon: Icon(_showRoutesList ? Icons.view_list : Icons.view_list_outlined, color: Colors.green),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.green.withOpacity(0.1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 16),
            
            // Offline Notice (if using mock data)
            if (!_backendConnected && _allRoutes.isNotEmpty && 
                _allRoutes.first['route_type'] == 'offline_mock_route') ...[
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.wifi_off, color: Colors.orange, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Using offline mock data - Backend server not available',
                        style: TextStyle(fontSize: 11, color: Colors.orange.shade700, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
            ],
            
            // Stats Row
            _buildStatsRow(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildViewModeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildViewModeButton('🗺️', 'routes', _viewMode == 'routes'),
          _buildViewModeButton('📊', 'reports', _viewMode == 'reports'),
          _buildViewModeButton('📋', 'both', _viewMode == 'both'),
        ],
      ),
    );
  }
  
  Widget _buildViewModeButton(String emoji, String mode, bool isActive) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _viewMode = mode;
        });
      },
      child: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isActive ? Colors.green : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(emoji, style: TextStyle(fontSize: 16)),
      ),
    );
  }
  
  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard('Routes', '${_allRoutes.length}', Icons.route, Colors.blue),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _buildStatCard('Reports', '${_userReports.length}', Icons.report_problem, Colors.orange),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            'Optimization',
            _optimizeRoutes ? 'On' : 'Off',
            _optimizeRoutes ? Icons.smart_toy : Icons.grid_view,
            _optimizeRoutes ? Colors.green : Colors.grey,
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            'Backend',
            _backendConnected ? 'Online' : 'Offline',
            _backendConnected ? Icons.cloud_done : Icons.cloud_off,
            _backendConnected ? Colors.green : Colors.red,
          ),
        ),
      ],
    );
  }
  
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          Text(title, style: TextStyle(fontSize: 10, color: color.withOpacity(0.8)), textAlign: TextAlign.center),
        ],
      ),
    );
  }
  
  Widget _buildRoutesListPanel() {
    return Positioned(
      top: 0,
      right: 0,
      bottom: 0,
      width: 320,
      child: Card(
        elevation: 8,
        margin: EdgeInsets.all(8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Colors.green.shade50.withOpacity(0.3)],
            ),
          ),
          child: Column(
            children: [
              // Panel Header
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  border: Border(
                    bottom: BorderSide(color: Colors.green.shade200),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [Colors.green, Colors.green.shade600]),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.list, color: Colors.white, size: 16),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Water Supply Routes', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                          Text('${_allRoutes.length} optimized routes', style: TextStyle(fontSize: 11, color: Colors.green.shade600)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _showRoutesList = false),
                      icon: Icon(Icons.close, size: 16, color: Colors.green.shade600),
                    ),
                  ],
                ),
              ),
              
              // Routes List
              Expanded(
                child: _allRoutes.isEmpty 
                    ? _buildEmptyRoutesView()
                    : ListView.builder(
                        padding: EdgeInsets.all(8),
                        itemCount: _allRoutes.length,
                        itemBuilder: (context, index) {
                          final route = _allRoutes[index];
                          return _buildRouteListItem(route, index);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildRouteListItem(Map<String, dynamic> route, int index) {
    final isSelected = _selectedRouteIndex == index;
    final isShortest = route['is_shortest'] == true;
    
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      child: Card(
        elevation: isSelected ? 6 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isSelected ? Colors.green : (isShortest ? Colors.blue : Colors.transparent),
            width: isSelected ? 2 : (isShortest ? 1 : 0),
          ),
        ),
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedRouteIndex = _selectedRouteIndex == index ? null : index;
              _selectedReport = null;
              _showReportDetails = false;
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  isShortest ? Colors.blue.shade50.withOpacity(0.3) : Colors.green.shade50.withOpacity(0.3),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    // Rank badge
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isShortest ? Colors.blue : Colors.green,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text('${index + 1}', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    
                    SizedBox(width: 8),
                    
                    // Special badges
                    if (isShortest) ...[
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('SHORTEST', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                      ),
                      SizedBox(width: 4),
                    ],
                    
                    if (isSelected) ...[
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('SELECTED', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                      ),
                    ],
                    
                    Spacer(),
                    
                    // Distance
                    Text('${(route['distance'] as double?)?.toStringAsFixed(1) ?? '?'}km', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isShortest ? Colors.blue : Colors.green)),
                  ],
                ),
                
                SizedBox(height: 8),
                
                // Destination name
                Text(
                  route['destination_name'] ?? 'Water Supply ${index + 1}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                
                SizedBox(height: 4),
                
                // Travel time and type
                Row(
                  children: [
                    Icon(Icons.access_time, size: 12, color: Colors.grey.shade600),
                    SizedBox(width: 4),
                    Text(route['travel_time'] ?? '?', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                    SizedBox(width: 12),
                    Icon(Icons.route, size: 12, color: Colors.grey.shade600),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _getRouteTypeDisplay(route['route_type'] as String?),
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                        overflow: TextOverflow.ellipsis,
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
  }
  
  String _getRouteTypeDisplay(String? routeType) {
    switch (routeType) {
      case 'csv_enhanced_route': return 'Enhanced CSV';
      case 'genetic_algorithm_driving': return 'AI Optimized';
      case 'google_maps_driving_api': return 'Google Maps';
      case 'enhanced_route': return 'Enhanced';
      case 'offline_mock_route': return 'Offline Mock';
      default: return 'Standard';
    }
  }
  
  Widget _buildEmptyRoutesView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.route_outlined, size: 48, color: Colors.grey.shade400),
          SizedBox(height: 16),
          Text('No Routes Available', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
          SizedBox(height: 8),
          Text(
            _isLoadingRoutes 
                ? 'Loading routes...'
                : 'Check backend connection\nor try refreshing',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          if (!_isLoadingRoutes)
            ElevatedButton.icon(
              onPressed: _loadOptimizedRoutes,
              icon: Icon(Icons.refresh, size: 16),
              label: Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildFloatingActionButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Reports Dashboard FAB
        FloatingActionButton(
          heroTag: "reports_dashboard",
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => SimpleAdminScreen()),
            );
          },
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          child: Icon(Icons.dashboard),
          tooltip: 'Reports Dashboard',
        ),
        
        SizedBox(height: 12),
        
        // Optimize Routes FAB
        FloatingActionButton(
          heroTag: "optimize_routes",
          onPressed: () {
            setState(() {
              _optimizeRoutes = !_optimizeRoutes;
            });
            _loadOptimizedRoutes();
          },
          backgroundColor: _optimizeRoutes ? Colors.blue : Colors.grey,
          foregroundColor: Colors.white,
          child: Icon(_optimizeRoutes ? Icons.smart_toy : Icons.grid_view),
          tooltip: _optimizeRoutes ? 'Disable Optimization' : 'Enable Optimization',
        ),
        
        SizedBox(height: 12),
        
        // Refresh Routes FAB
        FloatingActionButton(
          heroTag: "refresh_routes",
          onPressed: _isLoadingRoutes ? null : _initializeMapDashboard,
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          child: _isLoadingRoutes 
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : Icon(Icons.refresh),
          tooltip: 'Refresh Routes',
        ),
      ],
    );
  }
}