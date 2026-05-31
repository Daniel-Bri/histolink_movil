import 'package:flutter/material.dart';

class SoapSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final TextEditingController controller;
  final String placeholder;
  final bool isReadOnly;
  final int minLines;
  final int? maxLength;
  final String? Function(String?)? validator;

  const SoapSection({
    super.key,
    required this.title,
    required this.icon,
    required this.controller,
    required this.placeholder,
    this.isReadOnly = false,
    this.minLines = 3,
    this.maxLength = 1000,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.blue[700], size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: controller,
              maxLines: null,
              minLines: minLines,
              maxLength: maxLength,
              readOnly: isReadOnly,
              decoration: InputDecoration(
                hintText: placeholder,
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.blue, width: 1.5),
                ),
                filled: isReadOnly,
                fillColor: isReadOnly ? Colors.grey[50] : Colors.white,
                contentPadding: const EdgeInsets.all(12),
              ),
              style: const TextStyle(fontSize: 14, height: 1.5),
              validator: validator,
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.multiline,
            ),
          ],
        ),
      ),
    );
  }
}
