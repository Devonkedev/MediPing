import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';

import '../local/prescription_db.dart';



/// ---------- HELPERS ----------

Color prescriptionAccent(int id) {
  const colors = [
    Color(0xFF4F46E5), // Indigo
    Color(0xFF059669), // Green
    Color(0xFF0EA5E9), // Blue
    Color(0xFFF97316), // Orange
    Color(0xFFDB2777), // Pink
    Color(0xFF7C3AED), // Purple
  ];
  return colors[id % colors.length];
}

String formatDate(int millis) {
  return DateFormat('dd MMM yyyy')
      .format(DateTime.fromMillisecondsSinceEpoch(millis));
}

/// ---------- PDF THUMBNAIL (STABLE USING pdfx) ----------

class PdfThumbnail {
  static Future<File> generate(String pdfPath, {double width = 180}) async {
    final dir = await getApplicationDocumentsDirectory();
    final thumbPath =
    p.join(dir.path, 'thumb_${p.basenameWithoutExtension(pdfPath)}.png');

    final file = File(thumbPath);
    if (await file.exists()) return file;

    final document = await PdfDocument.openFile(pdfPath);
    final page = await document.getPage(1);

    final image = await page.render(
      width: width,
      height: (page.height * width / page.width).toDouble(),
      format: PdfPageImageFormat.png,
    );

    await file.writeAsBytes(image!.bytes);
    await page.close();
    await document.close();

    return file;
  }
}

/// ---------- SCREEN ----------

class PrescriptionsScreen extends StatefulWidget {
  const PrescriptionsScreen({super.key});

  @override
  State<PrescriptionsScreen> createState() => _PrescriptionsScreenState();
}

class _PrescriptionsScreenState extends State<PrescriptionsScreen> {
  final _picker = ImagePicker();
  final _db = PrescriptionDb();
  final _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;

  bool _isPdf(String p) => p.toLowerCase().endsWith('.pdf');

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_applySearch);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final data = await _db.getAll();
    if (!mounted) return;
    setState(() {
      _items = data;
      _filtered = data;
      _loading = false;
    });
  }

  void _applySearch() {
    final q = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      _filtered = q.isEmpty
          ? _items
          : _items.where((e) {
        return e['title'].toLowerCase().contains(q) ||
            (e['notes'] ?? '').toLowerCase().contains(q);
      }).toList();
    });
  }

  /// ---------- ADD ----------

  void _addPrescription() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Prescription'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('PDF'),
              onTap: () {
                Navigator.pop(ctx);
                _pickPdf();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 80);
    if (picked == null) return;

    final dir = await getApplicationDocumentsDirectory();
    final saved = await File(picked.path)
        .copy(p.join(dir.path, '${DateTime.now().millisecondsSinceEpoch}.jpg'));

    _openEditor(saved);
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result == null || result.files.single.path == null) return;

    final dir = await getApplicationDocumentsDirectory();
    final saved = await File(result.files.single.path!)
        .copy(p.join(dir.path, '${DateTime.now().millisecondsSinceEpoch}.pdf'));

    _openEditor(saved);
  }

  /// ---------- ADD / EDIT ----------

  void _openEditor(
      File file, {
        int? id,
        String? title,
        String? notes,
      }) {
    final titleCtrl = TextEditingController(text: title);
    final notesCtrl = TextEditingController(text: notes);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(id == null ? 'New Prescription' : 'Edit Prescription'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(14),
              ),
              child: _isPdf(file.path)
                  ? const Icon(Icons.picture_as_pdf,
                  color: Colors.red, size: 60)
                  : ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child:
                Image.file(file, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: titleCtrl,
              decoration:
              const InputDecoration(labelText: 'Prescription name'),
            ),
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(labelText: 'Notes'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty) return;

              if (_isPdf(file.path)) {
                await PdfThumbnail.generate(file.path);
              }

              if (id == null) {
                await _db.insert({
                  'imagePath': file.path,
                  'title': titleCtrl.text.trim(),
                  'notes': notesCtrl.text.trim(),
                  'createdAt':
                  DateTime.now().millisecondsSinceEpoch,
                });
              } else {
                await _db.update(id, {
                  'title': titleCtrl.text.trim(),
                  'notes': notesCtrl.text.trim(),
                });
              }

              Navigator.pop(ctx);
              _load();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  /// ---------- PREVIEW ----------

  void _openPreview(String path) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
        _isPdf(path) ? PdfPreview(path: path) : ImagePreview(path: path),
      ),
    );
  }

  /// ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(title: const Text('Prescriptions'), centerTitle: true),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addPrescription,
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          _SearchBar(controller: _searchCtrl),
          Expanded(
            child: _filtered.isEmpty
                ? const _EmptyState()
                : ListView.builder(
              padding:
              const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: _filtered.length,
              itemBuilder: (_, i) {
                final d = _filtered[i];

                return Dismissible(
                  key: ValueKey(d['id']),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    margin:
                    const EdgeInsets.only(bottom: 14),
                    padding:
                    const EdgeInsets.only(right: 24),
                    alignment: Alignment.centerRight,
                    decoration: BoxDecoration(
                      color: Colors.red.shade400,
                      borderRadius:
                      BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.delete,
                        color: Colors.white),
                  ),
                  confirmDismiss: (_) async {
                    return await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text(
                            'Delete prescription?'),
                        content: const Text(
                            'This action cannot be undone.'),
                        actions: [
                          TextButton(
                              onPressed: () =>
                                  Navigator.pop(
                                      ctx, false),
                              child:
                              const Text('Cancel')),
                          FilledButton(
                              onPressed: () =>
                                  Navigator.pop(
                                      ctx, true),
                              child:
                              const Text('Delete')),
                        ],
                      ),
                    );
                  },
                  onDismissed: (_) async {
                    await _db.delete(d['id']);
                    _load();
                  },
                  child: _PrescriptionCard(
                    data: d,
                    onEdit: () => _openEditor(
                      File(d['imagePath']),
                      id: d['id'],
                      title: d['title'],
                      notes: d['notes'],
                    ),
                    onPreview: () =>
                        _openPreview(d['imagePath']),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// ---------- SEARCH BAR ----------

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  const _SearchBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Search prescriptions, medicines...',
            prefixIcon: const Icon(Icons.search),
            border: InputBorder.none,
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }
}

/// ---------- CARD ----------

class _PrescriptionCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onEdit;
  final VoidCallback onPreview;

  const _PrescriptionCard({
    required this.data,
    required this.onEdit,
    required this.onPreview,
  });

  bool get isPdf =>
      data['imagePath'].toString().toLowerCase().endsWith('.pdf');

  @override
  Widget build(BuildContext context) {
    final accent = prescriptionAccent(data['id']);

    return InkWell(
      onTap: onPreview,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: accent.withOpacity(0.12),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 72,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: isPdf
                  ? FutureBuilder<File>(
                future:
                PdfThumbnail.generate(data['imagePath']),
                builder: (_, s) => s.hasData
                    ? ClipRRect(
                  borderRadius:
                  BorderRadius.circular(14),
                  child: Image.file(s.data!,
                      fit: BoxFit.cover),
                )
                    : Icon(Icons.picture_as_pdf,
                    color: accent),
              )
                  : ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.file(File(data['imagePath']),
                    fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data['title'],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600)),
                  if ((data['notes'] ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(data['notes'],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: Colors.grey.shade600)),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.calendar_today,
                          size: 13,
                          color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(formatDate(data['createdAt']),
                          style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.edit, color: accent),
              onPressed: onEdit,
            ),
          ],
        ),
      ),
    );
  }
}

/// ---------- EMPTY ----------

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('No prescriptions yet',
          style: TextStyle(color: Colors.grey)),
    );
  }
}

/// ---------- PREVIEW ----------

class ImagePreview extends StatelessWidget {
  final String path;
  const ImagePreview({required this.path});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black),
      body: Center(child: Image.file(File(path))),
    );
  }
}

class PdfPreview extends StatelessWidget {
  final String path;
  const PdfPreview({required this.path});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Prescription PDF')),
      body: PdfView(
        controller:
        PdfController(document: PdfDocument.openFile(path)),
      ),
    );
  }
}
