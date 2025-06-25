// lib/screens/simplified/simple_admin_screen.dart - ENHANCED with Shortest Route Button & Report Popup
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
  AnimationController? _panelController;
  Animation<double>? _fadeAnimation;
  Animation<double>? _panelAnimation;
  
  bool _isLoading = false;
  bool _isLoadingRoutes = false;
  bool _isLoadingReports = false;
  bool _backendConnected = false;
  
  GeoPoint? _currentLocation;
  List<Map<String, dynamic>> _allRoutes = [];
  List<ReportModel> _userReports = [];
  Map<String, dynamic>? _csvDataInfo;
  String? _errorMessage;
  
  late LocationService _locationService;
  late ApiService _apiService;
  late DatabaseService _databaseService;
  
  // UI state
  bool _showInfoPanel = true;
  bool _showSystemStats = false;
  bool _isInfoPanelExpanded = false;
  bool _showCreateReportPanel = false;
  
  // NEW: Simple state for shortest route filter
  bool _showOnlyShortestRoute = false;
  
  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _panelController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController!,
      curve: Curves.easeInOut,
    ));
    
    _panelAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _panelController!,
      curve: Curves.easeOutBack,
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
    _panelController?.dispose();
    super.dispose();
  }
  
  Future<void> _initializeAdminDashboard() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _backendConnected = false;
    });
    
    try {
      print('\n🚀 === ADMIN DASHBOARD INITIALIZATION ===');
      
      // Step 1: Test backend connection
      print('1️⃣ Testing backend connection...');
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
      
      print('✅ Backend connected successfully');
      
      // Step 2: Get current location
      print('2️⃣ Getting admin location...');
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
      
      print('✅ Location: ${position.latitude}, ${position.longitude}');
      
      // Step 3: Load CSV data
      print('3️⃣ Loading water supply data...');
      await _loadCSVData();
      
      // Step 4: Generate routes
      print('4️⃣ Generating route network...');
      await _loadRouteNetwork();
      
      // Step 5: Load user reports
      print('5️⃣ Loading user reports...');
      await _loadUserReports();
      
      print('✅ === ADMIN DASHBOARD READY ===\n');
      
    } catch (e) {
      print('❌ Admin dashboard initialization failed: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }
  
  Future<void> _loadCSVData() async {
    try {
      final csvData = await _apiService.getAllWaterSupplyPointsFromCSV();
      setState(() {
        _csvDataInfo = csvData;
      });
      
      final points = csvData['points'] as List<dynamic>;
      print('📊 Loaded ${points.length} water supply points');
      
    } catch (e) {
      print('❌ Failed to load CSV data: $e');
      throw Exception('Cannot load water supply data: $e');
    }
  }
  
  Future<void> _loadRouteNetwork() async {
    if (_currentLocation == null) {
      throw Exception('Current location not available');
    }
    
    setState(() {
      _isLoadingRoutes = true;
    });
    
    try {
      print('🗺️ Loading complete route network...');
      
      final result = await _apiService.getPolylineRoutesToWaterSupplies(
        _currentLocation!,
        'admin-dashboard',
        maxRoutes: 50,
      );
      
      final routes = result['polyline_routes'] as List<dynamic>;
      
      setState(() {
        _allRoutes = routes.cast<Map<String, dynamic>>();
        _isLoadingRoutes = false;
      });
      
      print('✅ Loaded ${routes.length} route networks');
      
      if (_allRoutes.isNotEmpty) {
        _panelController?.forward();
      }
      
    } catch (e) {
      print('❌ Failed to load route network: $e');
      setState(() {
        _errorMessage = 'Cannot load route network: $e';
        _isLoadingRoutes = false;
      });
    }
  }
  
  Future<void> _loadUserReports() async {
    setState(() {
      _isLoadingReports = true;
    });
    
    try {
      print('📋 Loading user reports from local database...');
      
      final unresolved = await _databaseService.getUnresolvedReportsList();
      final resolved = await _databaseService.getResolvedReportsList();
      
      final allReports = [...unresolved, ...resolved];
      
      setState(() {
        _userReports = allReports;
        _isLoadingReports = false;
        _isLoading = false;
      });
      
      print('✅ Loaded ${allReports.length} user reports');
      print('   - Unresolved: ${unresolved.length}');
      print('   - Resolved: ${resolved.length}');
      
    } catch (e) {
      print('❌ Failed to load user reports: $e');
      setState(() {
        _isLoadingReports = false;
        _isLoading = false;
      });
    }
  }
  
  Future<void> _refreshDashboard() async {
    print('🔄 Refreshing admin dashboard...');
    await _initializeAdminDashboard();
  }
  
  // NEW: Get filtered routes based on shortest route toggle
  List<Map<String, dynamic>> _getFilteredRoutes() {
    if (_showOnlyShortestRoute && _allRoutes.isNotEmpty) {
      return [_allRoutes.first]; // Only return the shortest route
    }
    return _allRoutes; // Return all routes
  }
  
  // NEW: Show report details popup
  void _showReportDetailsPopup(ReportModel report) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            constraints: BoxConstraints(maxHeight: 500, maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.report_problem, color: Colors.white, size: 20),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Report Details',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade800,
                              ),
                            ),
                            Text(
                              'By: ${report.userName}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close, color: Colors.orange.shade600),
                      ),
                    ],
                  ),
                ),
                
                // Content
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          'Title',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        SizedBox(height: 4),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            report.title,
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                        
                        SizedBox(height: 12),
                        
                        // Description
                        Text(
                          'Description',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        SizedBox(height: 4),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            report.description,
                            style: TextStyle(fontSize: 13),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        
                        SizedBox(height: 12),
                        
                        
                        // Status
                        Row(
                          children: [
                            Text(
                              'Status: ',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: report.isResolved ? Colors.green : Colors.red,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                report.isResolved ? 'Resolved' : 'Open',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Footer
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          report.address,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _fadeAnimation != null ? FadeTransition(
        opacity: _fadeAnimation!,
        child: Stack(
          children: [
            // MAIN MAP - Full screen background (UPDATED with filtered routes)
            _buildFullScreenMapWithReports(),
            
            // TOP STATUS BAR
            _buildUpdatedTopStatusBar(),
            
            // FLOATING ACTION BUTTON - Create Report
            _buildCreateReportFAB(),
            
            // INFO PANEL - Bottom overlay
            if (_showInfoPanel && (_allRoutes.isNotEmpty || _userReports.isNotEmpty))
              _buildUpdatedInfoPanel(),
            
            // SYSTEM STATS PANEL - Top right overlay
            if (_showSystemStats)
              _buildUpdatedSystemStatsPanel(),
            
            // CREATE REPORT PANEL - Right side overlay
            if (_showCreateReportPanel)
              _buildCreateReportPanel(),
            
            // LOADING OVERLAY
            if (_isLoading) _buildLoadingOverlay(),
            
            // ERROR OVERLAY
            if (_errorMessage != null && !_isLoading) _buildErrorOverlay(),
          ],
        ),
      ) : Container(),
    );
  }
  
  Widget _buildFullScreenMapWithReports() {
    if (_currentLocation == null) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade100,
              Colors.blue.shade50,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.map_outlined,
                size: 80,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'Loading Map...',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return OpenStreetMapWidget(
      currentLocation: _currentLocation!,
      polylineRoutes: _getFilteredRoutes(), // NEW: Use filtered routes
      userReports: _userReports,
      isLoading: _isLoadingRoutes || _isLoadingReports,
    );
  }
  
  Widget _buildUpdatedTopStatusBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 4,
          left: 12,
          right: 12,
          bottom: 4,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.6),
              Colors.transparent,
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              // ADMIN BADGE
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange, Colors.orange.shade600],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.3),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.admin_panel_settings, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'ADMIN',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 8),
              
              // CONNECTION STATUS
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: _backendConnected ? Colors.green : Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _backendConnected ? 'Online' : 'Offline',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 8),
              
              // NEW: Shortest route indicator
              if (_showOnlyShortestRoute)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, color: Colors.white, size: 10),
                      const SizedBox(width: 4),
                      Text(
                        'Shortest',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              
              // Reports indicator
              if (_userReports.isNotEmpty)
                Container(
                  margin: EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.report_problem, color: Colors.white, size: 10),
                      const SizedBox(width: 4),
                      Text(
                        '${_userReports.length}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              
              const Spacer(),
              
              // ACTION BUTTONS
              Row(
                children: [
                  _buildTopActionButton(
                    icon: _showSystemStats ? Icons.analytics : Icons.analytics_outlined,
                    onPressed: () {
                      setState(() {
                        _showSystemStats = !_showSystemStats;
                      });
                    },
                    isActive: _showSystemStats,
                  ),
                  
                  const SizedBox(width: 6),
                  
                  _buildTopActionButton(
                    icon: Icons.refresh,
                    onPressed: _refreshDashboard,
                  ),
                  
                  const SizedBox(width: 6),
                  
                  _buildTopActionButton(
                    icon: Icons.more_vert,
                    onPressed: _showMainMenu,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildTopActionButton({
    required IconData icon,
    required VoidCallback onPressed,
    bool isActive = false,
  }) {
    return Material(
      color: isActive ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.2),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(6),
          child: Icon(
            icon,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }
  
  Widget _buildCreateReportFAB() {
    double bottomPosition = 16;
    if (_showInfoPanel && (_allRoutes.isNotEmpty || _userReports.isNotEmpty)) {
      bottomPosition = _isInfoPanelExpanded ? 280 : 140;
    }
    
    return Positioned(
      bottom: bottomPosition,
      left: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            mini: true,
            heroTag: "info_toggle",
            backgroundColor: Colors.white,
            foregroundColor: Colors.orange,
            onPressed: () {
              setState(() {
                _showInfoPanel = !_showInfoPanel;
              });
              if (_showInfoPanel) {
                _panelController?.forward();
              } else {
                _panelController?.reverse();
              }
            },
            child: Icon(_showInfoPanel ? Icons.info : Icons.info_outline, size: 18),
          ),
          
          const SizedBox(height: 8),
          
          Container(
            height: 48,
            child: FloatingActionButton.extended(
              heroTag: "create_report",
              onPressed: _backendConnected ? () {
                setState(() {
                  _showCreateReportPanel = !_showCreateReportPanel;
                });
              } : null,
              backgroundColor: _backendConnected ? Colors.orange : Colors.grey,
              foregroundColor: Colors.white,
              icon: Icon(Icons.add_circle, size: 20),
              label: Text(
                'Report',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildUpdatedInfoPanel() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: _panelAnimation != null ? AnimatedBuilder(
        animation: _panelAnimation!,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, (1 - _panelAnimation!.value) * 200),
            child: child,
          );
        },
        child: _buildUpdatedInfoPanelContent(),
      ) : Container(),
    );
  }
  
  Widget _buildUpdatedInfoPanelContent() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 15,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // UPDATED PANEL HEADER
          GestureDetector(
            onTap: () {
              setState(() {
                _isInfoPanelExpanded = !_isInfoPanelExpanded;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Container(
                    width: 30,
                    height: 3,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(Icons.dashboard, color: Colors.white, size: 16),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Admin Dashboard',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${_getFilteredRoutes().length} supplies • ${_userReports.length} reports',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        _isInfoPanelExpanded ? Icons.expand_less : Icons.expand_more,
                        color: Colors.grey.shade600,
                        size: 18,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          if (_isInfoPanelExpanded) _buildUpdatedExpandedContent(),
        ],
      ),
    );
  }
  
  Widget _buildUpdatedExpandedContent() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        children: [
          Container(height: 1, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          
          // UPDATED QUICK STATS ROW
          Row(
            children: [
              Expanded(child: _buildCompactStat('Supplies', '${_getFilteredRoutes().length}', Colors.blue)),
              Expanded(child: _buildCompactStat('Reports', '${_userReports.length}', Colors.orange)),
              Expanded(child: _buildCompactStat('Unresolved', '${_userReports.where((r) => !r.isResolved).length}', Colors.red)),
              Expanded(child: _buildCompactStat('Status', _backendConnected ? 'Online' : 'Offline', _backendConnected ? Colors.green : Colors.red)),
            ],
          ),
          
          const SizedBox(height: 12),
          
          if (_allRoutes.isNotEmpty) _buildCompactShortestRouteInfo(),
          
          // Recent reports section
          if (_userReports.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildRecentReportsInfo(),
          ],
        ],
      ),
    );
  }
  
  Widget _buildCompactStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
  
  // ENHANCED: Compact shortest route info with button
  Widget _buildCompactShortestRouteInfo() {
    final shortestRoute = _allRoutes.first;
    
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade50, Colors.green.shade100.withOpacity(0.3)],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.star, color: Colors.green, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Shortest Route',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '${shortestRoute['distance']?.toStringAsFixed(1) ?? '?'} km • ${shortestRoute['travel_time'] ?? '?'}',
                      style: TextStyle(
                        color: Colors.green.shade600,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              
              // NEW: Simple toggle button
              GestureDetector(
                onTap: () {
                  setState(() {
                    _showOnlyShortestRoute = !_showOnlyShortestRoute;
                  });
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _showOnlyShortestRoute ? Colors.green : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _showOnlyShortestRoute ? Icons.visibility : Icons.visibility_off,
                        color: _showOnlyShortestRoute ? Colors.white : Colors.green,
                        size: 12,
                      ),
                      SizedBox(width: 4),
                      Text(
                        _showOnlyShortestRoute ? 'Only' : 'All',
                        style: TextStyle(
                          color: _showOnlyShortestRoute ? Colors.white : Colors.green,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  // ENHANCED: Recent reports info with click to show details
  Widget _buildRecentReportsInfo() {
    final recentReports = _userReports.take(3).toList();
    
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade50, Colors.orange.shade100.withOpacity(0.3)],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.report_problem, color: Colors.orange, size: 16),
              const SizedBox(width: 6),
              Text(
                'Recent Reports',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...recentReports.map((report) => GestureDetector(
            onTap: () => _showReportDetailsPopup(report), // NEW: Show popup on tap
            child: Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: report.isResolved ? Colors.green : Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      report.title,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.orange.shade700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.touch_app,
                    size: 12,
                    color: Colors.orange.shade400,
                  ),
                ],
              ),
            ),
          )).toList(),
        ],
      ),
    );
  }
  
  Widget _buildUpdatedSystemStatsPanel() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 60,
      right: 12,
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Colors.orange, size: 16),
                const SizedBox(width: 6),
                Text(
                  'System Stats',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _showSystemStats = false),
                  child: Icon(Icons.close, size: 14, color: Colors.grey),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            Container(height: 1, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            
            _buildStatRow('Backend', _backendConnected ? 'Connected' : 'Offline', _backendConnected ? Colors.green : Colors.red),
            _buildStatRow('Location', _currentLocation != null ? 'Active' : 'Inactive', _currentLocation != null ? Colors.green : Colors.orange),
            _buildStatRow('Routes', '${_getFilteredRoutes().length}/${_allRoutes.length}', Colors.blue),
            _buildStatRow('Data Points', '${(_csvDataInfo?['points'] as List<dynamic>?)?.length ?? 0}', Colors.purple),
            _buildStatRow('Total Reports', '${_userReports.length}', Colors.orange),
            _buildStatRow('Unresolved', '${_userReports.where((r) => !r.isResolved).length}', Colors.red),
            _buildStatRow('View Mode', _showOnlyShortestRoute ? 'Shortest' : 'All Routes', _showOnlyShortestRoute ? Colors.green : Colors.blue),
            _buildStatRow('Status', _isLoadingRoutes || _isLoadingReports ? 'Loading...' : 'Ready', _isLoadingRoutes || _isLoadingReports ? Colors.orange : Colors.green),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade700,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCreateReportPanel() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 60,
      bottom: _showInfoPanel ? 160 : 80,
      right: 12,
      child: Container(
        width: 260,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.orange.shade50,
              Colors.orange.shade100.withOpacity(0.3),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange, Colors.orange.shade600],
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Icons.admin_panel_settings, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Admin Report',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _showCreateReportPanel = false),
                  child: Icon(Icons.close, size: 14, color: Colors.grey),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.orange, Colors.orange.shade600],
                      ),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.3),
                          blurRadius: 10,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.add_circle,
                      size: 30,
                      color: Colors.white,
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  Text(
                    'Create Admin Report',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Text(
                    'Enhanced AI analysis with admin-level data access.',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 12,
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _backendConnected ? () {
                        setState(() => _showCreateReportPanel = false);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SimpleReportScreen(isAdmin: true),
                          ),
                        ).then((_) {
                          _loadUserReports();
                        });
                      } : null,
                      icon: Icon(Icons.admin_panel_settings, size: 16),
                      label: Text(
                        'Start Creating',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _backendConnected ? Colors.orange : Colors.grey,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              WaterDropLoader(message: 'Initializing Admin Dashboard...'),
              const SizedBox(height: 16),
              Text(
                _isLoadingReports 
                    ? 'Loading user reports and network data...'
                    : 'Loading water supply network and route data...',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
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
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 60,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                'Dashboard Error',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
                      ),
                      icon: Icon(Icons.arrow_back),
                      label: Text('Go Back'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _refreshDashboard,
                      icon: Icon(Icons.refresh),
                      label: Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
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
  
  void _showMainMenu() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Admin Menu',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.refresh, color: Colors.orange),
              title: Text('Refresh Dashboard'),
              subtitle: Text('Reload routes and reports'),
              onTap: () {
                Navigator.pop(context);
                _refreshDashboard();
              },
            ),
            ListTile(
              leading: Icon(Icons.analytics, color: Colors.blue),
              title: Text('System Statistics'),
              subtitle: Text('View detailed system info'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _showSystemStats = !_showSystemStats);
              },
            ),
            ListTile(
              leading: Icon(Icons.report_problem, color: Colors.purple),
              title: Text('View All Reports'),
              subtitle: Text('${_userReports.length} total reports'),
              onTap: () {
                Navigator.pop(context);
                _showReportsDialog();
              },
            ),
            ListTile(
              leading: Icon(Icons.logout, color: Colors.red),
              title: Text('Switch Role'),
              onTap: () {
                Navigator.pop(context);
                _showRoleSwitchDialog();
              },
            ),
          ],
        ),
      ),
    );
  }
  
  void _showReportsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.report_problem, color: Colors.orange),
            const SizedBox(width: 8),
            Text('User Reports'),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          height: 300,
          child: _userReports.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox, size: 60, color: Colors.grey.shade400),
                      SizedBox(height: 16),
                      Text('No reports found'),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _userReports.length,
                  itemBuilder: (context, index) {
                    final report = _userReports[index];
                    return Card(
                      margin: EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: report.isResolved ? Colors.green : Colors.red,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            report.isResolved ? Icons.check : Icons.warning,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          report.title,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'By: ${report.userName}',
                              style: TextStyle(fontSize: 12),
                            ),
                            Text(
                              report.description,
                              style: TextStyle(fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                        trailing: Text(
                          report.isResolved ? 'Resolved' : 'Open',
                          style: TextStyle(
                            color: report.isResolved ? Colors.green : Colors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _showReportDetailsPopup(report); // NEW: Show popup when tapped
                        },
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
          if (_userReports.isNotEmpty)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _loadUserReports();
              },
              child: Text('Refresh'),
            ),
        ],
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
          content: const Text(
            'Are you sure you want to leave the admin dashboard and return to role selection?',
          ),
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
                  MaterialPageRoute(
                    builder: (context) => const RoleSelectionScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Switch Role'),
            ),
          ],
        );
      },
    );
  }
}