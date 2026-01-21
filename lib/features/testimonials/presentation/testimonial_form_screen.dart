import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/providers.dart';
import '../../../core/models/testimonial.dart';
import '../../../core/widgets/app_toast.dart';
import 'package:stock_investment_flutter/app/app_icons.dart';

class TestimonialFormScreen extends ConsumerStatefulWidget {
  const TestimonialFormScreen({super.key, this.testimonial});

  final Testimonial? testimonial;

  @override
  ConsumerState<TestimonialFormScreen> createState() =>
      _TestimonialFormScreenState();
}

class _TestimonialFormScreenState extends ConsumerState<TestimonialFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authorController = TextEditingController();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  File? _proofFile;
  String? _proofUrl;
  String? _proofPath;
  bool _removeProof = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final testimonial = widget.testimonial;
    if (testimonial != null) {
      _authorController.text = testimonial.authorName;
      _titleController.text = testimonial.title;
      _messageController.text = testimonial.message;
      _proofUrl = testimonial.proofImageUrl;
      _proofPath = testimonial.proofImagePath;
    }
  }

  @override
  void dispose() {
    _authorController.dispose();
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickProof() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 90,
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _proofFile = File(picked.path);
      _removeProof = false;
    });
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }
    final user = ref.read(currentUserProvider).value;
    if (user == null || user.role != 'trader') {
      AppToast.error(context, 'Only traders can submit testimonials.');
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _submitting = true);
    try {
      final repo = ref.read(testimonialRepositoryProvider);
      final storage = ref.read(storageServiceProvider);
      final existing = widget.testimonial;
      if (existing != null) {
        final updates = <String, dynamic>{
          'authorName': _authorController.text.trim(),
          'title': _titleController.text.trim(),
          'message': _messageController.text.trim(),
        };
        if (_proofFile != null) {
          final result = await storage.uploadTestimonialProof(
            uid: user.uid,
            testimonialId: existing.id,
            file: _proofFile!,
          );
          updates['proofImageUrl'] = result.$1;
          updates['proofImagePath'] = result.$2;
          if (_proofPath != null && _proofPath!.isNotEmpty) {
            await storage.deletePath(_proofPath!);
          }
        } else if (_removeProof) {
          updates['proofImageUrl'] = null;
          updates['proofImagePath'] = null;
          if (_proofPath != null && _proofPath!.isNotEmpty) {
            await storage.deletePath(_proofPath!);
          }
        }
        await repo.update(existing.id, updates);
        if (!mounted) return;
        AppToast.success(context, 'Testimonial updated.');
        Navigator.of(context).pop();
        return;
      }

      final testimonialId = repo.newTestimonialId();
      String? proofUrl;
      String? proofPath;
      if (_proofFile != null) {
        final result = await storage.uploadTestimonialProof(
          uid: user.uid,
          testimonialId: testimonialId,
          file: _proofFile!,
        );
        proofUrl = result.$1;
        proofPath = result.$2;
      }

      final testimonial = Testimonial(
        id: testimonialId,
        authorUid: user.uid,
        authorName: _authorController.text.trim(),
        authorRole: user.role,
        title: _titleController.text.trim(),
        message: _messageController.text.trim(),
        status: 'published',
        proofImageUrl: proofUrl,
        proofImagePath: proofPath,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        publishedAt: DateTime.now(),
      );

      await repo.create(testimonial);
      if (!mounted) return;
      AppToast.success(context, 'Testimonial published.');
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        AppToast.error(context, 'Submission failed: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.testimonial != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit testimonial' : 'Submit testimonial'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!isEditing)
              Text(
                'Submissions go live immediately and can be edited later.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (!isEditing) const SizedBox(height: 12),
            TextFormField(
              controller: _authorController,
              decoration: const InputDecoration(
                labelText: 'Client name',
                hintText: 'e.g. Asha M.',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Client name is required.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title (optional)',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _messageController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Testimonial message',
                hintText: 'Describe the result in the client’s own words.',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Message is required.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _submitting ? null : _pickProof,
                    icon: const Icon(AppIcons.image_outlined),
                    label: Text(
                      (_proofFile != null || (_proofUrl ?? '').isNotEmpty)
                          ? 'Replace proof'
                          : 'Add proof image',
                    ),
                  ),
                ),
                if (_proofFile != null || (_proofUrl ?? '').isNotEmpty) ...[
                  const SizedBox(width: 12),
                  IconButton(
                    tooltip: 'Remove proof image',
                    onPressed: _submitting
                        ? null
                        : () => setState(() {
                              _proofFile = null;
                              _removeProof = true;
                              _proofUrl = null;
                              _proofPath = null;
                            }),
                    icon: const Icon(AppIcons.close),
                  ),
                ],
              ],
            ),
            if (_proofFile != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  _proofFile!,
                  height: 180,
                  fit: BoxFit.cover,
                ),
              ),
            ] else if ((_proofUrl ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  _proofUrl!,
                  height: 180,
                  fit: BoxFit.cover,
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(isEditing ? 'Save changes' : 'Publish testimonial'),
            ),
          ],
        ),
      ),
    );
  }
}
