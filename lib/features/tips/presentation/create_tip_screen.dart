import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/providers.dart';
import '../../../core/models/tip.dart';
import '../../../core/utils/role_helpers.dart';
import '../../../core/widgets/app_section_card.dart';
import 'package:stock_investment_flutter/app/app_icons.dart';

class CreateTipScreen extends StatelessWidget {
  const CreateTipScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const TipCreateScreen();
  }
}

class TipCreateScreen extends ConsumerStatefulWidget {
  const TipCreateScreen({super.key});

  @override
  ConsumerState<TipCreateScreen> createState() => _TipCreateScreenState();
}

class _TipCreateScreenState extends ConsumerState<TipCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _actionController = TextEditingController();

  String _selectedType = tipTypes.first;
  final List<String> _tags = [];
  File? _image;
  bool _loading = false;
  bool _autoValidate = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _actionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (picked == null) {
      return;
    }
    final file = File(picked.path);
    final bytes = await file.length();
    if (bytes > 5 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image must be under 5MB.')),
        );
      }
      return;
    }
    final extension = picked.path.split('.').last.toLowerCase();
    if (!['jpg', 'jpeg', 'png'].contains(extension)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Only JPG or PNG images are allowed.')),
        );
      }
      return;
    }
    setState(() => _image = file);
  }

  Future<void> _submit({required bool publishNow}) async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to create a tip.')),
      );
      return;
    }
    final isActiveTrader = isTrader(user.role) && user.traderStatus == 'active';
    if (!isActiveTrader) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only traders can submit tips.')),
      );
      return;
    }

    final formValid = _formKey.currentState?.validate() ?? false;
    if (!formValid) {
      if (!_autoValidate) {
        setState(() => _autoValidate = true);
      }
      return;
    }

    setState(() => _loading = true);

    final repo = ref.read(tipRepositoryProvider);
    String? imageUrl;
    String? imagePath;

    try {
      final tipId = repo.newTipId();
      if (_image != null) {
        final upload = await ref.read(storageServiceProvider).uploadTipImage(
              uid: user.uid,
              tipId: tipId,
              file: _image!,
            );
        imageUrl = upload.$1;
        imagePath = upload.$2;
      }

      final status = publishNow ? 'published' : 'draft';

      final tip = TraderTip(
        id: tipId,
        title: _titleController.text.trim(),
        type: _selectedType,
        content: _contentController.text.trim(),
        action: _actionController.text.trim(),
        tags: List<String>.from(_tags),
        imageUrl: imageUrl,
        imagePath: imagePath,
        status: status,
        createdBy: user.uid,
        authorName: user.displayName.isNotEmpty ? user.displayName : user.username,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isFeatured: false,
        likesCount: 0,
        savesCount: 0,
      );

      await repo.createTip(tip);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(publishNow ? 'Tip published' : 'Draft saved'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save tip: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _toggleTag(String tag, bool selected) {
    if (selected) {
      if (_tags.length >= 4) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Limit tags to 4.')),
        );
        return;
      }
      setState(() => _tags.add(tag));
    } else {
      setState(() => _tags.remove(tag));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    final isActiveTrader =
        isTrader(user?.role) && user?.traderStatus == 'active';

    return Scaffold(
      appBar: AppBar(title: const Text('Create tip')),
      body: user == null
          ? const Center(child: Text('Sign in to create a tip.'))
          : Form(
              key: _formKey,
              autovalidateMode: _autoValidate
                  ? AutovalidateMode.always
                  : AutovalidateMode.disabled,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  AppSectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppSectionTitle(title: 'Tip details'),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _titleController,
                          maxLength: 80,
                          decoration: const InputDecoration(
                            labelText: 'Title',
                            helperText: 'Max 80 characters',
                          ),
                          validator: _validateTitle,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _selectedType,
                          decoration: const InputDecoration(labelText: 'Type'),
                          items: tipTypes
                              .map(
                                (type) => DropdownMenuItem(
                                  value: type,
                                  child: Text(type),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _selectedType = value);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _contentController,
                          maxLength: 400,
                          minLines: 4,
                          maxLines: 8,
                          decoration: const InputDecoration(
                            labelText: 'Content',
                            helperText: 'Share one idea (max 400 characters)',
                          ),
                          validator: _validateContent,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _actionController,
                          maxLength: 120,
                          decoration: const InputDecoration(
                            labelText: 'Action',
                            helperText: 'One actionable takeaway (max 120)',
                          ),
                          validator: _validateAction,
                        ),
                        const SizedBox(height: 12),
                        const Text('Tags / Markets (optional, max 4)'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: tipTagOptions
                              .map(
                                (tag) => FilterChip(
                                  label: Text(tag),
                                  selected: _tags.contains(tag),
                                  onSelected: (selected) =>
                                      _toggleTag(tag, selected),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppSectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppSectionTitle(title: 'Optional image'),
                        const SizedBox(height: 12),
                        if (_image != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.file(
                              _image!,
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _pickImage,
                              icon: const Icon(AppIcons.image),
                              label: Text(
                                  _image == null ? 'Add image' : 'Replace image'),
                            ),
                            if (_image != null)
                              TextButton(
                                onPressed: () => setState(() => _image = null),
                                child: const Text('Remove'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppSectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppSectionTitle(title: 'Publish'),
                        const SizedBox(height: 8),
                        if (isActiveTrader != true)
                          Text(
                            'Only traders can submit tips.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        const SizedBox(height: 12),
                        if (isActiveTrader == true)
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _loading
                                      ? null
                                      : () => _submit(publishNow: false),
                                  child: const Text('Save draft'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _loading
                                      ? null
                                      : () => _submit(publishNow: true),
                                  child: _loading
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text('Publish'),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  String? _validateTitle(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty || text.length > 80) {
      return 'Title is required (max 80).';
    }
    return null;
  }

  String? _validateContent(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty || text.length > 400) {
      return 'Content is required (max 400).';
    }
    return null;
  }

  String? _validateAction(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty || text.length > 120) {
      return 'Action is required (max 120).';
    }
    return null;
  }
}
