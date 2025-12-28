import 'package:flutter/material.dart';
import '../../utils/colors.dart';
import '../../services/driver_verification_service.dart';
import '../../services/simplified_unified_auth_service.dart';
import '../../models/driver_document.dart';
import '../../models/driver_verification.dart';
import '../../widgets/document_status_card.dart';
import 'document_upload_screen.dart';

class DriverDocumentsHubScreen extends StatefulWidget {
  const DriverDocumentsHubScreen({super.key});

  @override
  State<DriverDocumentsHubScreen> createState() =>
      _DriverDocumentsHubScreenState();
}

class _DriverDocumentsHubScreenState extends State<DriverDocumentsHubScreen> {
  final _verificationService = DriverVerificationService();
  final _authService = SimplifiedUnifiedAuthService();

  DriverVerification? _verification;
  List<DriverDocument> _documents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final user = _authService.currentUser;
      if (user == null) return;

      // Initialize documents if needed
      await _verificationService.initializeDocuments(user.id);

      // Load verification status and documents
      final verification =
          await _verificationService.getVerificationStatus(user.id);
      final documents = await _verificationService.getDocuments(user.id);

      if (!mounted) return;

      setState(() {
        _verification = verification;
        _documents = documents;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

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
          'Driver Documents',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _showHelpDialog();
            },
            child: Text(
              'Help',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Warning banner (if any issues)
                    if (_verification?.verificationStatus == 'rejected')
                      Container(
                        color: AppColors.error.withOpacity(0.1),
                        padding: EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.warning, color: AppColors.error),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Some documents were rejected. Please review and resubmit.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Info banner
                    Container(
                      color: AppColors.primary.withOpacity(0.1),
                      padding: EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: AppColors.primary),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _verification?.verificationStatus == 'pending_review'
                                  ? 'Your documents are under review. This may take 1-2 business days.'
                                  : 'Upload all required documents to become a verified driver.',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 16),

                    // Welcome message
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back, ${_authService.currentUser?.userMetadata?['full_name']?.split(' ')[0] ?? 'Driver'}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Required steps',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Here\'s what you need to do to set up your account.',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 16),

                    // Progress indicator
                    if (_verification != null)
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Progress',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  '${_verification!.completedCount}/${_verification!.totalSteps}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: _verification!.progressPercentage,
                                backgroundColor: AppColors.divider,
                                color: AppColors.primary,
                                minHeight: 8,
                              ),
                            ),
                          ],
                        ),
                      ),

                    SizedBox(height: 24),

                    // Required documents
                    Container(
                      color: Colors.white,
                      child: Column(
                        children: _documents
                            .where((doc) => !doc.isCompleted)
                            .map((doc) => DocumentStatusCard(
                                  document: doc,
                                  onTap: () => _navigateToUpload(doc),
                                ))
                            .toList(),
                      ),
                    ),

                    // Completed section
                    if (_documents.any((doc) => doc.isCompleted)) ...[
                      SizedBox(height: 24),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Completed',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                      Container(
                        color: Colors.white,
                        child: Column(
                          children: _documents
                              .where((doc) => doc.isCompleted)
                              .map((doc) => DocumentStatusCard(
                                    document: doc,
                                    onTap: () => _navigateToUpload(doc),
                                  ))
                              .toList(),
                        ),
                      ),
                    ],

                    SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  void _navigateToUpload(DriverDocument document) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DocumentUploadScreen(document: document),
      ),
    );

    if (result == true) {
      _loadData();
    }
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Need Help?'),
        content: Text(
          'Upload clear photos of all required documents. Make sure:\n\n'
          '• Photos are well-lit and in focus\n'
          '• All text is readable\n'
          '• Documents are valid and not expired\n\n'
          'Review typically takes 1-2 business days.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Got it', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}