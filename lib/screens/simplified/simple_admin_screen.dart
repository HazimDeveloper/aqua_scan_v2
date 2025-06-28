// lib/screens/simplified/simple_admin_screen.dart - FIXED: Route Listing & Empty Reports Handling
import 'package:aquascan_v2/widgets/admin/google_maps_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/report_model.dart';
import '../../services/database_service.dart';
import '../../services/location_service.dart';
import '../../services/api_service.dart';
import '../../screens/simplified/role_selection_screen.dart';
import '../../screens/simplified/simple_report_screen.dart';
import '../../widgets/common/custom_loader.dart';
import '../../widgets/simplified/openstreet_map_widget.dart';

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
          _errorMessage = 'Backend server offline';
          _isLoading = false;
        });
        return;
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
      
      // Step 3: Load routes using genetic algorithm
      await _loadOptimizedRoutes();
      
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
  
  // ENHANCED: Load routes using genetic algorithm optimization
  Future<void> _loadOptimizedRoutes() async {
    if (_currentLocation == null) return;
    
    setState(() {
      _isLoadingRoutes = true;
    });
    
    try {
      print('🧬 Loading optimized routes using genetic algorithm...');
      
      // Try to get optimized routes first
      final result = await _apiService.getPolylineRoutesToWaterSupplies(
        _currentLocation!,
        'admin-dashboard',
        maxRoutes: 50,
      );
      
      final routes = result['polyline_routes'] as List<dynamic>;
      
      setState(() {
        _allRoutes = routes.cast<Map<String, dynamic>>();
        _isLoadingRoutes = false;
        _isLoading = false;
      });
      
      // Sort routes by distance (nearest first)
      _sortRoutes();
      
      print('✅ Loaded ${routes.length} optimized routes');
      
    } catch (e) {
      print('❌ Failed to load optimized routes: $e');
      setState(() {
        _errorMessage = 'Cannot load water supply routes: $e';
        _isLoadingRoutes = false;
        _isLoading = false;
      });
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
  
  // ENHANCED: Sort routes by different criteria
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
            // MAIN MAP - Show water supplies always, reports if available
            _buildMainMapView(),
            
            // TOP STATUS BAR
            _buildTopStatusBar(),
            
            // FLOATING ACTION BUTTONS
            _buildFloatingActions(),
            
            // ROUTES LIST PANEL - NEW
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
              Text('Loading Map...', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
            ],
          ),
        ),
      );
    }
    
    return GoogleMapsRouteWidget(
      currentLocation: _currentLocation!,
      polylineRoutes: _allRoutes,
      reports: _userReports, // Added required 'reports' parameter
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
                    Text('ADMIN', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              
              const SizedBox(width: 12),
              
              // ROUTE COUNT
              if (_allRoutes.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.route, color: Colors.white, size: 12),
                      SizedBox(width: 4),
                      Text('${_allRoutes.length}', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              
              // REPORTS COUNT
              if (_userReports.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.report_problem, color: Colors.white, size: 12),
                      SizedBox(width: 4),
                      Text('${_userReports.length}', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
              
              const Spacer(),
              
              // ACTION BUTTONS
              Row(
                children: [
                  _buildTopActionButton(icon: Icons.refresh, onPressed: _initializeAdminDashboard),
                  const SizedBox(width: 8),
                  _buildTopActionButton(icon: Icons.logout, onPressed: _showRoleSwitchDialog),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildTopActionButton({required IconData icon, required VoidCallback onPressed}) {
    return Material(
      color: Colors.black.withOpacity(0.3),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
  
  Widget _buildFloatingActions() {
    return Positioned(
      bottom: 20,
      left: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ROUTES LIST TOGGLE
          if (_allRoutes.isNotEmpty)
            FloatingActionButton(
              mini: true,
              heroTag: "routes_list",
              backgroundColor: _showRoutesList ? Colors.orange : Colors.white,
              foregroundColor: _showRoutesList ? Colors.white : Colors.orange,
              onPressed: () {
                setState(() {
                  _showRoutesList = !_showRoutesList;
                });
              },
              child: Icon(Icons.list, size: 20),
            ),
          
          const SizedBox(height: 12),
          
          // CREATE REPORT
          FloatingActionButton.extended(
            heroTag: "create_report",
            onPressed: _backendConnected ? () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SimpleReportScreen(isAdmin: true)),
              ).then((_) => _loadUserReports());
            } : null,
            backgroundColor: _backendConnected ? Colors.orange : Colors.grey,
            foregroundColor: Colors.white,
            icon: Icon(Icons.add_circle, size: 22),
            label: Text('Report', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ],
      ),
    );
  }
  
  // NEW: Routes list panel with sorting
  Widget _buildRoutesListPanel() {
    return Positioned(
      top: 100,
      bottom: 100,
      right: 16,
      child: Container(
        width: 320,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header with sorting options
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade50, Colors.blue.shade100.withOpacity(0.3)],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.route, color: Colors.blue, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Water Supply Routes',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue.shade800),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _showRoutesList = false),
                        child: Icon(Icons.close, size: 18, color: Colors.blue.shade600),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 12),
                  
                  // Sort options
                  Row(
                    children: [
                      Text('Sort by: ', style: TextStyle(fontSize: 12, color: Colors.blue.shade700)),
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
                        color: isSelected ? Colors.blue.shade50 : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? Colors.blue : Colors.grey.shade300,
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
                                  color: index == 0 ? Colors.green : (index < 3 ? Colors.blue : Colors.orange),
                                  borderRadius: BorderRadius.circular(6),
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
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: isSelected ? Colors.blue.shade800 : Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (index == 0)
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
                                '${(route['distance'] as double?)?.toStringAsFixed(1) ?? '?'} km',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                              ),
                              SizedBox(width: 12),
                              Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                              SizedBox(width: 4),
                              Text(
                                route['travel_time']?.toString() ?? '?',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                          
                          if (isSelected) ...[
                            SizedBox(height: 8),
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Address:',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                                  ),
                                  Text(
                                    route['destination_address'] ?? 'Address not available',
                                    style: TextStyle(fontSize: 11, color: Colors.blue.shade700),
                                  ),
                                ],
                              ),
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
  
  Widget _buildSortButton(String sortKey, String label) {
    final isSelected = _sortBy == sortKey;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _sortBy = sortKey;
        });
        _sortRoutes();
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isSelected ? Colors.white : Colors.blue.shade700,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
  
  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: Offset(0, 10))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              WaterDropLoader(message: 'Loading Admin Dashboard...'),
              const SizedBox(height: 20),
              Text(
                _isLoadingRoutes 
                    ? 'Optimizing water supply routes using genetic algorithm...'
                    : 'Initializing admin dashboard...',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildErrorOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: Offset(0, 10))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Dashboard Error', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                child: Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700, height: 1.4)),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const RoleSelectionScreen())),
                      icon: Icon(Icons.arrow_back),
                      label: Text('Go Back'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _initializeAdminDashboard,
                      icon: Icon(Icons.refresh),
                      label: Text('Retry'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _showRoleSwitchDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.swap_horiz, color: Colors.orange),
              const SizedBox(width: 8),
              const Text('Switch Role'),
            ],
          ),
          content: const Text('Are you sure you want to leave the admin dashboard?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
              child: const Text('Switch Role'),
            ),
          ],
        );
      },
    );
  }
}