bool canSeat({
  required String reservationStatus,
  required String tableStatus,
  required int party,
  required int capacity,
}) {
  return reservationStatus == 'booked' &&
      (tableStatus == 'available' || tableStatus == 'reserved') &&
      party > 0 &&
      party <= capacity;
}

bool shiftWindowValid(DateTime start, DateTime end) => end.isAfter(start);

bool canClockIn({required bool openEntry}) => !openEntry;

const eventStages = ['inquiry', 'hold', 'booked', 'live', 'closed'];

String? nextEventStage(String stage) {
  const next = {'inquiry': 'hold', 'hold': 'booked', 'booked': 'live', 'live': 'closed'};
  return next[stage];
}

bool reportAllowed({required String? status, required bool entitled}) {
  return entitled && (status == 'trial' || status == 'active');
}

String toCsv(List<List<String>> rows) {
  return rows.map((row) => row.map(_csvCell).join(',')).join('\n');
}

String _csvCell(String value) {
  if (value.contains(',') || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}
