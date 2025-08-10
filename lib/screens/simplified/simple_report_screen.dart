// lib/screens/simplified/simple_report_screen.dart - USER ONLY VERSION
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../../config/theme.dart';
import '../../models/report_model.dart';
import '../../services/database_service.dart';
import '../../services/storage_service.dart';
import '../../services/location_service.dart';
import '../../services/api_service.dart';
import '../../services/gemini_service.dart';
import '../../utils/water_quality_utils.dart';
import '../../utils/complaint_utils.dart';
import '../../widgets/common/custom_loader.dart';

class SimpleReportScreen extends StatefulWidget {
  const SimpleReportScreen({
    Key? key,
  }) : super(key: key);

  @override
  _SimpleReportScreenState createState() => _SimpleReportScreenState();
}

class _SimpleReportScreenState extends State<SimpleReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _reporterNameController = TextEditingController();
  
  // Page controller for multi-step form
  late PageController _pageController;
  int _currentPage = 0;
  
  List<File> _imageFiles = [];
  List<String> _savedImagePaths = [];
  final int _maxImages = 10;
  
  // Complaint type dropdown selection
  ComplaintType? _selectedComplaintType;
  
  bool _isLoading = false;
  bool _isDetecting = false;
  bool _isSavingImages = false;
  WaterQualityState _detectedQuality = WaterQualityState.unknown;
  double? _confidence;
  String? _originalClass;
  
  // ENHANCED: Better error state management
  bool _waterDetected = false;
  String? _analysisMessage;
  bool _analysisCompleted = false;
  String? _detectionError;
  bool _isLowConfidence = false;
  bool _canSubmitWithLowConfidence = false;
  
  // ENHANCED: Double Detection results
  Map<String, dynamic>? _combinedAnalysisResult;
  
  late DatabaseService _databaseService;
  late StorageService _storageService;
  late LocationService _locationService;
  late ApiService _apiService;
  
  GeoPoint? _location;
  String? _autoAddress;
  
  @override
  void initState() {
    super.initState();
    _databaseService = Provider.of<DatabaseService>(context, listen: false);
    _storageService = Provider.of<StorageService>(context, listen: false);
    _locationService = Provider.of<LocationService>(context, listen: false);
    _apiService = Provider.of<ApiService>(context, listen: false);
    
    // Initialize page controller for multi-step form
    _pageController = PageController(initialPage: 0);
    
    // Set default reporter name for users
    _reporterNameController.text = 'Water Reporter';
    
    print('📱 SimpleReport initialized for user mode');
    _getCurrentLocation();
  }
  
  Future<void> _getCurrentLocation() async {
    try {
      setState(() => _isLoading = true);
      
      final position = await _locationService.getCurrentLocation();
      
      if (position != null) {
        final address = await _locationService.getAddressFromCoordinates(
          position.latitude,
          position.longitude,
        );
        
        setState(() {
          _location = _locationService.positionToGeoPoint(position);
          _autoAddress = address;
          _addressController.text = address;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error getting location: $e');
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _pickImage() async {
    if (_imageFiles.length >= _maxImages) {
      _showMessage('Maximum $_maxImages images allowed', isError: true);
      return;
    }
    
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            SizedBox(height: 20),
            Text('Add Photo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _buildImageSourceOption(
                  icon: Icons.camera_alt,
                  title: 'Camera',
                  subtitle: 'Take new photo',
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromSource(ImageSource.camera);
                  },
                )),
                SizedBox(width: 16),
                Expanded(child: _buildImageSourceOption(
                  icon: Icons.photo_library,
                  title: 'Gallery',
                  subtitle: 'Choose existing',
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromSource(ImageSource.gallery);
                  },
                )),
              ],
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
  
  Widget _buildImageSourceOption({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Icon(icon, size: 32, color: AppTheme.primaryColor),
            SizedBox(height: 8),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
  
  Future<void> _pickImageFromSource(ImageSource source) async {
    try {
      print('📷 Opening image picker...');
      final picker = ImagePicker();
      
      final pickedFile = await picker.pickImage(
        source: source, 
        imageQuality: 85,
        maxWidth: 1920,          
        maxHeight: 1080,         
        preferredCameraDevice: CameraDevice.rear,
      );
      
      if (pickedFile != null) {
        File imageFile = File(pickedFile.path);
        
        if (!await imageFile.exists()) {
          _showMessage('Error: Could not access selected image', isError: true);
          return;
        }
        
        try {
          setState(() => _isSavingImages = true);
          
          final processedImageFile = await _processImageForAnalysis(imageFile, source);
          final localPath = await _storageService.uploadImage(processedImageFile, 'reports');
          
          print('📁 Image saved to local storage: $localPath');
          
          setState(() {
            _imageFiles.add(File(localPath));
            _savedImagePaths.add(localPath);
            _isSavingImages = false;
          });
          
          // Reset analysis results when new image added
          if (_imageFiles.length == 1) {
            _resetAnalysisState();
          }
          
          _showMessage('Image processed and saved successfully!', isError: false);
          
          if (_imageFiles.length == 1) {
            print('🔬 Auto-analyzing first image...');
            await _detectWaterQuality(File(localPath));
          }
          
        } catch (e) {
          setState(() => _isSavingImages = false);
          _showMessage('Error processing image: $e', isError: true);
        }
      }
    } catch (e) {
      setState(() => _isSavingImages = false);
      _showMessage('Error picking image: $e', isError: true);
    }
  }

  Future<File> _processImageForAnalysis(File originalFile, ImageSource source) async {
    try {
      print('🔧 Processing image for analysis...');
      
      final imageBytes = await originalFile.readAsBytes();
      print('📏 Original size: ${(imageBytes.length / 1024).toStringAsFixed(2)} KB');
      
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final processedPath = path.join(tempDir.path, 'processed_${timestamp}.jpg');
      
      final processedFile = await originalFile.copy(processedPath);
      
      if (await processedFile.exists()) {
        final processedSize = await processedFile.length();
        print('✅ Image processed: ${(processedSize / 1024).toStringAsFixed(2)} KB');
        return processedFile;
      } else {
        throw Exception('Failed to create processed image');
      }
      
    } catch (e) {
      print('❌ Error processing image: $e');
      return originalFile;
    }
  }

  // ENHANCED: Water quality detection with double Detection (API + Gemini)
  Future<void> _detectWaterQuality(File image) async {
    try {
      _resetAnalysisState();
      setState(() => _isDetecting = true);
      
      print('🔬 Starting enhanced water quality detection...');
      
      // Validate image file
      if (!await image.exists()) {
        throw Exception('Image file does not exist');
      }
      
      final fileSize = await image.length();
      if (fileSize == 0) {
        throw Exception('Image file is empty');
      }
      
      print('📏 Image size: ${fileSize} bytes');
      
      // Test backend connection
      final isConnected = await _apiService.testBackendConnection();
      if (!isConnected) {
        throw Exception('Backend server is not running. Please start the Python server.');
      }
      
      print('✅ Backend connected, starting double verification analysis...');
      
      // Analyze water quality with double verification (API + Gemini)
      final combinedResult = await _apiService.analyzeWaterQualityWithDoubleVerification(image);
      
      final apiResult = combinedResult['api_result'] as WaterAnalysisResult;
      final geminiResult = combinedResult['gemini_result'] as GeminiAnalysisResult?;
      
      print('📊 Double verification results:');
      print('   API Water detected: ${apiResult.waterDetected}');
      print('   API Quality: ${apiResult.waterQuality}');
      print('   API Confidence: ${apiResult.confidence}%');
      if (geminiResult != null) {
        print('   Gemini Water detected: ${geminiResult.waterDetected}');
        print('   Gemini Safety: ${geminiResult.isSafe}');
        print('   Gemini Confidence: ${geminiResult.confidence}%');
      }
      print('   Final Safety: ${combinedResult['final_safety_assessment']}');
      print('   Agreement: ${combinedResult['agreement_level']}');
      
      setState(() {
        _waterDetected = apiResult.waterDetected;
        _confidence = combinedResult['combined_confidence'] as double;
        _originalClass = apiResult.originalClass;
        _analysisCompleted = true;
        _isDetecting = false;
        _isLowConfidence = apiResult.isLowConfidence;
        _canSubmitWithLowConfidence = true;
        
        // Store combined results for display
        _combinedAnalysisResult = combinedResult;
      });
      
      // ENHANCED: Handle all possible scenarios without blocking submission
      _handleAnalysisResult(apiResult, combinedResult);
      
    } catch (e) {
      print('❌ Double verification analysis failed: $e');
      
      setState(() {
        _isDetecting = false;
        _analysisCompleted = true;
        _detectionError = e.toString();
        _canSubmitWithLowConfidence = true;
      });
      
      _handleAnalysisError(e);
    }
  }
  
  // ENHANCED: Handle analysis results with double verification
  void _handleAnalysisResult(WaterAnalysisResult apiResult, Map<String, dynamic> combinedResult) {
    final finalSafety = combinedResult['final_safety_assessment'] as String;
    final recommendation = combinedResult['recommendation'] as String;
    final agreementLevel = combinedResult['agreement_level'] as String;
    
    if (!apiResult.waterDetected) {
      // NO WATER DETECTED
      _showMessage(
        'No water detected in image. You can still submit the report, but consider adding photos that clearly show water.',
        isError: false,
        duration: 6,
      );
      
    } else if (apiResult.isLowConfidence) {
      // LOW CONFIDENCE BUT DETECTED
      _showMessage(
        'Low confidence analysis completed. Double verification provides additional assessment.',
        isError: false,
        duration: 6,
      );
      
    } else if (apiResult.confidence != null && apiResult.confidence! > 0) {
      // SUCCESSFUL ANALYSIS
      if (finalSafety == 'Likely Safe') {
        _showMessage(
          'Double verification completed! Both analyses indicate safe water quality.',
          isError: false,
          duration: 6,
        );
      } else if (finalSafety == 'Likely Unsafe') {
        _showMessage(
          'Double verification completed! Both analyses indicate potential water quality issues.',
          isError: false,
          duration: 6,
        );
      } else {
        _showMessage(
          'Double verification completed with mixed results. Manual verification recommended.',
          isError: false,
          duration: 6,
        );
      }
      
    } else {
      // ANALYSIS FAILED BUT WATER DETECTED
      _showMessage(
        'Water detected but analysis had issues. You can still submit the report with your observations.',
        isError: false,
        duration: 6,
      );
    }
  }
  
  // ENHANCED: Handle analysis errors gracefully
  void _handleAnalysisError(dynamic error) {
    String userFriendlyMessage = 'Analysis error occurred, but you can still submit your report manually.';
    
    final errorStr = error.toString().toLowerCase();
    
    if (errorStr.contains('backend') || errorStr.contains('server')) {
      userFriendlyMessage = 'Backend server not available. You can still submit the report without AI analysis.';
    } else if (errorStr.contains('network') || errorStr.contains('connection')) {
      userFriendlyMessage = 'Network connection issue. You can still submit the report offline.';
    } else if (errorStr.contains('timeout')) {
      userFriendlyMessage = 'Analysis timeout. You can still submit the report with your manual assessment.';
    } else if (errorStr.contains('image')) {
      userFriendlyMessage = 'Image processing issue. Try another photo or submit with current observations.';
    }
    
    _showMessage(userFriendlyMessage, isError: false, duration: 8);
  }
  
  void _resetAnalysisState() {
    setState(() {
      _detectedQuality = WaterQualityState.unknown;
      _confidence = null;
      _originalClass = null;
      _waterDetected = false;
      _analysisMessage = null;
      _analysisCompleted = false;
      _detectionError = null;
      _isLowConfidence = false;
      _canSubmitWithLowConfidence = false;
      _combinedAnalysisResult = null;
    });
  }
  
  void _removeImage(int index) {
    if (index >= 0 && index < _imageFiles.length) {
      final file = _imageFiles[index];
      final localPath = _savedImagePaths[index];
      
      setState(() {
        _imageFiles.removeAt(index);
        _savedImagePaths.removeAt(index);
        
        if (_imageFiles.isEmpty) {
          _resetAnalysisState();
        }
      });
      
      try {
        if (file.existsSync()) {
          file.deleteSync();
          print('🗑️ Deleted local file: $localPath');
        }
      } catch (e) {
        print('❌ Error deleting local file: $e');
      }
    }
  }
  
  // ENHANCED: Allow submission regardless of analysis state
  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    if (_location == null) {
      _showMessage('Location is required. Please try again.', isError: true);
      return;
    }
    
    // ENHANCED: Show confirmation dialog for low confidence or no analysis
    if ((_isLowConfidence || _detectionError != null || !_waterDetected) && _imageFiles.isNotEmpty) {
      final shouldContinue = await _showSubmissionConfirmationDialog();
      if (!shouldContinue) return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      print('📝 Starting report submission...');
      
      final imageUrls = List<String>.from(_savedImagePaths);
      
      print('📸 Using ${imageUrls.length} local image paths');
      
      final now = DateTime.now();
      final report = ReportModel(
        id: '',
        userId: 'user_${now.millisecondsSinceEpoch}',
        userName: _reporterNameController.text.trim(),
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        location: _location!,
        address: _addressController.text.trim(),
        imageUrls: imageUrls,
        waterQuality: _detectedQuality,
        isResolved: false,
        createdAt: now,
        updatedAt: now,
        // New complaint fields
        complaintType: _selectedComplaintType ?? ComplaintType.poorQuality,
        priority: _selectedComplaintType != null 
            ? ReportModel.getPriorityFromComplaintType(_selectedComplaintType!) 
            : ComplaintPriority.medium,
        status: ComplaintStatus.new_,
      );
      
      final reportId = await _databaseService.createReport(report);
      
      print('✅ Report created successfully with ID: $reportId');
      
      if (mounted) {
        String successMessage = _buildSuccessMessage(imageUrls.length);
        _showMessage(successMessage, isError: false, duration: 6);
        Navigator.pop(context);
      }
      
    } catch (e) {
      print('❌ Error submitting report: $e');
      _showMessage('Error submitting report: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  // NEW: Show confirmation dialog for problematic submissions
  Future<bool> _showSubmissionConfirmationDialog() async {
    String title = 'Confirm Submission';
    String message = '';
    
    if (_detectionError != null) {
      title = 'Submit Without Analysis?';
      message = 'Your report and input matter — the authorities will review your submission.';
    } else if (!_waterDetected && _imageFiles.isNotEmpty) {
      title = 'No Water Detected';
      message = 'AI did not detect water in your images. Do you still want to submit this report?';
    } else if (_isLowConfidence) {
      title = 'Low Confidence Result';
      message = 'AI analysis has low confidence (${_confidence?.toStringAsFixed(1)}%). The result might not be accurate. Continue with submission?';
    } else {
      return true; // No confirmation needed
    }
    
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.help_outline, color: Colors.orange),
              SizedBox(width: 8),
              Text(title),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Retake'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: Text('Submit Anyway'),
            ),
          ],
        );
      },
    );
    
    return result ?? false;
  }
  
  String _buildSuccessMessage(int imageCount) {
    String baseMessage = 'Report submitted successfully with $imageCount image${imageCount == 1 ? '' : 's'}!';
    
    if (_analysisCompleted && _waterDetected && _confidence != null) {
      if (_combinedAnalysisResult != null) {
        final finalSafety = _combinedAnalysisResult!['final_safety_assessment'] as String;
        final agreementLevel = _combinedAnalysisResult!['agreement_level'] as String;
        
        baseMessage += '\nDouble verification completed with ${_confidence!.toStringAsFixed(1)}% combined confidence.';
        baseMessage += '\nFinal assessment: $finalSafety';
        baseMessage += '\nAgreement level: $agreementLevel';
      } else if (_isLowConfidence) {
        baseMessage += '\nSubmitted with low confidence analysis (${_confidence!.toStringAsFixed(1)}%).';
      } else if (_confidence! >= 80) {
        baseMessage += '\nHigh confidence analysis included (${_confidence!.toStringAsFixed(1)}%).';
      } else {
        baseMessage += '\nAnalysis included with ${_confidence!.toStringAsFixed(1)}% confidence.';
      }
    } else if (_analysisCompleted && !_waterDetected) {
      baseMessage += '\nSubmitted without water detection — manual assessment included.';
    } else if (_detectionError != null) {
      baseMessage += '\nSubmitted without AI analysis — manual assessment recorded.';
    }
    
    return baseMessage;
  }
  
  void _showMessage(String message, {required bool isError, int duration = 4}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(isError ? Icons.error : Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(message, style: TextStyle(fontSize: 14))),
            ],
          ),
          backgroundColor: isError ? Colors.red : Colors.green,
          duration: Duration(seconds: duration),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('Report Water Issue'),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          if (_imageFiles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.folder, size: 12, color: Colors.white),
                      SizedBox(width: 4),
                      Text('${_imageFiles.length}/$_maxImages', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading && !_isSavingImages
        ? Center(child: WaterFillLoader(message: 'Getting your location...'))
        : Container(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Step indicator
                  _buildStepIndicator(),
                  
                  // Page view for multi-step form
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: NeverScrollableScrollPhysics(), // Disable swiping
                      onPageChanged: (int page) {
                        setState(() {
                          _currentPage = page;
                        });
                      },
                      children: [
                        // Page 1: Photo Upload
                        _buildPhotoUploadPage(),
                        
                        // Page 2: Form Details
                        _buildFormDetailsPage(),
                      ],
                    ),
                  ),
                  
                  // Navigation buttons
                  _buildNavigationButtons(),
                ],
              ),
            ),
          ),
    );
  }
  
  // Step indicator to show current progress
  Widget _buildStepIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        children: [
          _buildStepCircle(0, 'Photos'),
          _buildStepConnector(_currentPage > 0),
          _buildStepCircle(1, 'Details'),
        ],
      ),
    );
  }
  
  // Individual step circle for the step indicator
  Widget _buildStepCircle(int step, String label) {
    final isActive = _currentPage >= step;
    final isCurrent = _currentPage == step;
    
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isActive ? AppTheme.primaryColor : Colors.grey.shade300,
              shape: BoxShape.circle,
              border: isCurrent ? Border.all(color: AppTheme.primaryColor, width: 3) : null,
              boxShadow: isCurrent ? [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 2,
                )
              ] : null,
            ),
            child: Center(
              child: Text(
                '${step + 1}',
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.grey.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: isActive ? AppTheme.primaryColor : Colors.grey.shade600,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
  
  // Connector line between step circles
  Widget _buildStepConnector(bool isActive) {
    return Container(
      width: 60,
      height: 4,
      color: isActive ? AppTheme.primaryColor : Colors.grey.shade300,
    );
  }
  
  // Page 1: Photo Upload
  Widget _buildPhotoUploadPage() {
    return ListView(
      children: [
        // Header Card
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.primaryColor.withOpacity(0.1), AppTheme.primaryColor.withOpacity(0.05)],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppTheme.primaryColor, borderRadius: BorderRadius.circular(12)),
                        child: Icon(Icons.photo_camera, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Upload Photos',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Take photos of the water issue (optional)',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                            ),
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
        
        const SizedBox(height: 16),
        
        // Photos Grid
        if (_imageFiles.isNotEmpty) _buildPhotosGrid(),
        
        // Analysis Results
        if (_isDetecting) _buildAnalyzingCard()
        else if (_analysisCompleted) _buildAnalysisResultCard()
        else if (_imageFiles.isNotEmpty) _buildAnalysisPrompt(),
        
        // Camera Button
        _buildCameraButton(),
        
        const SizedBox(height: 16),
        
        // Skip Photos Info Card
        if (_imageFiles.isEmpty)
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade300, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    'No Photos Added',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You can continue without adding photos, but adding photos helps us better analyze the water issue.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPhotosGrid() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Saved Photos', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getAnalysisStatusColor().withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_getAnalysisStatusIcon(), size: 12, color: _getAnalysisStatusColor()),
                      SizedBox(width: 4),
                      Text(_getAnalysisStatusText(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _getAnalysisStatusColor())),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _imageFiles.length,
              itemBuilder: (context, index) => _buildImageTile(index),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageTile(int index) {
    final isMainPhoto = index == 0;
    final file = _imageFiles[index];
    
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: isMainPhoto 
                ? Border.all(color: AppTheme.primaryColor, width: 3)
                : Border.all(color: Colors.grey.shade300, width: 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Container(
              width: double.infinity,
              height: double.infinity,
              child: file.existsSync()
                  ? Image.file(file, fit: BoxFit.cover)
                  : Container(
                      color: Colors.grey.shade200,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.folder, color: Colors.grey.shade400, size: 20),
                          SizedBox(height: 4),
                          Text('Local\nStorage', style: TextStyle(fontSize: 8, color: Colors.grey.shade600), textAlign: TextAlign.center),
                        ],
                      ),
                    ),
            ),
          ),
        ),
        
        if (isMainPhoto)
          Positioned(
            top: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: AppTheme.primaryColor, borderRadius: BorderRadius.circular(6)),
              child: Text('MAIN', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
            ),
          ),
        
        // Analysis status
        if (isMainPhoto && _analysisCompleted)
          Positioned(
            bottom: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(color: _getAnalysisStatusColor(), borderRadius: BorderRadius.circular(4)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_getAnalysisStatusIcon(), color: Colors.white, size: 8),
                  SizedBox(width: 2),
                  Text(_getAnalysisStatusText(), style: TextStyle(color: Colors.white, fontSize: 6, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => _removeImage(index),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.close, color: Colors.white, size: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCameraButton() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              _isSavingImages ? Icons.hourglass_empty : Icons.add_a_photo,
              size: 48,
              color: _isSavingImages 
                  ? Colors.orange 
                  : _imageFiles.length < _maxImages 
                      ? AppTheme.primaryColor 
                      : Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              _isSavingImages
                  ? 'Processing for Analysis...'
                  : _imageFiles.isEmpty 
                      ? 'Take Your First Photo' 
                      : _imageFiles.length < _maxImages 
                          ? 'Add Another Photo' 
                          : 'Maximum Photos Reached',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _isSavingImages || _imageFiles.length < _maxImages 
                    ? Colors.black87 
                    : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isSavingImages
                  ? 'Preparing for enhanced water detection...'
                  : _imageFiles.isEmpty
                      ? 'AI will analyze for water presence and quality'
                      : 'Multiple photos improve detection accuracy',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_imageFiles.length < _maxImages && !_isSavingImages) ? _pickImage : null,
                icon: _isSavingImages
                    ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                    : Icon(_imageFiles.isEmpty ? Icons.camera_alt : Icons.add_a_photo),
                label: Text(
                  _isSavingImages
                      ? 'Processing...'
                      : _imageFiles.isEmpty 
                          ? 'Take Photo' 
                          : _imageFiles.length < _maxImages 
                              ? 'Add More Photos' 
                              : 'Limit Reached',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _imageFiles.length < _maxImages && !_isSavingImages ? AppTheme.primaryColor : Colors.grey.shade400,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyzingCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue.shade50, Colors.blue.shade100.withOpacity(0.3)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [Colors.blue, Colors.blue.shade300]),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: CircularProgressIndicator(strokeWidth: 4, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                ),
              ),
              const SizedBox(height: 20),
              Text('Double Verification Analysis', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue.shade800)),
              const SizedBox(height: 8),
              Text(
                'AI models are analyzing your image for enhanced accuracy and safety assessment.',
                style: TextStyle(color: Colors.blue.shade600, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(8)),
                    child: Text('API Model', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                  ),
                  SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.purple.shade100, borderRadius: BorderRadius.circular(8)),
                    child: Text('Gemini AI', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.purple.shade700)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: BorderRadius.circular(20)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text('Double Verification in Progress...', style: TextStyle(fontSize: 12, color: Colors.blue.shade700, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnalysisPrompt() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.primaryColor.withOpacity(0.1), AppTheme.primaryColor.withOpacity(0.05)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(Icons.psychology, size: 40, color: AppTheme.primaryColor),
              ),
              const SizedBox(height: 16),
              Text('Ready for Double Verification', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
              const SizedBox(height: 8),
              Text(
                'Your photos are ready for enhanced analysis using AI models for better accuracy and safety assessment.',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 14, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _detectWaterQuality(_imageFiles.first),
                  icon: Icon(Icons.verified, size: 24),
                  label: Text('Start Double Verification', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ENHANCED: Comprehensive analysis result display with double verification
  Widget _buildAnalysisResultCard() {
    if (!_analysisCompleted) return Container();
    
    Color resultColor = _waterDetected 
        ? (_isLowConfidence ? Colors.amber : WaterQualityUtils.getWaterQualityColor(_detectedQuality))
        : (_detectionError != null ? Colors.red : Colors.orange);
    
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, resultColor.withOpacity(0.03)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with double verification indicator
              Row(
                children: [
                  Icon(Icons.verified, color: Colors.blue, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Double Verification Analysis',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                  Spacer(),
                  if (_combinedAnalysisResult != null)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Two AI Models',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                    ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Main result content
              _buildResultContent(resultColor),
              
              const SizedBox(height: 16),
              
              // ENHANCED: Double verification details
              if (_combinedAnalysisResult != null)
                _buildDoubleVerificationDetails(),
              
              const SizedBox(height: 16),
              
              // ENHANCED: Always show submission option
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.green.shade50, Colors.green.shade100.withOpacity(0.3)]),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your Report and Input Matter — The Authorities Will Review Your Submission',
                        style: TextStyle(fontSize: 12, color: Colors.green.shade800, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildResultContent(Color resultColor) {
    if (_detectionError != null) {
      // ERROR CASE
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Analysis Error', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red.shade800)),
            const SizedBox(height: 8),
            Text(
              'AI analysis encountered an error, but you can still submit this report with your manual assessment.',
              style: TextStyle(fontSize: 14, color: Colors.red.shade700),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    } else if (!_waterDetected) {
      // NO WATER DETECTED
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(Icons.warning_amber, size: 48, color: Colors.orange),
            const SizedBox(height: 16),
            Text('No Water Detected', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
            const SizedBox(height: 8),
            Text(
              _analysisMessage ?? 'AI did not detect water in your image. You can still submit if you observed water quality issues.',
              style: TextStyle(fontSize: 14, color: Colors.orange.shade700),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    } else {
      // WATER DETECTED
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: resultColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: resultColor.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: resultColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: resultColor.withOpacity(0.3), blurRadius: 8, offset: Offset(0, 4))],
                  ),
                  child: Icon(WaterQualityUtils.getWaterQualityIcon(_detectedQuality), color: Colors.white, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Water Quality Result",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: resultColor),
                      ),
                      const SizedBox(height: 4),
                      if (_originalClass != null && _originalClass!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: resultColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('$_originalClass', style: TextStyle(fontSize: 14, color: resultColor, fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            
            if (_confidence != null) ...[
              const SizedBox(height: 16),
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Confidence Level', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getConfidenceColor(_confidence!),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text('${_confidence!.toStringAsFixed(1)}%', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 8,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), color: Colors.grey.shade200),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _confidence! / 100,
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(_getConfidenceColor(_confidence!)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    }
  }

  // Helper methods for status display
  Color _getAnalysisStatusColor() {
    if (_detectionError != null) return Colors.red;
    if (!_waterDetected && _analysisCompleted) return Colors.orange;
    if (_isLowConfidence) return Colors.amber;
    if (_confidence != null && _confidence! >= 80) return Colors.green;
    return Colors.lightGreen;
  }
  
  IconData _getAnalysisStatusIcon() {
    if (_detectionError != null) return Icons.error;
    if (!_waterDetected && _analysisCompleted) return Icons.warning;
    if (_isLowConfidence) return Icons.info;
    return Icons.check_circle;
  }
  
  String _getAnalysisStatusText() {
    if (_detectionError != null) return 'ERROR';
    if (!_waterDetected && _analysisCompleted) return 'NO H2O';
    if (_isLowConfidence) return 'LOW';
    if (_confidence != null && _confidence! >= 80) return 'HIGH';
    return 'OK';
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 90) return Colors.green.shade600;
    if (confidence >= 80) return Colors.lightGreen.shade600;
    if (confidence >= 70) return Colors.orange.shade600;
    if (confidence >= 60) return Colors.deepOrange.shade600;
    return Colors.red.shade600;
  }
  
  // ENHANCED: Build double verification details
  Widget _buildDoubleVerificationDetails() {
    if (_combinedAnalysisResult == null) return Container();
    
    final apiResult = _combinedAnalysisResult!['api_result'] as WaterAnalysisResult;
    final geminiResult = _combinedAnalysisResult!['gemini_result'] as GeminiAnalysisResult?;
    final finalSafety = _combinedAnalysisResult!['final_safety_assessment'] as String;
    final agreementLevel = _combinedAnalysisResult!['agreement_level'] as String;
    final recommendation = _combinedAnalysisResult!['recommendation'] as String;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.compare_arrows, color: Colors.blue, size: 20),
              SizedBox(width: 8),
              Text(
                'Double Verification Results',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
              ),
            ],
          ),
          SizedBox(height: 12),
          
          // API Results
          _buildAnalysisComparisonRow(
            'API Analysis',
            apiResult.waterDetected ? 'Water Detected' : 'No Water',
            apiResult.confidence,
            apiResult.waterQuality == WaterQualityState.optimum ? 'Safe' : 'Needs Attention',
            Colors.green,
          ),
          
          SizedBox(height: 8),
          
          // Gemini Results
          if (geminiResult != null)
            _buildAnalysisComparisonRow(
              'Gemini Analysis',
              geminiResult.waterDetected ? 'Water Detected' : 'No Water',
              geminiResult.confidence,
              geminiResult.isSafe ? 'Safe' : 'Unsafe',
              Colors.purple,
            ),
          
          SizedBox(height: 12),
          
          // Final Assessment
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getFinalSafetyColor(finalSafety).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _getFinalSafetyColor(finalSafety).withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.security, color: _getFinalSafetyColor(finalSafety), size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Final Safety Assessment',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _getFinalSafetyColor(finalSafety)),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  finalSafety,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _getFinalSafetyColor(finalSafety)),
                ),
                SizedBox(height: 4),
                Text(
                  recommendation,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          
          SizedBox(height: 8),
          
          // Agreement Level
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: agreementLevel == 'High Agreement' ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Agreement: $agreementLevel',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: agreementLevel == 'High Agreement' ? Colors.green : Colors.orange,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAnalysisComparisonRow(String title, String detection, double? confidence, String safety, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        Text(
          detection,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        SizedBox(width: 8),
        if (confidence != null)
          Text(
            '${confidence.toStringAsFixed(1)}%',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
          ),
        SizedBox(width: 8),
        Text(
          safety,
          style: TextStyle(fontSize: 12, color: color),
        ),
      ],
    );
  }
  
  Color _getFinalSafetyColor(String safety) {
    switch (safety) {
      case 'Likely Safe':
        return Colors.green;
      case 'Likely Unsafe':
        return Colors.red;
      case 'Needs Further Assessment':
        return Colors.orange;
      case 'No Water Detected':
        return Colors.grey;
      case 'Partial Detection':
        return Colors.amber;
      default:
        return Colors.blue;
    }
  }

  Widget _buildDetailsSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.description, color: AppTheme.primaryColor),
                const SizedBox(width: 12),
                Text('Report Details', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 20),
            
            TextFormField(
              controller: _reporterNameController,
              decoration: InputDecoration(
                labelText: 'Reporter Name *',
                hintText: 'Your name',
                prefixIcon: Icon(Icons.person),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter reporter name';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // Complaint Type Dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey.shade400),
              ),
              child: DropdownButtonFormField<ComplaintType>(
                value: _selectedComplaintType,
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.report_problem),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                hint: Text('Select Complaint Type *'),
                isExpanded: true,
                icon: Icon(Icons.arrow_drop_down),
                items: ComplaintUtils.getAllComplaintTypes().map((ComplaintType type) {
                  final color = ComplaintUtils.getComplaintTypeColor(type);
                  return DropdownMenuItem<ComplaintType>(
                    value: type,
                    child: Row(
                      children: [
                        Icon(ComplaintUtils.getComplaintTypeIcon(type), color: color, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            ComplaintUtils.getComplaintTypeText(type),
                            style: TextStyle(color: Colors.black87),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: ComplaintUtils.getComplaintPriorityColor(
                              ReportModel.getPriorityFromComplaintType(type)
                            ).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            ComplaintUtils.getComplaintPriorityText(
                              ReportModel.getPriorityFromComplaintType(type)
                            ),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: ComplaintUtils.getComplaintPriorityColor(
                                ReportModel.getPriorityFromComplaintType(type)
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (ComplaintType? newValue) {
                  setState(() {
                    _selectedComplaintType = newValue;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Please select a complaint type';
                  }
                  return null;
                },
              ),
            ),
            
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Issue Title *',
                hintText: 'Brief title describing the issue',
                prefixIcon: Icon(Icons.title),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Description *',
                hintText: 'Detailed description of the water issue',
                prefixIcon: Icon(Icons.description),
                alignLabelWithHint: true,
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a description';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _addressController,
              decoration: InputDecoration(
                labelText: 'Location Address *',
                hintText: 'Where is this issue located?',
                prefixIcon: const Icon(Icons.location_on),
                filled: true,
                fillColor: Colors.grey.shade50,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.my_location),
                  onPressed: _getCurrentLocation,
                  tooltip: 'Use current location',
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter the location';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }
  
  // Page 2: Form Details
  Widget _buildFormDetailsPage() {
    return ListView(
      children: [
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.primaryColor.withOpacity(0.1), AppTheme.primaryColor.withOpacity(0.05)],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppTheme.primaryColor, borderRadius: BorderRadius.circular(12)),
                        child: Icon(Icons.edit_note, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Report Details',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Provide information about the water issue',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                            ),
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
        
        const SizedBox(height: 16),
        
        // Form fields
        _buildDetailsSection(),
        
        const SizedBox(height: 16),
      ],
    );
  }
  
  // Navigation buttons for moving between steps
  Widget _buildNavigationButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back button (hidden on first page)
          _currentPage > 0
              ? ElevatedButton.icon(
                  onPressed: () {
                    _pageController.previousPage(
                      duration: Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  icon: Icon(Icons.arrow_back),
                  label: Text('Back'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade200,
                    foregroundColor: Colors.black87,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                )
              : SizedBox(width: 100), // Empty space to maintain layout
          
          // Next/Skip button (on first page) or Submit button (on last page)
          _currentPage == 0
              ? ElevatedButton.icon(
                  onPressed: () {
                    _pageController.nextPage(
                      duration: Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  icon: Text(_imageFiles.isEmpty ? 'Skip' : 'Next'),
                  label: Icon(_imageFiles.isEmpty ? Icons.skip_next : Icons.arrow_forward),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                )
              : _buildSubmitButton(),
        ],
      ),
    );
  }
  
  Widget _buildSubmitButton() {
    return ElevatedButton.icon(
      onPressed: (_isLoading || _isSavingImages) ? null : _submitReport,
      icon: Icon(Icons.send, size: 24),
      label: Text(
        _isLoading || _isSavingImages
            ? (_isSavingImages 
                ? 'Preparing...'
                : 'Submitting...')
            : 'Submit Report',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
  
  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _reporterNameController.dispose();
    _pageController.dispose();
    super.dispose();
  }
}