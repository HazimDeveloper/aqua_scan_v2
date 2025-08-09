// lib/utils/complaint_utils.dart

import 'package:flutter/material.dart';
import '../models/report_model.dart';

class ComplaintUtils {
  // Get user-friendly text for complaint types
  static String getComplaintTypeText(ComplaintType type) {
    switch (type) {
      case ComplaintType.billingIssues:
        return 'Billing Issues';
      case ComplaintType.supplyDisruption:
        return 'Supply Disruption';
      case ComplaintType.poorQuality:
        return 'Poor Water Quality';
      case ComplaintType.pollution:
        return 'Water Pollution';
      case ComplaintType.leakingPipes:
        return 'Leaking Pipes';
      case ComplaintType.lowPressure:
        return 'Low Water Pressure';
      case ComplaintType.noAccess:
        return 'No Water Access';
      case ComplaintType.chemicalSpill:
        return 'Chemical Spill';
      case ComplaintType.other:
        return 'Other Issue';
      default:
        return 'Unknown Issue';
    }
  }

  // Get color for complaint type
  static Color getComplaintTypeColor(ComplaintType type) {
    final priority = ReportModel.getPriorityFromComplaintType(type);
    return getPriorityColor(priority);
  }

  // Get color for priority
  static Color getPriorityColor(ComplaintPriority priority) {
    switch (priority) {
      case ComplaintPriority.low:
        return Colors.amber; // Yellow
      case ComplaintPriority.medium:
        return Colors.orange; // Orange
      case ComplaintPriority.high:
        return Colors.red; // Red
      case ComplaintPriority.critical:
        return Colors.purple; // Purple
      default:
        return Colors.blue; // Default
    }
  }
  
  // Get complaint priority color (alias for getPriorityColor for consistency)
  static Color getComplaintPriorityColor(ComplaintPriority priority) {
    return getPriorityColor(priority);
  }

  // Get priority text
  static String getPriorityText(ComplaintPriority priority) {
    switch (priority) {
      case ComplaintPriority.low:
        return 'Low Priority';
      case ComplaintPriority.medium:
        return 'Medium Priority';
      case ComplaintPriority.high:
        return 'High Priority';
      case ComplaintPriority.critical:
        return 'Critical Priority';
      default:
        return 'Unknown Priority';
    }
  }
  
  // Get complaint priority text (alias for getPriorityText for consistency)
  static String getComplaintPriorityText(ComplaintPriority priority) {
    return getPriorityText(priority);
  }
  
  // Get complaint priority icon
  static IconData getComplaintPriorityIcon(ComplaintPriority priority) {
    switch (priority) {
      case ComplaintPriority.low:
        return Icons.info_outline;
      case ComplaintPriority.medium:
        return Icons.warning_amber_outlined;
      case ComplaintPriority.high:
        return Icons.priority_high;
      case ComplaintPriority.critical:
        return Icons.report_problem;
      default:
        return Icons.help_outline;
    }
  }

  // Get status text
  static String getStatusText(ComplaintStatus status) {
    switch (status) {
      case ComplaintStatus.new_:
        return 'New';
      case ComplaintStatus.inProgress:
        return 'In Progress';
      case ComplaintStatus.resolved:
        return 'Resolved';
      case ComplaintStatus.closed:
        return 'Closed';
      default:
        return 'Unknown Status';
    }
  }

  // Get complaint status text (alias for getStatusText for consistency)
  static String getComplaintStatusText(ComplaintStatus status) {
    return getStatusText(status);
  }

  // Get status color
  static Color getStatusColor(ComplaintStatus status) {
    switch (status) {
      case ComplaintStatus.new_:
        return Colors.blue;
      case ComplaintStatus.inProgress:
        return Colors.orange;
      case ComplaintStatus.resolved:
        return Colors.green;
      case ComplaintStatus.closed:
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }
  
  // Get complaint status color (alias for getStatusColor for consistency)
  static Color getComplaintStatusColor(ComplaintStatus status) {
    return getStatusColor(status);
  }
  
  // Get complaint status icon
  static IconData getComplaintStatusIcon(ComplaintStatus status) {
    switch (status) {
      case ComplaintStatus.new_:
        return Icons.fiber_new;
      case ComplaintStatus.inProgress:
        return Icons.pending;
      case ComplaintStatus.resolved:
        return Icons.check_circle;
      case ComplaintStatus.closed:
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  // Get complaint type description
  static String getComplaintTypeDescription(ComplaintType type) {
    switch (type) {
      case ComplaintType.billingIssues:
        return 'Issues related to water billing, charges, or payment problems';
      case ComplaintType.supplyDisruption:
        return 'Complete disruption of water supply to your area';
      case ComplaintType.poorQuality:
        return 'Water appears discolored, has bad taste or odor';
      case ComplaintType.pollution:
        return 'Suspected contamination or pollution of water sources';
      case ComplaintType.leakingPipes:
        return 'Water leakage from pipes, meters, or connections';
      case ComplaintType.lowPressure:
        return 'Insufficient water pressure from taps or outlets';
      case ComplaintType.noAccess:
        return 'No access to clean water or water services';
      case ComplaintType.chemicalSpill:
        return 'Chemical spill affecting water supply or sources';
      case ComplaintType.other:
        return 'Other water-related issues not listed above';
      default:
        return 'Please provide details about your water-related issue';
    }
  }

  // Get icon for complaint type
  static IconData getComplaintTypeIcon(ComplaintType type) {
    switch (type) {
      case ComplaintType.billingIssues:
        return Icons.receipt_long;
      case ComplaintType.supplyDisruption:
        return Icons.water_drop_outlined;
      case ComplaintType.poorQuality:
        return Icons.opacity;
      case ComplaintType.pollution:
        return Icons.warning_amber;
      case ComplaintType.leakingPipes:
        return Icons.plumbing;
      case ComplaintType.lowPressure:
        return Icons.speed;
      case ComplaintType.noAccess:
        return Icons.not_interested;
      case ComplaintType.chemicalSpill:
        return Icons.science;
      case ComplaintType.other:
        return Icons.help_outline;
      default:
        return Icons.help_outline;
    }
  }

  // Get all complaint types as a list for dropdown
  static List<ComplaintType> getAllComplaintTypes() {
    return ComplaintType.values.toList();
  }
}