/// Utility for generating and parsing standardized vCard (3.0) and MeCard
/// formatted strings for QR code contact sharing.
class ContactInfo {
  final String firstName;
  final String lastName;
  final String organization;
  final String jobTitle;
  final String phoneMobile;
  final String phoneWork;
  final String email;
  final String address;
  final String website;
  final String note;

  const ContactInfo({
    this.firstName = '',
    this.lastName = '',
    this.organization = '',
    this.jobTitle = '',
    this.phoneMobile = '',
    this.phoneWork = '',
    this.email = '',
    this.address = '',
    this.website = '',
    this.note = '',
  });

  String get displayName {
    final parts = [firstName.trim(), lastName.trim()].where((s) => s.isNotEmpty).toList();
    if (parts.isNotEmpty) return parts.join(' ');
    if (organization.trim().isNotEmpty) return organization.trim();
    if (email.trim().isNotEmpty) return email.trim();
    return 'Contact';
  }

  bool get isEmpty =>
      firstName.trim().isEmpty &&
      lastName.trim().isEmpty &&
      organization.trim().isEmpty &&
      phoneMobile.trim().isEmpty &&
      email.trim().isEmpty;

  ContactInfo copyWith({
    String? firstName,
    String? lastName,
    String? organization,
    String? jobTitle,
    String? phoneMobile,
    String? phoneWork,
    String? email,
    String? address,
    String? website,
    String? note,
  }) {
    return ContactInfo(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      organization: organization ?? this.organization,
      jobTitle: jobTitle ?? this.jobTitle,
      phoneMobile: phoneMobile ?? this.phoneMobile,
      phoneWork: phoneWork ?? this.phoneWork,
      email: email ?? this.email,
      address: address ?? this.address,
      website: website ?? this.website,
      note: note ?? this.note,
    );
  }
}

class VCardUtils {
  /// Generates a RFC 2426 compliant vCard 3.0 formatted string.
  static String generateVCard(ContactInfo contact) {
    final buffer = StringBuffer();
    buffer.writeln('BEGIN:VCARD');
    buffer.writeln('VERSION:3.0');

    final lName = contact.lastName.trim();
    final fName = contact.firstName.trim();
    buffer.writeln('N:$lName;$fName;;;');

    final fn = contact.displayName;
    buffer.writeln('FN:$fn');

    if (contact.organization.trim().isNotEmpty) {
      buffer.writeln('ORG:${contact.organization.trim()}');
    }

    if (contact.jobTitle.trim().isNotEmpty) {
      buffer.writeln('TITLE:${contact.jobTitle.trim()}');
    }

    if (contact.phoneMobile.trim().isNotEmpty) {
      buffer.writeln('TEL;TYPE=CELL:${contact.phoneMobile.trim()}');
    }

    if (contact.phoneWork.trim().isNotEmpty) {
      buffer.writeln('TEL;TYPE=WORK:${contact.phoneWork.trim()}');
    }

    if (contact.email.trim().isNotEmpty) {
      buffer.writeln('EMAIL;TYPE=INTERNET:${contact.email.trim()}');
    }

    if (contact.address.trim().isNotEmpty) {
      // Escape commas and semicolons in address
      final safeAddr = contact.address.trim().replaceAll(';', r'\;').replaceAll(',', r'\,');
      buffer.writeln('ADR;TYPE=HOME:;;$safeAddr;;;;');
    }

    if (contact.website.trim().isNotEmpty) {
      var url = contact.website.trim();
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        url = 'https://$url';
      }
      buffer.writeln('URL:$url');
    }

    if (contact.note.trim().isNotEmpty) {
      buffer.writeln('NOTE:${contact.note.trim()}');
    }

    buffer.write('END:VCARD');
    return buffer.toString();
  }

  /// Generates a compact NTT DoCoMo MeCard formatted string for legacy scanners.
  static String generateMeCard(ContactInfo contact) {
    final buffer = StringBuffer('MECARD:');

    final name = [contact.lastName.trim(), contact.firstName.trim()].where((s) => s.isNotEmpty).join(',');
    if (name.isNotEmpty) buffer.write('N:$name;');

    if (contact.organization.trim().isNotEmpty) buffer.write('ORG:${contact.organization.trim()};');
    if (contact.phoneMobile.trim().isNotEmpty) buffer.write('TEL:${contact.phoneMobile.trim()};');
    if (contact.email.trim().isNotEmpty) buffer.write('EMAIL:${contact.email.trim()};');
    if (contact.address.trim().isNotEmpty) buffer.write('ADR:${contact.address.trim()};');
    if (contact.website.trim().isNotEmpty) buffer.write('URL:${contact.website.trim()};');
    if (contact.note.trim().isNotEmpty) buffer.write('NOTE:${contact.note.trim()};');

    buffer.write(';');
    return buffer.toString();
  }
}
