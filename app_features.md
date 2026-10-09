# App Features & Release Status

> **Release Version**: `1.0.84` (Build `#84`)  
> **Status**: Production Ready & Fully Tested (22/22 Unit Tests Passing)  
> **Architecture**: Pure Offline Flutter Client with Dynamic Scaling & Multi-Language Support (English, தமிழ், हिंदी, Español)

Here is the comprehensive list of features currently implemented in the app, categorized by domain and screen toolkit:

---

## 1. Calculate
- [x] **Scientific Calculator** (`CalculatorScreen`):
  - Full scientific keypad with trigonometric functions (`sin`, `cos`, `tan`), logarithms (`ln`, `log`), square root (`√`), powers (`^`), reciprocals (`1/x`), factorials (`x!`), and constants ($\pi$, $e$)
  - Angle mode toggle: **Degree (DEG)** and **Radian (RAD)**
  - Live expression evaluation with real-time preview result
  - Full calculation history logging and persistent storage
- [x] **Percentage Calculator** (`PercentageCalculatorScreen`):
  - **What is X% of Y?**: Computes percentage share with residual percentage and value breakdown
  - **X is what % of Y?**: Computes relative proportion with division-by-zero protection
  - **% Change from X to Y**: Calculates percentage increase or decrease with absolute difference indicators
- [x] **Equation Solver** (in `AcademicToolkitScreen`):
  - **Linear Equations**: Solves $ax + b = 0$
  - **Quadratic Equations**: Solves $ax^2 + bx + c = 0$ with discriminant analysis and real & complex roots
  - **2×2 Simultaneous Linear Systems**: Solves system using Cramer's rule with determinant evaluation
- [x] **Matrix Calculator** (in `AcademicToolkitScreen`):
  - 2×2 and 3×3 matrix arithmetic (Addition $A+B$, Subtraction $A-B$, Matrix Multiplication $A \times B$)
  - Determinant calculation $\det(A)$
  - Transpose computation $A^T$
  - Matrix inversion $A^{-1}$ with singularity detection
- [x] **GCD & LCM Calculator** (in `AcademicToolkitScreen`):
  - Multi-number Greatest Common Divisor (GCD / HCF) and Least Common Multiple (LCM)
  - Euclidean algorithm computation with step-by-step breakdown
- [x] **Prime Number & Factorization Tools** (in `AcademicToolkitScreen`):
  - Primality test for arbitrary integers
  - Prime factor decomposition with exponential factor tree
  - Next consecutive prime number finder
  - Prime number sequence generator within custom ranges
- [x] **Permutation & Combination** (in `AcademicToolkitScreen`):
  - $nPr$ (Permutations) and $nCr$ (Combinations) with factorial formula breakdowns

---

## 2. Convert
- [x] **Unit Converter** (`UnitConverterScreen`):
  - **Length**: Meter, Kilometer, Centimeter, Millimeter, Mile, Yard, Foot, Inch, Nautical Mile
  - **Mass & Weight**: Kilogram, Gram, Milligram, Metric Ton, Pound, Ounce
  - **Temperature**: Celsius (°C), Fahrenheit (°F), Kelvin (K)
  - **Area**: Square Meter, Square Kilometer, Square Foot, Square Yard, Acre, Hectare
  - **Volume**: Liter, Milliliter, Cubic Meter, Gallon US, Fluid Ounce US
  - **Speed**: Meter/second (m/s), Kilometer/hour (km/h), Miles/hour (mph), Knot (kn)
  - **Data Storage**: Byte (B), Kilobyte (KB), Megabyte (MB), Gigabyte (GB), Terabyte (TB), Petabyte (PB)
- [x] **Land Area Converter** (in `HomeTravelToolkitScreen`):
  - Cross-conversion for regional and international land measurement units: Acres, Cents, Hectares, Square Feet, Square Meters, Guntha, Ground, Bigha

---

## 3. Date & Time
- [x] **Age Calculator** (`AgeCalculatorScreen`):
  - Exact age breakdown in years, months, and days
  - Countdown to next birthday in months and days
  - Total cumulative lifetime statistics: total months, total weeks, and total days lived
- [x] **Date Difference** (`DateDifferenceScreen`):
  - Total calendar days between two dates
  - Decomposed breakdown in weeks and remaining days
  - Business / working days count vs weekend days count
  - Optional toggle to include the end date in the total duration
- [x] **Duration Converter** (`DurationConverterScreen`):
  - Input across flexible duration units: Hours, Minutes, Seconds, Days, Weeks
  - Decomposed human-readable breakdown (days, hours, minutes, seconds)
  - Total duration equivalent conversions across all time units

---

## 4. Finance
- [x] **GST Calculator** (`GstCalculatorScreen`):
  - Exclusive and Inclusive GST calculations
  - Pre-configured tax slabs (5%, 12%, 18%, 28%) and custom tax rates
  - Automated equal split breakdown of CGST and SGST
- [x] **Loan EMI Calculator** (`LoanEmiCalculatorScreen`):
  - Monthly EMI calculation, total interest payable, and total amount payable
  - Tenure toggle: Months or Years
  - Complete amortization breakdown with principal vs interest ratio
- [x] **Discount Calculator** (`DiscountCalculatorScreen`):
  - Original price, discount %, and sales tax rate
  - Multi-tier stackable promo discount code simulation
  - Final price to pay and total savings breakdown
- [x] **Currency Converter** (`CurrencyConverterScreen`):
  - Offline rates and multi-currency exchange for USD, INR, EUR, GBP, AED, JPY, CAD, AUD, SGD, CNY, CHF
  - Reverse currency swap action and per-unit exchange rate display
- [x] **Interest Calculator** (`InterestCalculatorScreen`):
  - Simple Interest ($P \times R \times T$) and Compound Interest ($A = P(1 + r/n)^{nt}$)
  - Compounding frequency options: Annually, Quarterly, Monthly
  - Maturity amount, total interest earned, and percentage growth rate (ROI)
- [x] **Tip & Split Bill** (`TipSplitScreen`):
  - Restaurant tip calculation by percentage (10%, 15%, 18%, 20% or custom)
  - Split bill counter across parties
  - Per-person total bill share and tip contribution
- [x] **Electricity Bill Estimator** (`ElectricityBillScreen`):
  - **By Monthly Units (kWh)**: Units consumed, rate per unit, fixed charges, and electricity duty / tax %
  - **By Appliance Usage**: Pre-configured appliance wattage presets (AC, Refrigerator, Geyser, Fan, TV, Washing Machine, Microwave, PC, LED Bulb) with hours per day and quantity calculation

---

## 5. Health & Fitness
- [x] **Health & Fitness Suite** (`HealthFitnessToolkitScreen`):
  - **Body-Fat Estimator**: US Navy circumference method using neck, waist, hip, and height with fitness category classifications
  - **Waist-to-Height Ratio (WHtR)**: Abdominal visceral fat risk gauge and health boundary assessment
  - **Running Pace and Speed**: Pace (min/km, min/mi), speed (km/h, mph), and race split forecasts (5K, 10K, Half Marathon, Full Marathon)
  - **Step-to-Distance Calculator**: Step count to km, miles, burned calories, and height-calibrated stride length
  - **Heart-Rate Zone Calculator**: Tanaka max HR & Karvonen reserve formulas across 5 training zones (Warm-up to VO2 Max)
  - **Workout Interval Timer**: HIIT & Tabata timer with customizable work/rest cycles, sets, rounds, and audio/haptic cues
  - **Protein & Macronutrient Calculator**: TDEE baseline, fitness goals (cutting, maintenance, bulking), and grams/calories of Protein, Carbs & Fats
  - **Water Intake Tracker**: Daily hydration target by body weight, quick +250ml/+500ml/+750ml logging, circular progress ring & daily log history
- [x] **Health & BMI Calculator** (`HealthCalculatorScreen`):
  - Body Mass Index (BMI) calculation with category classifications (Underweight, Normal, Overweight, Obese)
  - Basal Metabolic Rate (BMR) using Mifflin-St Jeor equation
  - Ideal Body Weight range using Devine formula
  - Daily maintenance calorie requirements

---

## 6. Education & Academic
- [x] **Academic & Education Suite** (`AcademicToolkitScreen`):
  - **Marks Percentage Calculator**: Dynamic subject list with maximum marks, scored marks, aggregate %, letter grade & pass/fail status
  - **Exam Score Needed Calculator**: Target final grade, current coursework grade, and final exam weighting
  - **Attendance Eligibility Calculator**: Attended vs total classes, minimum required attendance %, classes to attend or safe skips
  - **Scientific Calculator**: Full scientific keypad with trigonometric, logarithmic, exponential, powers & history
  - **Equation Solver**: Linear equations, quadratic equations with discriminant & real/complex roots, 2×2 linear system solver
  - **Prime Number & Factorization Tools**: Primality test, prime factor tree, next prime finder, and prime numbers generator
  - **GCD and LCM Calculator**: Multi-number greatest common divisor and least common multiple
  - **Matrix Calculator**: 2×2 and 3×3 matrix arithmetic, determinants, inverses, and transposes
  - **Permutation & Combination Calculator**: $nPr$ and $nCr$ with step-by-step factorial breakdowns
- [x] **GPA & CGPA Calculator** (`GpaCalculatorScreen`):
  - Dynamic course ledger with credit weights and grade selection (O, A+, A, B+, B, C, F)
  - Cumulative GPA calculation and total credit accumulation

---

## 7. Home, Construction & Travel
- [x] **Home, Construction & Travel Suite** (`HomeTravelToolkitScreen`):
  - **Fuel Mileage and Trip Cost**: Distance, vehicle fuel economy, fuel cost per unit, total fuel needed & cost per passenger
  - **EV Charging Cost Estimator**: Battery capacity (kWh), start/target charge %, electricity rate, charger efficiency & charge time
  - **Paint Quantity Calculator**: Room length, width, height, deductions for doors/windows, number of coats & paint required in Liters/Gallons
  - **Tile and Flooring Calculator**: Room dimensions, tile dimensions, wastage % buffer, total tiles needed & box counts
  - **Concrete and Cement Estimator**: Slab/footing length, width, thickness, mix designs (1:2:4, 1:1.5:3, 1:3:6), 50kg cement bags, sand & gravel volume
  - **Land Area Converter**: Instant cross-conversion for Acres, Cents, Hectares, Square Feet, Square Meters, Guntha, Ground, Bigha
  - **Water Tank Capacity**: Rectangular and cylindrical water tank volume in Liters, US Gallons, and Cubic Meters
  - **Appliance Electricity Consumption**: Appliance wattage (Watts), daily hours used, electricity rate -> daily, monthly, and annual costs
  - **Travel Budget Splitter**: Group expense ledger with payer tracking and automated minimal debt settlements
  - **Download-Time Estimator**: File size (MB, GB, TB) and network speed (Mbps, MB/s, Gbps) -> download time in days, hours, minutes, seconds
- [x] **Electricity Bill Estimator** (`ElectricityBillScreen`):
  - Monthly energy bill estimates by consumption units or household appliance inventory

---

## 8. Files, Text & Media Tools
- [x] **Advanced PDF Toolkit** (`PdfToolkitScreen`):
  - **Images to PDF**: Convert multi-image selections into clean PDFs with page format (A4, Letter, Legal), portrait/landscape, custom page numbers, and naming
  - **Text to PDF**: Multi-page flowing text document generator with custom title, author, and diagonal confidentiality watermark
  - **Merge PDFs**: Combine multiple PDF files into one with total combined page count tracking
  - **Split PDF**: Extract page subsets by range or comma-separated page numbers (e.g., `1-3, 5, 8-10`)
  - **Organize Pages**: Visual page grid to reorder, rotate (90°/180°/270°), or delete specific pages
  - **Compress PDF**: Optimize and compress PDF streams with reduction percentage reporting
  - **Protect / Lock PDF**: AES-256 bit encryption with separate user and owner passwords, plus print, copy, and edit permission flags
  - **PDF to Images**: High-resolution PNG image rendering from PDF pages with gallery saving and printing
  - **Sign & Stamp**: Place digital signature drawings or official approval/confidential stamps onto document pages
  - **Fill Forms**: Inspect and modify interactive fillable form fields in PDF documents
  - **PDF to Text**: Extract raw text content directly from PDF pages with clipboard copy
- [x] **Image Toolkit** (`ImageToolkitScreen`):
  - **Image Compression**: Quality slider, target dimensions, real-time file size comparison
  - **Format Conversion**: Convert images between JPG, PNG, WebP, BMP, and GIF formats
  - **Resize & Crop**: Custom pixel dimensions or aspect ratio presets (1:1, 16:9, 4:3, 9:16) with aspect lock
  - **Rotate & Flip**: 90°, 180°, 270° rotation, horizontal mirror flip, vertical mirror flip
  - **Combine & Stitch**: Stitch multiple images horizontally, vertically, or in a 2×2 grid layout
  - **Image ⇄ Base64**: Two-way converter between image bytes and Base64 Data URI strings
  - **EXIF Metadata Stripper**: Strip privacy-sensitive GPS coordinates, camera models, lens info, and timestamps
  - **Photo Watermark**: Add custom text watermarks with position (Center, Bottom Right, Top Left) and opacity controls
  - **Passport Photo Maker**: Generate single passport photos and printable multi-copy 4×6 photo sheets (2, 4, 6, 8 copies)
- [x] **Image Collage Maker** (`CollageMakerScreen`):
  - Select 2 to 9 photos from gallery
  - Dynamic grid layouts (2×1, 1×2, 2×2, 3×1, 3×2, 3×3)
  - Custom border spacing, margins, and canvas background colors
  - High-res image rendering and export
- [x] **Audio & Video Studio** (`MediaToolsScreen`):
  - **Audio Trimmer**: Waveform timeline, start/end range sliders, playback toggle, and trimmed duration calculation
  - **Video Compressor & Trimmer**: Resolution presets (480p, 720p, 1080p), bitrate slider, duration trimmer, and compression ratio estimation
- [x] **OCR & Voice Studio** (`OcrToolkitScreen`):
  - **Photo OCR**: On-device machine learning text extraction from camera or gallery images using Google ML Kit
  - **Table to CSV**: Recognize tabular structures in image documents and export directly to structured CSV
  - **Smart Contact & Entity Extractor**: Automatically extract emails, phone numbers, URLs, dates, and currency amounts with copy actions
  - **Text-to-Speech (TTS)**: Natural voice speech synthesis with speech rate, pitch controls, and playback toggle
  - **Voice to Text (STT)**: Real-time microphone dictation speech recognition
  - **OCR to PDF**: Generate structured, printable PDF documents directly from recognized OCR text
- [x] **Document Scanner** (`DocumentScannerScreen`):
  - **Multi-Page Scanner**: Camera/gallery page capture with live Color, Grayscale, and B&W high-contrast document filters, page rotation
  - **ID Card Scanner Mode**: Front & back card capture aligned on a single 2-sided identity card layout document
  - **Digital Signature Pad**: Touch/stylus drawing canvas, stroke clearing, and PNG signature export
  - **Export to PDF**: Compile scanned pages into a multi-page PDF document
- [x] **Text Diff & Cleaner** (`TextDiffCleanerScreen`):
  - **Text Diff & Comparison**: Side-by-side and line-by-line comparison with color-coded additions (+), deletions (-), unchanged lines, and unified diff copy
  - **Duplicate Line Remover**: Deduplication with case sensitivity toggle, whitespace trimming, blank line removal, and sorting (original order, alphabetical, line length)
- [x] **Markdown Editor & Preview** (`MarkdownEditorScreen`):
  - Live dual-tab editor and rendered markdown preview
  - Formatting toolbar: Headings (H1-H3), Bold, Italic, Strikethrough, Inline Code, Code Block, Blockquote, Bullet List, Numbered List, Task Checklist, Tables, Links
  - Document character/word metrics and `.md` file export
- [x] **File & ZIP Suite** (`FileZipToolkitScreen`):
  - **Create ZIP**: Archive multiple files and folders into custom `.zip` files with compression statistics
  - **Extract ZIP**: Inspect ZIP archives, view contents, and extract/share individual files
  - **Batch File Renamer**: Batch renaming with prefixes, suffixes, search/replace, sequential numeric sequencing, and case alterations
  - **Storage Analyzer**: Visual size breakdown bar chart and sorted storage consumption
  - **File Hash Calculator**: Cryptographic hash checksums (MD5, SHA-1, SHA-256, SHA-512) with verification comparison
  - **Duplicate File Finder**: Identify duplicate files via byte-level cryptographic checksum matches
  - **File Metadata Inspector**: Inspect file headers, magic bytes, file extensions, MIME types, and sizes
  - **CSV ⇄ JSON Converter**: Two-way converter between tabular CSV and JSON arrays with custom indent formatting
- [x] **Text & Words Analyzer** (`TextAnalyzerScreen`):
  - Real-time metrics: words, total characters, characters without spaces, sentences, paragraphs
  - Estimated reading time computation (~200 wpm)
  - One-touch case transformations: UPPERCASE, lowercase, Title Case, kebab-case (slug), clean extra spaces

---

## 9. Developer & QR Suite
- [x] **QR & Barcode Suite** (`QrBarcodeToolkitScreen`):
  - **Live Camera & Image Scanner**: Real-time scanner with camera flip, torch toggle, and gallery image scanner
  - **QR Code Generator**: Custom colors, background colors, error correction levels (L, M, Q, H), and copy/share actions
  - **Wi-Fi QR Generator**: Network credentials sharing (WPA/WPA2, WEP, Open, SSID, hidden network flag)
  - **Contact & Web QR**: vCard format, URL, Email, Phone, SMS, Geolocation coordinates
  - **Barcode Generator**: 1D and 2D barcodes (Code 128, Code 39, EAN-13, EAN-8, UPC-A, ISBN, Aztec, PDF417)
  - **Bulk QR Generator**: Batch generate QR codes from lists and export to printable multi-page PDF sheets
  - **Persistent Scan History**: Local storage log of scanned QR/barcodes with timestamps and one-tap re-use
- [x] **XML & YAML Formatter** (`XmlYamlFormatterScreen`):
  - XML beautifier with custom indentation and minification
  - YAML / JSON beautifier, validation, and parser error detection
- [x] **Device & Hardware Studio** (`DeviceHardwareToolkitScreen`):
  - **Device Info Viewer**: Device model, brand, manufacturer, OS version, SDK build, screen resolution, DPR, hardware specs & PDF/Text spec report export
  - **Digital Magnetic Compass**: Rotating 360° compass rose with heading degrees and cardinal orientation (N, NE, E, SE, S, SW, W, NW)
  - **Spirit Bubble Level & Inclinometer**: 2D circular bubble surface level, pitch and roll angles with zero-calibration
  - **Sensor Diagnostic Tester**: Real-time 3-axis streams for Accelerometer ($m/s^2$ and total $g$), Gyroscope ($rad/s$), Magnetometer ($\mu T$), and shake detector
- [x] **Developer Suite** (`DevToolsScreen`):
  - **JSON Formatter & Minifier**: Prettify indented JSON or minify to compact string with syntax validation
  - **Base64 & URL Tool**: Text to Base64 encode/decode and URL percent-encoding/decoding
  - **UUID v4 Generator**: Cryptographically secure UUID generation
  - **Color Code Converter**: HEX ⇄ RGB converter with color swatch preview and quick material color palette

---

## 10. Security
- [x] **Password & Security Generator** (`PasswordGeneratorScreen`):
  - Secure pseudo-random high-entropy password generator
  - Adjustable length slider (4 to 64 characters)
  - Granular character pool toggles (Uppercase A-Z, Lowercase a-z, Numbers 0-9, Special Symbols `!@#$%^&*...`)
  - Real-time strength audit (Weak, Moderate, Strong, Very Strong with entropy estimation)
  - One-tap copy to clipboard

---

## 11. Kitchen & Cooking
- [x] **Kitchen & Recipe Tools** (`KitchenConverterScreen`):
  - **Recipe Portion & Yield Scaler**: Dynamically scales ingredient quantities from base servings to target servings, with add/remove custom ingredients
  - **Kitchen Unit Converter**: Instant bidirectional conversion for cooking measurements: teaspoons (tsp), tablespoons (tbsp), fluid ounces (fl oz), cups, pints, quarts, milliliters (ml), liters (l)

---

## 12. Everyday & Decision Tools
- [x] **Randomizer & Decision Tools** (`RandomUtilitiesScreen`):
  - **Random Number Generator**: Custom min/max integer bounds with instant re-roll
  - **Dice Roller**: Roll 1 to 6 six-sided dice simultaneously, showing individual dice outcomes and total sum
  - **Coin Toss**: Fair 50/50 virtual coin toss with animated outcome and lifetime Heads/Tails counters

---

## 13. System Architecture, Preferences & Navigation
- [x] **Customizable & Movable Toolbox Categories** (`CategoryHubScreen` & `PreferencesService`):
  - **Drag-and-Drop Reordering**: Long-press and drag any category card (e.g., drag Kitchen to the top) to customize the category hierarchy
  - **Touch Drag Handles**: Immediate drag handles (`Icons.drag_indicator_rounded`) for quick fluid reordering
  - **Quick "Move to Top"**: One-tap `⬆` action button to instantly promote any category (like Kitchen) to the #1 top spot
  - **Toolbox Edit Button**: Dedicated "Edit" toggle button in the category header with active editing banner and Done button
  - **Long-Press Direct Activation**: Long-pressing any category card in the standard grid provides haptic feedback, enters Edit Mode, and offers an instant "Move to Top" snackbar action
  - **Reset to Default**: One-tap "Reset" action to restore the canonical 12-category order
  - **Local Persistence**: Saves custom order to `SharedPreferences` (`custom_category_order`) and reloads on startup
- [x] **Navigation Scaffold** (`MainNavigationScaffold`):
  - Bottom navigation bar with 4 primary destinations:
    1. **Tools Hub**: Category-based browsing and global search across all 32+ tool suites
    2. **Dedicated Scientific Calculator**: Instant access to full scientific keypad
    3. **Finance Hub**: Curated finance suite (GST, EMI, Currency, Discounts, Interest, Tips, Electricity)
    4. **Settings & Preferences**: App theme and data controls
- [x] **Search & Category Hub** (`CategoryHubScreen`):
  - Responsive tool cards and real-time search across tool titles, descriptions, and keywords
  - Favorites quick-access section with custom badge chips
- [x] **App Settings & Persistence** (`SettingsScreen` & `PreferencesService`):
  - Theme selection: **Dark Mode**, **Light Mode**, or **System Default**
  - Haptic feedback toggle (selection & impact haptics)
  - Calculation history tracking with one-tap clear history action
  - Persistent storage via `SharedPreferences`

---

## 17. Device & Everyday Utilities
- [x] **Battery Health Information, Where Supported** (`BatteryDisplayInfoScreen`):
  - Real-time battery percentage with dynamic visual gauge and color thresholds
  - Power charging status: Charging, Discharging, Fully Charged, and Connected state via `battery_plus`
  - Low Power Mode / Battery Saver detection (`isInBatterySaveMode`)
  - Battery health evaluation (Optimal / Normal operating condition), nominal voltage (~3.85V-4.35V DC), technology (Li-Ion / Li-Po), and thermal operating ranges
  - Battery longevity care guide & dark mode power savings recommendations

- [x] **Microphone and Speaker Tester** (`MicSpeakerTesterScreen`):
  - **Speaker Hardware Testing**:
    - Discrete left and right audio channel tests to verify stereo separation and speaker balance
    - Frequency sweep tests: Bass (250 Hz Low), Mid Vocals (1 kHz), and Treble (4 kHz High)
    - Full volume output clarity test for bottom loudspeaker and earpiece
  - **Microphone Hardware Testing**:
    - Real-time sound level input meter indicator during recording
    - Speech recognition capture and loopback audio transcription to verify mic input clarity
    - Hardware responsiveness and audio input permission diagnostics

- [x] **Touchscreen Test** (`TouchscreenTestScreen`):
  - **Digitizer Grid Coverage Test**: Full-screen 160-cell (10×16) digitizer matrix where every touched cell lights up green with haptic buzz to pinpoint touchscreen dead zones
  - **Multi-Touch Pointer Tracker**: Tracks simultaneous multi-finger touches (1 to 10 fingers) with live pointer coordinate HUD $(X, Y)$ and color-coded touch trails

- [x] **Screen Color Test** (`ScreenColorTestScreen`):
  - Immersive fullscreen inspection hiding all system UI bars
  - 10 standard diagnostic test patterns: Pure Red, Pure Green, Pure Blue, Pure White, Pure Black (OLED burn-in & backlight bleed), Neutral 50% Gray, Cyan, Magenta, Yellow, and 256-level Grayscale Gradient
  - Tap, double-tap, and swipe controls with dead pixel identification guidelines

- [x] **Vibration Tester** (`VibrationTesterScreen`):
  - Standard tactile haptic engine testing: Light Impact, Medium Impact, Heavy Impact, Selection Click, and Standard Motor Vibrate
  - Continuous rhythmic patterns: Heartbeat (Lub-Dub), SOS Emergency Morse Code (`... --- ...`), Rapid Pulse (10 Hz), and Gaming Rumble
  - Animated visual ripple wave synchronized with vibration motor pulses

- [x] **Screen Refresh-Rate Information, Where Available** (`BatteryDisplayInfoScreen`):
  - Native display hardware refresh rate detection (`PlatformDispatcher.views.first.display.refreshRate`: 60 Hz, 90 Hz, 120 Hz, 144 Hz)
  - Real-time live render FPS monitor tracking active frame smoothness
  - Display resolution diagnostics: Physical resolution (pixels), Logical resolution (points), Device Pixel Ratio (DPR), and screen density class

- [x] **Sound-Level Estimator** (`SoundLevelEstimatorScreen`):
  - Real-time Decibel (dB SPL) sound level meter with dynamic circular gauge
  - Live sound wave graph logging the last 30 readings
  - Minimum, Average, and Peak / Maximum dB statistics tracking with one-tap reset
  - Microphone sensitivity calibration slider (±15 dB offset)
  - Environmental noise reference benchmarks (Whisper, Living Room, Office, Traffic, Danger zone)

- [x] **QR-Based Contact Sharing** (`QrContactShareScreen`, `VCardUtils`):
  - RFC 2426 compliant vCard 3.0 and NTT DoCoMo MeCard generator
  - Fields for Name, Organization, Job Title, Mobile Phone, Work Phone, Email, Address, Website URL, and Notes
  - Real-time high-resolution QR code rendering with logo overlay and crisp data modules
  - Fullscreen enlarged QR mode for effortless camera scanning by other smartphones
  - One-tap "Copy vCard Text", "Save Contact", and "Clear Fields"

---

## 19. App-Wide Improvements
- [x] **Favorites and Pinned Tools** (`PreferencesService`, `CategoryHubScreen`, `SectionDetailScreen`):
  - Quick-pin tools to favorites from Category Hub, Section Details, Search Results, or individual tool toolbars
  - Persistent storage of favorite IDs in `SharedPreferences` (`favorite_tools`)
  - Dedicated interactive Favorites tray on the home screen with one-tap launch
  - Favorite toggle switch in Settings to customize home screen display

- [x] **Recently Used Tools** (`PreferencesService`, `CategoryHubScreen`):
  - Automatic recency tracking for the last 12 launched tools across all categories
  - Quick-launch horizontal scroll tray directly beneath the home search bar
  - One-tap Clear Recents capability and visibility toggle in Settings

- [x] **Universal Search with Calculation Shortcuts** (`SearchCalculatorService`, `CategoryHubScreen`):
  - Instant live search across all 32+ tools, descriptions, categories, and tags
  - Inline mathematical evaluation: Type `25 * 40`, `100 / 4`, `2 ^ 8`, `sqrt(144)` directly into search for immediate result card
  - Inline percentage shortcuts: Type `15% of 2500` or `18 percent of 500` to see instant calculation with remainder breakdown
  - Inline unit and currency conversion shortcuts: Type `5 km to m`, `10 kg to g`, `100 c to f`, or `100 usd to inr` for real-time conversion
  - Tap-to-copy result and automatic archiving into Calculation History

- [x] **Share and Export Results Consistently** (`CalculationHistoryScreen`, `BackupService`, Tool screens):
  - Unified clipboard copying with user feedback toasts
  - Formatted text export for calculation breakdowns and finance summaries
  - Export full history log and backup payloads for sharing across platforms

- [x] **Calculation History Filters and Search** (`CalculationHistoryScreen`, `PreferencesService`):
  - Dedicated Calculation History screen tracking computations across standard calculator, scientific calculator, finance suite, and search shortcuts
  - Real-time search query filtering over historical expressions, results, and dates
  - Category filter chips (All, Math & Calculator, Finance Suite, Conversions, Search Shortcuts)
  - One-tap copy to clipboard, share record, bulk export all records, and clear history

- [x] **Customizable Home Screen** (`CategoryHubScreen`, `SettingsScreen`, `PreferencesService`):
  - Fluid drag-and-drop category reordering with immediate touch handles
  - Quick "Move to Top" action (`⬆`) to promote any category (e.g. Kitchen, Finance) to the first position
  - Dedicated "Edit" mode toggle with informative visual banner
  - Home screen customization toggles in Settings: Show/Hide Favorites tray and Recently Used tray
  - "Reset Category Ordering" button to restore canonical MIUI-inspired grid layout

- [x] **Tamil and Other Language Support** (`AppLocalizations`, `AppLocalizationsDelegate`, `SettingsScreen`):
  - Full multilingual localization architecture supporting:
    - **English** (`en`)
    - **Tamil / தமிழ்** (`ta`): Complete Tamil translations for categories, tools, settings, dialogs, and actions
    - **Hindi / हिंदी** (`hi`)
    - **Spanish / Español** (`es`)
    - In-app language picker in Settings with instant reactive UI switching

- [x] **Accessibility and Dynamic Font Sizing** (`main.dart`, `SettingsScreen`, `PreferencesService`):
  - App-wide dynamic `TextScaler.linear(prefs.fontScale)` applied via `MaterialApp` builder
  - 3-tier font scaling presets: **Standard (1.0x)**, **Large (1.15x)**, and **Extra Large (1.30x)** for enhanced readability
  - High-contrast color tokens and dark/light adaptive surfaces meeting WCAG accessibility guidelines

- [x] **App Onboarding and Interactive Tutorials** (`AppOnboardingScreen`, `SettingsScreen`, `PreferencesService`):
  - 4-step interactive feature tour covering:
    1. *All-in-One Utility Powerhouse*: 32+ modular tools across 12 categories
    2. *Customizable Home & Layout*: Drag-and-drop reordering & quick pin
    3. *Universal Search & Math Shortcuts*: Calculate math and convert units directly in search
    4. *100% Offline & Private*: Zero telemetry, zero internet dependency
  - Automated presentation for new users with "Get Started" and "Skip" actions
  - "Replay App Onboarding Tour" tile in Settings to re-trigger the walkthrough anytime

- [x] **Offline Capability Indicators** (`CategoryHubScreen`, `SettingsScreen`):
  - "100% Offline" visual badge displayed on the Category Hub header
  - Detailed Offline & Privacy assurance card in Settings verifying local-only processing for all PDF tools, OCR, scanners, and calculators
  - Zero required internet permissions in Android manifest

- [x] **Error Reporting and Input Validation** (`ValidationUtils`):
  - Centralized `ValidationUtils` with typed `ValidationResult<T>`
  - Robust validations for numeric bounds, non-empty fields, positive numbers, percentage ceilings (0-100%), and date sequence consistency
  - Mathematical safety guards preventing division by zero without crashes, with clear user-facing error prompts

- [x] **Unit and Calculation Accuracy Tests** (`test/math_calculation_test.dart`, `test/widget_test.dart`):
  - Automated unit test suite verifying:
    - Arithmetic expressions, operator precedence, powers, square roots
    - Percentage evaluation and remainder calculations
    - Unit conversions (length, mass, temperature, offline currency)
    - Input validation boundary checks and division by zero protection
  - 100% test pass rate validated via `flutter test`

- [x] **App-Size Optimization and Optional Heavy Dependencies**:
  - Native pure-Dart computational routines for mathematical expressions, unit conversions, and date calculations
  - Font and icon tree-shaking with zero heavy external network libraries
  - Modular on-demand controller instantiation to minimize memory footprint

- [x] **Automated Backup and Restore Testing** (`BackupService`, `test/backup_restore_test.dart`, `SettingsScreen`):
  - Structured JSON export including favorites, recents, category order, calculation history, theme mode, language, and font scale
  - Schema validation with version checks to reject corrupt or malformed payloads
  - Complete import restoration flow with UI confirmation in Settings
  - Dedicated unit tests in `test/backup_restore_test.dart` verifying backup export, schema validation, and preference recovery

---

## 20. Release Artifacts & Build Configuration
- **Version**: `1.0.84`
- **Build Number**: `84`
- **Output Target**: Android Release APKs (`--split-per-abi`)
  - `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (Target: ARM64 devices, Android 10+)
  - `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk` (Target: 32-bit legacy ARM devices)
  - `build/app/outputs/flutter-apk/app-x86_64-release.apk` (Target: Emulators & x86 tablets)
- **Zero Internet Permissions**: 100% offline security verified in `AndroidManifest.xml`
- **Test Suite**: 22/22 Unit & Integration tests passing (`flutter test`)
- **Audit & Bug Fixes (Release 84 - More Tools & Device Diagnostics)**:
  - Fixed blank white screen bug caused by unbounded flex height constraints in `ToolScaffold`: Added `isScrollable: false` option so screens managing their own `ListView` or `Expanded` containers render without layout exceptions.
  - Fixed `BatteryDisplayInfoScreen` ("Battery Health" and "Display & Refresh Rate" tabs) layout crash in release mode.
  - Fixed `TouchscreenTestScreen` touch digitizer matrix aspect-ratio calculation so that touch coordinates align 1:1 with all 160 grid cells across any screen aspect ratio.
  - Audited and verified all submenus in `ScreenColorTestScreen`, `VibrationTesterScreen`, `MicSpeakerTesterScreen`, `SoundLevelEstimatorScreen`, and `QrContactShareScreen` with zero layout overflows and full offline support.
  - **Hardware Vibration Fix**: Added `<uses-permission android:name="android.permission.VIBRATE"/>` in `AndroidManifest.xml` and native Android `Vibrator` / `VibratorManager` MethodChannel in `MainActivity.kt` via `VibrationService` to ensure 100% physical haptic feedback on all devices.
  - **SOS Morse Text Clarity**: Redesigned SOS Morse pattern card with high-contrast badge (`· · ·   — — —   · · ·`), clear dot/dash breakdown, and high-visibility typography.
  - **Toolbox Reorder Done Button & Header Overlap Fix**: Redesigned `CategoryHubScreen` edit header to remove the redundant badge and compact the "Reset" & "Done" action buttons, eliminating horizontal overflow and preventing the checkmark button from being cut off on the screen edge.
  - **Multilingual Crash Fix**: Integrated `flutter_localizations` with `GlobalMaterialLocalizations`, `GlobalWidgetsLocalizations`, and `GlobalCupertinoLocalizations` delegates for `hi` (Hindi), `ta` (Tamil), `es` (Spanish), resolving the fatal missing `MaterialLocalizations` assertion that caused the grey/black error screen when changing languages.
  - **Vibrant & Colorful More Tools**: Enhanced `ToolCategory.moreTools` with vibrant violet `Color(0xFF8B5CF6)` and assigned unique rich theme colors (`customColor`) to every single tool in the category (Compass, Randomizer, Battery, Mic/Speaker, Touchscreen, Color Test, Vibration, Refresh Rate, Decibel Meter). Upgraded `SectionDetailScreen` tool cards with gradient icon containers, dynamic border glows, and colorful chevron badges.
  - **Relevant Runtime Permissions**: Added explicit user disclosure dialogs and permission prompt banners for microphone access in `MicSpeakerTesterScreen` and `SoundLevelEstimatorScreen`.



