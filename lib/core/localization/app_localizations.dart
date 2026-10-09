import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('en'));
  }

  static const List<Locale> supportedLocales = [
    Locale('en'), // English
    Locale('ta'), // Tamil (தமிழ்)
    Locale('hi'), // Hindi (हिंदी)
    Locale('es'), // Spanish (Español)
  ];

  static const Map<String, String> languageNames = {
    'en': 'English',
    'ta': 'தமிழ் (Tamil)',
    'hi': 'हिंदी (Hindi)',
    'es': 'Español (Spanish)',
  };

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'app_title': 'ToolBox Pro',
      'tools': 'Tools',
      'calculator': 'Calculator',
      'finance': 'Finance',
      'settings': 'Settings',
      'categories': 'Categories',
      'favorites': 'Favorites',
      'recents': 'Recently Used',
      'search_hint': 'Search tools, math (e.g. 25 * 40), or units...',
      'no_tools_found': 'No tools found',
      'all_tools': 'All Tools',
      'edit_toolbox': 'Edit Toolbox',
      'customize_toolbox': 'Customize Toolbox',
      'reset_order': 'Reset Order',
      'done': 'Done',
      'clear_history': 'Clear History',
      'offline_ready': '100% Offline & Private',
      'language': 'Language',
      'appearance': 'Appearance & Theme',
      'dark_mode': 'Dark Mode',
      'light_mode': 'Light Mode',
      'system_mode': 'System Default',
      'haptics': 'Haptic Vibration Feedback',
      'font_size': 'Font Scaling & Accessibility',
      'backup_restore': 'Backup & Restore',
      'export_backup': 'Export Backup Data',
      'import_backup': 'Restore from Backup',
      'calculation_history': 'Calculation History',
      'view_history': 'View History',
      'move_to_top': 'Move to Top',
      'quick_calc_result': 'Quick Calculation Result',
      'copy_result': 'Copy Result',
      'share': 'Share',
      'reset': 'Reset',
      'calculate': 'Calculate',
      'convert': 'Convert',
      'date_time': 'Date & Time',
      'health': 'Health',
      'education': 'Education',
      'home_travel': 'Home & Travel',
      'files_text': 'Files & Text',
      'developer': 'Developer',
      'security': 'Security',
      'kitchen': 'Kitchen',
      'more_tools': 'More Tools',
    },
    'ta': {
      'app_title': 'டூல்பாக்ஸ் புரோ',
      'tools': 'கருவிகள்',
      'calculator': 'கால்குலேட்டர்',
      'finance': 'நிதி',
      'settings': 'அமைப்புகள்',
      'categories': 'வகைகள்',
      'favorites': 'விருப்பமானவை',
      'recents': 'சமீபத்தில் பயன்படுத்தியவை',
      'search_hint': 'கருவிகள் அல்லது கணக்கீடுகளைத் தேடுக (எ.கா. 25 * 40)...',
      'no_tools_found': 'கருவிகள் எதுவும் கிடைக்கவில்லை',
      'all_tools': 'அனைத்து கருவிகள்',
      'edit_toolbox': 'கருவிப்பெட்டியை மாற்று',
      'customize_toolbox': 'வரிசைப்படுத்து',
      'reset_order': 'மீட்டமை',
      'done': 'முடிந்தது',
      'clear_history': 'வரலாற்றை அழி',
      'offline_ready': '100% ஆஃப்லைன் & தனிப்பட்டவை',
      'language': 'மொழி',
      'appearance': 'தோற்றம் & தீம்',
      'dark_mode': 'டார்க் மோட்',
      'light_mode': 'லைட் மோட்',
      'system_mode': 'கணினி இயல்புநிலை',
      'haptics': 'அதிர்வு பின்னூட்டம்',
      'font_size': 'எழுத்துரு அளவு & அணுகல்',
      'backup_restore': 'காப்புப்பிரதி & மீட்டெடுப்பு',
      'export_backup': 'காப்புப்பிரதி ஏற்றுமதி',
      'import_backup': 'காப்புப்பிரதியிலிருந்து மீட்டெடு',
      'calculation_history': 'கணக்கீட்டு வரலாறு',
      'view_history': 'வரலாற்றைப் பார்',
      'move_to_top': 'மேலே நகர்த்து',
      'quick_calc_result': 'விரைவு கணக்கீட்டு முடிவு',
      'copy_result': 'முடிவை நகலெடு',
      'share': 'பகிர்',
      'reset': 'மீட்டமை',
      'calculate': 'கணக்கிடு',
      'convert': 'மாற்று',
      'date_time': 'தேதி & நேரம்',
      'health': 'உடல்நலம்',
      'education': 'கல்வி',
      'home_travel': 'வீடு & பயணம்',
      'files_text': 'கோப்புகள் & உரை',
      'developer': 'டெவலப்பர்',
      'security': 'பாதுகாப்பு',
      'kitchen': 'சமையலறை',
      'more_tools': 'கூடுதல் கருவிகள்',
    },
    'hi': {
      'app_title': 'टूलबॉक्स प्रो',
      'tools': 'उपकरण',
      'calculator': 'कैलकुलेटर',
      'finance': 'वित्त',
      'settings': 'सेटिंग्स',
      'categories': 'श्रेणियाँ',
      'favorites': 'पसंदीदा',
      'recents': 'हाल ही में उपयोग किए गए',
      'search_hint': 'उपकरण या गणना खोजें (उदा. 25 * 40)...',
      'no_tools_found': 'कोई उपकरण नहीं मिला',
      'all_tools': 'सभी उपकरण',
      'edit_toolbox': 'टूलबॉक्स संपादित करें',
      'customize_toolbox': 'टूलबॉक्स कस्टमाइज़ करें',
      'reset_order': 'रीसेट करें',
      'done': 'संपन्न',
      'clear_history': 'इतिहास साफ़ करें',
      'offline_ready': '100% ऑफ़लाइन और सुरक्षित',
      'language': 'भाषा',
      'appearance': 'थीम और दिखावट',
      'dark_mode': 'डार्क मोड',
      'light_mode': 'लाइट मोड',
      'system_mode': 'सिस्टम डिफ़ॉल्ट',
      'haptics': 'कंपन प्रतिक्रिया',
      'font_size': 'फ़ॉन्ट आकार और पहुंच',
      'backup_restore': 'बैकअप और पुनर्स्थापना',
      'export_backup': 'बैकअप निर्यात करें',
      'import_backup': 'बैकअप से पुनर्स्थापित करें',
      'calculation_history': 'गणना इतिहास',
      'view_history': 'इतिहास देखें',
      'move_to_top': 'शीर्ष पर ले जाएं',
      'quick_calc_result': 'त्वरित गणना परिणाम',
      'copy_result': 'परिणाम कॉपी करें',
      'share': 'साझा करें',
      'reset': 'रीसेट',
      'calculate': 'गणना',
      'convert': 'रूपांतरण',
      'date_time': 'दिनांक और समय',
      'health': 'स्वास्थ्य',
      'education': 'शिक्षा',
      'home_travel': 'घर और यात्रा',
      'files_text': 'फ़ाइलें और टेक्स्ट',
      'developer': 'डेवलपर',
      'security': 'सुरक्षा',
      'kitchen': 'रसोई',
      'more_tools': 'अन्य उपकरण',
    },
    'es': {
      'app_title': 'ToolBox Pro',
      'tools': 'Herramientas',
      'calculator': 'Calculadora',
      'finance': 'Finanzas',
      'settings': 'Ajustes',
      'categories': 'Categorías',
      'favorites': 'Favoritos',
      'recents': 'Recientes',
      'search_hint': 'Buscar herramientas o cálculos (ej. 25 * 40)...',
      'no_tools_found': 'No se encontraron herramientas',
      'all_tools': 'Todas las herramientas',
      'edit_toolbox': 'Editar caja de herramientas',
      'customize_toolbox': 'Personalizar',
      'reset_order': 'Restablecer',
      'done': 'Listo',
      'clear_history': 'Borrar historial',
      'offline_ready': '100% Sin conexión y privado',
      'language': 'Idioma',
      'appearance': 'Apariencia y tema',
      'dark_mode': 'Modo oscuro',
      'light_mode': 'Modo claro',
      'system_mode': 'Predeterminado',
      'haptics': 'Vibración táctil',
      'font_size': 'Tamaño de fuente y accesibilidad',
      'backup_restore': 'Copia de seguridad y restauración',
      'export_backup': 'Exportar copia',
      'import_backup': 'Restaurar copia',
      'calculation_history': 'Historial de cálculos',
      'view_history': 'Ver historial',
      'move_to_top': 'Mover arriba',
      'quick_calc_result': 'Resultado de cálculo rápido',
      'copy_result': 'Copiar resultado',
      'share': 'Compartir',
      'reset': 'Reiniciar',
      'calculate': 'Calcular',
      'convert': 'Convertir',
      'date_time': 'Fecha y hora',
      'health': 'Salud',
      'education': 'Educación',
      'home_travel': 'Hogar y viajes',
      'files_text': 'Archivos y texto',
      'developer': 'Desarrollador',
      'security': 'Seguridad',
      'kitchen': 'Cocina',
      'more_tools': 'Más herramientas',
    },
  };

  String tr(String key) {
    final langCode = locale.languageCode;
    return _localizedValues[langCode]?[key] ??
        _localizedValues['en']?[key] ??
        key;
  }

  String translate(String key) => tr(key);
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'ta', 'hi', 'es'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}
