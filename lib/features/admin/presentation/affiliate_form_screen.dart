import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/providers.dart';
import '../../../core/models/broker.dart';

class BrokerFormScreen extends ConsumerStatefulWidget {
  const BrokerFormScreen({
    super.key,
    this.broker,
  });

  final Broker? broker;

  @override
  ConsumerState<BrokerFormScreen> createState() => _BrokerFormScreenState();
}

class _BrokerFormScreenState extends ConsumerState<BrokerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _urlController;
  late final TextEditingController _sortOrderController;
  bool _isActive = true;
  File? _logoFile;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final broker = widget.broker;
    _nameController = TextEditingController(text: broker?.name ?? '');
    _descriptionController = TextEditingController(text: broker?.description ?? '');
    _urlController = TextEditingController(text: broker?.affiliateUrl ?? '');
    _sortOrderController = TextEditingController(text: broker?.sortOrder.toString() ?? '0');
    _isActive = broker?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _urlController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final result = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (result == null) {
      return;
    }
    setState(() {
      _logoFile = File(result.path);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(brokerRepositoryProvider);
      final broker = Broker(
        id: widget.broker?.id ?? '',
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        affiliateUrl: _urlController.text.trim(),
        logoUrl: widget.broker?.logoUrl,
        isActive: _isActive,
        sortOrder: int.tryParse(_sortOrderController.text) ?? 0,
        createdAt: widget.broker?.createdAt,
        updatedAt: DateTime.now(),
      );
      if (widget.broker == null) {
        await repo.createBroker(broker: broker, logoFile: _logoFile);
      } else {
        await repo.updateBroker(broker: broker, logoFile: _logoFile);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save broker: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.broker != null;
    final existingLogo = widget.broker?.logoUrl;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit broker' : 'Create broker')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Broker name'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Broker name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                maxLength: 240,
                decoration: const InputDecoration(labelText: 'Description'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Description is required';
                  }
                  if (value.trim().length > 240) {
                    return 'Max 240 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _urlController,
                decoration: const InputDecoration(labelText: 'Affiliate URL'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'URL is required';
                  }
                  final uri = Uri.tryParse(value.trim());
                  if (uri == null || !uri.hasAbsolutePath) {
                    return 'Provide a valid URL';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _sortOrderController,
                decoration: const InputDecoration(labelText: 'Sort order'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                value: _isActive,
                title: const Text('Active'),
                onChanged: (value) => setState(() => _isActive = value),
              ),
              TextButton.icon(
                icon: const Icon(Icons.photo),
                label: Text(existingLogo == null && _logoFile == null ? 'Upload logo' : 'Replace logo'),
                onPressed: _pickLogo,
              ),
              if (_logoFile != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Image.file(_logoFile!, height: 120),
                )
              else if (existingLogo != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Image.network(existingLogo, height: 120),
                ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save broker'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
