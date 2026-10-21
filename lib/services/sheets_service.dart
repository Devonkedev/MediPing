import 'package:http/http.dart' as http;
import 'package:csv/csv.dart';
import '../models/health_item.dart';

class SheetsService {
  final String csvUrl;
  SheetsService(this.csvUrl);

  Future<List<HealthItem>> fetchAll() async {
    final res = await http.get(Uri.parse(csvUrl));

    if (res.statusCode != 200) {
      throw 'Failed to load Google Sheet (HTTP ${res.statusCode})';
    }

    final csv = const CsvToListConverter(
      shouldParseNumbers: false,
      eol: '\n',
    ).convert(res.body);

    if (csv.isEmpty) return [];

    final headers =
        csv.first.map((e) => e.toString().trim()).toList();
    final List<HealthItem> items = [];

    for (int i = 1; i < csv.length; i++) {
      final row = csv[i];
      if (row.isEmpty) continue;

      final Map<String, String> map = {};

      for (int j = 0; j < headers.length && j < row.length; j++) {
        map[headers[j]] = row[j].toString().trim();
      }

      items.add(
        HealthItem(
          age: map['Age / Interval'] ?? '',
          reminder: map['Reminder / Test / Vaccine'] ?? '',
          frequency: map['Frequency / Notes'] ?? '',
          target: map['Target Group'] ?? '',
        ),
      );
    }

    return items;
  }
}
