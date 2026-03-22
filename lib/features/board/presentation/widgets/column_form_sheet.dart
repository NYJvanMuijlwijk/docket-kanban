import 'package:flutter/material.dart';

const _maxColumnNameLength = 50;

class ColumnFormSheet extends StatefulWidget {
  const ColumnFormSheet({
    super.key,
    this.initialName,
  });

  final String? initialName;

  @override
  State<ColumnFormSheet> createState() => _ColumnFormSheetState();

  static Future<String?> show(
    BuildContext context, {
    String? initialName,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ColumnFormSheet(initialName: initialName),
    );
  }
}

class _ColumnFormSheetState extends State<ColumnFormSheet> {
  late final TextEditingController _controller;
  bool _isValid = false;

  bool get _isRename => widget.initialName != null;

  @override
  void initState() {
    super.initState();
    _controller =
        TextEditingController(text: widget.initialName ?? '');
    _isValid = _controller.text.trim().isNotEmpty;
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() {
    final valid = _controller.text.trim().isNotEmpty;
    if (valid != _isValid) {
      setState(() => _isValid = valid);
    }
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isNotEmpty) {
      Navigator.of(context).pop(name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _isRename ? 'Rename Column' : 'New Column',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: _maxColumnNameLength,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Column name',
              border: OutlineInputBorder(),
            ),
            onSubmitted: _isValid ? (_) => _submit() : null,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _isValid ? _submit : null,
            child: Text(_isRename ? 'Rename' : 'Create'),
          ),
        ],
      ),
    );
  }
}
