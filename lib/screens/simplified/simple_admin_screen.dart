// lib/screens/simplified/simple_admin_screen.dart - REDESIGNED: Report Details & Analysis Focus
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/report_model.dart';
import '../../services/database_service.dart';
import '../../services/location_service.dart';
import '../../services/api_service.dart';
import '../../screens/simplified/role_selection_screen.dart';
import '../../screens/simplified/simple_report_screen.dart';
import '../../screens/simplified/simple_map_screen.dart';
import '../../utils/water_quality_utils.dart';

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
  bool _backendConnected = false;
  
  List<ReportModel> _userReports = [];
  ReportModel? _selectedReport;
  String? _errorMessage;
  
  late LocationService _locationService;
  late ApiService _apiService;
  late DatabaseService _databaseService;
  
  // UI State
  int _currentTabIndex = 0;
  bool _showResolvedReports = false;
  
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
      
      // Test backend connection
      final isConnected = await _apiService.testBackendConnection();
      setState(() {
        _backendConnected = isConnected;
      });
      
      // Load reports
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
  
  Future<void> _loadUserReports() async {
    try {
      print('📋 Loading user reports...');
      
      final reports = _showResolvedReports 
          ? await _databaseService.getResolvedReportsList()
          : await _databaseService.getUnresolvedReportsList();
      
      if (mounted) {
        setState(() {
          _userReports = reports;
          _isLoading = false;
        });
        
        print('✅ Loaded ${_userReports.length} ${_showResolvedReports ? 'resolved' : 'unresolved'} reports');
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
            child: Icon(Icons.admin_panel_settings, color: Colors.white, size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Admin Dashboard', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                Text('Report Management & Analysis', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.9))),
              ],
            ),
          ),
        ],
      ),
      backgroundColor: Colors.orange,
      elevation: 0,
      actions: [
        // Backend Status
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          margin: EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: _backendConnected ? Colors.green : Colors.red,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_backendConnected ? Icons.cloud_done : Icons.cloud_off, color: Colors.white, size: 14),
              SizedBox(width: 4),
              Text(_backendConnected ? 'Online' : 'Offline', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        
        // Menu
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: Colors.white),
          onSelected: (value) {
            switch (value) {
              case 'refresh':
                _initializeAdminDashboard();
                break;
              case 'toggle_resolved':
                setState(() {
                  _showResolvedReports = !_showResolvedReports;
                });
                _loadUserReports();
                break;
              case 'map_view':
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SimpleMapScreen()),
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
            PopupMenuItem(value: 'refresh', child: Row(children: [Icon(Icons.refresh, color: Colors.orange, size: 16), SizedBox(width: 8), Text('Refresh')])),
            PopupMenuItem(value: 'toggle_resolved', child: Row(children: [Icon(_showResolvedReports ? Icons.visibility_off : Icons.visibility, color: Colors.blue, size: 16), SizedBox(width: 8), Text(_showResolvedReports ? 'Show Unresolved' : 'Show Resolved')])),
            PopupMenuItem(value: 'map_view', child: Row(children: [Icon(Icons.map, color: Colors.green, size: 16), SizedBox(width: 8), Text('View Map & Routes')])),
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
            colors: [Colors.orange, Colors.orange.shade600],
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
          colors: [Colors.orange.shade50, Colors.white],
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
                    color: Colors.orange.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                strokeWidth: 3,
              ),
            ),
            SizedBox(height: 24),
            Text('Loading Admin Dashboard...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.orange.shade800)),
            SizedBox(height: 8),
            Text('Fetching reports and analysis data', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMainContent() {
    if (_errorMessage != null) {
      return _buildErrorView();
    }
    
    return Column(
      children: [
        // Stats Header
        _buildStatsHeader(),
        
        // Content
        Expanded(
          child: _selectedReport != null 
              ? _buildReportDetailsView()
              : _buildReportsListView(),
        ),
      ],
    );
  }
  
  Widget _buildStatsHeader() {
    return Container(
      padding: EdgeInsets.all(16),
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
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Total Reports',
              '${_userReports.length}',
              Icons.report_problem,
              Colors.orange,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Status',
              _showResolvedReports ? 'Resolved' : 'Active',
              _showResolvedReports ? Icons.check_circle : Icons.pending,
              _showResolvedReports ? Colors.green : Colors.blue,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Backend',
              _backendConnected ? 'Connected' : 'Offline',
              _backendConnected ? Icons.cloud_done : Icons.cloud_off,
              _backendConnected ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 12, color: color.withOpacity(0.8)), textAlign: TextAlign.center),
        ],
      ),
    );
  }
  
  Widget _buildReportsListView() {
    if (_userReports.isEmpty) {
      return _buildEmptyReportsView();
    }
    
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _userReports.length,
      itemBuilder: (context, index) {
        final report = _userReports[index];
        return _buildReportCard(report, index);
      },
    );
  }
  
  Widget _buildReportCard(ReportModel report, int index) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedReport = report;
            });
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, WaterQualityUtils.getWaterQualityColor(report.waterQuality).withOpacity(0.05)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  children: [
                    // Quality Indicator
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            WaterQualityUtils.getWaterQualityColor(report.waterQuality),
                            WaterQualityUtils.getWaterQualityColor(report.waterQuality).withOpacity(0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: WaterQualityUtils.getWaterQualityColor(report.waterQuality).withOpacity(0.3),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        WaterQualityUtils.getWaterQualityIcon(report.waterQuality),
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    
                    SizedBox(width: 16),
                    
                    // Report Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  report.title,
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(width: 8),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: WaterQualityUtils.getWaterQualityColor(report.waterQuality),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  WaterQualityUtils.getWaterQualityText(report.waterQuality),
                                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.person, size: 14, color: Colors.grey.shade600),
                              SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  report.userName,
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                              SizedBox(width: 4),
                              Text(
                                '${report.createdAt.day}/${report.createdAt.month} at ${report.createdAt.hour}:${report.createdAt.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 12),
                
                // Description
                Text(
                  report.description,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.3),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                
                SizedBox(height: 12),
                
                // Footer Row
                Row(
                  children: [
                    // Location
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.location_on, size: 14, color: Colors.grey.shade500),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              report.address,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Images Count
                    if (report.imageUrls.isNotEmpty) ...[
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.image, size: 12, color: Colors.blue),
                            SizedBox(width: 4),
                            Text('${report.imageUrls.length}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue)),
                          ],
                        ),
                      ),
                      SizedBox(width: 8),
                    ],
                    
                    // Action Button
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.visibility, size: 12, color: Colors.orange),
                          SizedBox(width: 4),
                          Text('View Details', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange)),
                        ],
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
  
  Widget _buildReportDetailsView() {
    if (_selectedReport == null) return Container();
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back Button & Header
          _buildDetailsHeader(),
          
          SizedBox(height: 16),
          
          // Report Summary Card
          _buildReportSummaryCard(),
          
          SizedBox(height: 16),
          
          // Images Section
          if (_selectedReport!.imageUrls.isNotEmpty)
            _buildImagesSection(),
          
          SizedBox(height: 16),
          
          // Analysis Results Section
          _buildAnalysisSection(),
          
          SizedBox(height: 16),
          
          // Location & Reporter Info
          _buildLocationInfoSection(),
          
          SizedBox(height: 16),
          
          // Actions Section
          if (!_selectedReport!.isResolved)
            _buildActionsSection(),
        ],
      ),
    );
  }
  
  Widget _buildDetailsHeader() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            IconButton(
              onPressed: () {
                setState(() {
                  _selectedReport = null;
                });
              },
              icon: Icon(Icons.arrow_back, color: Colors.orange),
              style: IconButton.styleFrom(
                backgroundColor: Colors.orange.withOpacity(0.1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Report Analysis', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
                  Text('Detailed water quality assessment', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
            if (!_selectedReport!.isResolved)
              ElevatedButton.icon(
                onPressed: () => _resolveReport(_selectedReport!),
                icon: Icon(Icons.check_circle, size: 18),
                label: Text('Resolve'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildReportSummaryCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              WaterQualityUtils.getWaterQualityColor(_selectedReport!.waterQuality).withOpacity(0.1),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        WaterQualityUtils.getWaterQualityColor(_selectedReport!.waterQuality),
                        WaterQualityUtils.getWaterQualityColor(_selectedReport!.waterQuality).withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: WaterQualityUtils.getWaterQualityColor(_selectedReport!.waterQuality).withOpacity(0.3),
                        blurRadius: 12,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(
                    WaterQualityUtils.getWaterQualityIcon(_selectedReport!.waterQuality),
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                
                SizedBox(width: 16),
                
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedReport!.title,
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      SizedBox(height: 4),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: WaterQualityUtils.getWaterQualityColor(_selectedReport!.waterQuality),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          WaterQualityUtils.getWaterQualityText(_selectedReport!.waterQuality),
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 16),
            
            Text('Description', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
            SizedBox(height: 8),
            Text(
              _selectedReport!.description,
              style: TextStyle(fontSize: 16, color: Colors.black87, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildImagesSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.blue.shade50, Colors.white],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.image, color: Colors.white, size: 20),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Uploaded Images', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue.shade800)),
                      Text('${_selectedReport!.imageUrls.length} image${_selectedReport!.imageUrls.length == 1 ? '' : 's'} available for analysis', style: TextStyle(fontSize: 12, color: Colors.blue.shade600)),
                    ],
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 16),
            
            Container(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedReport!.imageUrls.length,
                itemBuilder: (context, index) {
                  final imagePath = _selectedReport!.imageUrls[index];
                  return Container(
                    width: 120,
                    margin: EdgeInsets.only(right: 12),
                    child: _buildImageCard(imagePath, index),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildImageCard(String imagePath, int index) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Colors.grey.shade50],
          ),
        ),
        child: Stack(
          children: [
            // Image Display
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                height: double.infinity,
                child: _buildImageWidget(imagePath),
              ),
            ),
            
            // Image Number Badge
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('${index + 1}', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildImageWidget(String imagePath) {
    try {
      if (imagePath.startsWith('/')) {
        final file = File(imagePath);
        return FutureBuilder<bool>(
          future: file.exists(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.blue), strokeWidth: 2));
            }
            
            if (snapshot.data == true) {
              return Image.file(file, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => _buildImageErrorWidget('Error loading image'));
            } else {
              return _buildImageErrorWidget('Image not found');
            }
          },
        );
      } else {
        return Image.network(
          imagePath,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes! : null,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                strokeWidth: 2,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) => _buildImageErrorWidget('Failed to load image'),
        );
      }
    } catch (e) {
      return _buildImageErrorWidget('Image error: $e');
    }
  }
  
  Widget _buildImageErrorWidget(String message) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image, color: Colors.grey.shade400, size: 32),
          SizedBox(height: 8),
          Text(message, style: TextStyle(color: Colors.grey.shade600, fontSize: 10), textAlign: TextAlign.center),
        ],
      ),
    );
  }
  
  Widget _buildAnalysisSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.purple.shade50, Colors.white],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.psychology, color: Colors.white, size: 20),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('AI Analysis Results', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.purple.shade800)),
                      Text('Water quality classification and confidence score', style: TextStyle(fontSize: 12, color: Colors.purple.shade600)),
                    ],
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 16),
            
            _buildAnalysisResultCard(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAnalysisResultCard() {
    // Mock analysis data (in real app, this would come from the report)
    final confidence = _getMockConfidenceScore(_selectedReport!.waterQuality);
    final classification = WaterQualityUtils.getWaterQualityText(_selectedReport!.waterQuality);
    final recommendation = _getRecommendation(_selectedReport!.waterQuality);
    
    return Column(
      children: [
        // Classification Result
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.purple.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Classification Result', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
              SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: WaterQualityUtils.getWaterQualityColor(_selectedReport!.waterQuality),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(classification, style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      WaterQualityUtils.getWaterQualityDescription(_selectedReport!.waterQuality),
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        SizedBox(height: 12),
        
        // Confidence Score
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.purple.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Confidence Score', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: confidence / 100,
                      backgroundColor: Colors.grey.shade300,
                      valueColor: AlwaysStoppedAnimation<Color>(_getConfidenceColor(confidence)),
                    ),
                  ),
                  SizedBox(width: 12),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getConfidenceColor(confidence),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('${confidence.toStringAsFixed(1)}%', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                WaterQualityUtils.getConfidenceLevelDescription(confidence),
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        
        SizedBox(height: 12),
        
        // Recommendation
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.purple.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Recommendation', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.lightbulb, color: Colors.amber, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(recommendation, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildLocationInfoSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.green.shade50, Colors.white],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.location_on, color: Colors.white, size: 20),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Location & Reporter Info', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                      Text('Geographic and user information', style: TextStyle(fontSize: 12, color: Colors.green.shade600)),
                    ],
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 16),
            
            _buildInfoRow('Reporter', _selectedReport!.userName, Icons.person),
            _buildInfoRow('Address', _selectedReport!.address, Icons.location_on),
            _buildInfoRow(
              'Reported At',
              '${_selectedReport!.createdAt.day}/${_selectedReport!.createdAt.month}/${_selectedReport!.createdAt.year} at ${_selectedReport!.createdAt.hour}:${_selectedReport!.createdAt.minute.toString().padLeft(2, '0')}',
              Icons.access_time,
            ),
            _buildInfoRow(
              'Coordinates',
              '${_selectedReport!.location.latitude.toStringAsFixed(6)}, ${_selectedReport!.location.longitude.toStringAsFixed(6)}',
              Icons.my_location,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.green.shade600),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 14, color: Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildActionsSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.orange.shade50, Colors.white],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.settings, color: Colors.white, size: 20),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Admin Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
                      Text('Manage this report', style: TextStyle(fontSize: 12, color: Colors.orange.shade600)),
                    ],
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _resolveReport(_selectedReport!),
                    icon: Icon(Icons.check_circle, size: 18),
                    label: Text('Mark as Resolved'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => SimpleMapScreen()),
                      );
                    },
                    icon: Icon(Icons.map, size: 18),
                    label: Text('View on Map'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildEmptyReportsView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.report_outlined, size: 64, color: Colors.grey.shade400),
          ),
          SizedBox(height: 24),
          Text(
            _showResolvedReports ? 'No Resolved Reports' : 'No Active Reports',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
          ),
          SizedBox(height: 12),
          Text(
            _showResolvedReports 
                ? 'No resolved water quality reports found.\nReports will appear here once marked as resolved.'
                : 'No active water quality reports found.\nReports will appear here when users submit them.',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14, height: 1.4),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _showResolvedReports = !_showResolvedReports;
              });
              _loadUserReports();
            },
            icon: Icon(_showResolvedReports ? Icons.pending : Icons.check_circle),
            label: Text(_showResolvedReports ? 'View Active Reports' : 'View Resolved Reports'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
          SizedBox(height: 16),
          Text('Error Loading Dashboard', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text(_errorMessage ?? 'Unknown error occurred', style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _initializeAdminDashboard,
            icon: Icon(Icons.refresh),
            label: Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
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
        // Map View FAB
        FloatingActionButton(
          heroTag: "map_view",
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => SimpleMapScreen()),
            );
          },
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          child: Icon(Icons.map),
          tooltip: 'View Routes Map',
        ),
        
        SizedBox(height: 12),
        
        // Add Report FAB
        FloatingActionButton(
          heroTag: "add_report",
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => SimpleReportScreen(isAdmin: true)),
            );
          },
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          child: Icon(Icons.add),
          tooltip: 'Add Report',
        ),
        
        SizedBox(height: 12),
        
        // Refresh FAB
        FloatingActionButton(
          heroTag: "refresh",
          onPressed: _isLoading ? null : _initializeAdminDashboard,
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          child: _isLoading 
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : Icon(Icons.refresh),
          tooltip: 'Refresh Data',
        ),
      ],
    );
  }
  
  Future<void> _resolveReport(ReportModel report) async {
    try {
      await _databaseService.resolveReport(report.id);
      
      setState(() {
        _userReports.removeWhere((r) => r.id == report.id);
        if (_selectedReport?.id == report.id) {
          _selectedReport = null;
        }
      });
      
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
  
  // Helper Methods
  double _getMockConfidenceScore(WaterQualityState quality) {
    switch (quality) {
      case WaterQualityState.optimum: return 92.5;
      case WaterQualityState.highPh: return 87.3;
      case WaterQualityState.lowPh: return 84.7;
      case WaterQualityState.highPhTemp: return 91.2;
      case WaterQualityState.lowTemp: return 89.8;
      case WaterQualityState.lowTempHighPh: return 86.4;
      case WaterQualityState.unknown:
      default: return 78.9;
    }
  }
  
  Color _getConfidenceColor(double confidence) {
    if (confidence >= 90) return Colors.green;
    if (confidence >= 80) return Colors.lightGreen;
    if (confidence >= 70) return Colors.orange;
    return Colors.red;
  }
  
  String _getRecommendation(WaterQualityState quality) {
    switch (quality) {
      case WaterQualityState.optimum: return 'Water quality is within acceptable parameters';
      case WaterQualityState.highPh: return 'Consider pH reduction treatment';
      case WaterQualityState.lowPh: return 'pH neutralization recommended';
      case WaterQualityState.highPhTemp: return 'Immediate intervention required';
      case WaterQualityState.lowTemp: return 'Monitor temperature fluctuations';
      case WaterQualityState.lowTempHighPh: return 'Multiple parameter adjustment needed';
      case WaterQualityState.unknown:
      default: return 'Further testing required';
    }
  }
}