const reportMonthNamesId = <String>[
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

const reportMonthNamesEn = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String reportMonthName(int month, {required bool isEnglish}) {
  if (month < 1 || month > 12) {
    throw RangeError.range(month, 1, 12, 'month');
  }
  return isEnglish
      ? reportMonthNamesEn[month - 1]
      : reportMonthNamesId[month - 1];
}

({DateTime start, DateTime end}) buildReportPeriodRange({
  required int year,
  required int month,
  required bool fullYear,
}) {
  if (month < 1 || month > 12) {
    throw RangeError.range(month, 1, 12, 'month');
  }
  if (fullYear) {
    return (
      start: DateTime(year, 1, 1),
      end: DateTime(year + 1, 1, 1),
    );
  }
  return (
    start: DateTime(year, month, 1),
    end: DateTime(year, month + 1, 1),
  );
}

bool isFullYearReportPeriod({
  required DateTime start,
  required DateTime end,
}) {
  return start.month == 1 &&
      start.day == 1 &&
      end.year == start.year + 1 &&
      end.month == 1 &&
      end.day == 1;
}

String reportPeriodLabel({
  required DateTime start,
  required DateTime end,
  required bool isEnglish,
}) {
  if (isFullYearReportPeriod(start: start, end: end)) {
    return '${start.year}';
  }
  return '${reportMonthName(start.month, isEnglish: isEnglish)} ${start.year}';
}
