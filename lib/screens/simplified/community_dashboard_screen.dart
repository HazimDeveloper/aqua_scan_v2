// lib/screens/simplified/community_dashboard_screen.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../models/report_model.dart';
import '../../services/database_service.dart';
import '../../services/location_service.dart';
import '../../utils/complaint_utils.dart';
import '../../widgets/admin/google_maps_widget.dart';

class CommunityDashboardScreen extends StatefulWidget {
  const CommunityDashboardScreen({Key? key}) : super(key: key);

  @override
  _CommunityDashboardScreenState createState() => _CommunityDashboardScreenState();
}

class _CommunityDashboardScreenState extends State<CommunityDashboardScreen> {
  bool _isLoading = true;
  List<ReportModel> _allReports = [];
  List<ReportModel> _filteredReports = [];
  GeoPoint? _currentLocation;
  String? _errorMessage;
  
  // Filter state
  ComplaintType? _selectedComplaintType;
  ComplaintStatus? _selectedStatus;
  bool _showResolvedReports = false;
  
  // Statistics
  Map<ComplaintType, int> _complaintTypeCounts = {};
  Map<ComplaintStatus, int> _statusCounts = {};
  Map<ComplaintPriority, int> _priorityCounts = {};
  
  late DatabaseService _databaseService;
  late LocationService _locationService;
  
  @override
  void initState() {
    super.initState();
    _databaseService = Provider.of<DatabaseService>(context, listen: false);
    _locationService = Provider.of<LocationService>(context, listen: false);
    _loadData();
  }
  
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // Get current location
      final position = await _locationService.getCurrentLocation();
      if (position != null) {
        setState(() {
          _currentLocation = GeoPoint(
            latitude: position.latitude,
            longitude: position.longitude,
          );
        });
      }
      
      // Load all reports
      final reports = await _databaseService.getReports().first;
      
      if (mounted) {
        setState(() {
          _allReports = reports;
          _applyFilters();
          _calculateStatistics();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading data: $e';
          _isLoading = false;
        });
      }
    }
  }
  
  void _applyFilters() {
    setState(() {
      _filteredReports = _allReports.where((report) {
        // Filter by resolved status
        if (!_showResolvedReports && report.status == ComplaintStatus.resolved) {
          return false;
        }
        
        // Filter by complaint type
        if (_selectedComplaintType != null && report.complaintType != _selectedComplaintType) {
          return false;
        }
        
        // Filter by status
        if (_selectedStatus != null && report.status != _selectedStatus) {
          return false;
        }
        
        return true;
      }).toList();
    });
  }
  
  void _calculateStatistics() {
    // Reset counters
    _complaintTypeCounts = {};
    _statusCounts = {};
    _priorityCounts = {};
    
    // Count occurrences
    for (final report in _allReports) {
      // Count by complaint type
      _complaintTypeCounts[report.complaintType] = 
          (_complaintTypeCounts[report.complaintType] ?? 0) + 1;
      
      // Count by status
      _statusCounts[report.status] = 
          (_statusCounts[report.status] ?? 0) + 1;
      
      // Count by priority
      _priorityCounts[report.priority] = 
          (_priorityCounts[report.priority] ?? 0) + 1;
    }
  }
  
  void _resetFilters() {
    setState(() {
      _selectedComplaintType = null;
      _selectedStatus = null;
      _showResolvedReports = false;
      _applyFilters();
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Dashboard'),
        backgroundColor: AppTheme.primaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh data',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : Column(
                  children: [
                    _buildFilterBar(),
                    _buildStatisticsSection(),
                    Expanded(
                      child: _buildMapSection(),
                    ),
                  ],
                ),
    );
  }
  
  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey.shade100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Filters:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Complaint Type Filter
                      _buildFilterChip(
                        label: _selectedComplaintType == null
                            ? 'All Types'
                            : ComplaintUtils.getComplaintTypeText(_selectedComplaintType!),
                        icon: Icons.filter_list,
                        onTap: _showComplaintTypeFilterDialog,
                        color: _selectedComplaintType == null
                            ? Colors.grey
                            : ComplaintUtils.getComplaintTypeColor(_selectedComplaintType!),
                      ),
                      
                      const SizedBox(width: 8),
                      
                      // Status Filter
                      _buildFilterChip(
                        label: _selectedStatus == null
                            ? 'All Statuses'
                            : ComplaintUtils.getComplaintStatusText(_selectedStatus!),
                        icon: Icons.check_circle_outline,
                        onTap: _showStatusFilterDialog,
                        color: _selectedStatus == null
                            ? Colors.grey
                            : ComplaintUtils.getComplaintStatusColor(_selectedStatus!),
                      ),
                      
                      const SizedBox(width: 8),
                      
                      // Show Resolved Toggle
                      FilterChip(
                        label: const Text('Show Resolved'),
                        selected: _showResolvedReports,
                        onSelected: (value) {
                          setState(() {
                            _showResolvedReports = value;
                            _applyFilters();
                          });
                        },
                        backgroundColor: Colors.grey.shade200,
                        selectedColor: Colors.green.shade100,
                        checkmarkColor: Colors.green,
                      ),
                      
                      const SizedBox(width: 8),
                      
                      // Reset Filters
                      ActionChip(
                        label: const Text('Reset'),
                        onPressed: _resetFilters,
                        avatar: const Icon(Icons.clear, size: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          // Results count
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Showing ${_filteredReports.length} of ${_allReports.length} reports',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: color)),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatisticsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Community Statistics',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Priority Stats
                _buildStatCard(
                  title: 'High Priority',
                  count: _priorityCounts[ComplaintPriority.high] ?? 0,
                  icon: Icons.priority_high,
                  color: Colors.red,
                ),
                _buildStatCard(
                  title: 'Medium Priority',
                  count: _priorityCounts[ComplaintPriority.medium] ?? 0,
                  icon: Icons.warning,
                  color: Colors.orange,
                ),
                _buildStatCard(
                  title: 'Low Priority',
                  count: _priorityCounts[ComplaintPriority.low] ?? 0,
                  icon: Icons.info,
                  color: Colors.blue,
                ),
                
                // Status Stats
                _buildStatCard(
                  title: 'New',
                  count: _statusCounts[ComplaintStatus.new_] ?? 0,
                  icon: Icons.fiber_new,
                  color: Colors.purple,
                ),
                _buildStatCard(
                  title: 'In Progress',
                  count: _statusCounts[ComplaintStatus.inProgress] ?? 0,
                  icon: Icons.pending,
                  color: Colors.amber,
                ),
                _buildStatCard(
                  title: 'Resolved',
                  count: _statusCounts[ComplaintStatus.resolved] ?? 0,
                  icon: Icons.check_circle,
                  color: Colors.green,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatCard({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(right: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        width: 120,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 4),
                Text(
                  title,
                  style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              count.toString(),
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMapSection() {
    return Stack(
      children: [
        GoogleMapsRouteWidget(
          reports: _filteredReports,
          currentLocation: _currentLocation,
          onReportTap: _showReportDetails,
        ),
        
        // Map overlay info
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Community Water Issues',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap on markers to view details. Use filters above to narrow down issues.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildLegendItem(
                        color: Colors.red,
                        label: 'High Priority',
                      ),
                      const SizedBox(width: 12),
                      _buildLegendItem(
                        color: Colors.orange,
                        label: 'Medium Priority',
                      ),
                      const SizedBox(width: 12),
                      _buildLegendItem(
                        color: Colors.blue,
                        label: 'Low Priority',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildLegendItem({required Color color, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12)),
      ],
    );
  }
  
  void _showComplaintTypeFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Complaint Type'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: const Text('All Types'),
                leading: const Icon(Icons.filter_list, color: Colors.grey),
                selected: _selectedComplaintType == null,
                onTap: () {
                  setState(() {
                    _selectedComplaintType = null;
                    _applyFilters();
                  });
                  Navigator.pop(context);
                },
              ),
              const Divider(),
              ...ComplaintUtils.getAllComplaintTypes().map((type) {
                final color = ComplaintUtils.getComplaintTypeColor(type);
                return ListTile(
                  title: Text(ComplaintUtils.getComplaintTypeText(type)),
                  leading: Icon(ComplaintUtils.getComplaintTypeIcon(type), color: color),
                  selected: _selectedComplaintType == type,
                  onTap: () {
                    setState(() {
                      _selectedComplaintType = type;
                      _applyFilters();
                    });
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
  
  void _showStatusFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Status'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: const Text('All Statuses'),
                leading: const Icon(Icons.filter_list, color: Colors.grey),
                selected: _selectedStatus == null,
                onTap: () {
                  setState(() {
                    _selectedStatus = null;
                    _applyFilters();
                  });
                  Navigator.pop(context);
                },
              ),
              const Divider(),
              ...[
                ComplaintStatus.new_,
                ComplaintStatus.inProgress,
                ComplaintStatus.resolved,
              ].map((status) {
                final color = ComplaintUtils.getComplaintStatusColor(status);
                return ListTile(
                  title: Text(ComplaintUtils.getComplaintStatusText(status)),
                  leading: Icon(ComplaintUtils.getComplaintStatusIcon(status), color: color),
                  selected: _selectedStatus == status,
                  onTap: () {
                    setState(() {
                      _selectedStatus = status;
                      _applyFilters();
                    });
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
  
  void _showReportDetails(ReportModel report) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Complaint Type and Priority
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: ComplaintUtils.getComplaintTypeColor(report.complaintType).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: ComplaintUtils.getComplaintTypeColor(report.complaintType).withOpacity(0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            ComplaintUtils.getComplaintTypeIcon(report.complaintType),
                            size: 16,
                            color: ComplaintUtils.getComplaintTypeColor(report.complaintType),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            ComplaintUtils.getComplaintTypeText(report.complaintType),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: ComplaintUtils.getComplaintTypeColor(report.complaintType),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: ComplaintUtils.getComplaintPriorityColor(report.priority).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: ComplaintUtils.getComplaintPriorityColor(report.priority).withOpacity(0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            ComplaintUtils.getComplaintPriorityIcon(report.priority),
                            size: 16,
                            color: ComplaintUtils.getComplaintPriorityColor(report.priority),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            ComplaintUtils.getComplaintPriorityText(report.priority),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: ComplaintUtils.getComplaintPriorityColor(report.priority),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: ComplaintUtils.getComplaintStatusColor(report.status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: ComplaintUtils.getComplaintStatusColor(report.status).withOpacity(0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            ComplaintUtils.getComplaintStatusIcon(report.status),
                            size: 16,
                            color: ComplaintUtils.getComplaintStatusColor(report.status),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            ComplaintUtils.getComplaintStatusText(report.status),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: ComplaintUtils.getComplaintStatusColor(report.status),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Title
                Text(
                  report.title,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                
                // Reporter and Date
                Row(
                  children: [
                    const Icon(Icons.person, size: 16, color: Colors.grey),
                    const SizedBox(width: 5),
                    Text(
                      'Reported by: ${report.userName}',
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                    ),
                    const Spacer(),
                    const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                    const SizedBox(width: 5),
                    Text(
                      'On: ${report.createdAt.day}/${report.createdAt.month}/${report.createdAt.year}',
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Description
                const Text(
                  'Description',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 5),
                Text(
                  report.description,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
                ),
                const SizedBox(height: 20),
                
                // Location
                const Text(
                  'Location',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 16, color: Colors.grey),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        report.address,
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Images
                if (report.imageUrls.isNotEmpty) ...[  
                  const Text(
                    'Images',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: report.imageUrls.length,
                      itemBuilder: (context, index) {
                        final imagePath = report.imageUrls[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: imagePath.startsWith('/')
                                ? Image.file(
                                    File(imagePath),
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                  )
                                : Image.network(
                                    imagePath,
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}