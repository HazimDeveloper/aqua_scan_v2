// lib/models/route_model.dart - FIXED FOR LOCAL STORAGE ONLY
// Removed Firebase dependencies
import 'package:aquascan_v2/models/report_model.dart';

class RouteModel {
  final String id;
  final String adminId;
  final List<String> reportIds;
  final List<RoutePoint> points;
  final List<RouteSegment> segments;
  final double totalDistance;
  final DateTime createdAt;
  final DateTime updatedAt;

  RouteModel({
    required this.id,
    required this.adminId,
    required this.reportIds,
    required this.points,
    required this.segments,
    required this.totalDistance,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RouteModel.fromJson(Map<String, dynamic> json) {
    try {
      // Handle reportIds safely
      List<String> reportIds = [];
      if (json['reportIds'] != null) {
        reportIds = List<String>.from((json['reportIds'] as List<dynamic>).map((e) => e.toString()));
      }

      // Handle points safely
      List<RoutePoint> points = [];
      if (json['points'] != null) {
        points = (json['points'] as List<dynamic>).map((point) {
          if (point != null && point is Map<String, dynamic>) {
            try {
              return RoutePoint.fromJson(point);
            } catch (e) {
              print('Error creating RoutePoint: $e');
              return RoutePoint(
                nodeId: '',
                location: GeoPoint(latitude: 0, longitude: 0),
                address: '',
              );
            }
          } else {
            return RoutePoint(
              nodeId: '',
              location: GeoPoint(latitude: 0, longitude: 0),
              address: '',
            );
          }
        }).toList();
      }

      // Handle segments safely
      List<RouteSegment> segments = [];
      if (json['segments'] != null) {
        segments = (json['segments'] as List<dynamic>).map((segment) {
          if (segment != null && segment is Map<String, dynamic>) {
            try {
              return RouteSegment.fromJson(segment);
            } catch (e) {
              print('Error creating RouteSegment: $e');
              return RouteSegment(
                from: RoutePoint(
                  nodeId: '',
                  location: GeoPoint(latitude: 0, longitude: 0),
                  address: '',
                ),
                to: RoutePoint(
                  nodeId: '',
                  location: GeoPoint(latitude: 0, longitude: 0),
                  address: '',
                ),
                distance: 0.0,
                polyline: [],
              );
            }
          } else {
            return RouteSegment(
              from: RoutePoint(
                nodeId: '',
                location: GeoPoint(latitude: 0, longitude: 0),
                address: '',
              ),
              to: RoutePoint(
                nodeId: '',
                location: GeoPoint(latitude: 0, longitude: 0),
                address: '',
              ),
              distance: 0.0,
              polyline: [],
            );
          }
        }).toList();
      }

      // FIXED: Handle dates without Firebase Timestamp
      DateTime createdAt = DateTime.now();
      if (json['createdAt'] != null) {
        final createdAtValue = json['createdAt'];
        if (createdAtValue is String) {
          try {
            createdAt = DateTime.parse(createdAtValue);
          } catch (e) {
            print('Error parsing createdAt: $e');
          }
        } else if (createdAtValue is int) {
          createdAt = DateTime.fromMillisecondsSinceEpoch(createdAtValue);
        } else {
          // Handle Timestamp if it somehow exists
          try {
            createdAt = (createdAtValue as dynamic).toDate();
          } catch (e) {
            print('Error parsing createdAt timestamp: $e');
          }
        }
      }

      DateTime updatedAt = DateTime.now();
      if (json['updatedAt'] != null) {
        final updatedAtValue = json['updatedAt'];
        if (updatedAtValue is String) {
          try {
            updatedAt = DateTime.parse(updatedAtValue);
          } catch (e) {
            print('Error parsing updatedAt: $e');
          }
        } else if (updatedAtValue is int) {
          updatedAt = DateTime.fromMillisecondsSinceEpoch(updatedAtValue);
        } else {
          // Handle Timestamp if it somehow exists
          try {
            updatedAt = (updatedAtValue as dynamic).toDate();
          } catch (e) {
            print('Error parsing updatedAt timestamp: $e');
          }
        }
      }

      return RouteModel(
        id: json['id']?.toString() ?? '',
        adminId: json['adminId']?.toString() ?? '',
        reportIds: reportIds,
        points: points,
        segments: segments,
        totalDistance: (json['totalDistance'] as num?)?.toDouble() ?? 0.0,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
    } catch (e, stackTrace) {
      print('Error in RouteModel.fromJson: $e');
      print('Stack trace: $stackTrace');
      print('JSON data: $json');
      
      // Return a minimal valid model rather than throwing
      return RouteModel(
        id: 'error-${DateTime.now().millisecondsSinceEpoch}',
        adminId: '',
        reportIds: [],
        points: [],
        segments: [],
        totalDistance: 0.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
  }

  // FIXED: Store dates as ISO strings
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'adminId': adminId,
      'reportIds': reportIds,
      'points': points.map((point) => point.toJson()).toList(),
      'segments': segments.map((segment) => segment.toJson()).toList(),
      'totalDistance': totalDistance,
      'createdAt': createdAt.toIso8601String(), // Store as ISO string
      'updatedAt': updatedAt.toIso8601String(), // Store as ISO string
    };
  }

  RouteModel copyWith({required String id}) {
    return RouteModel(
      id: id,
      adminId: adminId,
      reportIds: reportIds,
      points: points,
      segments: segments,
      totalDistance: totalDistance,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}