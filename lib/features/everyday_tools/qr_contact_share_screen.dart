import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/models/tool_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/vcard_utils.dart';
import '../../shared/widgets/tool_scaffold.dart';

class QrContactShareScreen extends StatefulWidget {
  const QrContactShareScreen({super.key});

  @override
  State<QrContactShareScreen> createState() => _QrContactShareScreenState();
}

class _QrContactShareScreenState extends State<QrContactShareScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _orgController = TextEditingController();
  final _titleController = TextEditingController();
  final _mobileController = TextEditingController();
  final _workPhoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _websiteController = TextEditingController();
  final _noteController = TextEditingController();

  bool _useMeCardFormat = false;

  @override
  void initState() {
    super.initState();
    // Default demo template
    _firstNameController.text = 'Alex';
    _lastNameController.text = 'Morgan';
    _orgController.text = 'Apex Tech Solutions';
    _titleController.text = 'Product Architect';
    _mobileController.text = '+1 (555) 234-5678';
    _emailController.text = 'alex.morgan@example.com';
    _websiteController.text = 'https://apextech.io';
    _noteController.text = 'Scanned via ToolBox Pro Contact Share';
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _orgController.dispose();
    _titleController.dispose();
    _mobileController.dispose();
    _workPhoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _websiteController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  ContactInfo _buildContact() {
    return ContactInfo(
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      organization: _orgController.text.trim(),
      jobTitle: _titleController.text.trim(),
      phoneMobile: _mobileController.text.trim(),
      phoneWork: _workPhoneController.text.trim(),
      email: _emailController.text.trim(),
      address: _addressController.text.trim(),
      website: _websiteController.text.trim(),
      note: _noteController.text.trim(),
    );
  }

  String _getPayloadString() {
    final contact = _buildContact();
    return _useMeCardFormat ? VCardUtils.generateMeCard(contact) : VCardUtils.generateVCard(contact);
  }

  void _showFullscreenQr(BuildContext context, String payload) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.qr_code_2_rounded, color: AppColors.primaryOrange, size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _buildContact().displayName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.black54),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: QrImageView(
                    data: payload,
                    version: QrVersions.auto,
                    size: 260,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Color(0xFF1E293B),
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Point any phone camera to instantly save contact details',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final payload = _getPayloadString();
    final contact = _buildContact();

    return ToolScaffold(
      title: 'QR Contact Sharing',
      category: ToolCategory.filesText,
      toolId: 'qr_contact_share',
      isScrollable: false,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // QR Code Interactive Preview Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            contact.displayName,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                          Text(
                            _useMeCardFormat ? 'Format: MeCard' : 'Format: vCard 3.0 Standard',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                          ),
                        ],
                      ),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.fullscreen_rounded),
                        tooltip: 'Fullscreen QR Scanner Mode',
                        onPressed: () => _showFullscreenQr(context, payload),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // The QR Code Image
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: QrImageView(
                      data: payload,
                      version: QrVersions.auto,
                      size: 200,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Color(0xFF1E293B),
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Actions row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text('Copy vCard Text'),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: payload));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('vCard data copied to clipboard!')),
                          );
                        },
                      ),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: AppColors.primaryOrange),
                        icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
                        label: const Text('Enlarge QR'),
                        onPressed: () => _showFullscreenQr(context, payload),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Format Selector
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: SwitchListTile(
                title: const Text('Compact MeCard Format', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('Use MeCard for compatibility with basic barcode scanners', style: TextStyle(fontSize: 12)),
                value: _useMeCardFormat,
                activeColor: AppColors.primaryOrange,
                onChanged: (val) => setState(() => _useMeCardFormat = val),
              ),
            ),
            const SizedBox(height: 20),

            // Edit Contact Details Form
            Text(
              'CONTACT INFORMATION',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildTextField('First Name', _firstNameController, Icons.person_outline),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField('Last Name', _lastNameController, Icons.person_outline),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTextField('Organization / Company', _orgController, Icons.business_outlined),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField('Job Title', _titleController, Icons.badge_outlined),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTextField('Mobile Phone', _mobileController, Icons.phone_android_outlined, keyboardType: TextInputType.phone),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField('Work Phone', _workPhoneController, Icons.phone_outlined, keyboardType: TextInputType.phone),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildTextField('Email Address', _emailController, Icons.email_outlined, keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 12),
            _buildTextField('Physical Address', _addressController, Icons.location_on_outlined),
            const SizedBox(height: 12),
            _buildTextField('Website URL', _websiteController, Icons.language_outlined, keyboardType: TextInputType.url),
            const SizedBox(height: 12),
            _buildTextField('Notes / Bio', _noteController, Icons.notes_outlined, maxLines: 2),

            const SizedBox(height: 24),
            OutlinedButton.icon(
              icon: const Icon(Icons.clear_all_rounded),
              label: const Text('Clear All Fields'),
              onPressed: () {
                setState(() {
                  _firstNameController.clear();
                  _lastNameController.clear();
                  _orgController.clear();
                  _titleController.clear();
                  _mobileController.clear();
                  _workPhoneController.clear();
                  _emailController.clear();
                  _addressController.clear();
                  _websiteController.clear();
                  _noteController.clear();
                });
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}
