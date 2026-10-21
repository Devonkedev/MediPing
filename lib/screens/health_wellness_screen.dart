import 'package:flutter/material.dart';
import '../services/sheets_service.dart';
import '../constants.dart';
import '../models/health_item.dart';

enum AgeGroup { birth, child, adult, senior }
enum Category { vaccine, screening, lifestyle }

class AgeRange {
  final int min;
  final int max;
  AgeRange(this.min, this.max);
}

class HealthWellnessScreen extends StatefulWidget {
  const HealthWellnessScreen({super.key});

  @override
  State<HealthWellnessScreen> createState() => _HealthWellnessScreenState();
}

class _HealthWellnessScreenState extends State<HealthWellnessScreen>
    with SingleTickerProviderStateMixin {
  bool loading = true;
  List<HealthItem> allItems = [];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    load();
  }

  Future<void> load() async {
    final service = SheetsService(Constants.googleSheetCsvUrl);
    final data = await service.fetchAll();
    setState(() {
      allItems = data;
      loading = false;
    });
  }

  // ---------------------------------------------------------------------------
  // CATEGORY LOGIC
  // ---------------------------------------------------------------------------

  Category resolveCategory(String reminder) {
    final r = reminder.toLowerCase();
    if (r.contains('vaccine') ||
        r.contains('bcg') ||
        r.contains('dtp') ||
        r.contains('mmr') ||
        r.contains('influenza') ||
        r.contains('opv') ||
        r.contains('pcv')) {
      return Category.vaccine;
    }

    if (r.contains('screen') ||
        r.contains('test') ||
        r.contains('exam') ||
        r.contains('ecg') ||
        r.contains('lipid') ||
        r.contains('bp') ||
        r.contains('sugar') ||
        r.contains('mammography') ||
        r.contains('colonoscopy')) {
      return Category.screening;
    }

    return Category.lifestyle;
  }

  // ---------------------------------------------------------------------------
  // AGE PARSING (CRITICAL FIX)
  // ---------------------------------------------------------------------------

  AgeRange parseAgeRange(String ageText) {
    final text = ageText.toLowerCase().trim();

    // Birth
    if (text.contains('birth')) {
      return AgeRange(0, 0);
    }

    // Weeks / Months => < 1 year
    if (text.contains('week') || text.contains('month')) {
      return AgeRange(0, 1);
    }

    // >60 Years
    final greater = RegExp(r'>\s*(\d+)').firstMatch(text);
    if (greater != null) {
      final min = int.parse(greater.group(1)!);
      return AgeRange(min, 120);
    }

    // Range: 19-45 Years
    final range = RegExp(r'(\d+)\s*-\s*(\d+)').firstMatch(text);
    if (range != null) {
      return AgeRange(
        int.parse(range.group(1)!),
        int.parse(range.group(2)!),
      );
    }

    // Single age: 30 Years
    final single = RegExp(r'(\d+)').firstMatch(text);
    if (single != null) {
      final age = int.parse(single.group(1)!);
      return AgeRange(age, age);
    }

    return AgeRange(0, 120);
  }

  AgeGroup resolveAgeGroup(String ageText) {
    final range = parseAgeRange(ageText);

    if (range.max <= 1) return AgeGroup.birth;
    if (range.max <= 18) return AgeGroup.child;
    if (range.max <= 45) return AgeGroup.adult;
    return AgeGroup.senior;
  }

  // ---------------------------------------------------------------------------
  // UI HELPERS
  // ---------------------------------------------------------------------------

  String ageGroupTitle(AgeGroup g) {
    switch (g) {
      case AgeGroup.birth:
        return 'Birth & Infancy';
      case AgeGroup.child:
        return 'Child & Adolescent';
      case AgeGroup.adult:
        return 'Adult';
      case AgeGroup.senior:
        return 'Senior';
    }
  }

  Color ageAccent(AgeGroup g) {
    switch (g) {
      case AgeGroup.birth:
        return const Color(0xFFB23A48);
      case AgeGroup.child:
        return const Color(0xFF1E6F5C);
      case AgeGroup.adult:
        return const Color(0xFF2A5CAA);
      case AgeGroup.senior:
        return const Color(0xFF6A4C93);
    }
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  Widget buildSection(AgeGroup group, Category category) {
    final items = allItems
        .where((e) =>
    resolveAgeGroup(e.age) == group &&
        resolveCategory(e.reminder) == category)
        .toList();

    if (items.isEmpty) return const SizedBox.shrink();

    final accent = ageAccent(group);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            ageGroupTitle(group),
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ),
        ...items.map(
              (item) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // AGE BAR
                    Container(
                      width: 6,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(14),
                          bottomLeft: Radius.circular(14),
                        ),
                      ),
                    ),

                    // CONTENT
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // AGE BADGE
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: accent.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                item.age,
                                style: TextStyle(
                                  color: accent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),

                            const SizedBox(height: 8),

                            Text(
                              item.reminder,
                              style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w600,
                                height: 1.3,
                              ),
                            ),

                            if (item.frequency.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                item.frequency,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],

                            const SizedBox(height: 8),

                            Text(
                              item.target,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildTab(Category category) {
    return ListView(
      children: [
        buildSection(AgeGroup.birth, category),
        buildSection(AgeGroup.child, category),
        buildSection(AgeGroup.adult, category),
        buildSection(AgeGroup.senior, category),
        const SizedBox(height: 24),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        title: const Text('Health & Wellness'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Vaccines'),
            Tab(text: 'Screenings'),
            Tab(text: 'Lifestyle'),
          ],
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
        controller: _tabController,
        children: [
          buildTab(Category.vaccine),
          buildTab(Category.screening),
          buildTab(Category.lifestyle),
        ],
      ),
    );
  }
}
