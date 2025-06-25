// lib/widgets/simplified/openstreet_map_widget.dart - FIXED: Multiple Lines Per Report
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
  bool _showReportRoutes = true;
  int? _selectedRoute;
  ReportModel? _selectedReport;
  double _currentZoom = 12.0;
  
  // SIMPLIFIED: Reduce settings
  int _maxVisibleMarkers = 10;
  bool _isMinimized = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.polylineRoutes.isNotEmpty || widget.userReports.isNotEmpty) {
        _fitMapToAllPoints();
      }
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _fitMapToAllPoints() {
    try {
      final bounds = _calculateMapBounds();
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: EdgeInsets.all(50),
        ),
      );
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _currentZoom = _mapController.camera.zoom;
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
          _buildHeader(),
        if (widget.polylineRoutes.isNotEmpty || widget.userReports.isNotEmpty) 
          _buildViewControls(),
        if (_showRouteInfo && (widget.polylineRoutes.isNotEmpty || widget.userReports.isNotEmpty)) 
          _buildRoutePanel(),
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
              _maxVisibleMarkers = _currentZoom >= 15 ? 25 : (_currentZoom >= 13 ? 15 : 10);
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
        if (_showRouteLines)
          PolylineLayer(polylines: _buildAllPolylines()),
        MarkerLayer(markers: _buildAllMarkers()),
      ],
    );
  }

  // FIXED: Build multiple lines per report
  List<Polyline> _buildAllPolylines() {
    List<Polyline> polylines = [];
    
    // Add water supply routes
    polylines.addAll(_buildWaterSupplyPolylines());
    
    // FIXED: Add multiple report to water supply routes
    if (_showReportRoutes) {
      polylines.addAll(_buildMultipleReportToWaterSupplyPolylines());
    }
    
    return polylines;
  }

  List<Polyline> _buildWaterSupplyPolylines() {
    List<Polyline> polylines = [];
    
    List<int> routesToShow = _selectedRoute != null 
        ? [_selectedRoute!] 
        : List.generate(
            math.min(_showAllMarkers ? widget.polylineRoutes.length : _maxVisibleMarkers, widget.polylineRoutes.length),
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
            final routeColor = _getRouteColor(index);
            final isSelected = _selectedRoute == index;
            final isTop3 = index < 3;
            
            polylines.add(
              Polyline(
                points: latLngPoints,
                strokeWidth: isSelected ? 6.0 : (isTop3 ? 4.0 : 3.0),
                color: routeColor.withOpacity(isSelected ? 1.0 : 0.7),
                borderStrokeWidth: isSelected ? 8.0 : (isTop3 ? 5.0 : 4.0),
                borderColor: routeColor.withOpacity(0.3),
              ),
            );
          }
        }
      }
    }
    
    return polylines;
  }

  // FIXED: Build multiple polylines from EVERY report to MULTIPLE water supplies
  List<Polyline> _buildMultipleReportToWaterSupplyPolylines() {
    List<Polyline> polylines = [];
    
    print('🔗 Building MULTIPLE connection lines for ${widget.userReports.length} reports...');
    
    for (int reportIndex = 0; reportIndex < widget.userReports.length; reportIndex++) {
      final report = widget.userReports[reportIndex];
      
      // FIXED: Find multiple nearest water supplies for THIS report
      final nearestWaterSupplies = _findMultipleNearestWaterSupplies(report, maxConnections: 5);
      
      print('📍 Report ${reportIndex + 1}: "${report.title}" → ${nearestWaterSupplies.length} connections');
      
      for (int connectionIndex = 0; connectionIndex < nearestWaterSupplies.length; connectionIndex++) {
        final waterSupply = nearestWaterSupplies[connectionIndex];
        
        // Create connection line from report to this water supply
        final reportLatLng = LatLng(report.location.latitude, report.location.longitude);
        final waterSupplyLatLng = LatLng(
          (waterSupply['latitude'] as num).toDouble(),
          (waterSupply['longitude'] as num).toDouble(),
        );
        
        // Get unique styling for each connection
        Color lineColor = _getWaterQualityColor(report.waterQuality);
        bool isSelected = _selectedReport?.id == report.id;
        bool isPrimaryConnection = connectionIndex == 0; // Closest connection
        
        // FIXED: Create different line styles for each connection
        double strokeWidth;
        double opacity;
        
        if (isPrimaryConnection) {
          // Primary connection - thickest line
          strokeWidth = isSelected ? 5.0 : 3.5;
          opacity = isSelected ? 1.0 : 0.8;
        } else {
          // Secondary connections - thinner lines
          strokeWidth = isSelected ? 3.0 : 2.0;
          opacity = isSelected ? 0.8 : 0.5;
        }
        
        // Make line color slightly different for each connection
        Color adjustedColor = _adjustColorBrightness(lineColor, connectionIndex * 0.1);
        
        if (connectionIndex % 2 == 0) {
          // Solid line for even connections
          polylines.add(
            Polyline(
              points: [reportLatLng, waterSupplyLatLng],
              strokeWidth: strokeWidth,
              color: adjustedColor.withOpacity(opacity),
              borderStrokeWidth: isPrimaryConnection ? 2.0 : 1.0,
              borderColor: Colors.white.withOpacity(0.6),
            ),
          );
        } else {
          // Dashed line for odd connections
          final segments = _createDashedLine(reportLatLng, waterSupplyLatLng, 20);
          
          for (int i = 0; i < segments.length; i += 2) {
            if (i + 1 < segments.length) {
              polylines.add(
                Polyline(
                  points: [segments[i], segments[i + 1]],
                  strokeWidth: strokeWidth,
                  color: adjustedColor.withOpacity(opacity),
                ),
              );
            }
          }
        }
        
        // Add direction arrow for primary connection when selected
        if (isPrimaryConnection && isSelected) {
          _addDirectionArrow(polylines, reportLatLng, waterSupplyLatLng, adjustedColor);
        }
      }
    }
    
    print('✅ Created ${polylines.length} connection line segments total');
    return polylines;
  }

  // FIXED: Find multiple nearest water supplies
  List<Map<String, dynamic>> _findMultipleNearestWaterSupplies(ReportModel report, {int maxConnections = 5}) {
    if (widget.polylineRoutes.isEmpty) return [];
    
    List<Map<String, dynamic>> allSupplies = [];
    
    // Calculate distance to all water supplies
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
    
    // Sort by distance and take closest ones
    allSupplies.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
    
    // Return up to maxConnections closest supplies
    return allSupplies.take(maxConnections).toList();
  }

  // Helper: Adjust color brightness
  Color _adjustColorBrightness(Color color, double adjustment) {
    final hsl = HSLColor.fromColor(color);
    final adjustedLightness = (hsl.lightness + adjustment).clamp(0.0, 1.0);
    return hsl.withLightness(adjustedLightness).toColor();
  }

  // Add arrow to show direction
  void _addDirectionArrow(List<Polyline> polylines, LatLng start, LatLng end, Color color) {
    final midLat = (start.latitude + end.latitude) / 2;
    final midLng = (start.longitude + end.longitude) / 2;
    final midPoint = LatLng(midLat, midLng);
    
    final deltaLat = end.latitude - start.latitude;
    final deltaLng = end.longitude - start.longitude;
    final length = math.sqrt(deltaLat * deltaLat + deltaLng * deltaLng);
    
    if (length > 0) {
      final arrowSize = 0.002;
      final arrowAngle = 30 * (math.pi / 180);
      
      final dirLat = deltaLat / length;
      final dirLng = deltaLng / length;
      
      final arrowTip = LatLng(
        midPoint.latitude + dirLat * arrowSize,
        midPoint.longitude + dirLng * arrowSize,
      );
      
      final arrowLeft = LatLng(
        midPoint.latitude - dirLat * arrowSize * math.cos(arrowAngle) + dirLng * arrowSize * math.sin(arrowAngle),
        midPoint.longitude - dirLng * arrowSize * math.cos(arrowAngle) - dirLat * arrowSize * math.sin(arrowAngle),
      );
      
      final arrowRight = LatLng(
        midPoint.latitude - dirLat * arrowSize * math.cos(arrowAngle) - dirLng * arrowSize * math.sin(arrowAngle),
        midPoint.longitude - dirLng * arrowSize * math.cos(arrowAngle) + dirLat * arrowSize * math.sin(arrowAngle),
      );
      
      polylines.add(Polyline(points: [arrowTip, arrowLeft], strokeWidth: 3.0, color: color));
      polylines.add(Polyline(points: [arrowTip, arrowRight], strokeWidth: 3.0, color: color));
    }
  }

  List<LatLng> _createDashedLine(LatLng start, LatLng end, int segments) {
    List<LatLng> points = [];
    
    for (int i = 0; i <= segments; i++) {
      final ratio = i / segments;
      final lat = start.latitude + (end.latitude - start.latitude) * ratio;
      final lng = start.longitude + (end.longitude - start.longitude) * ratio;
      points.add(LatLng(lat, lng));
    }
    
    return points;
  }

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

  List<Marker> _buildAllMarkers() {
    List<Marker> markers = [];
    markers.addAll(_buildWaterSupplyMarkers());
    markers.addAll(_buildUserReportMarkers());
    return markers;
  }

  List<Marker> _buildUserReportMarkers() {
    List<Marker> markers = [];
    
    for (int i = 0; i < widget.userReports.length; i++) {
      final report = widget.userReports[i];
      final isSelected = _selectedReport?.id == report.id;
      
      // Get multiple nearest supplies info
      final nearestSupplies = _findMultipleNearestWaterSupplies(report, maxConnections: 3);
      final connectionCount = nearestSupplies.length;
      final closestDistance = nearestSupplies.isNotEmpty 
          ? nearestSupplies.first['distance']?.toStringAsFixed(1) ?? '?' 
          : '?';
      
      markers.add(
        Marker(
          point: LatLng(report.location.latitude, report.location.longitude),
          width: isSelected ? 80 : 60,
          height: isSelected ? 100 : 80,
          child: GestureDetector(
            onTap: () => _selectReport(report),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: isSelected ? 50 : 40,
                  height: isSelected ? 50 : 40,
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
                          size: isSelected ? 28 : 20,
                        ),
                      ),
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Container(
                          width: 16,
                          height: 16,
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
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // FIXED: Show connection count
                      Positioned(
                        bottom: -2,
                        left: -2,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1),
                          ),
                          child: Center(
                            child: Text(
                              '$connectionCount',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 7,
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
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '$connectionCount lines → ${closestDistance}km',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                if (!isSelected) ...[
                  SizedBox(height: 4),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _getWaterQualityColor(report.waterQuality).withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      '$connectionCount→${closestDistance}km',
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
    
    print('📍 Created ${markers.length} report markers with multiple connections');
    return markers;
  }

  List<Marker> _buildWaterSupplyMarkers() {
    List<Marker> markers = [];
    
    final maxMarkers = _showAllMarkers ? widget.polylineRoutes.length : _maxVisibleMarkers;
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
          markers.add(_buildWaterMarker(route, i, lat, lng));
        }
      }
    }
    
    return markers;
  }

  Marker _buildWaterMarker(Map<String, dynamic> route, int index, double lat, double lng) {
    final isSelected = _selectedRoute == index;
    final isTop3 = index < 3;
    final routeColor = _getRouteColor(index);
    
    return Marker(
      point: LatLng(lat, lng),
      width: isSelected ? 50 : (isTop3 ? 44 : 40),
      height: isSelected ? 50 : (isTop3 ? 44 : 40),
      child: GestureDetector(
        onTap: () => _selectRoute(index),
        child: Container(
          decoration: BoxDecoration(
            color: routeColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: isSelected ? 3 : 2),
            boxShadow: [
              BoxShadow(
                color: routeColor.withAlpha((0.4 * 255).toInt()),
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
                  top: 2,
                  right: 2,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: index == 0 ? Color(0xFFFFD700) : (index == 1 ? Colors.grey.shade400 : Colors.brown),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 7,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // SIMPLIFIED UI COMPONENTS
  Widget _buildHeader() {
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue,
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
                          'Water Network + Reports',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${widget.polylineRoutes.length} supplies • ${widget.userReports.length} reports',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  _buildSimpleToggle(),
                ],
              ),
              
              if (!_isMinimized) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStat('Supplies', '${widget.polylineRoutes.length}', Colors.blue),
                    _buildStat('Reports', '${widget.userReports.length}', Colors.orange),
                    _buildStat('Zoom', '${_currentZoom.toInt()}x', Colors.purple),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSimpleToggle() {
    return PopupMenuButton<String>(
      icon: Icon(Icons.tune, color: Colors.blue),
      onSelected: (value) {
        setState(() {
          switch (value) {
            case 'show_all': _showAllMarkers = !_showAllMarkers; break;
            case 'toggle_routes': _showRouteLines = !_showRouteLines; break;
            case 'toggle_report_routes': _showReportRoutes = !_showReportRoutes; break;
            case 'minimize': _isMinimized = !_isMinimized; break;
          }
        });
      },
      itemBuilder: (context) => [
        PopupMenuItem(value: 'show_all', child: Text(_showAllMarkers ? 'Show Less' : 'Show All')),
        PopupMenuItem(value: 'toggle_routes', child: Text(_showRouteLines ? 'Hide Routes' : 'Show Routes')),
        PopupMenuItem(value: 'toggle_report_routes', child: Text(_showReportRoutes ? 'Hide Report Lines' : 'Show Report Lines')),
        PopupMenuItem(value: 'minimize', child: Text(_isMinimized ? 'Expand' : 'Minimize')),
      ],
    );
  }

  Widget _buildStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildRoutePanel() {
    if (_isMinimized) return Container();
    
    return Positioned(
      top: 200,
      left: 16,
      right: 16,
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: BoxConstraints(maxHeight: 320),
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
                    Text(
                      _selectedReport != null ? 'Report Details' : 'Network Overview',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue.shade800),
                    ),
                    Spacer(),
                    if (_selectedReport != null)
                      GestureDetector(
                        onTap: () => setState(() => _selectedReport = null),
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
                  child: _selectedReport != null ? _buildReportInfo() : _buildOverview(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportInfo() {
    if (_selectedReport == null) return Container();
    
    final nearestSupplies = _findMultipleNearestWaterSupplies(_selectedReport!, maxConnections: 5);
    
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
          Text('Closest: ${nearestSupplies.first['distance']?.toStringAsFixed(1)} km', 
               style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ],
      ],
    );
  }

  Widget _buildOverview() {
    int totalConnections = 0;
    for (final report in widget.userReports) {
      final connections = _findMultipleNearestWaterSupplies(report, maxConnections: 5);
      totalConnections += connections.length;
    }
    
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
        
        SizedBox(height: 8),
        
        Row(
          children: [
            Expanded(child: _buildOverviewCard('Total Lines', '$totalConnections', Icons.link, Colors.green)),
            SizedBox(width: 8),
            Expanded(child: _buildOverviewCard('Avg/Report', '${totalConnections > 0 ? (totalConnections / widget.userReports.length).toStringAsFixed(1) : "0"}', Icons.analytics, Colors.purple)),
          ],
        ),
      ],
    );
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

  Widget _buildViewControls() {
    return Positioned(
      bottom: _showRouteInfo ? 240 : 100,
      right: 16,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            IconButton(onPressed: _currentZoom >= 18.0 ? null : _zoomIn, icon: Icon(Icons.add, size: 20)),
            Container(height: 1, color: Colors.grey.shade300),
            IconButton(onPressed: _currentZoom <= 8.0 ? null : _zoomOut, icon: Icon(Icons.remove, size: 20)),
            Container(height: 1, color: Colors.grey.shade300),
            IconButton(onPressed: _fitMapToAllPoints, icon: Icon(Icons.zoom_out_map, size: 20)),
          ],
        ),
      ),
    );
  }

  // Helper methods
  Color _getRouteColor(int index) {
    final colors = [Colors.red.shade600, Colors.blue.shade600, Colors.green.shade600, Colors.orange.shade600, Colors.purple.shade600];
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

  LatLngBounds _calculateMapBounds() {
    double? minLat, maxLat, minLng, maxLng;
    
    for (final route in widget.polylineRoutes) {
      final points = route['polyline_points'] as List<dynamic>? ?? [];
      for (final point in points) {
        if (point is Map<String, dynamic>) {
          final lat = (point['latitude'] as num?)?.toDouble() ?? 0.0;
          final lng = (point['longitude'] as num?)?.toDouble() ?? 0.0;
          
          if (lat != 0.0 && lng != 0.0) {
            minLat = (minLat == null) ? lat : (minLat < lat ? minLat : lat);
            maxLat = (maxLat == null) ? lat : (maxLat > lat ? maxLat : lat);
            minLng = (minLng == null) ? lng : (minLng < lng ? minLng : lng);
            maxLng = (maxLng == null) ? lng : (maxLng > lng ? maxLng : lng);
          }
        }
      }
    }
    
    for (final report in widget.userReports) {
      final lat = report.location.latitude;
      final lng = report.location.longitude;
      
      minLat = (minLat == null) ? lat : (minLat < lat ? minLat : lat);
      maxLat = (maxLat == null) ? lat : (maxLat > lat ? maxLat : lat);
      minLng = (minLng == null) ? lng : (minLng < lng ? minLng : lng);
      maxLng = (maxLng == null) ? lng : (maxLng > lng ? maxLng : lng);
    }
    
    if (minLat == null || maxLat == null || minLng == null || maxLng == null) {
      minLat = widget.currentLocation.latitude;
      maxLat = widget.currentLocation.latitude;
      minLng = widget.currentLocation.longitude;
      maxLng = widget.currentLocation.longitude;
    }
    
    final latPadding = (maxLat - minLat) * 0.1;
    final lngPadding = (maxLng - minLng) * 0.1;
    
    return LatLngBounds(
      LatLng(minLat - latPadding, minLng - lngPadding),
      LatLng(maxLat + latPadding, maxLng + lngPadding),
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
            Text('No Reports or Water Supplies', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Text('No user reports or water supplies found.\nCreate a report or check water supply data.', 
                 style: TextStyle(color: Colors.grey.shade600), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}