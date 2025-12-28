import 'package:flutter/material.dart';
import '../utils/colors.dart';
import '../models/driver_document.dart';

class DocumentStatusCard extends StatelessWidget {
  final DriverDocument document;
  final VoidCallback onTap;

  const DocumentStatusCard({
    super.key,
    required this.document,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(color: AppColors.divider, width: 1),
          ),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _getStatusColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getIcon(),
                color: _getStatusColor(),
                size: 24,
              ),
            ),
            SizedBox(width: 16),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.displayName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    _getSubtitle(),
                    style: TextStyle(
                      fontSize: 14,
                      color: _getSubtitleColor(),
                    ),
                  ),
                  if (document.isRejected && document.rejectionReason != null)
                    ...[
                      SizedBox(height: 4),
                      Text(
                        document.rejectionReason!,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.error,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                ],
              ),
            ),

            // Status indicator
            Icon(
              Icons.chevron_right,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIcon() {
    if (document.isCompleted) return Icons.check_circle;
    if (document.isPending) return Icons.schedule;
    if (document.isRejected) return Icons.error;
    return Icons.description;
  }

  Color _getStatusColor() {
    if (document.isCompleted) return AppColors.success;
    if (document.isPending) return AppColors.warning;
    if (document.isRejected) return AppColors.error;
    return AppColors.textSecondary;
  }

  String _getSubtitle() {
    if (document.isCompleted) return 'Approved';
    if (document.isPending) return 'Under Review';
    if (document.isRejected) return 'Rejected - Resubmit';
    return 'Get Started';
  }

  Color _getSubtitleColor() {
    if (document.isCompleted) return AppColors.success;
    if (document.isPending) return AppColors.warning;
    if (document.isRejected) return AppColors.error;
    return AppColors.primary;
  }
}