import 'package:cvant_mobile/features/dashboard/utils/report_period_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Report period logic', () {
    test('returns localized month names', () {
      expect(reportMonthName(6, isEnglish: false), 'Juni');
      expect(reportMonthName(6, isEnglish: true), 'June');
      expect(() => reportMonthName(13, isEnglish: true), throwsRangeError);
    });

    test('builds monthly and yearly half-open ranges', () {
      final monthly = buildReportPeriodRange(
        year: 2026,
        month: 12,
        fullYear: false,
      );
      expect(monthly.start, DateTime(2026, 12, 1));
      expect(monthly.end, DateTime(2027, 1, 1));

      final yearly = buildReportPeriodRange(
        year: 2026,
        month: 6,
        fullYear: true,
      );
      expect(yearly.start, DateTime(2026, 1, 1));
      expect(yearly.end, DateTime(2027, 1, 1));
    });

    test('formats period label for month and year', () {
      expect(
        reportPeriodLabel(
          start: DateTime(2026, 6, 1),
          end: DateTime(2026, 7, 1),
          isEnglish: false,
        ),
        'Juni 2026',
      );
      expect(
        reportPeriodLabel(
          start: DateTime(2026, 1, 1),
          end: DateTime(2027, 1, 1),
          isEnglish: true,
        ),
        '2026',
      );
    });
  });
}
