export 'csv_exporter_stub.dart'
    if (dart.library.html) 'csv_exporter_web.dart';

class AttendanceCsvRow {
  final String rollNumber;
  final String studentName;
  final String status;
  final String courseCode;
  final String batch;
  final String date;

  AttendanceCsvRow({
    required this.rollNumber,
    required this.studentName,
    required this.status,
    required this.courseCode,
    required this.batch,
    required this.date,
  });

  String toCsvLine() {
    final sanitizedName = studentName.replaceAll('"', '""');
    return '$rollNumber,"$sanitizedName",$status,$courseCode,$batch,$date';
  }
}

String buildAttendanceCsv(List<AttendanceCsvRow> rows) {
  final buffer = StringBuffer();
  buffer.writeln('Roll Number,Student Name,Status,Course Code,Batch,Date');
  for (final row in rows) {
    buffer.writeln(row.toCsvLine());
  }
  return buffer.toString();
}
