import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'productivity_models.dart';

// ponytail: the built-in PDF fonts are Latin-1 only, so other scripts print as '?'.
// Bundle a Unicode .ttf and pass it to pw.ThemeData.withFont if that becomes a need.
String pdfSafe(String text) => text.replaceAll(RegExp(r'[^\x00-\xFF]'), '?').replaceAllMapped(
      // A single unbreakable run (long URL, base64) cannot be split across pages and
      // makes the PDF export throw, so let it wrap every 60 characters.
      RegExp(r'\S{60,}'),
      (m) => RegExp(r'.{1,60}').allMatches(m[0]!).map((c) => c[0]).join(' '),
    );

/// A printable PDF of [notes] (pinned first as given by the caller).
Future<Uint8List> buildNotesPdf(List<NoteItem> notes) async {
  final doc = pw.Document();
  final stamp = DateFormat('MMM d, yyyy');
  doc.addPage(
    pw.MultiPage(
      build: (_) => [
        pw.Header(level: 0, text: 'Notes (${notes.length})'),
        for (final n in notes) ...[
          pw.Text(
            pdfSafe(n.isPinned ? '${n.title} (pinned)' : n.title),
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            pdfSafe('${n.category} - ${stamp.format(n.updatedAt)}'),
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.SizedBox(height: 3),
          pw.Text(pdfSafe(n.content), overflow: pw.TextOverflow.span), // span: lets a long note flow onto the next page
          pw.SizedBox(height: 14),
        ],
      ],
    ),
  );
  return doc.save();
}

/// A printable PDF of one day's agenda.
Future<Uint8List> buildAgendaPdf(DateTime day, List<CalendarEventItem> events) async {
  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      build: (_) => [
        pw.Header(level: 0, text: 'Agenda - ${DateFormat('EEEE, MMM d, yyyy').format(day)}'),
        if (events.isEmpty) pw.Text('No events scheduled.'),
        for (final e in events) ...[
          pw.Text(
            pdfSafe('${e.time}  ${e.title}'),
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            pdfSafe([
              e.category,
              'Priority: ${e.priority.label}',
              if (e.location.isNotEmpty) e.location,
            ].join(' - ')),
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.SizedBox(height: 10),
        ],
      ],
    ),
  );
  return doc.save();
}
