// lib/widgets/simplified/openstreet_map_widget.dart - ENHANCED: Better Empty Reports Handling
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../config/theme.dart';
import '../../models/report_model.dart';
import 'dart:math' as math;

class OpenStreetMapWidget extends StatefulWidget {
  final GeoPoint currentLocation;
  final List<Map<String, dynamic>> polylineRoutes;
  final List<ReportModel> userReports;
  final bool isLoading;

  const OpenStreetMapWidget({
    Key? key,
    required this.currentLocation,
    required this.polylineRoutes,
    this.userReports = const [],
    this.isLoading = false,
  }) : super(key: key);

  @override
  _OpenStreetMapWidgetState createState() => _OpenStreetMapWidgetState();
}

class _OpenStreetMapWidgetState extends State<OpenStreetMapWidget> {
  late MapController _mapController;
  bool _showRouteInfo = true;
  bool _showAllMarkers = false;
  bool _showRouteLines = true;
  bool _showReportConnections = true;
  int? _selectedRoute;
  ReportModel? _selectedReport;
  double _currentZoom = 12.0;
  
  // ENHANCED: Better state management
  int _maxVisibleRoutes = 15;
  bool _isMinimized = false;
  String _mapMode = 'auto'; // auto, water_only, reports_focus

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    
    // ENHANCED: Auto-detect map mode
    _mapMode = widget.userReports.isEmpty ? 'water_only' : 'auto';
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fitMapToContent();
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  // ENHANCED: Smart map fitting based on content
  void _fitMapToContent() {
    try {
      if (widget.polylineRoutes.isEmpty && widget.userReports.isEmpty) {
        // Only current location
        _mapController.move(
          LatLng(widget.currentLocation.latitude, widget.currentLocation.longitude),
          13.0,
        );
        return;
      }
      
      final bounds = _calculateSmartBounds();
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: EdgeInsets.all(_mapMode == 'water_only' ? 30 : 50),
        ),
      );
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _currentZoom = _mapController.camera.zoom;
          _maxVisibleRoutes = _currentZoom >= 15 ? 25 : (_currentZoom >= 13 ? 20 : 15);
        });
      });
    } catch (e) {
      print('Error fitting map: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildMainMap(),
        if (widget.isLoading) _buildLoadingOverlay(),
        if (!widget.isLoading && widget.polylineRoutes.isEmpty && widget.userReports.isEmpty) 
          _buildEmptyOverlay(),
        if (widget.polylineRoutes.isNotEmpty || widget.userReports.isNotEmpty) 
          _buildEnhancedHeader(),
        if (widget.polylineRoutes.isNotEmpty || widget.userReports.isNotEmpty) 
          _buildControlPanel(),
        if (_showRouteInfo && (widget.polylineRoutes.isNotEmpty || widget.userReports.isNotEmpty)) 
          _buildInfoPanel(),
      ],
    );
  }

  Widget _buildMainMap() {
    final currentLatLng = LatLng(
      widget.currentLocation.latitude,
      widget.currentLocation.longitude,
    );

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: currentLatLng,
        initialZoom: 12.0,
        minZoom: 8.0,
        maxZoom: 18.0,
        onMapEvent: (MapEvent mapEvent) {
          if (mapEvent is MapEventMove) {
            setState(() {
              _currentZoom = mapEvent.camera.zoom;
              _maxVisibleRoutes = _currentZoom >= 15 ? 25 : (_currentZoom >= 13 ? 20 : 15);
            });
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.aquascan',
          maxZoom: 18,
        ),
        if (_showRouteLines && widget.polylineRoutes.isNotEmpty)
          PolylineLayer(polylines: _buildRoutePolylines()),
        if (_showReportConnections && widget.userReports.isNotEmpty)
          PolylineLayer(polylines: _buildReportConnectionLines()),
        MarkerLayer(markers: _buildAllMarkers()),
      ],
    );
  }

  // ENHANCED: Build route polylines with better visibility
  List<Polyline> _buildRoutePolylines() {
    List<Polyline> polylines = [];
    
    final routesToShow = _selectedRoute != null 
        ? [_selectedRoute!] 
        : List.generate(
            math.min(_showAllMarkers ? widget.polylineRoutes.length : _maxVisibleRoutes, widget.polylineRoutes.length),
            (index) => index,
          );
    
    for (int index in routesToShow) {
      if (index < widget.polylineRoutes.length) {
        final route = widget.polylineRoutes[index];
        final polylinePoints = route['polyline_points'] as List<dynamic>? ?? [];
        
        if (polylinePoints.length >= 2) {
          List<LatLng> latLngPoints = [];
          
          for (final point in polylinePoints) {
            if (point is Map<String, dynamic>) {
              final lat = (point['latitude'] as num?)?.toDouble();
              final lng = (point['longitude'] as num?)?.toDouble();
              
              if (lat != null && lng != null) {
                latLngPoints.add(LatLng(lat, lng));
              }
            }
          }
          
          if (latLngPoints.length >= 2) {
            final isSelected = _selectedRoute == index;
            final isTop3 = index < 3;
            final routeColor = _getRouteColor(index);
            
            // ENHANCED: Better line styling
            polylines.add(
              Polyline(
                points: latLngPoints,
                strokeWidth: isSelected ? 7.0 : (isTop3 ? 5.0 : 3.5),
                color: routeColor.withOpacity(isSelected ? 1.0 : (isTop3 ? 0.8 : 0.6)),
                borderStrokeWidth: isSelected ? 9.0 : (isTop3 ? 6.0 : 4.5),
                borderColor: routeColor.withOpacity(0.3),
              ),
            );
          }
        }
      }
    }
    
    return polylines;
  }

  // ENHANCED: Smart report connection lines
  List<Polyline> _buildReportConnectionLines() {
    List<Polyline> polylines = [];
    
    if (widget.userReports.isEmpty || widget.polylineRoutes.isEmpty) {
      return polylines;
    }
    
    print('🔗 Building connection lines for ${widget.userReports.length} reports...');
    
    for (int reportIndex = 0; reportIndex < widget.userReports.length; reportIndex++) {
      final report = widget.userReports[reportIndex];
      
      // Find closest water supplies for this report
      final nearestSupplies = _findNearestWaterSupplies(report, maxConnections: _mapMode == 'water_only' ? 1 : 3);
      
      for (int connectionIndex = 0; connectionIndex < nearestSupplies.length; connectionIndex++) {
        final waterSupply = nearestSupplies[connectionIndex];
        
        final reportLatLng = LatLng(report.location.latitude, report.location.longitude);
        final waterSupplyLatLng = LatLng(
          (waterSupply['latitude'] as num).toDouble(),
          (waterSupply['longitude'] as num).toDouble(),
        );
        
        Color lineColor = _getWaterQualityColor(report.waterQuality);
        bool isSelected = _selectedReport?.id == report.id;
        bool isPrimaryConnection = connectionIndex == 0;
        
        // ENHANCED: Better line styling
        double strokeWidth = isPrimaryConnection ? (isSelected ? 4.0 : 2.5) : (isSelected ? 2.5 : 1.5);
        double opacity = isPrimaryConnection ? (isSelected ? 1.0 : 0.7) : (isSelected ? 0.7 : 0.4);
        
        polylines.add(
          Polyline(
            points: [reportLatLng, waterSupplyLatLng],
            strokeWidth: strokeWidth,
            color: lineColor.withOpacity(opacity),
            borderStrokeWidth: isPrimaryConnection ? 1.5 : 1.0,
            borderColor: Colors.white.withOpacity(0.5),
          ),
        );
      }
    }
    
    return polylines;
  }

  List<Map<String, dynamic>> _findNearestWaterSupplies(ReportModel report, {int maxConnections = 3}) {
    if (widget.polylineRoutes.isEmpty) return [];
    
    List<Map<String, dynamic>> allSupplies = [];
    
    for (final route in widget.polylineRoutes) {
      final destinationDetails = route['destination_details'] as Map<String, dynamic>? ?? {};
      final lat = (destinationDetails['latitude'] as num?)?.toDouble();
      final lng = (destinationDetails['longitude'] as num?)?.toDouble();
      
      if (lat != null && lng != null) {
        final distance = _calculateDistance(
          report.location.latitude,
          report.location.longitude,
          lat,
          lng,
        );
        
        allSupplies.add({
          'latitude': lat,
          'longitude': lng,
          'distance': distance,
          'name': destinationDetails['street_name'] ?? 'Water Supply',
          'route_index': widget.polylineRoutes.indexOf(route),
        });
      }
    }
    
    allSupplies.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
    return allSupplies.take(maxConnections).toList();
  }

  List<Marker> _buildAllMarkers() {
    List<Marker> markers = [];
    
    // Always add current location marker
    markers.add(_buildCurrentLocationMarker());
    
    // Add water supply markers
    markers.addAll(_buildWaterSupplyMarkers());
    
    // Add report markers only if reports exist
    if (widget.userReports.isNotEmpty) {
      markers.addAll(_buildUserReportMarkers());
    }
    
    return markers;
  }

  Marker _buildCurrentLocationMarker() {
    return Marker(
      point: LatLng(widget.currentLocation.latitude, widget.currentLocation.longitude),
      width: 50,
      height: 50,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.4),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Icon(Icons.my_location, color: Colors.white, size: 24),
      ),
    );
  }

  List<Marker> _buildWaterSupplyMarkers() {
    List<Marker> markers = [];
    
    final maxMarkers = _showAllMarkers ? widget.polylineRoutes.length : _maxVisibleRoutes;
    Set<String> addedLocations = {};
    
    for (int i = 0; i < maxMarkers && i < widget.polylineRoutes.length; i++) {
      final route = widget.polylineRoutes[i];
      final destinationDetails = route['destination_details'] as Map<String, dynamic>? ?? {};
      
      final lat = (destinationDetails['latitude'] as num?)?.toDouble();
      final lng = (destinationDetails['longitude'] as num?)?.toDouble();
      
      if (lat != null && lng != null) {
        final locationKey = '${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}';
        
        if (!addedLocations.contains(locationKey)) {
          addedLocations.add(locationKey);
          markers.add(_buildWaterSupplyMarker(route, i, lat, lng));
        }
      }
    }
    
    return markers;
  }

  Marker _buildWaterSupplyMarker(Map<String, dynamic> route, int index, double lat, double lng) {
    final isSelected = _selectedRoute == index;
    final isTop3 = index < 3;
    final routeColor = _getRouteColor(index);
    
    return Marker(
      point: LatLng(lat, lng),
      width: isSelected ? 60 : (isTop3 ? 50 : 44),
      height: isSelected ? 80 : (isTop3 ? 65 : 60),
      child: GestureDetector(
        onTap: () => _selectRoute(index),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: isSelected ? 45 : (isTop3 ? 38 : 34),
              height: isSelected ? 45 : (isTop3 ? 38 : 34),
              decoration: BoxDecoration(
                color: routeColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: isSelected ? 3 : 2),
                boxShadow: [
                  BoxShadow(
                    color: routeColor.withOpacity(0.4),
                    blurRadius: isSelected ? 12 : 8,
                    offset: Offset(0, isSelected ? 4 : 2),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Center(
                    child: Icon(
                      Icons.water_drop,
                      color: Colors.white,
                      size: isSelected ? 24 : (isTop3 ? 20 : 18),
                    ),
                  ),
                  if (isTop3)
                    Positioned(
                      top: -1,
                      right: -1,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: index == 0 ? Color(0xFFFFD700) : (index == 1 ? Colors.grey.shade300 : Colors.brown.shade400),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            if (isSelected) ...[
              SizedBox(height: 4),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                constraints: BoxConstraints(maxWidth: 120),
                decoration: BoxDecoration(
                  color: routeColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Route ${index + 1}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${(route['distance'] as double?)?.toStringAsFixed(1) ?? '?'} km',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Marker> _buildUserReportMarkers() {
    List<Marker> markers = [];
    
    for (int i = 0; i < widget.userReports.length; i++) {
      final report = widget.userReports[i];
      final isSelected = _selectedReport?.id == report.id;
      
      final nearestSupplies = _findNearestWaterSupplies(report, maxConnections: 1);
      final closestDistance = nearestSupplies.isNotEmpty 
          ? nearestSupplies.first['distance']?.toStringAsFixed(1) ?? '?' 
          : '?';
      
      markers.add(
        Marker(
          point: LatLng(report.location.latitude, report.location.longitude),
          width: isSelected ? 90 : 70,
          height: isSelected ? 110 : 90,
          child: GestureDetector(
            onTap: () => _selectReport(report),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: isSelected ? 55 : 45,
                  height: isSelected ? 55 : 45,
                  decoration: BoxDecoration(
                    color: _getWaterQualityColor(report.waterQuality),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: isSelected ? 3 : 2),
                    boxShadow: [
                      BoxShadow(
                        color: _getWaterQualityColor(report.waterQuality).withOpacity(0.4),
                        blurRadius: isSelected ? 12 : 8,
                        offset: Offset(0, isSelected ? 4 : 2),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Icon(
                          Icons.report_problem,
                          color: Colors.white,
                          size: isSelected ? 28 : 22,
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
                            border: Border.all(color: Colors.grey.shade400, width: 1),
                          ),
                          child: Center(
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                if (isSelected) ...[
                  SizedBox(height: 6),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    constraints: BoxConstraints(maxWidth: 140),
                    decoration: BoxDecoration(
                      color: _getWaterQualityColor(report.waterQuality),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Report ${i + 1}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Nearest: ${closestDistance}km',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  SizedBox(height: 4),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _getWaterQualityColor(report.waterQuality).withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      '${closestDistance}km',
                      style: TextStyle(
                        color: _getWaterQualityColor(report.waterQuality),
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }
    
    return markers;
  }

  // ENHANCED: Better header with map mode indicator
  Widget _buildEnhancedHeader() {
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [Colors.white, Colors.blue.shade50.withOpacity(0.3)],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [Colors.blue, Colors.blue.shade600]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.water_drop, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getHeaderTitle(),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            _getHeaderSubtitle(),
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    _buildHeaderToggle(),
                  ],
                ),
                
                if (!_isMinimized) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStat('Water Supplies', '${widget.polylineRoutes.length}', Colors.blue),
                      if (widget.userReports.isNotEmpty)
                        _buildStat('Reports', '${widget.userReports.length}', Colors.orange),
                      _buildStat('Zoom', '${_currentZoom.toInt()}x', Colors.green),
                      _buildStat('Mode', _mapMode == 'water_only' ? 'Supply' : 'Mixed', Colors.purple),
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

  String _getHeaderTitle() {
    if (widget.userReports.isEmpty) {
      return 'Water Supply Network';
    } else {
      return 'Water Network + Reports';
    }
  }

  String _getHeaderSubtitle() {
    if (widget.userReports.isEmpty) {
      return '${widget.polylineRoutes.length} water supplies available';
    } else {
      return '${widget.polylineRoutes.length} supplies • ${widget.userReports.length} reports';
    }
  }

  Widget _buildHeaderToggle() {
    return PopupMenuButton<String>(
      icon: Icon(Icons.tune, color: Colors.blue),
      onSelected: (value) {
        setState(() {
          switch (value) {
            case 'show_all': 
              _showAllMarkers = !_showAllMarkers; 
              break;
            case 'toggle_routes': 
              _showRouteLines = !_showRouteLines; 
              break;
            case 'toggle_connections': 
              _showReportConnections = !_showReportConnections; 
              break;
            case 'minimize': 
              _isMinimized = !_isMinimized; 
              break;
            case 'mode_water':
              _mapMode = 'water_only';
              _showReportConnections = false;
              break;
            case 'mode_mixed':
              _mapMode = 'auto';
              _showReportConnections = true;
              break;
          }
        });
      },
      itemBuilder: (context) => [
        PopupMenuItem(value: 'show_all', child: Text(_showAllMarkers ? 'Show Less Markers' : 'Show All Markers')),
        PopupMenuItem(value: 'toggle_routes', child: Text(_showRouteLines ? 'Hide Route Lines' : 'Show Route Lines')),
        if (widget.userReports.isNotEmpty)
          PopupMenuItem(value: 'toggle_connections', child: Text(_showReportConnections ? 'Hide Connections' : 'Show Connections')),
        PopupMenuItem(value: 'minimize', child: Text(_isMinimized ? 'Expand Header' : 'Minimize Header')),
        PopupMenuItem(value: 'mode_water', child: Text('Water Supplies Only')),
        if (widget.userReports.isNotEmpty)
          PopupMenuItem(value: 'mode_mixed', child: Text('Mixed Mode')),
      ],
    );
  }

  Widget _buildStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value, 
          style: TextStyle(
            fontSize: 16, 
            fontWeight: FontWeight.bold, 
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label, 
          style: TextStyle(
            fontSize: 10, 
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildControlPanel() {
    if (_isMinimized) return Container();
    
    return Positioned(
      bottom: _showRouteInfo ? 260 : 120,
      right: 16,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            IconButton(
              onPressed: _currentZoom >= 18.0 ? null : _zoomIn, 
              icon: Icon(Icons.add, size: 20),
            ),
            Container(height: 1, color: Colors.grey.shade300),
            IconButton(
              onPressed: _currentZoom <= 8.0 ? null : _zoomOut, 
              icon: Icon(Icons.remove, size: 20),
            ),
            Container(height: 1, color: Colors.grey.shade300),
            IconButton(
              onPressed: _fitMapToContent, 
              icon: Icon(Icons.zoom_out_map, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoPanel() {
    if (_isMinimized) return Container();
    
    return Positioned(
      bottom: 170,
      left: 16,
      right: 16,
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: BoxConstraints(maxHeight: 270),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getInfoPanelTitle(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold, 
                          fontSize: 16, 
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ),
                    if (_selectedReport != null || _selectedRoute != null)
                      GestureDetector(
                        onTap: () => setState(() {
                          _selectedReport = null;
                          _selectedRoute = null;
                        }),
                        child: Icon(Icons.clear, size: 16, color: Colors.blue.shade600),
                      ),
                    SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() => _showRouteInfo = false),
                      child: Icon(Icons.close, size: 16, color: Colors.blue.shade600),
                    ),
                  ],
                ),
              ),
              
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: _buildInfoPanelContent(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getInfoPanelTitle() {
    if (_selectedReport != null) return 'Report Details';
    if (_selectedRoute != null) return 'Route Details';
    if (widget.userReports.isEmpty) return 'Water Supply Network';
    return 'Network Overview';
  }

  Widget _buildInfoPanelContent() {
    if (_selectedReport != null) {
      return _buildReportInfo();
    } else if (_selectedRoute != null) {
      return _buildRouteInfo();
    } else {
      return _buildOverview();
    }
  }

  Widget _buildReportInfo() {
    if (_selectedReport == null) return Container();
    
    final nearestSupplies = _findNearestWaterSupplies(_selectedReport!, maxConnections: 3);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _getWaterQualityColor(_selectedReport!.waterQuality),
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
                    _selectedReport!.title,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'By: ${_selectedReport!.userName}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        
        SizedBox(height: 12),
        
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.link, color: Colors.blue, size: 16),
              SizedBox(width: 8),
              Text(
                'Connected to ${nearestSupplies.length} water supplies',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.blue.shade800),
              ),
            ],
          ),
        ),
        
        if (nearestSupplies.isNotEmpty) ...[
          SizedBox(height: 8),
          Text(
            'Closest: ${nearestSupplies.first['distance']?.toStringAsFixed(1)} km', 
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ],
    );
  }

  Widget _buildRouteInfo() {
    if (_selectedRoute == null || _selectedRoute! >= widget.polylineRoutes.length) {
      return Container();
    }
    
    final route = widget.polylineRoutes[_selectedRoute!];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _getRouteColor(_selectedRoute!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.water_drop, color: Colors.white, size: 20),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    route['destination_name'] ?? 'Water Supply ${_selectedRoute! + 1}',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Route ${_selectedRoute! + 1}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        
        SizedBox(height: 12),
        
        Row(
          children: [
            Expanded(
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  children: [
                    Icon(Icons.straighten, color: Colors.green, size: 16),
                    SizedBox(height: 4),
                    Text(
                      '${(route['distance'] as double?)?.toStringAsFixed(1) ?? '?'} km',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                    ),
                    Text('Distance', style: TextStyle(fontSize: 10, color: Colors.green.shade600)),
                  ],
                ),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  children: [
                    Icon(Icons.access_time, color: Colors.orange, size: 16),
                    SizedBox(height: 4),
                    Text(
                      route['travel_time']?.toString() ?? '?',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange.shade800),
                    ),
                    Text('Travel Time', style: TextStyle(fontSize: 10, color: Colors.orange.shade600)),
                  ],
                ),
              ),
            ),
          ],
        ),
        
        if (route['destination_address'] != null) ...[
          SizedBox(height: 8),
          Text(
            'Address: ${route['destination_address']}',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ],
    );
  }

  Widget _buildOverview() {
    if (widget.userReports.isEmpty) {
      // Water supplies only mode
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Water Supply Network', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildOverviewCard('Total Supplies', '${widget.polylineRoutes.length}', Icons.water_drop, Colors.blue)),
              SizedBox(width: 8),
              Expanded(child: _buildOverviewCard('Shortest Route', '${widget.polylineRoutes.isNotEmpty ? (widget.polylineRoutes.first['distance'] as double?)?.toStringAsFixed(1) ?? '?' : '?'} km', Icons.star, Colors.green)),
            ],
          ),
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info, color: Colors.blue, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No user reports found. Map showing water supply network only.',
                    style: TextStyle(fontSize: 11, color: Colors.blue.shade700),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    } else {
      // Mixed mode
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Network Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildOverviewCard('Supplies', '${widget.polylineRoutes.length}', Icons.water_drop, Colors.blue)),
              SizedBox(width: 8),
              Expanded(child: _buildOverviewCard('Reports', '${widget.userReports.length}', Icons.report_problem, Colors.orange)),
            ],
          ),
        ],
      );
    }
  }

  Widget _buildOverviewCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          Text(title, style: TextStyle(fontSize: 10, color: color)),
        ],
      ),
    );
  }

  // Helper methods
  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const double earthRadius = 6371;
    
    final double dLat = (lat2 - lat1) * (math.pi / 180);
    final double dLng = (lng2 - lng1) * (math.pi / 180);
    
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * (math.pi / 180)) * math.cos(lat2 * (math.pi / 180)) *
        math.sin(dLng / 2) * math.sin(dLng / 2);
    
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }

  Color _getRouteColor(int index) {
    final colors = [
      Colors.red.shade600, 
      Colors.blue.shade600, 
      Colors.green.shade600, 
      Colors.orange.shade600, 
      Colors.purple.shade600,
      Colors.cyan.shade600,
      Colors.pink.shade600,
      Colors.teal.shade600,
    ];
    return colors[index % colors.length];
  }

  Color _getWaterQualityColor(WaterQualityState quality) {
    switch (quality) {
      case WaterQualityState.optimum: return Colors.green;
      case WaterQualityState.highPh: return Colors.orange;
      case WaterQualityState.lowPh: return Colors.yellow.shade700;
      case WaterQualityState.highPhTemp: return Colors.red;
      case WaterQualityState.lowTemp: return Colors.blue;
      case WaterQualityState.lowTempHighPh: return Colors.purple;
      default: return Colors.grey.shade600;
    }
  }

  void _selectRoute(int index) {
    setState(() {
      _selectedRoute = _selectedRoute == index ? null : index;
      _selectedReport = null;
    });
  }

  void _selectReport(ReportModel report) {
    setState(() {
      _selectedReport = _selectedReport?.id == report.id ? null : report;
      _selectedRoute = null;
    });
  }

  void _zoomIn() {
    final newZoom = (_currentZoom + 1).clamp(8.0, 18.0);
    _mapController.move(_mapController.camera.center, newZoom);
    setState(() => _currentZoom = newZoom);
  }

  void _zoomOut() {
    final newZoom = (_currentZoom - 1).clamp(8.0, 18.0);
    _mapController.move(_mapController.camera.center, newZoom);
    setState(() => _currentZoom = newZoom);
  }

  LatLngBounds _calculateSmartBounds() {
    double? minLat, maxLat, minLng, maxLng;
    
    // Include current location
    minLat = maxLat = widget.currentLocation.latitude;
    minLng = maxLng = widget.currentLocation.longitude;
    
    // Include route points
    for (final route in widget.polylineRoutes) {
      final points = route['polyline_points'] as List<dynamic>? ?? [];
      for (final point in points) {
        if (point is Map<String, dynamic>) {
          final lat = (point['latitude'] as num?)?.toDouble() ?? 0.0;
          final lng = (point['longitude'] as num?)?.toDouble() ?? 0.0;
          
          if (lat != 0.0 && lng != 0.0) {
            minLat = math.min(minLat!, lat);
            maxLat = math.max(maxLat!, lat);
            minLng = math.min(minLng!, lng);
            maxLng = math.max(maxLng!, lng);
          }
        }
      }
    }
    
    // Include reports
    for (final report in widget.userReports) {
      final lat = report.location.latitude;
      final lng = report.location.longitude;
      
      minLat = math.min(minLat!, lat);
      maxLat = math.max(maxLat!, lat);
      minLng = math.min(minLng!, lng);
      maxLng = math.max(maxLng!, lng);
    }
    
    // Add padding
    final latPadding = (maxLat! - minLat!) * 0.1;
    final lngPadding = (maxLng! - minLng!) * 0.1;
    
    return LatLngBounds(
      LatLng(minLat! - latPadding, minLng! - lngPadding),
      LatLng(maxLat! + latPadding, maxLng! + lngPadding),
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
                CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.orange)),
                SizedBox(height: 16),
                Text('Loading Water Network...'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyOverlay() {
    return Container(
      color: Colors.grey.shade100,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined, size: 100, color: Colors.grey.shade400),
            SizedBox(height: 24),
            Text('No Data Available', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Text(
              'No water supplies or reports found.\nCheck your backend connection and data sources.',
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}