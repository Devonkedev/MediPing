import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_service.dart';

class ProfileScreen extends StatefulWidget {
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();

  DateTime? _dob;
  double _height = 0;
  double _weight = 0;

  String? _photoUrl;
  bool _loadingProfile = true;
  bool _isSaving = false;

  late AnimationController _btnController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();

    _btnController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _scaleAnim = Tween<double>(begin: 1, end: 0.96).animate(
      CurvedAnimation(
        parent: _btnController,
        curve: Curves.easeOut,
      ),
    );

    _loadUserData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _btnController.dispose();
    super.dispose();
  }

  // ---------------- DATA LOAD ----------------

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser!;

    // Google Auth data
    _photoUrl = user.photoURL;
    _nameCtrl.text = user.displayName ?? '';

    // Firestore profile data
    final profile =
    await FirebaseService().getUserProfile(user.uid);

    if (profile != null) {
      _nameCtrl.text = profile['name'] ?? _nameCtrl.text;

      if (profile['dob'] != null) {
        _dob = DateTime.tryParse(profile['dob']);
      }

      _height = (profile['heightCm'] ?? 0).toDouble();
      _weight = (profile['weightKg'] ?? 0).toDouble();
    }

    setState(() => _loadingProfile = false);
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    if (_loadingProfile) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Profile'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _avatarSection(),
                      const SizedBox(height: 24),

                      _sectionTitle('Personal Details'),
                      _card(
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _nameCtrl,
                              decoration:
                              _input('Full Name', Icons.person),
                              validator: (v) =>
                              v == null || v.isEmpty
                                  ? 'Name is required'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            _dobPicker(context),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      _sectionTitle('Body Metrics'),
                      _card(
                        child: Column(
                          children: [
                            TextFormField(
                              initialValue:
                              _height > 0 ? '$_height' : '',
                              decoration:
                              _input('Height (cm)', Icons.height),
                              keyboardType: TextInputType.number,
                              onChanged: (v) =>
                              _height = double.tryParse(v) ?? 0,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              initialValue:
                              _weight > 0 ? '$_weight' : '',
                              decoration: _input(
                                  'Weight (kg)', Icons.monitor_weight),
                              keyboardType: TextInputType.number,
                              onChanged: (v) =>
                              _weight = double.tryParse(v) ?? 0,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ---------- SAVE BUTTON ----------
            Padding(
              padding: const EdgeInsets.all(16),
              child: ScaleTransition(
                scale: _scaleAnim,
                child: SizedBox(
                  height: 52,
                  width: double.infinity,
                  child: FilledButton(
                    onPressed:
                    _isSaving ? null : () => _submit(user.uid),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _isSaving
                          ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : const Text(
                        'Save Profile',
                        key: ValueKey('text'),
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- WIDGETS ----------------

  Widget _avatarSection() {
    return Column(
      children: [
        CircleAvatar(
          radius: 48,
          backgroundColor: Colors.grey.shade200,
          backgroundImage:
          _photoUrl != null ? NetworkImage(_photoUrl!) : null,
          child: _photoUrl == null
              ? Icon(Icons.person,
              size: 48, color: Colors.grey.shade600)
              : null,
        ),
        const SizedBox(height: 8),
        Text(
          'Profile Photo',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }

  Widget _dobPicker(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: _dob ?? DateTime(1990),
          firstDate: DateTime(1900),
          lastDate: DateTime.now(),
        );
        if (d != null) setState(() => _dob = d);
      },
      child: InputDecorator(
        decoration: _input('Date of Birth', Icons.cake),
        child: Text(
          _dob == null
              ? 'Select date'
              : _dob!.toLocal().toString().split(' ')[0],
        ),
      ),
    );
  }

  InputDecoration _input(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  // ---------------- SUBMIT ----------------

  Future<void> _submit(String uid) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    _btnController.forward();

    final data = {
      'name': _nameCtrl.text.trim(),
      'dob': (_dob ?? DateTime(1990)).toIso8601String(),
      'heightCm': _height,
      'weightKg': _weight,
      'updatedAt': DateTime.now().toIso8601String(),
    };

    await FirebaseService().saveUserProfile(uid, data);

    _btnController.reverse();
    setState(() => _isSaving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile saved successfully'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
