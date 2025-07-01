// lib/services/location_service.dart - ENHANCED: Address Caching & Batch Loading
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../models/report_model.dart';

class LocationService {
  // Address cache untuk performance
  static final Map<String, String> _addressCache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};
  static const int _cacheExpiryHours = 24; // Cache valid for 24 hours
  
  // Check permissions
  Future<bool> checkPermission() async {
    bool serviceEnabled;
    LocationPermission permission;
    
    // Test if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are disabled
      return false;
    }
    
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied
        return false;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      // Permissions are permanently denied
      return false;
    }
    
    return true;
  }
  
  // Get current location
  Future<Position?> getCurrentLocation() async {
    final hasPermission = await checkPermission();
    
    if (!hasPermission) {
      return null;
    }
    
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      throw Exception('Failed to get location: $e');
    }
  }
  
  // ENHANCED: Get address dengan caching
  Future<String> getAddressFromCoordinates(double latitude, double longitude) async {
    final key = _generateCacheKey(latitude, longitude);
    
    // Check cache first
    if (_isCacheValid(key)) {
      print('📍 Address from cache: ${_addressCache[key]}');
      return _addressCache[key]!;
    }
    
    try {
      print('📍 Fetching address for $latitude, $longitude...');
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      
      String address = 'Unknown location';
      
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        address = _buildFormattedAddress(place);
      }
      
      // Cache the result
      _cacheAddress(key, address);
      
      print('📍 Address cached: $address');
      return address;
    } catch (e) {
      print('⚠️ Geocoding error: $e');
      
      // Return coordinate-based fallback address
      final fallbackAddress = 'Location at ${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
      _cacheAddress(key, fallbackAddress);
      
      return fallbackAddress;
    }
  }
  
  // NEW: Batch load addresses untuk multiple locations
  Future<Map<String, String>> getBatchAddresses(List<Map<String, dynamic>> locations) async {
    final results = <String, String>{};
    final futures = <Future<void>>[];
    
    print('📍 Batch loading ${locations.length} addresses...');
    
    for (final location in locations) {
      final lat = (location['latitude'] as num?)?.toDouble();
      final lng = (location['longitude'] as num?)?.toDouble();
      final name = location['name'] as String? ?? 'Location';
      
      if (lat != null && lng != null) {
        final key = _generateCacheKey(lat, lng);
        
        // If already cached, add to results immediately
        if (_isCacheValid(key)) {
          results[key] = _addressCache[key]!;
        } else {
          // Add to batch fetch
          futures.add(_fetchAndCacheAddress(lat, lng, key, results));
        }
      }
    }
    
    // Wait for all fetches to complete
    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }
    
    print('✅ Batch address loading completed. Results: ${results.length}');
    return results;
  }
  
  // Helper method untuk batch fetching
  Future<void> _fetchAndCacheAddress(
    double lat, 
    double lng, 
    String key, 
    Map<String, String> results,
  ) async {
    try {
      final address = await getAddressFromCoordinates(lat, lng);
      results[key] = address;
    } catch (e) {
      print('⚠️ Failed to fetch address for $lat, $lng: $e');
      results[key] = 'Location at ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
    }
  }
  
  // NEW: Get cached address atau return loading message
  String getCachedAddress(double latitude, double longitude, {String loadingMessage = 'Loading address...'}) {
    final key = _generateCacheKey(latitude, longitude);
    
    if (_isCacheValid(key)) {
      return _addressCache[key]!;
    }
    
    return loadingMessage;
  }
  
  // NEW: Preload address untuk specific location
  Future<void> preloadAddress(double latitude, double longitude) async {
    final key = _generateCacheKey(latitude, longitude);
    
    if (!_isCacheValid(key)) {
      await getAddressFromCoordinates(latitude, longitude);
    }
  }
  
  // NEW: Clear cache (untuk memory management)
  void clearAddressCache() {
    _addressCache.clear();
    _cacheTimestamps.clear();
    print('📍 Address cache cleared');
  }
  
  // NEW: Get cache statistics
  Map<String, dynamic> getCacheStats() {
    final validEntries = _addressCache.keys.where((key) => _isCacheValid(key)).length;
    final expiredEntries = _addressCache.length - validEntries;
    
    return {
      'total_entries': _addressCache.length,
      'valid_entries': validEntries,
      'expired_entries': expiredEntries,
      'cache_hit_ratio': _addressCache.isNotEmpty ? (validEntries / _addressCache.length * 100).toStringAsFixed(1) : '0.0',
    };
  }
  
  // Generate cache key from coordinates
  String _generateCacheKey(double latitude, double longitude) {
    // Round to 4 decimal places for cache key (accuracy ~11 meters)
    final lat = latitude.toStringAsFixed(4);
    final lng = longitude.toStringAsFixed(4);
    return '$lat,$lng';
  }
  
  // Check if cached address is still valid
  bool _isCacheValid(String key) {
    if (!_addressCache.containsKey(key) || !_cacheTimestamps.containsKey(key)) {
      return false;
    }
    
    final timestamp = _cacheTimestamps[key]!;
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    return difference.inHours < _cacheExpiryHours;
  }
  
  // Cache address dengan timestamp
  void _cacheAddress(String key, String address) {
    _addressCache[key] = address;
    _cacheTimestamps[key] = DateTime.now();
    
    // Clean expired entries periodically
    if (_addressCache.length > 100) {
      _cleanExpiredEntries();
    }
  }
  
  // Clean expired cache entries
  void _cleanExpiredEntries() {
    final expiredKeys = <String>[];
    
    for (final key in _cacheTimestamps.keys) {
      if (!_isCacheValid(key)) {
        expiredKeys.add(key);
      }
    }
    
    for (final key in expiredKeys) {
      _addressCache.remove(key);
      _cacheTimestamps.remove(key);
    }
    
    if (expiredKeys.isNotEmpty) {
      print('📍 Cleaned ${expiredKeys.length} expired cache entries');
    }
  }
  
  // Build formatted address dari placemark
  String _buildFormattedAddress(Placemark place) {
    List<String> addressParts = [];
    
    // Street number + street name
    if (place.street != null && place.street!.isNotEmpty) {
      addressParts.add(place.street!);
    }
    
    // Sub locality (neighborhood)
    if (place.subLocality != null && place.subLocality!.isNotEmpty) {
      addressParts.add(place.subLocality!);
    }
    
    // City/locality
    if (place.locality != null && place.locality!.isNotEmpty) {
      addressParts.add(place.locality!);
    }
    
    // State/subAdministrativeArea  
    if (place.subAdministrativeArea != null && place.subAdministrativeArea!.isNotEmpty) {
      addressParts.add(place.subAdministrativeArea!);
    }
    
    // Administrative area (state/province)
    if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
      addressParts.add(place.administrativeArea!);
    }
    
    // Postal code
    if (place.postalCode != null && place.postalCode!.isNotEmpty) {
      addressParts.add(place.postalCode!);
    }
    
    // Country
    if (place.country != null && place.country!.isNotEmpty) {
      addressParts.add(place.country!);
    }
    
    if (addressParts.isNotEmpty) {
      return addressParts.join(', ');
    } else {
      return 'Unknown location';
    }
  }
  
  // Convert Position to GeoPoint
  GeoPoint positionToGeoPoint(Position position) {
    return GeoPoint(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }
  
  // Calculate distance between two points
  double calculateDistance(GeoPoint point1, GeoPoint point2) {
    return Geolocator.distanceBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    ) / 1000; // Convert meters to kilometers
  }
  
  // NEW: Get distance dan address information together
  Future<Map<String, dynamic>> getLocationInfo(GeoPoint point1, GeoPoint point2) async {
    final distance = calculateDistance(point1, point2);
    
    final address1Future = getAddressFromCoordinates(point1.latitude, point1.longitude);
    final address2Future = getAddressFromCoordinates(point2.latitude, point2.longitude);
    
    final addresses = await Future.wait([address1Future, address2Future]);
    
    return {
      'distance_km': distance,
      'address_1': addresses[0],
      'address_2': addresses[1],
      'estimated_travel_time': _estimateTravelTime(distance),
    };
  }
  
  // Estimate travel time based on distance
  String _estimateTravelTime(double distanceKm) {
    // Assume average speed in urban area
    const double avgSpeedKmh = 40.0;
    final timeHours = distanceKm / avgSpeedKmh;
    
    if (timeHours < 1) {
      return '${(timeHours * 60).round()} min';
    } else {
      final hours = timeHours.floor();
      final minutes = ((timeHours - hours) * 60).round();
      return minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';
    }
  }
}