import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../utils/colors.dart';
import '../../services/driver_verification_service.dart';
import '../../services/simplified_unified_auth_service.dart';
import '../../models/driver_document.dart';

class DocumentUploadScreen extends StatefulWidget {
  final DriverDocument document;

  const DocumentUploadScreen({super.key, required this.document});

  @override
  State<DocumentUploadScreen> createState() => _DocumentUploadScreenState();
}

class _DocumentUploadScreenState extends State<DocumentUploadScreen> {
  final _verificationService = DriverVerificationService();
  final _authService = SimplifiedUnifiedAuthService();
  final _picker = ImagePicker();

  File? _frontImage;
  File? _backImage;
  bool _isUploading = false;

  bool get _needsBackImage =>
      widget.document.documentType != 'profile_photo';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.document.displayName,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status banner
            if (widget.document.isRejected)
              Container(
                color: AppColors.error.withOpacity(0.1),
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.error, color: AppColors.error),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Document Rejected',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.error,
                            ),
                          ),
                          if (widget.document.rejectionReason != null) ...[
                            SizedBox(height: 4),
                            Text(
                              widget.document.rejectionReason!,
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.error,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else if (widget.document.isPending)
              Container(
                color: AppColors.warning.withOpacity(0.1),
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.schedule, color: AppColors.warning),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your document is under review. This typically takes 1-2 business days.',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else if (widget.document.isCompleted)
              Container(
                color: AppColors.success.withOpacity(0.1),
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: AppColors.success),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Document approved! You can update it anytime if needed.',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            SizedBox(height: 24),

            // Instructions
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getInstructions(),
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 16),
                  _buildTips(),
                ],
              ),
            ),

            SizedBox(height: 24),

            // Front image upload
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _needsBackImage ? 'Front Side' : 'Photo',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 8),
                  _buildImagePicker(
                    image: _frontImage,
                    existingUrl: widget.document.frontImageUrl,
                    onTap: () => _pickImage(true),
                  ),
                ],
              ),
            ),

            // Back image upload (if needed)
            if (_needsBackImage) ...[
              SizedBox(height: 24),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Back Side',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 8),
                    _buildImagePicker(
                      image: _backImage,
                      existingUrl: widget.document.backImageUrl,
                      onTap: () => _pickImage(false),
                    ),
                  ],
                ),
              ),
            ],

            SizedBox(height: 32),

            // Submit button
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _canSubmit() ? _submitDocument : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.divider,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isUploading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Submit Document',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),

            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePicker({
    File? image,
    String? existingUrl,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider, width: 2),
        ),
        child: image != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(image, fit: BoxFit.cover),
              )
            : existingUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(existingUrl, fit: BoxFit.cover),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_a_photo,
                        size: 48,
                        color: AppColors.textSecondary,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Tap to upload',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildTips() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline,
                  size: 20, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'Tips for best results',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          _buildTip('Ensure good lighting'),
          _buildTip('Keep document flat and in frame'),
          _buildTip('Make sure all text is readable'),
          _buildTip('Avoid glare and shadows'),
        ],
      ),
    );
  }

  Widget _buildTip(String text) {
    return Padding(
      padding: EdgeInsets.only(left: 28, top: 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getInstructions() {
    switch (widget.document.documentType) {
      case 'profile_photo':
        return 'Upload a clear photo of yourself. This will be visible to passengers.';
      case 'driving_license':
        return 'Upload both sides of your valid driving license.';
      case 'vehicle_insurance':
        return 'Upload your current vehicle insurance certificate.';
      case 'revenue_license':
        return 'Upload your valid revenue license for passenger transport.';
      case 'vehicle_registration':
        return 'Upload your vehicle registration certificate.';
      default:
        return 'Upload the required document.';
    }
  }

  Future<void> _pickImage(bool isFront) async {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt, color: AppColors.primary),
              title: Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _getImage(ImageSource.camera, isFront);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: AppColors.primary),
              title: Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _getImage(ImageSource.gallery, isFront);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _getImage(ImageSource source, bool isFront) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (pickedFile != null) {
        setState(() {
          if (isFront) {
            _frontImage = File(pickedFile.path);
          } else {
            _backImage = File(pickedFile.path);
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick image: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  bool _canSubmit() {
    if (_isUploading) return false;
    if (_frontImage == null && widget.document.frontImageUrl == null) {
      return false;
    }
    if (_needsBackImage &&
        _backImage == null &&
        widget.document.backImageUrl == null) {
      return false;
    }
    return true;
  }

  Future<void> _submitDocument() async {
    setState(() => _isUploading = true);

    try {
      final user = _authService.currentUser;
      if (user == null) return;

      String? frontUrl = widget.document.frontImageUrl;
      String? backUrl = widget.document.backImageUrl;

      // Upload front image if new
      if (_frontImage != null) {
        frontUrl = await _verificationService.uploadDocumentImage(
          user.id,
          widget.document.documentType,
          _frontImage!,
          'front',
        );
      }

      // Upload back image if needed and new
      if (_needsBackImage && _backImage != null) {
        backUrl = await _verificationService.uploadDocumentImage(
          user.id,
          widget.document.documentType,
          _backImage!,
          'back',
        );
      }

      if (frontUrl == null) {
        throw Exception('Failed to upload front image');
      }

      if (_needsBackImage && backUrl == null) {
        throw Exception('Failed to upload back image');
      }

      // Submit document
      final result = await _verificationService.submitDocument(
        driverId: user.id,
        documentType: widget.document.documentType,
        frontImageUrl: frontUrl,
        backImageUrl: backUrl,
      );

      if (result['success']) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Document submitted successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      } else {
        throw Exception(result['message']);
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }
}