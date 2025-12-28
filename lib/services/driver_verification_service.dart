import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/driver_document.dart';
import '../models/driver_verification.dart';

class DriverVerificationService {
  final SupabaseClient _supabase = SupabaseConfig.client;

  // ✅ NEW: Check if driver is fully verified
  Future<Map<String, dynamic>> checkDriverVerification(String driverId) async {
    try {
      final verification = await getVerificationStatus(driverId);
      final documents = await getDocuments(driverId);

      if (verification == null) {
        return {
          'isVerified': false,
          'status': 'incomplete',
          'canPostRides': false,
        };
      }

      // Check if all 5 documents are approved
      final allApproved = documents.length == 5 &&
          documents.every((doc) => doc.status == 'approved');

      return {
        'isVerified': allApproved,
        'status': verification.verificationStatus,
        'canPostRides': allApproved,
        'verification': verification,
        'documents': documents,
      };
    } catch (e) {
      print('❌ Error checking driver verification: $e');
      return {
        'isVerified': false,
        'status': 'error',
        'canPostRides': false,
        'error': e.toString(),
      };
    }
  }

  // Get or create driver verification status
  Future<DriverVerification?> getVerificationStatus(String driverId) async {
    try {
      final response = await _supabase
          .from('driver_verification')
          .select()
          .eq('driver_id', driverId)
          .maybeSingle();

      if (response == null) {
        // Create new verification record
        final newVerification = await _supabase
            .from('driver_verification')
            .insert({
              'driver_id': driverId,
              'is_verified': false,
              'verification_status': 'incomplete',
              'completed_steps': [],
              'total_steps': 5,
            })
            .select()
            .single();

        return DriverVerification.fromJson(newVerification);
      }

      return DriverVerification.fromJson(response);
    } catch (e) {
      print('❌ Error getting verification status: $e');
      return null;
    }
  }

  // Get all documents for a driver
  Future<List<DriverDocument>> getDocuments(String driverId) async {
    try {
      final response = await _supabase
          .from('driver_documents')
          .select()
          .eq('driver_id', driverId)
          .order('created_at');

      return (response as List)
          .map((doc) => DriverDocument.fromJson(doc))
          .toList();
    } catch (e) {
      print('❌ Error getting documents: $e');
      return [];
    }
  }

  // Get specific document
  Future<DriverDocument?> getDocument(
    String driverId,
    String documentType,
  ) async {
    try {
      final response = await _supabase
          .from('driver_documents')
          .select()
          .eq('driver_id', driverId)
          .eq('document_type', documentType)
          .maybeSingle();

      if (response == null) return null;
      return DriverDocument.fromJson(response);
    } catch (e) {
      print('❌ Error getting document: $e');
      return null;
    }
  }

  // Upload document image
  Future<String?> uploadDocumentImage(
    String driverId,
    String documentType,
    File imageFile,
    String side, // 'front' or 'back'
  ) async {
    try {
      final fileName =
          '$driverId/${documentType}_${side}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await _supabase.storage
          .from('driver-documents')
          .upload(fileName, imageFile);

      final publicUrl =
          _supabase.storage.from('driver-documents').getPublicUrl(fileName);

      return publicUrl;
    } catch (e) {
      print('❌ Error uploading image: $e');
      return null;
    }
  }

  // Submit document
  Future<Map<String, dynamic>> submitDocument({
    required String driverId,
    required String documentType,
    required String frontImageUrl,
    String? backImageUrl,
  }) async {
    try {
      // Check if document exists
      final existing = await getDocument(driverId, documentType);

      if (existing == null) {
        // Insert new document
        await _supabase.from('driver_documents').insert({
          'driver_id': driverId,
          'document_type': documentType,
          'status': 'pending',
          'front_image_url': frontImageUrl,
          'back_image_url': backImageUrl,
          'submitted_at': DateTime.now().toIso8601String(),
        });
      } else {
        // Update existing document
        await _supabase
            .from('driver_documents')
            .update({
              'status': 'pending',
              'front_image_url': frontImageUrl,
              'back_image_url': backImageUrl,
              'submitted_at': DateTime.now().toIso8601String(),
              'rejection_reason': null, // Clear rejection reason
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('driver_id', driverId)
            .eq('document_type', documentType);
      }

      // Update verification status
      await _updateVerificationStatus(driverId);

      return {'success': true, 'message': 'Document submitted successfully'};
    } catch (e) {
      print('❌ Error submitting document: $e');
      return {'success': false, 'message': 'Failed to submit document: $e'};
    }
  }

  // Update verification status based on documents
  Future<void> _updateVerificationStatus(String driverId) async {
    try {
      final documents = await getDocuments(driverId);

      final completedSteps = documents
          .where((doc) => doc.status == 'approved')
          .map((doc) => doc.documentType)
          .toList();

      final allSubmitted = documents.every((doc) => doc.status != 'not_submitted');
      final allApproved = documents.every((doc) => doc.status == 'approved');
      final anyRejected = documents.any((doc) => doc.status == 'rejected');

      String verificationStatus;
      if (allApproved && documents.length == 5) {
        verificationStatus = 'approved';
      } else if (anyRejected) {
        verificationStatus = 'rejected';
      } else if (allSubmitted) {
        verificationStatus = 'pending_review';
      } else {
        verificationStatus = 'incomplete';
      }

      await _supabase.from('driver_verification').upsert({
        'driver_id': driverId,
        'is_verified': allApproved && documents.length == 5,
        'verification_status': verificationStatus,
        'completed_steps': completedSteps,
        'total_steps': 5,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('❌ Error updating verification status: $e');
    }
  }

  // Initialize all document records for a driver
  Future<void> initializeDocuments(String driverId) async {
    try {
      final documentTypes = [
        'profile_photo',
        'driving_license',
        'vehicle_insurance',
        'revenue_license',
        'vehicle_registration',
      ];

      for (final type in documentTypes) {
        final existing = await getDocument(driverId, type);
        if (existing == null) {
          await _supabase.from('driver_documents').insert({
            'driver_id': driverId,
            'document_type': type,
            'status': 'not_submitted',
          });
        }
      }
    } catch (e) {
      print('❌ Error initializing documents: $e');
    }
  }
}