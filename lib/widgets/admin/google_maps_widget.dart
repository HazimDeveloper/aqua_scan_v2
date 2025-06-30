// lib/widgets/admin/google_maps_route_widget.dart - COMPLETE SIMPLE VERSION
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/report_model.dart';
import '../../services/api_service.dart';

class GoogleMapsRouteWidget extends StatefulWidget {
  final List<Map<String, dynamic>>? polylineRoutes;
  final List<ReportModel> reports;
  final GeoPoint? currentLocation;
  final Function(ReportModel)? onReportTap;
  final Function(int)? onRouteSelected;
  final bool showMultipleRoutes;
  final int? selectedRouteIndex;

  const GoogleMapsRouteWidget({
    Key? key,
    this.polylineRoutes,
    required this.reports,
    this.currentLocation,
    this.onReportTap,
    this.onRouteSelected,
    this.showMultipleRoutes = true,
    this.selectedRouteIndex,
  }) : super(key: key);

  @override
  _GoogleMapsRouteWidgetState createState() => _GoogleMapsRouteWidgetState();
}

class _GoogleMapsRouteWidgetState extends State<GoogleMapsRouteWidget>
    with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  
  // Animation controllers
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  // UI State
  int? _selectedRouteIndex;
  Map<String, dynamic>? _selectedRoute;
  bool _showRouteDetails = false;
  double _currentZoom = 12.0;
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _selectedRouteIndex = widget.selectedRouteIndex;
    _updateMarkersAndPolylines();
  }
  
  @override
  void didUpdateWidget(GoogleMapsRouteWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.polylineRoutes != widget.polylineRoutes ||
        oldWidget.selectedRouteIndex != widget.selectedRouteIndex) {
      _selectedRouteIndex = widget.selectedRouteIndex;
      _updateMarkersAndPolylines();
    }
  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }
  
  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }
  
  void _updateMarkersAndPolylines() {
    final newMarkers = <Marker>{};
    final newPolylines = <Polyline>{};
    
    print('🗺️ Updating map with ${widget.polylineRoutes?.length ?? 0} routes');
    
    // Add current location marker
    if (widget.currentLocation != null) {
      newMarkers.add(_buildCurrentLocationMarker());
    }
    
    // Add route markers and polylines
    if (widget.polylineRoutes != null) {
      for (int i = 0; i < widget.polylineRoutes!.length; i++) {
        final route = widget.polylineRoutes![i];
        
        // Add destination marker
        final marker = _buildRouteMarker(route, i);
        if (marker != null) {
          newMarkers.add(marker);
        }
        
        // Add polyline
        final polyline = _buildRoutePolyline(route, i);
        if (polyline != null) {
          newPolylines.add(polyline);
        }
      }
    }
    
    // Add report markers
    for (final report in widget.reports) {
      newMarkers.add(_buildReportMarker(report));
    }
    
    if (mounted) {
      setState(() {
        _markers = newMarkers;
        _polylines = newPolylines;
      });
      
      print('✅ Map updated: ${_markers.length} markers, ${_polylines.length} polylines');
    }
  }
  
  Marker _buildCurrentLocationMarker() {
    return Marker(
      markerId: const MarkerId('current_location'),
      position: LatLng(
        widget.currentLocation!.latitude,
        widget.currentLocation!.longitude,
      ),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      infoWindow: const InfoWindow(
        title: '📍 Your Location',
        snippet: 'Current GPS position',
      ),
    );
  }
  
  Marker? _buildRouteMarker(Map<String, dynamic> route, int index) {
    final destination = route['destination_details'] as Map<String, dynamic>? ?? {};
    final lat = (destination['latitude'] as num?)?.toDouble();
    final lng = (destination['longitude'] as num?)?.toDouble();
    
    if (lat == null || lng == null || lat == 0.0 || lng == 0.0) {
      return null;
    }
    
    final isSelected = _selectedRouteIndex == index;
    final isNearest = index == 0;
    
    return Marker(
      markerId: MarkerId('route_$index'),
      position: LatLng(lat, lng),
      icon: BitmapDescriptor.defaultMarkerWithHue(
        isNearest ? BitmapDescriptor.hueGreen :
        isSelected ? BitmapDescriptor.hueBlue :
        _getMarkerHue(index),
      ),
      infoWindow: InfoWindow(
        title: route['destination_name'] ?? 'Water Supply ${index + 1}',
        snippet: _buildRouteSnippet(route, index),
      ),
      onTap: () {
        _onRouteMarkerTap(route, index);
      },
    );
  }
  
  String _buildRouteSnippet(Map<String, dynamic> route, int index) {
    final distance = '${(route['distance'] as num?)?.toStringAsFixed(1) ?? '?'}km';
    final time = route['travel_time'] ?? '? min';
    final isNearest = index == 0;
    
    String snippet = '$distance • $time';
    
    if (isNearest) {
      snippet += ' • 🌟 NEAREST';
    }
    
    final routeSource = route['route_source'] as String?;
    if (routeSource == 'google_directions') {
      snippet += ' • 🗺️ Google';
    } else if (routeSource == 'enhanced_fallback') {
      snippet += ' • 🛣️ Enhanced';
    }
    
    return snippet;
  }
  
  Polyline? _buildRoutePolyline(Map<String, dynamic> route, int index) {
    final polylinePoints = route['polyline_points'] as List<dynamic>?;
    
    if (polylinePoints == null || polylinePoints.isEmpty) {
      return null;
    }
    
    final points = <LatLng>[];
    
    for (final point in polylinePoints) {
      if (point is Map<String, dynamic>) {
        final lat = (point['latitude'] as num?)?.toDouble();
        final lng = (point['longitude'] as num?)?.toDouble();
        
        if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
          points.add(LatLng(lat, lng));
        }
      }
    }
    
    if (points.length < 2) {
      return null;
    }
    
    final isSelected = _selectedRouteIndex == index;
    final isNearest = index == 0;
    
    Color routeColor;
    int strokeWidth;
    double opacity;
    
    if (isNearest) {
      routeColor = Colors.green;
      strokeWidth = 7;
      opacity = 0.9;
    } else if (isSelected) {
      routeColor = Colors.blue;
      strokeWidth = 6;
      opacity = 0.8;
    } else {
      routeColor = _getRouteColor(index);
      strokeWidth = 4;
      opacity = 0.6;
    }
    
    return Polyline(
      polylineId: PolylineId('route_$index'),
      points: points,
      color: routeColor.withOpacity(opacity),
      width: strokeWidth,
      geodesic: true,
      patterns: isSelected ? [PatternItem.dash(10), PatternItem.gap(5)] : [],
    );
  }
  
  Marker _buildReportMarker(ReportModel report) {
    return Marker(
      markerId: MarkerId('report_${report.id}'),
      position: LatLng(report.location.latitude, report.location.longitude),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      infoWindow: InfoWindow(
        title: '📋 ${report.title}',
        snippet: '${report.waterQuality.name} • ${report.address}',
      ),
      onTap: () => widget.onReportTap?.call(report),
    );
  }
  
  void _onRouteMarkerTap(Map<String, dynamic> route, int index) {
    setState(() {
      if (_selectedRouteIndex == index) {
        _selectedRouteIndex = null;
        _selectedRoute = null;
        _showRouteDetails = false;
      } else {
        _selectedRouteIndex = index;
        _selectedRoute = route;
        _showRouteDetails = true;
      }
    });
    
    // Update polylines
    _updateMarkersAndPolylines();
    
    // Notify parent
    widget.onRouteSelected?.call(_selectedRouteIndex ?? -1);
    
    // Zoom to route
    _zoomToRoute(route);
  }
  
  void _zoomToRoute(Map<String, dynamic> route) {
    final polylinePoints = route['polyline_points'] as List<dynamic>?;
    if (polylinePoints == null || polylinePoints.isEmpty || _mapController == null) {
      return;
    }
    
    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;
    
    for (final point in polylinePoints) {
      if (point is Map<String, dynamic>) {
        final lat = (point['latitude'] as num?)?.toDouble();
        final lng = (point['longitude'] as num?)?.toDouble();
        
        if (lat != null && lng != null) {
          minLat = math.min(minLat, lat);
          maxLat = math.max(maxLat, lat);
          minLng = math.min(minLng, lng);
          maxLng = math.max(maxLng, lng);
        }
      }
    }
    
    if (minLat != double.infinity) {
      final bounds = LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      );
      
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100.0),
      );
    }
  }
  
  void _fitAllRoutes() {
    if (_mapController == null || widget.polylineRoutes == null || widget.polylineRoutes!.isEmpty) {
      return;
    }
    
    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;
    
    // Include current location
    if (widget.currentLocation != null) {
      minLat = math.min(minLat, widget.currentLocation!.latitude);
      maxLat = math.max(maxLat, widget.currentLocation!.latitude);
      minLng = math.min(minLng, widget.currentLocation!.longitude);
      maxLng = math.max(maxLng, widget.currentLocation!.longitude);
    }
    
    // Include all route points
    for (final route in widget.polylineRoutes!) {
      final polylinePoints = route['polyline_points'] as List<dynamic>?;
      if (polylinePoints != null) {
        for (final point in polylinePoints) {
          if (point is Map<String, dynamic>) {
            final lat = (point['latitude'] as num?)?.toDouble();
            final lng = (point['longitude'] as num?)?.toDouble();
            
            if (lat != null && lng != null) {
              minLat = math.min(minLat, lat);
              maxLat = math.max(maxLat, lat);
              minLng = math.min(minLng, lng);
              maxLng = math.max(maxLng, lng);
            }
          }
        }
      }
    }
    
    if (minLat != double.infinity) {
      final bounds = LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      );
      
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 50.0),
      );
    }
  }
  
  Color _getRouteColor(int index) {
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.purple,
      Colors.orange,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
      Colors.amber,
      Colors.cyan,
      Colors.lime,
    ];
    return colors[index % colors.length];
  }
  
  double _getMarkerHue(int index) {
    final hues = [
      BitmapDescriptor.hueRed,
      BitmapDescriptor.hueBlue,
      BitmapDescriptor.hueViolet,
      BitmapDescriptor.hueOrange,
      BitmapDescriptor.hueCyan,
      BitmapDescriptor.hueYellow,
      BitmapDescriptor.hueMagenta,
      BitmapDescriptor.hueAzure,
      BitmapDescriptor.hueRose,
    ];
    return hues[index % hues.length];
  }
  
  @override
  Widget build(BuildContext context) {
    if (widget.currentLocation == null) {
      return _buildNoLocationView();
    }
    
    return Stack(
      children: [
        // Google Map
        GoogleMap(
          onMapCreated: (GoogleMapController controller) {
            _mapController = controller;
            print('🗺️ Google Map created successfully');
            
            // Fit all routes after map is ready
            Future.delayed(Duration(milliseconds: 500), () {
              _fitAllRoutes();
            });
          },
          initialCameraPosition: CameraPosition(
            target: LatLng(
              widget.currentLocation!.latitude,
              widget.currentLocation!.longitude,
            ),
            zoom: 12.0,
          ),
          markers: _markers,
          polylines: _polylines,
          myLocationEnabled: true,
          myLocationButtonEnabled: false, // We'll add custom controls
          zoomControlsEnabled: false, // Custom zoom controls
          mapToolbarEnabled: true,
          compassEnabled: true,
          mapType: MapType.normal,
          trafficEnabled: true,
          onCameraMove: (CameraPosition position) {
            _currentZoom = position.zoom;
          },
          onTap: (LatLng latLng) {
            // Deselect route when tapping empty area
            setState(() {
              _selectedRouteIndex = null;
              _selectedRoute = null;
              _showRouteDetails = false;
            });
            _updateMarkersAndPolylines();
            widget.onRouteSelected?.call(-1);
          },
        ),
        
        // Top info panel
        _buildTopInfoPanel(),
        
        // Zoom controls
        _buildZoomControls(),
        
        // Route details panel
        if (_showRouteDetails && _selectedRoute != null)
          _buildRouteDetailsPanel(),
        
        // Map controls
        _buildMapControls(),
      ],
    );
  }
  
  Widget _buildNoLocationView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_off, size: 64, color: Colors.grey.shade400),
          SizedBox(height: 16),
          Text(
            "Location not available",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            "Please enable location services",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTopInfoPanel() {
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
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
                      '${widget.polylineRoutes?.length ?? 0} Routes Found',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      'Tap route markers for details • Zoom: ${_currentZoom.toStringAsFixed(1)}x',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              if (_selectedRouteIndex != null)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Route ${_selectedRouteIndex! + 1}',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildZoomControls() {
    return Positioned(
      right: 16,
      top: 100,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Column(
          children: [
            IconButton(
              icon: Icon(Icons.zoom_in),
              onPressed: () {
                _mapController?.animateCamera(CameraUpdate.zoomIn());
              },
            ),
            Container(height: 1, width: 30, color: Colors.grey.shade300),
            IconButton(
              icon: Icon(Icons.zoom_out),
              onPressed: () {
                _mapController?.animateCamera(CameraUpdate.zoomOut());
              },
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMapControls() {
    return Positioned(
      right: 16,
      bottom: 100,
      child: Column(
        children: [
          // Fit all routes button
          FloatingActionButton(
            heroTag: "fit_routes",
            mini: true,
            onPressed: _fitAllRoutes,
            child: Icon(Icons.center_focus_strong),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          SizedBox(height: 8),
          // My location button
          FloatingActionButton(
            heroTag: "my_location",
            mini: true,
            onPressed: () {
              if (widget.currentLocation != null) {
                _mapController?.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(
                      target: LatLng(
                        widget.currentLocation!.latitude,
                        widget.currentLocation!.longitude,
                      ),
                      zoom: 15.0,
                    ),
                  ),
                );
              }
            },
            child: Icon(Icons.my_location),
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
        ],
      ),
    );
  }
  
  Widget _buildRouteDetailsPanel() {
    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue.shade50, Colors.white],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _selectedRouteIndex == 0 ? Colors.green : Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${(_selectedRouteIndex ?? 0) + 1}',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedRoute!['destination_name'] ?? 'Water Supply',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _selectedRoute!['destination_address'] ?? 'Terengganu Water Infrastructure',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        _selectedRouteIndex = null;
                        _selectedRoute = null;
                        _showRouteDetails = false;
                      });
                      _updateMarkersAndPolylines();
                      widget.onRouteSelected?.call(-1);
                    },
                  ),
                ],
              ),
              
              SizedBox(height: 16),
              
              // Route details
              Row(
                children: [
                  Expanded(
                    child: _buildDetailItem(
                      Icons.straighten,
                      'Distance',
                      '${(_selectedRoute!['distance'] as num?)?.toStringAsFixed(1) ?? '?'} km',
                      Colors.blue,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: _buildDetailItem(
                      Icons.access_time,
                      'Travel Time',
                      _selectedRoute!['travel_time'] ?? '? min',
                      Colors.green,
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 12),
              
              Row(
                children: [
                  Expanded(
                    child: _buildDetailItem(
                      Icons.flag,
                      'Priority',
                      _selectedRouteIndex == 0 ? 'Nearest Route' : 'Alternative Route',
                      _selectedRouteIndex == 0 ? Colors.green : Colors.orange,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: _buildDetailItem(
                      Icons.route,
                      'Source',
                      _getRouteSourceLabel(_selectedRoute!['route_source'] as String?),
                      Colors.purple,
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 16),
              
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _zoomToRoute(_selectedRoute!);
                      },
                      icon: Icon(Icons.zoom_in_map, size: 18),
                      label: Text('Zoom to Route'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // Open external navigation
                        print('🚗 Navigate to: ${_selectedRoute!['destination_name']}');
                        // Here you could integrate with Google Maps app
                      },
                      icon: Icon(Icons.navigation, size: 18),
                      label: Text('Navigate'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
  
  Widget _buildDetailItem(IconData icon, String label, String value, Color color) {
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
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          ),
          SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  String _getRouteSourceLabel(String? source) {
    switch (source) {
      case 'google_directions':
        return 'Google Maps';
      case 'enhanced_fallback':
        return 'Enhanced Route';
      case 'offline_fallback':
        return 'Offline Route';
      default:
        return 'Basic Route';
    }
  }
}