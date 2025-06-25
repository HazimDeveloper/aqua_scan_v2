
// lib/services/location_service.dart
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../models/report_model.dart';

class LocationService {
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
  
  // Get address from coordinates
  Future<String> getAddressFromCoordinates(double latitude, double longitude) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        return [
          place.street,
          place.subLocality,
          place.locality,
          place.postalCode,
          place.country,
        ].where((e) => e != null && e.isNotEmpty).join(', ');
      }
      
      return 'Unknown location';
    } catch (e) {
      throw Exception('Failed to get address: $e');
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
}