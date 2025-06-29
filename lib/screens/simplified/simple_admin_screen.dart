// lib/screens/simplified/simple_admin_screen.dart - COMPLETE REAL ROUTES IMPLEMENTATION
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/report_model.dart';
import '../../services/database_service.dart';
import '../../services/location_service.dart';
import '../../services/api_service.dart';
import '../../screens/simplified/role_selection_screen.dart';
import '../../screens/simplified/simple_report_screen.dart';
import '../../widgets/admin/google_maps_widget.dart';

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
  String _sortBy = 'distance'; // distance, name, time
  String _routeMethod = 'enhanced_simulation'; // Track which method was used
  
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
        // Continue without backend for demo purposes
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
      
      // Step 3: Load optimized routes with real driving paths
      await _loadRealDrivingRoutes();
      
      // Step 4: Load user reports (optional)
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
  
  /// Load real driving routes with enhanced API service
  Future<void> _loadRealDrivingRoutes() async {
    if (_currentLocation == null) return;
    
    setState(() {
      _isLoadingRoutes = true;
    });
    
    try {
      print('🗺️ Loading REAL driving routes with curved paths...');
      
      // Use enhanced API service to get real driving routes
      final result = await _apiService.getPolylineRoutesToWaterSupplies(
        _currentLocation!,
        'admin-dashboard',
        maxRoutes: 15, // Reasonable number for performance
      );
      
      final routes = result['polyline_routes'] as List<dynamic>;
      final method = result['method'] as String? ?? 'unknown';
      
      setState(() {
        _allRoutes = routes.cast<Map<String, dynamic>>();
        _routeMethod = method;
        _isLoadingRoutes = false;
        _isLoading = false;
      });
      
      // Sort routes by distance (nearest first)
      _sortRoutes();
      
      print('✅ Loaded ${routes.length} REAL driving routes using method: $method');
      
      // Log route quality for debugging
      _logRouteQuality();
      
    } catch (e) {
      print('❌ Failed to load real driving routes: $e');
      setState(() {
        _errorMessage = 'Cannot load water supply routes: $e';
        _isLoadingRoutes = false;
        _isLoading = false;
      });
    }
  }
  
  /// Log route quality for debugging
  void _logRouteQuality() {
    for (int i = 0; i < _allRoutes.length && i < 3; i++) {
      final route = _allRoutes[i];
      final polylinePoints = route['polyline_points'] as List<dynamic>? ?? [];
      
      print('📊 Route ${i + 1} Quality:');
      print('   Name: ${route['destination_name']}');
      print('   Distance: ${route['distance']}km');
      print('   Travel Time: ${route['travel_time']}');
      print('   Waypoints: ${polylinePoints.length} points');
      print('   Method: ${route['route_type'] ?? _routeMethod}');
    }
  }
  
  Future<void> _loadUserReports() async {
    try {
      print('📋 Loading user reports...');
      
      final unresolved = await _databaseService.getUnresolvedReportsList();
      final resolved = await _databaseService.getResolvedReportsList();
      
      final allReports = [...unresolved, ...resolved];
      
      setState(() {
        _userReports = allReports;
      });
      
      print('✅ Loaded ${allReports.length} user reports');
      
    } catch (e) {
      print('❌ Failed to load user reports: $e');
      // Don't set error state here - reports are optional
    }
  }
  
  /// Sort routes by different criteria
  void _sortRoutes() {
    setState(() {
      switch (_sortBy) {
        case 'distance':
          _allRoutes.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
          break;
        case 'name':
          _allRoutes.sort((a, b) => (a['destination_name'] ?? '').toString().compareTo((b['destination_name'] ?? '').toString()));
          break;
        case 'time':
          _allRoutes.sort((a, b) {
            final timeA = _parseTimeToMinutes(a['travel_time']?.toString() ?? '0 min');
            final timeB = _parseTimeToMinutes(b['travel_time']?.toString() ?? '0 min');
            return timeA.compareTo(timeB);
          });
          break;
      }
    });
  }
  
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
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _fadeAnimation != null ? FadeTransition(
        opacity: _fadeAnimation!,
        child: Stack(
          children: [
            // MAIN MAP - Real driving routes with Google Maps
            _buildMainMapView(),
            
            // TOP STATUS BAR
            _buildTopStatusBar(),
            
            // FLOATING ACTION BUTTONS
            _buildFloatingActions(),
            
            // ROUTES LIST PANEL
            if (_showRoutesList && _allRoutes.isNotEmpty)
              _buildRoutesListPanel(),
            
            // LOADING OVERLAY
            if (_isLoading) _buildLoadingOverlay(),
            
            // ERROR OVERLAY
            if (_errorMessage != null && !_isLoading) _buildErrorOverlay(),
          ],
        ),
      ) : Container(),
    );
  }
  
  Widget _buildMainMapView() {
    if (_currentLocation == null) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade100, Colors.blue.shade50],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.map_outlined, size: 80, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text('Loading Google Maps...', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
              const SizedBox(height: 8),
              Text('Getting your location...', style: TextStyle(color: Colors.grey.shade500)),
            ],
          ),
        ),
      );
    }
    
    // MAIN FEATURE: Google Maps with real driving routes
    return GoogleMapsRouteWidget(
      polylineRoutes: _allRoutes, // ← Real routes with curved polyline_points
      reports: _userReports,
      currentLocation: _currentLocation,
      showMultipleRoutes: true,
      enableGeneticAlgorithm: true,
      onReportTap: (report) {
        print('📍 Report tapped: ${report.title}');
        _showReportDetails(report);
      },
      onRouteSelected: (index) {
        setState(() {
          _selectedRouteIndex = index;
        });
        print('🗺️ Route selected: $index');
        
        if (index < _allRoutes.length) {
          final route = _allRoutes[index];
          _showRouteDetails(route, index);
        }
      },
      selectedRouteIndex: _selectedRouteIndex,
    );
  }
  
  void _showReportDetails(ReportModel report) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.report_problem, color: Colors.orange),
            SizedBox(width: 8),
            Text(report.title),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Description:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(report.description),
            SizedBox(height: 12),
            Text('Location:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(report.address),
            SizedBox(height: 12),
            Text('Water Quality:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(report.waterQuality.name),
            SizedBox(height: 12),
            Text('Status:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(report.isResolved ? 'Resolved' : 'Pending'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
          if (!report.isResolved)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // Navigate to route to this report
                print('🚗 Navigate to report location');
              },
              child: Text('Navigate'),
            ),
        ],
      ),
    );
  }
  
  void _showRouteDetails(Map<String, dynamic> route, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: index == 0 ? Colors.green : Colors.blue,
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
            Expanded(child: Text(route['destination_name'] ?? 'Water Supply')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRouteDetailRow('📍 Address', route['destination_address'] ?? 'Unknown'),
            _buildRouteDetailRow('📏 Distance', '${route['distance']?.toStringAsFixed(1) ?? '?'} km'),
            _buildRouteDetailRow('⏱️ Travel Time', route['travel_time'] ?? 'Unknown'),
            _buildRouteDetailRow('🚗 Route Type', route['route_type'] ?? _routeMethod),
            _buildRouteDetailRow('🎯 Priority', index == 0 ? 'Nearest Route' : 'Alternative Route'),
            
            if (route['polyline_points'] != null) 
              _buildRouteDetailRow('🗺️ Waypoints', '${(route['polyline_points'] as List).length} points'),
            
            if (route['estimated_fuel_cost'] != null)
              _buildRouteDetailRow('⛽ Est. Fuel Cost', 'RM ${route['estimated_fuel_cost'].toStringAsFixed(2)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              print('🚗 Starting navigation to: ${route['destination_name']}');
              // Here you could integrate with external navigation apps
            },
            child: Text('Navigate'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildRouteDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: TextStyle(fontWeight: FontWeight.w500)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
  
  Widget _buildTopStatusBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
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
                    color: _getMethodColor(_routeMethod).withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getMethodDisplayName(_routeMethod),
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
      ),
    );
  }
  
  Color _getMethodColor(String method) {
    switch (method) {
      case 'google_maps_driving_api':
        return Colors.green;
      case 'genetic_algorithm_driving':
        return Colors.purple;
      case 'enhanced_simulation':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
  
  String _getMethodDisplayName(String method) {
    switch (method) {
      case 'google_maps_driving_api':
        return 'GOOGLE MAPS';
      case 'genetic_algorithm_driving':
        return 'AI OPTIMIZED';
      case 'enhanced_simulation':
        return 'ENHANCED ROUTES';
      default:
        return 'BASIC';
    }
  }
  
  Widget _buildFloatingActions() {
    return Positioned(
      bottom: 20,
      right: 20,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Refresh routes button
          FloatingActionButton(
            heroTag: "refresh",
            onPressed: _isLoadingRoutes ? null : () async {
              await _loadRealDrivingRoutes();
            },
            backgroundColor: Colors.blue,
            child: _isLoadingRoutes 
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh Routes',
          ),
          
          SizedBox(height: 12),
          
          // Toggle routes list
          FloatingActionButton(
            heroTag: "list",
            onPressed: _allRoutes.isEmpty ? null : () {
              setState(() {
                _showRoutesList = !_showRoutesList;
              });
            },
            backgroundColor: _showRoutesList ? Colors.orange : Colors.grey.shade600,
            child: Icon(
              _showRoutesList ? Icons.close : Icons.list,
              color: Colors.white,
            ),
            tooltip: 'Routes List',
          ),
          
          SizedBox(height: 12),
          
          // Add new report button
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
            backgroundColor: Colors.green,
            child: Icon(Icons.add_location, color: Colors.white),
            tooltip: 'Add Report',
          ),
        ],
      ),
    );
  }
  
  Widget _buildRoutesListPanel() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 60,
      right: 16,
      bottom: 100,
      width: 300,
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade600,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.route, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Driving Routes (${_allRoutes.length})',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Spacer(),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.white, size: 20),
                        onPressed: () {
                          setState(() {
                            _showRoutesList = false;
                          });
                        },
                      ),
                    ],
                  ),
                  
                  // Sort options
                  Row(
                    children: [
                      Text('Sort by:', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Row(
                          children: [
                            _buildSortButton('distance', 'Distance'),
                            SizedBox(width: 4),
                            _buildSortButton('time', 'Time'),
                            SizedBox(width: 4),
                            _buildSortButton('name', 'Name'),
                          ],
                        ),
                      ),
                    ],
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
                          // Route header
                          Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: isNearest ? Colors.green : (index < 3 ? Colors.orange : Colors.blue),
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
                          
                          // Route details
                          Row(
                            children: [
                              Icon(Icons.straighten, size: 14, color: Colors.grey.shade600),
                              SizedBox(width: 4),
                              Text(
                                '${route['distance']?.toStringAsFixed(1) ?? '?'} km',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              SizedBox(width: 12),
                              Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                              SizedBox(width: 4),
                              Text(
                                route['travel_time'] ?? '?',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          
                          if (route['destination_address'] != null) ...[
                            SizedBox(height: 6),
                            Text(
                              route['destination_address'],
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          
                          // Route quality indicator
                          if (route['polyline_points'] != null) ...[
                            SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.timeline, size: 12, color: Colors.blue),
                                SizedBox(width: 4),
                                Text(
                                  '${(route['polyline_points'] as List).length} waypoints',
                                  style: TextStyle(fontSize: 10, color: Colors.blue),
                                ),
                                if (isNearest) ...[
                                  Spacer(),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'NEAREST',
                                      style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSortButton(String sortType, String label) {
    final isSelected = _sortBy == sortType;
    return GestureDetector(
      onTap: () {
        setState(() {
          _sortBy = sortType;
        });
        _sortRoutes();
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
  
  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black26,
      child: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.blue)),
                SizedBox(height: 16),
                Text('Loading Real Driving Routes...'),
                SizedBox(height: 8),
                Text(
                  'Getting curved paths to water facilities',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildErrorOverlay() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 80,
      left: 16,
      right: 16,
      child: Card(
        color: Colors.red.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        _errorMessage = null;
                      });
                    },
                  ),
                ],
              ),
              SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () async {
                      await _loadRealDrivingRoutes();
                    },
                    child: Text('Retry'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => RoleSelectionScreen()),
                      );
                    },
                    child: Text('Back to Menu'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}