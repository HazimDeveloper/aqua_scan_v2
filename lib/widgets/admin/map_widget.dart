// lib/widgets/admin/map_widget.dart - FIXED VERSION
import 'dart:math' as Math show cos, sin, atan2, asin;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../config/theme.dart';
import '../../models/report_model.dart';
import '../../models/report_model.dart' as route_model;
import '../../models/route_model.dart' as route_model;

class RouteMapWidget extends StatefulWidget {
  final route_model.RouteModel? routeModel;
  final List<ReportModel> reports;
  final List<ReportModel> selectedReports;
  final GeoPoint? currentLocation;
  final Function(ReportModel)? onReportTap;
  final bool showSelectionStatus;
  
  // Enhanced multiple routes support
  final List<Map<String, dynamic>>? multipleRoutes;
  final int? shortestRouteIndex;
  final List<Map<String, dynamic>>? waterSupplyPoints;
  final bool showMultipleRoutes;
  final Function(int)? onRouteSelected;

  const RouteMapWidget({
    Key? key,
    this.routeModel,
    required this.reports,
    this.selectedReports = const [],
    this.currentLocation,
    this.onReportTap,
    this.showSelectionStatus = true,
    this.multipleRoutes,
    this.shortestRouteIndex,
    this.waterSupplyPoints,
    this.showMultipleRoutes = false,
    this.onRouteSelected,
  }) : super(key: key);

  @override
  _RouteMapWidgetState createState() => _RouteMapWidgetState();
}

class _RouteMapWidgetState extends State<RouteMapWidget> with TickerProviderStateMixin {
  late MapController _mapController;
  ReportModel? _selectedReportForInfo;
  bool _isInfoWindowVisible = false;
  int? _selectedRouteIndex;
  double _currentZoom = 12.0;
  
  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _routeAnimationController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _routeAnimation;
  
  // UI State
  bool _showRoutesList = true;
  bool _sortByDistance = true;
  
  // Routes sorted by distance (nearest first)
  List<Map<String, dynamic>> _sortedRoutes = [];
  
  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    
    // Initialize animations
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _routeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _routeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _routeAnimationController, curve: Curves.easeInOut),
    );
    
    _initializeRoutes();
    
    // Start animation
    if (widget.showMultipleRoutes && widget.multipleRoutes?.isNotEmpty == true) {
      _routeAnimationController.forward();
    }
  }
  
  @override
  void didUpdateWidget(RouteMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.multipleRoutes != widget.multipleRoutes) {
      _initializeRoutes();
      
      if (widget.showMultipleRoutes && widget.multipleRoutes?.isNotEmpty == true) {
        _routeAnimationController.reset();
        _routeAnimationController.forward();
      }
    }
  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    _routeAnimationController.dispose();
    super.dispose();
  }
  
  void _initializeRoutes() {
    if (widget.multipleRoutes != null) {
      _sortedRoutes = List<Map<String, dynamic>>.from(widget.multipleRoutes!);
      
      // Sort by distance (nearest first)
      _sortedRoutes.sort((a, b) {
        final distanceA = (a['distance'] as num?)?.toDouble() ?? double.infinity;
        final distanceB = (b['distance'] as num?)?.toDouble() ?? double.infinity;
        return distanceA.compareTo(distanceB);
      });
      
      print('🗺️ Routes sorted by distance: ${_sortedRoutes.length} routes');
      for (int i = 0; i < _sortedRoutes.length; i++) {
        final route = _sortedRoutes[i];
        print('   ${i + 1}. ${route['destination_name']} - ${route['distance']?.toStringAsFixed(1)}km');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // FIXED: Show different UI based on reports availability
    final hasReports = widget.reports.isNotEmpty;
    
    if (widget.currentLocation == null && !hasReports && 
        (widget.waterSupplyPoints?.isEmpty ?? true)) {
      return _buildNoDataView();
    }

    return Stack(
      children: [
        // Main map
        _buildMainMap(),
        
        // Top info panel - different content based on reports
        _buildTopInfoPanel(hasReports),
        
        // Routes list sidebar (only if has water supplies)
        if (widget.multipleRoutes?.isNotEmpty == true)
          _buildRoutesListSidebar(),
        
        // Map controls
        _buildMapControls(),
        
        // Selected route details
        if (_selectedRouteIndex != null && _sortedRoutes.isNotEmpty)
          _buildSelectedRouteDetails(),
        
        // Report info (only if reports exist)
        if (hasReports && _isInfoWindowVisible && _selectedReportForInfo != null)
          _buildReportInfoCard(_selectedReportForInfo!),
      ],
    );
  }
  
  Widget _buildNoDataView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_off, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text("No data available", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text("No location data or water supplies found", style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
        ],
      ),
    );
  }
  
  Widget _buildMainMap() {
    final currentLatLng = LatLng(
      widget.currentLocation?.latitude ?? 3.1390,
      widget.currentLocation?.longitude ?? 101.6869,
    );

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: currentLatLng,
        initialZoom: 12.0,
        minZoom: 4,
        maxZoom: 18,
        onTap: (_, __) {
          setState(() {
            _isInfoWindowVisible = false;
            _selectedReportForInfo = null;
            _selectedRouteIndex = null;
          });
        },
        onMapReady: () {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final bounds = _calculateMapBounds();
            if (bounds != null) {
              _mapController.fitCamera(
                CameraFit.bounds(
                  bounds: bounds,
                  padding: const EdgeInsets.all(50.0),
                ),
              );
            }
          });
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c'],
          userAgentPackageName: 'com.example.water_watch',
        ),
        
        // Routes polylines
        PolylineLayer(polylines: _buildRoutePolylines()),
        
        // Markers
        MarkerLayer(markers: _buildAllMarkers()),
      ],
    );
  }
  
  // FIXED: Top info panel with different content
  Widget _buildTopInfoPanel(bool hasReports) {
    return Positioned(
      top: 16,
      left: 16,
      right: _showRoutesList ? 320 : 16,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: hasReports ? Colors.orange : Colors.blue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      hasReports ? Icons.admin_panel_settings : Icons.water_drop,
                      color: Colors.white, 
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasReports ? 'Admin Dashboard' : 'Water Supply Network',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          hasReports 
                              ? '${widget.multipleRoutes?.length ?? 0} supplies • ${widget.reports.length} reports'
                              : '${widget.multipleRoutes?.length ?? 0} water supply points available',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  // Toggle routes list
                  if (widget.multipleRoutes?.isNotEmpty == true)
                    IconButton(
                      icon: Icon(_showRoutesList ? Icons.list : Icons.list_outlined),
                      onPressed: () {
                        setState(() {
                          _showRoutesList = !_showRoutesList;
                        });
                      },
                      tooltip: _showRoutesList ? 'Hide Routes List' : 'Show Routes List',
                    ),
                ],
              ),
              
              if (_sortedRoutes.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                
                // Quick stats row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildQuickStat('Nearest', '${_sortedRoutes.first['distance']?.toStringAsFixed(1) ?? '?'}km', Colors.green),
                    _buildQuickStat('Furthest', '${_sortedRoutes.last['distance']?.toStringAsFixed(1) ?? '?'}km', Colors.red),
                    _buildQuickStat('Total', '${_sortedRoutes.length}', Colors.blue),
                    if (hasReports)
                      _buildQuickStat('Reports', '${widget.reports.length}', Colors.orange),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildQuickStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
        ),
      ],
    );
  }
  
  // FIXED: Routes list sidebar sorted by distance
  Widget _buildRoutesListSidebar() {
    if (!_showRoutesList || _sortedRoutes.isEmpty) return Container();
    
    return Positioned(
      top: 16,
      right: 16,
      bottom: 16,
      width: 300,
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Icon(Icons.route, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Water Supply Routes',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ),
                  Text(
                    '${_sortedRoutes.length}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade600,
                    ),
                  ),
                ],
              ),
            ),
            
            // Routes list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: _sortedRoutes.length,
                itemBuilder: (context, index) {
                  final route = _sortedRoutes[index];
                  final isSelected = _selectedRouteIndex == index;
                  final isNearest = index == 0;
                  
                  return _buildRouteListItem(route, index, isSelected, isNearest);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildRouteListItem(Map<String, dynamic> route, int index, bool isSelected, bool isNearest) {
    final distance = route['distance']?.toStringAsFixed(1) ?? '?';
    final travelTime = route['travel_time'] ?? route['estimated_time'] ?? '?';
    final destination = route['destination_details'] as Map<String, dynamic>? ?? {};
    final destinationName = destination['street_name'] ?? route['destination_name'] ?? 'Water Supply ${index + 1}';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Card(
        elevation: isSelected ? 4 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isSelected ? Colors.blue : (isNearest ? Colors.green : Colors.transparent),
            width: isSelected ? 2 : (isNearest ? 1 : 0),
          ),
        ),
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedRouteIndex = _selectedRouteIndex == index ? null : index;
            });
            
            if (widget.onRouteSelected != null) {
              widget.onRouteSelected!(index);
            }
            
            // Focus map on selected route
            _focusOnRoute(route);
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
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
                        color: isNearest ? Colors.green : Colors.blue,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 8),
                    
                    // Special badges
                    if (isNearest) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'NEAREST',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    
                    if (isSelected) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'SELECTED',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                    
                    const Spacer(),
                    
                    // Distance
                    Text(
                      '${distance}km',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isNearest ? Colors.green : Colors.blue,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                // Destination name
                Text(
                  destinationName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                
                const SizedBox(height: 4),
                
                // Travel time
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      travelTime,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                
                // Address (if available)
                if (destination['address'] != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          destination['address'],
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  void _focusOnRoute(Map<String, dynamic> route) {
    final destination = route['destination_details'] as Map<String, dynamic>? ?? {};
    final lat = (destination['latitude'] as num?)?.toDouble();
    final lng = (destination['longitude'] as num?)?.toDouble();
    
    if (lat != null && lng != null) {
      _mapController.move(LatLng(lat, lng), 15.0);
    }
  }
  
  List<Polyline> _buildRoutePolylines() {
    final polylines = <Polyline>[];
    
    if (widget.showMultipleRoutes && _sortedRoutes.isNotEmpty) {
      for (int i = 0; i < _sortedRoutes.length; i++) {
        final route = _sortedRoutes[i];
        final isSelected = _selectedRouteIndex == i;
        final isNearest = i == 0;
        
        if (route.containsKey('polyline_points') && route['polyline_points'] is List) {
          final polylineData = route['polyline_points'] as List<dynamic>;
          
          final points = polylineData.map((point) {
            if (point is Map<String, dynamic>) {
              final lat = (point['latitude'] as num?)?.toDouble() ?? 0.0;
              final lng = (point['longitude'] as num?)?.toDouble() ?? 0.0;
              return LatLng(lat, lng);
            }
            return null;
          }).where((point) => point != null && point.latitude != 0.0 && point.longitude != 0.0)
           .cast<LatLng>()
           .toList();
          
          if (points.length >= 2) {
            Color routeColor;
            double strokeWidth;
            double opacity;
            
            if (isNearest) {
              routeColor = Colors.green;
              strokeWidth = 6.0;
              opacity = 0.9;
            } else if (isSelected) {
              routeColor = Colors.blue;
              strokeWidth = 5.0;
              opacity = 0.8;
            } else {
              routeColor = _getRouteColorByIndex(i);
              strokeWidth = 3.0;
              opacity = 0.6;
            }
            
            // Main route line
            polylines.add(
              Polyline(
                points: points,
                color: routeColor.withOpacity(opacity),
                strokeWidth: strokeWidth,
              ),
            );
            
            // Shadow effect for nearest route
            if (isNearest) {
              polylines.add(
                Polyline(
                  points: points,
                  color: Colors.green.withOpacity(0.3),
                  strokeWidth: strokeWidth + 3,
                ),
              );
            }
          }
        }
      }
    }
    
    return polylines;
  }
  
  List<Marker> _buildAllMarkers() {
    final markers = <Marker>[];
    
    // Current location marker
    if (widget.currentLocation != null) {
      markers.add(_buildCurrentLocationMarker());
    }
    
    // Water supply markers
    if (_sortedRoutes.isNotEmpty) {
      for (int i = 0; i < _sortedRoutes.length; i++) {
        final route = _sortedRoutes[i];
        markers.add(_buildWaterSupplyMarker(route, i));
      }
    }
    
    // Report markers (only if reports exist)
    if (widget.reports.isNotEmpty) {
      for (final report in widget.reports) {
        markers.add(_buildReportMarker(report));
      }
    }
    
    return markers;
  }
  
  Marker _buildCurrentLocationMarker() {
    return Marker(
      point: LatLng(widget.currentLocation!.latitude, widget.currentLocation!.longitude),
      width: 120,
      height: 60,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 30 + (10 * _pulseAnimation.value),
                height: 30 + (10 * _pulseAnimation.value),
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.4),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.my_location,
                  color: Colors.white,
                  size: 16 + (4 * _pulseAnimation.value),
                ),
              ),
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green, width: 2),
                ),
                child: const Text(
                  "Your Location",
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
  
  Marker _buildWaterSupplyMarker(Map<String, dynamic> route, int index) {
    final destination = route['destination_details'] as Map<String, dynamic>? ?? {};
    final lat = (destination['latitude'] as num?)?.toDouble() ?? 0.0;
    final lng = (destination['longitude'] as num?)?.toDouble() ?? 0.0;
    
    final isSelected = _selectedRouteIndex == index;
    final isNearest = index == 0;
    
    return Marker(
      point: LatLng(lat, lng),
      width: 120,
      height: 80,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedRouteIndex = _selectedRouteIndex == index ? null : index;
          });
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                Container(
                  width: isSelected ? 50 : (isNearest ? 45 : 40),
                  height: isSelected ? 50 : (isNearest ? 45 : 40),
                  decoration: BoxDecoration(
                    color: isNearest ? Colors.green : (isSelected ? Colors.blue : _getRouteColorByIndex(index)),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: (isNearest ? Colors.green : Colors.blue).withOpacity(0.4),
                        blurRadius: isSelected ? 12 : 8,
                        offset: Offset(0, isSelected ? 4 : 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    isNearest ? Icons.star : Icons.water_drop,
                    color: Colors.white,
                    size: isSelected ? 28 : (isNearest ? 25 : 22),
                  ),
                ),
                
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 4),
            
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isNearest ? Colors.green : (isSelected ? Colors.blue : Colors.white),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isNearest ? Colors.green : (isSelected ? Colors.blue : Colors.grey.shade300),
                ),
              ),
              child: Text(
                isNearest ? "NEAREST" : "${route['distance']?.toStringAsFixed(1) ?? '?'}km",
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: isNearest || isSelected ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Marker _buildReportMarker(ReportModel report) {
    final isSelected = widget.selectedReports.any((r) => r.id == report.id);
    
    return Marker(
      point: LatLng(report.location.latitude, report.location.longitude),
      width: 60,
      height: 60,
      child: GestureDetector(
        onTap: () {
          if (widget.onReportTap != null) {
            widget.onReportTap!(report);
          } else {
            setState(() {
              _selectedReportForInfo = report;
              _isInfoWindowVisible = true;
            });
          }
        },
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor : _getWaterQualityColor(report.waterQuality),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(
            isSelected ? Icons.check : Icons.warning,
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }
  
  Widget _buildMapControls() {
    return Positioned(
      right: _showRoutesList ? 320 : 16,
      bottom: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1);
                  },
                  tooltip: 'Zoom In',
                ),
                const Divider(height: 1),
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: () {
                    _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1);
                  },
                  tooltip: 'Zoom Out',
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          FloatingActionButton(
            mini: true,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            onPressed: () {
              final bounds = _calculateMapBounds();
              if (bounds != null) {
                _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50.0)));
              }
            },
            child: const Icon(Icons.fit_screen),
            tooltip: 'Fit all markers',
          ),
        ],
      ),
    );
  }
  
  Widget _buildSelectedRouteDetails() {
    if (_selectedRouteIndex == null || _selectedRouteIndex! >= _sortedRoutes.length) {
      return Container();
    }
    
    final route = _sortedRoutes[_selectedRouteIndex!];
    final destination = route['destination_details'] as Map<String, dynamic>? ?? {};
    final isNearest = _selectedRouteIndex == 0;
    
    return Positioned(
      bottom: 16,
      left: 16,
      right: _showRoutesList ? 320 : 16,
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isNearest ? Colors.green : Colors.blue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isNearest ? Icons.star : Icons.route,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isNearest ? 'Nearest Route' : 'Route ${_selectedRouteIndex! + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isNearest ? Colors.green : Colors.blue,
                          ),
                        ),
                        Text(
                          destination['street_name'] ?? route['destination_name'] ?? 'Water Supply Point',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        _selectedRouteIndex = null;
                      });
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildDetailStat('Distance', '${route['distance']?.toStringAsFixed(1) ?? '?'} km', Icons.straighten),
                  _buildDetailStat('Time', route['travel_time'] ?? '?', Icons.access_time),
                  _buildDetailStat('Rank', '${_selectedRouteIndex! + 1}/${_sortedRoutes.length}', Icons.numbers),
                ],
              ),
              
              if (destination['address'] != null) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        destination['address'],
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildDetailStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 16, color: Colors.blue),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
        ),
      ],
    );
  }
  
  Widget _buildReportInfoCard(ReportModel report) {
    return Positioned(
      left: 16,
      right: _showRoutesList ? 320 : 16,
      bottom: 16,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getWaterQualityColor(report.waterQuality).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.water_drop, 
                      color: _getWaterQualityColor(report.waterQuality),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      report.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        _isInfoWindowVisible = false;
                        _selectedReportForInfo = null;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                report.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      report.address,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
  
  // Helper methods
  Color _getRouteColorByIndex(int index) {
    final colors = [
      Colors.red.shade600,
      Colors.blue.shade600, 
      Colors.green.shade600,
      Colors.orange.shade600,
      Colors.purple.shade600,
      Colors.teal.shade600,
      Colors.pink.shade600,
    ];
    return colors[index % colors.length];
  }
  
  Color _getWaterQualityColor(WaterQualityState quality) {
    switch (quality) {
      case WaterQualityState.optimum: return Colors.blue;
      case WaterQualityState.lowTemp: return Colors.green;
      case WaterQualityState.highPh:
      case WaterQualityState.lowPh: return Colors.orange;
      case WaterQualityState.highPhTemp: return Colors.red;
      case WaterQualityState.lowTempHighPh: return Colors.purple;
      case WaterQualityState.unknown:
      default: return Colors.grey;
    }
  }
  
  LatLngBounds? _calculateMapBounds() {
    final points = <LatLng>[];
    
    if (widget.currentLocation != null) {
      points.add(LatLng(widget.currentLocation!.latitude, widget.currentLocation!.longitude));
    }
    
    // Add water supply points
    for (final route in _sortedRoutes) {
      final destination = route['destination_details'] as Map<String, dynamic>? ?? {};
      final lat = (destination['latitude'] as num?)?.toDouble();
      final lng = (destination['longitude'] as num?)?.toDouble();
      
      if (lat != null && lng != null) {
        points.add(LatLng(lat, lng));
      }
    }
    
    // Add report points
    for (final report in widget.reports) {
      points.add(LatLng(report.location.latitude, report.location.longitude));
    }
    
    if (points.isEmpty) {
      return null;
    } else if (points.length == 1) {
      final point = points.first;
      const delta = 0.01;
      return LatLngBounds(
        LatLng(point.latitude - delta, point.longitude - delta),
        LatLng(point.latitude + delta, point.longitude + delta),
      );
    }
    
    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    
    for (final point in points) {
      minLat = point.latitude < minLat ? point.latitude : minLat;
      maxLat = point.latitude > maxLat ? point.latitude : maxLat;
      minLng = point.longitude < minLng ? point.longitude : minLng;
      maxLng = point.longitude > maxLng ? point.longitude : maxLng;
    }
    
    return LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));
  }
}