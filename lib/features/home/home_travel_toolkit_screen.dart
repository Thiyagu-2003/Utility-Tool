import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/models/tool_model.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/feature_tab_selector.dart';
import '../../shared/widgets/modern_text_field.dart';
import '../../shared/widgets/result_card.dart';
import '../../shared/widgets/tool_scaffold.dart';

enum HomeTravelTab {
  fuel('Fuel & Trip Cost', Icons.local_gas_station_rounded),
  ev('EV Charging', Icons.electric_car_rounded),
  paint('Paint Calculator', Icons.format_paint_rounded),
  flooring('Tile & Flooring', Icons.dashboard_rounded),
  concrete('Concrete & Cement', Icons.foundation_rounded),
  land('Land Area Converter', Icons.landscape_rounded),
  waterTank('Water Tank Capacity', Icons.water_rounded),
  appliance('Appliance Power', Icons.bolt_rounded),
  tripSplitter('Trip Expense Splitter', Icons.group_rounded),
  downloadTime('Download Time', Icons.download_rounded);

  final String label;
  final IconData icon;
  const HomeTravelTab(this.label, this.icon);
}

class TripExpenseItem {
  final String title;
  final double amount;
  final String paidBy;
  TripExpenseItem({required this.title, required this.amount, required this.paidBy});
}

class HomeTravelToolkitScreen extends StatefulWidget {
  const HomeTravelToolkitScreen({super.key});

  @override
  State<HomeTravelToolkitScreen> createState() => _HomeTravelToolkitScreenState();
}

class _HomeTravelToolkitScreenState extends State<HomeTravelToolkitScreen> {
  HomeTravelTab _activeTab = HomeTravelTab.fuel;

  // 1. FUEL TRIP COST
  final _fuelDistCtrl = TextEditingController(text: '350');
  final _fuelMileageCtrl = TextEditingController(text: '15');
  final _fuelPriceCtrl = TextEditingController(text: '1.45');
  final _fuelPaxCtrl = TextEditingController(text: '4');

  // 2. EV CHARGING
  final _evCapacityCtrl = TextEditingController(text: '60');
  final _evCurrentPctCtrl = TextEditingController(text: '20');
  final _evTargetPctCtrl = TextEditingController(text: '80');
  final _evRateCtrl = TextEditingController(text: '0.18');
  final _evPowerCtrl = TextEditingController(text: '7.4');

  // 3. PAINT CALCULATOR
  final _paintLengthCtrl = TextEditingController(text: '14');
  final _paintWidthCtrl = TextEditingController(text: '12');
  final _paintHeightCtrl = TextEditingController(text: '9');
  final _paintDoorsCtrl = TextEditingController(text: '2');
  final _paintWindowsCtrl = TextEditingController(text: '2');
  final _paintCoatsCtrl = TextEditingController(text: '2');

  // 4. TILE & FLOORING
  final _floorRoomLCtrl = TextEditingController(text: '5'); // meters
  final _floorRoomWCtrl = TextEditingController(text: '4');
  final _floorTileLCtrl = TextEditingController(text: '60'); // cm
  final _floorTileWCtrl = TextEditingController(text: '60');
  final _floorWastageCtrl = TextEditingController(text: '10'); // %
  final _floorPerBoxCtrl = TextEditingController(text: '4');

  // 5. CONCRETE ESTIMATOR
  final _concLCtrl = TextEditingController(text: '6'); // meters
  final _concWCtrl = TextEditingController(text: '4');
  final _concDCtrl = TextEditingController(text: '0.15'); // 15cm thickness
  String _concMix = '1:2:4 (M15 General)';

  // 6. LAND CONVERTER
  final _landInputCtrl = TextEditingController(text: '1');
  String _landFromUnit = 'Acres';

  // 7. WATER TANK
  bool _isRectTank = true;
  final _tankLCtrl = TextEditingController(text: '2.5'); // meters
  final _tankWCtrl = TextEditingController(text: '2.0');
  final _tankHCtrl = TextEditingController(text: '1.5');
  final _tankDiamCtrl = TextEditingController(text: '1.8');

  // 8. APPLIANCE ELECTRICITY
  final _appPowerCtrl = TextEditingController(text: '1500'); // Watts
  final _appHoursCtrl = TextEditingController(text: '6');
  final _appRateCtrl = TextEditingController(text: '0.15'); // per kWh

  // 9. TRIP BUDGET SPLITTER
  final List<String> _tripMembers = ['Alice', 'Bob', 'Charlie'];
  final List<TripExpenseItem> _tripExpenses = [
    TripExpenseItem(title: 'Hotel Stay', amount: 240, paidBy: 'Alice'),
    TripExpenseItem(title: 'Rental Car & Fuel', amount: 150, paidBy: 'Bob'),
    TripExpenseItem(title: 'Dinner & Groceries', amount: 90, paidBy: 'Charlie'),
  ];
  final _newExpTitleCtrl = TextEditingController();
  final _newExpAmtCtrl = TextEditingController();
  String _newExpPayer = 'Alice';
  final _newMemberCtrl = TextEditingController();

  // 10. DOWNLOAD TIME
  final _dlSizeCtrl = TextEditingController(text: '45');
  String _dlSizeUnit = 'GB';
  final _dlSpeedCtrl = TextEditingController(text: '100');
  String _dlSpeedUnit = 'Mbps';

  @override
  void dispose() {
    _fuelDistCtrl.dispose();
    _fuelMileageCtrl.dispose();
    _fuelPriceCtrl.dispose();
    _fuelPaxCtrl.dispose();
    _evCapacityCtrl.dispose();
    _evCurrentPctCtrl.dispose();
    _evTargetPctCtrl.dispose();
    _evRateCtrl.dispose();
    _evPowerCtrl.dispose();
    _paintLengthCtrl.dispose();
    _paintWidthCtrl.dispose();
    _paintHeightCtrl.dispose();
    _paintDoorsCtrl.dispose();
    _paintWindowsCtrl.dispose();
    _paintCoatsCtrl.dispose();
    _floorRoomLCtrl.dispose();
    _floorRoomWCtrl.dispose();
    _floorTileLCtrl.dispose();
    _floorTileWCtrl.dispose();
    _floorWastageCtrl.dispose();
    _floorPerBoxCtrl.dispose();
    _concLCtrl.dispose();
    _concWCtrl.dispose();
    _concDCtrl.dispose();
    _landInputCtrl.dispose();
    _tankLCtrl.dispose();
    _tankWCtrl.dispose();
    _tankHCtrl.dispose();
    _tankDiamCtrl.dispose();
    _appPowerCtrl.dispose();
    _appHoursCtrl.dispose();
    _appRateCtrl.dispose();
    _newExpTitleCtrl.dispose();
    _newExpAmtCtrl.dispose();
    _newMemberCtrl.dispose();
    _dlSizeCtrl.dispose();
    _dlSpeedCtrl.dispose();
    super.dispose();
  }

  // --- CALCULATION LOGIC ---

  // 1. Fuel Trip Cost
  Map<String, dynamic> _calcFuel() {
    final dist = double.tryParse(_fuelDistCtrl.text) ?? 350;
    final mileage = double.tryParse(_fuelMileageCtrl.text) ?? 15;
    final price = double.tryParse(_fuelPriceCtrl.text) ?? 1.45;
    final pax = int.tryParse(_fuelPaxCtrl.text) ?? 1;

    if (dist <= 0 || mileage <= 0 || price <= 0 || pax <= 0) {
      return {'total': '\$0.00', 'perPerson': '\$0.00', 'fuelNeeded': '0 L'};
    }

    final fuelNeeded = dist / mileage;
    final totalCost = fuelNeeded * price;
    final costPerPerson = totalCost / pax;

    return {
      'total': '\$${totalCost.toStringAsFixed(2)}',
      'perPerson': '\$${costPerPerson.toStringAsFixed(2)} per person',
      'fuelNeeded': '${fuelNeeded.toStringAsFixed(1)} Liters / Gallons',
    };
  }

  // 2. EV Charging
  Map<String, dynamic> _calcEv() {
    final capacity = double.tryParse(_evCapacityCtrl.text) ?? 60;
    final curPct = double.tryParse(_evCurrentPctCtrl.text) ?? 20;
    final targetPct = double.tryParse(_evTargetPctCtrl.text) ?? 80;
    final rate = double.tryParse(_evRateCtrl.text) ?? 0.18;
    final powerKw = double.tryParse(_evPowerCtrl.text) ?? 7.4;

    if (targetPct <= curPct || capacity <= 0 || powerKw <= 0) {
      return {'cost': '\$0.00', 'time': '0h 0m', 'energy': '0 kWh'};
    }

    final energyNeededKwh = ((targetPct - curPct) / 100.0) * capacity / 0.90; // 90% charging efficiency
    final cost = energyNeededKwh * rate;
    final hoursNeeded = energyNeededKwh / powerKw;
    final hh = hoursNeeded.floor();
    final mm = ((hoursNeeded - hh) * 60).round();

    return {
      'cost': '\$${cost.toStringAsFixed(2)}',
      'time': '${hh}h ${mm}m',
      'energy': '${energyNeededKwh.toStringAsFixed(1)} kWh',
    };
  }

  // 3. Paint Calculator
  Map<String, dynamic> _calcPaint() {
    final l = double.tryParse(_paintLengthCtrl.text) ?? 14;
    final w = double.tryParse(_paintWidthCtrl.text) ?? 12;
    final h = double.tryParse(_paintHeightCtrl.text) ?? 9;
    final doors = int.tryParse(_paintDoorsCtrl.text) ?? 2;
    final windows = int.tryParse(_paintWindowsCtrl.text) ?? 2;
    final coats = int.tryParse(_paintCoatsCtrl.text) ?? 2;

    final grossArea = 2 * (l + w) * h;
    final deductions = (doors * 21.0) + (windows * 12.0); // standard door 21 sq.ft, window 12 sq.ft
    final netArea = math.max(0.0, grossArea - deductions);
    final totalAreaToPaint = netArea * coats;

    // 1 Gallon covers ~350 sq.ft, 1 Liter covers ~9 sq.meters (~97 sq.ft)
    final gallons = totalAreaToPaint / 350.0;
    final liters = totalAreaToPaint / 97.0;

    return {
      'gallons': '${gallons.toStringAsFixed(1)} Gallons',
      'liters': '${liters.toStringAsFixed(1)} Liters',
      'netArea': '${netArea.toStringAsFixed(0)} sq.ft ($coats coats)',
    };
  }

  // 4. Flooring & Tile
  Map<String, dynamic> _calcFlooring() {
    final roomL = double.tryParse(_floorRoomLCtrl.text) ?? 5; // meters
    final roomW = double.tryParse(_floorRoomWCtrl.text) ?? 4;
    final tileL = (double.tryParse(_floorTileLCtrl.text) ?? 60) / 100.0; // cm to m
    final tileW = (double.tryParse(_floorTileWCtrl.text) ?? 60) / 100.0;
    final wastage = (double.tryParse(_floorWastageCtrl.text) ?? 10) / 100.0;
    final perBox = int.tryParse(_floorPerBoxCtrl.text) ?? 4;

    final roomArea = roomL * roomW;
    final tileArea = tileL * tileW;
    if (tileArea <= 0 || roomArea <= 0 || perBox <= 0) {
      return {'tiles': '0', 'boxes': '0', 'area': '0 m²'};
    }

    final rawTiles = roomArea / tileArea;
    final totalTiles = (rawTiles * (1.0 + wastage)).ceil();
    final totalBoxes = (totalTiles / perBox).ceil();

    return {
      'tiles': '$totalTiles tiles',
      'boxes': '$totalBoxes boxes ($perBox tiles/box)',
      'area': '${roomArea.toStringAsFixed(1)} m² (${(roomArea * 10.7639).toStringAsFixed(1)} sq.ft)',
    };
  }

  // 5. Concrete Estimator
  Map<String, dynamic> _calcConcrete() {
    final l = double.tryParse(_concLCtrl.text) ?? 6;
    final w = double.tryParse(_concWCtrl.text) ?? 4;
    final d = double.tryParse(_concDCtrl.text) ?? 0.15;

    final wetVol = l * w * d;
    final dryVol = wetVol * 1.54; // dry shrinkage factor

    int cRatio = 1, sRatio = 2, aRatio = 4;
    if (_concMix.contains('1:1.5:3')) {
      cRatio = 1;
      sRatio = 2; // ~1.5
      aRatio = 3;
    } else if (_concMix.contains('1:3:6')) {
      cRatio = 1;
      sRatio = 3;
      aRatio = 6;
    }

    final totalParts = cRatio + sRatio + aRatio;
    final cementVolM3 = dryVol * (cRatio / totalParts);
    // 1 bag (50kg) cement is ~0.0347 m3
    final bags = (cementVolM3 / 0.0347).ceil();
    final sandVolM3 = dryVol * (sRatio / totalParts);
    final aggVolM3 = dryVol * (aRatio / totalParts);

    return {
      'wet': '${wetVol.toStringAsFixed(2)} m³',
      'bags': '$bags Bags (50kg each)',
      'sand': '${sandVolM3.toStringAsFixed(2)} m³ (${(sandVolM3 * 35.3147).toStringAsFixed(1)} cu.ft)',
      'gravel': '${aggVolM3.toStringAsFixed(2)} m³ (${(aggVolM3 * 35.3147).toStringAsFixed(1)} cu.ft)',
    };
  }

  // 6. Land Area Converter
  Map<String, String> _calcLand() {
    final val = double.tryParse(_landInputCtrl.text) ?? 1;

    // Base unit: Square Feet
    double sqFt = 0;
    switch (_landFromUnit) {
      case 'Acres':
        sqFt = val * 43560;
        break;
      case 'Cents':
        sqFt = val * 435.6;
        break;
      case 'Hectares':
        sqFt = val * 107639;
        break;
      case 'Square Feet':
        sqFt = val;
        break;
      case 'Square Meters':
        sqFt = val * 10.7639;
        break;
      case 'Guntha':
        sqFt = val * 1089;
        break;
      case 'Ground':
        sqFt = val * 2400;
        break;
      case 'Bigha (Standard)':
        sqFt = val * 27000;
        break;
    }

    return {
      'Acres': (sqFt / 43560).toStringAsFixed(4),
      'Cents': (sqFt / 435.6).toStringAsFixed(2),
      'Hectares': (sqFt / 107639).toStringAsFixed(4),
      'Square Feet': sqFt.toStringAsFixed(1),
      'Square Meters': (sqFt / 10.7639).toStringAsFixed(2),
      'Guntha': (sqFt / 1089).toStringAsFixed(2),
      'Ground': (sqFt / 2400).toStringAsFixed(2),
      'Bigha': (sqFt / 27000).toStringAsFixed(3),
    };
  }

  // 7. Water Tank Capacity
  Map<String, dynamic> _calcTank() {
    double volM3 = 0;
    if (_isRectTank) {
      final l = double.tryParse(_tankLCtrl.text) ?? 2.5;
      final w = double.tryParse(_tankWCtrl.text) ?? 2.0;
      final h = double.tryParse(_tankHCtrl.text) ?? 1.5;
      volM3 = l * w * h;
    } else {
      final diam = double.tryParse(_tankDiamCtrl.text) ?? 1.8;
      final h = double.tryParse(_tankHCtrl.text) ?? 1.5;
      final radius = diam / 2.0;
      volM3 = math.pi * radius * radius * h;
    }

    final liters = (volM3 * 1000).round();
    final gallons = (liters * 0.264172).round();

    return {
      'liters': '$liters Liters',
      'gallons': '$gallons US Gallons',
      'vol': '${volM3.toStringAsFixed(2)} m³',
    };
  }

  // 8. Appliance Consumption
  Map<String, dynamic> _calcAppliance() {
    final watts = double.tryParse(_appPowerCtrl.text) ?? 1500;
    final hours = double.tryParse(_appHoursCtrl.text) ?? 6;
    final rate = double.tryParse(_appRateCtrl.text) ?? 0.15;

    final dailyKwh = (watts * hours) / 1000.0;
    final monthlyKwh = dailyKwh * 30;
    final dailyCost = dailyKwh * rate;
    final monthlyCost = dailyCost * 30;
    final yearlyCost = dailyCost * 365;

    return {
      'monthlyCost': '\$${monthlyCost.toStringAsFixed(2)} / month (${monthlyKwh.toStringAsFixed(1)} kWh)',
      'daily': '\$${dailyCost.toStringAsFixed(2)} / day (${dailyKwh.toStringAsFixed(2)} kWh)',
      'yearly': '\$${yearlyCost.toStringAsFixed(2)} / year (${(dailyKwh * 365).toStringAsFixed(0)} kWh)',
    };
  }

  // 9. Travel Budget Splitter
  Map<String, dynamic> _calcTripDebts() {
    if (_tripMembers.isEmpty || _tripExpenses.isEmpty) {
      return {'total': '\$0', 'perPerson': '\$0', 'settlements': <String>[]};
    }

    double totalExp = 0;
    final Map<String, double> paidMap = {for (var m in _tripMembers) m: 0.0};

    for (final exp in _tripExpenses) {
      totalExp += exp.amount;
      paidMap[exp.paidBy] = (paidMap[exp.paidBy] ?? 0) + exp.amount;
    }

    final perPerson = totalExp / _tripMembers.length;
    final Map<String, double> netBalance = {};
    for (final m in _tripMembers) {
      netBalance[m] = (paidMap[m] ?? 0) - perPerson;
    }

    // Compute minimal debt settlements
    final List<MapEntry<String, double>> debtors = [];
    final List<MapEntry<String, double>> creditors = [];

    netBalance.forEach((name, bal) {
      if (bal < -0.01) {
        debtors.add(MapEntry(name, -bal));
      } else if (bal > 0.01) {
        creditors.add(MapEntry(name, bal));
      }
    });

    final List<String> settlements = [];
    int dIdx = 0, cIdx = 0;
    while (dIdx < debtors.length && cIdx < creditors.length) {
      final debtor = debtors[dIdx];
      final creditor = creditors[cIdx];
      final settleAmt = math.min(debtor.value, creditor.value);

      settlements.add('${debtor.key} pays ${creditor.key}: \$${settleAmt.toStringAsFixed(2)}');

      debtors[dIdx] = MapEntry(debtor.key, debtor.value - settleAmt);
      creditors[cIdx] = MapEntry(creditor.key, creditor.value - settleAmt);

      if (debtors[dIdx].value <= 0.01) dIdx++;
      if (creditors[cIdx].value <= 0.01) cIdx++;
    }

    return {
      'total': '\$${totalExp.toStringAsFixed(2)}',
      'perPerson': '\$${perPerson.toStringAsFixed(2)}',
      'settlements': settlements,
    };
  }

  // 10. Download Time
  Map<String, dynamic> _calcDownloadTime() {
    final sizeVal = double.tryParse(_dlSizeCtrl.text) ?? 45;
    final speedVal = double.tryParse(_dlSpeedCtrl.text) ?? 100;

    if (sizeVal <= 0 || speedVal <= 0) {
      return {'time': '0s', 'desc': 'Invalid inputs'};
    }

    // Size in Megabits (Mb)
    double sizeMegabits = sizeVal * 8; // if MB
    if (_dlSizeUnit == 'GB') sizeMegabits = sizeVal * 8 * 1024;
    if (_dlSizeUnit == 'TB') sizeMegabits = sizeVal * 8 * 1024 * 1024;

    // Speed in Megabits per second (Mbps)
    double speedMbps = speedVal;
    if (_dlSpeedUnit == 'MBps' || _dlSpeedUnit == 'MB/s') speedMbps = speedVal * 8;
    if (_dlSpeedUnit == 'Gbps') speedMbps = speedVal * 1000;

    final totalSeconds = (sizeMegabits / speedMbps).round();
    final dd = totalSeconds ~/ 86400;
    final hh = (totalSeconds % 86400) ~/ 3600;
    final mm = (totalSeconds % 3600) ~/ 60;
    final ss = totalSeconds % 60;

    String timeStr = '';
    if (dd > 0) timeStr += '${dd}d ';
    if (hh > 0 || dd > 0) timeStr += '${hh}h ';
    timeStr += '${mm}m ${ss}s';

    final effectiveMbSec = (speedMbps / 8).toStringAsFixed(1);

    return {
      'time': timeStr.trim(),
      'desc': 'Effective transfer speed: ~$effectiveMbSec MB/second',
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ToolScaffold(
      title: 'Home, Construction & Travel Suite',
      category: ToolCategory.homeTravel,
      toolId: 'home_travel_toolkit',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTabs(isDark),
          const SizedBox(height: 16),
          if (_activeTab == HomeTravelTab.fuel) _buildFuelTab(isDark),
          if (_activeTab == HomeTravelTab.ev) _buildEvTab(isDark),
          if (_activeTab == HomeTravelTab.paint) _buildPaintTab(isDark),
          if (_activeTab == HomeTravelTab.flooring) _buildFlooringTab(isDark),
          if (_activeTab == HomeTravelTab.concrete) _buildConcreteTab(isDark),
          if (_activeTab == HomeTravelTab.land) _buildLandTab(isDark),
          if (_activeTab == HomeTravelTab.waterTank) _buildWaterTankTab(isDark),
          if (_activeTab == HomeTravelTab.appliance) _buildApplianceTab(isDark),
          if (_activeTab == HomeTravelTab.tripSplitter) _buildTripSplitterTab(isDark),
          if (_activeTab == HomeTravelTab.downloadTime) _buildDownloadTimeTab(isDark),
        ],
      ),
    );
  }

  Widget _buildTabs(bool isDark) {
    return FeatureTabSelector<HomeTravelTab>(
      tabs: HomeTravelTab.values
          .map((tab) => FeatureTabItem(value: tab, label: tab.label, icon: tab.icon))
          .toList(),
      activeTab: _activeTab,
      accentColor: AppColors.catHomeTravel,
      title: 'Home & Travel Calculators',
      onTabSelected: (tab) => setState(() => _activeTab = tab),
    );
  }

  // --- TAB 1: FUEL ---
  Widget _buildFuelTab(bool isDark) {
    final res = _calcFuel();
    return Column(
      children: [
        ResultCard(
          title: 'Total Trip Fuel Cost',
          primaryResult: res['total'] as String,
          subtitle: '${res['perPerson']} • Fuel Required: ${res['fuelNeeded']}',
          accentColor: AppColors.catHomeTravel,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: ModernTextField(label: 'Trip Distance (km/mi)', controller: _fuelDistCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
            const SizedBox(width: 10),
            Expanded(child: ModernTextField(label: 'Mileage (km/L or MPG)', controller: _fuelMileageCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: ModernTextField(label: 'Fuel Price / Unit', controller: _fuelPriceCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
            const SizedBox(width: 10),
            Expanded(child: ModernTextField(label: 'Passengers Count', controller: _fuelPaxCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
          ],
        ),
      ],
    );
  }

  // --- TAB 2: EV CHARGING ---
  Widget _buildEvTab(bool isDark) {
    final res = _calcEv();
    return Column(
      children: [
        ResultCard(
          title: 'EV Charging Session Cost',
          primaryResult: res['cost'] as String,
          subtitle: 'Est. Charging Time: ${res['time']} • Energy Added: ${res['energy']}',
          accentColor: AppColors.catHomeTravel,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: ModernTextField(label: 'Battery Size (kWh)', controller: _evCapacityCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
            const SizedBox(width: 10),
            Expanded(child: ModernTextField(label: 'Electricity Rate (\$/kWh)', controller: _evRateCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: ModernTextField(label: 'Start Charge %', controller: _evCurrentPctCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
            const SizedBox(width: 8),
            Expanded(child: ModernTextField(label: 'Target Charge %', controller: _evTargetPctCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
            const SizedBox(width: 8),
            Expanded(child: ModernTextField(label: 'Charger (kW)', controller: _evPowerCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
          ],
        ),
      ],
    );
  }

  // --- TAB 3: PAINT ---
  Widget _buildPaintTab(bool isDark) {
    final res = _calcPaint();
    return Column(
      children: [
        ResultCard(
          title: 'Estimated Paint Required',
          primaryResult: res['gallons'] as String,
          subtitle: 'Equivalent to ${res['liters']} • Net Wall Area: ${res['netArea']}',
          accentColor: AppColors.catHomeTravel,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: ModernTextField(label: 'Length (ft)', controller: _paintLengthCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
            const SizedBox(width: 8),
            Expanded(child: ModernTextField(label: 'Width (ft)', controller: _paintWidthCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
            const SizedBox(width: 8),
            Expanded(child: ModernTextField(label: 'Height (ft)', controller: _paintHeightCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: ModernTextField(label: 'Doors', controller: _paintDoorsCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
            const SizedBox(width: 8),
            Expanded(child: ModernTextField(label: 'Windows', controller: _paintWindowsCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
            const SizedBox(width: 8),
            Expanded(child: ModernTextField(label: 'Coats', controller: _paintCoatsCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
          ],
        ),
      ],
    );
  }

  // --- TAB 4: FLOORING ---
  Widget _buildFlooringTab(bool isDark) {
    final res = _calcFlooring();
    return Column(
      children: [
        ResultCard(
          title: 'Flooring Tiles Required',
          primaryResult: res['tiles'] as String,
          subtitle: '${res['boxes']} • Room Area: ${res['area']}',
          accentColor: AppColors.catHomeTravel,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: ModernTextField(label: 'Room Length (m)', controller: _floorRoomLCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
            const SizedBox(width: 10),
            Expanded(child: ModernTextField(label: 'Room Width (m)', controller: _floorRoomWCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: ModernTextField(label: 'Tile Length (cm)', controller: _floorTileLCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
            const SizedBox(width: 8),
            Expanded(child: ModernTextField(label: 'Tile Width (cm)', controller: _floorTileWCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
            const SizedBox(width: 8),
            Expanded(child: ModernTextField(label: 'Wastage %', controller: _floorWastageCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
          ],
        ),
      ],
    );
  }

  // --- TAB 5: CONCRETE ---
  Widget _buildConcreteTab(bool isDark) {
    final res = _calcConcrete();
    return Column(
      children: [
        ResultCard(
          title: 'Cement & Sand Estimate',
          primaryResult: res['bags'] as String,
          subtitle: 'Sand: ${res['sand']} • Gravel: ${res['gravel']}',
          accentColor: AppColors.catHomeTravel,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: ModernTextField(label: 'Length (m)', controller: _concLCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
            const SizedBox(width: 8),
            Expanded(child: ModernTextField(label: 'Width (m)', controller: _concWCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
            const SizedBox(width: 8),
            Expanded(child: ModernTextField(label: 'Thickness (m)', controller: _concDCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _concMix,
          decoration: InputDecoration(labelText: 'Mix Ratio', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
          items: ['1:2:4 (M15 General)', '1:1.5:3 (M20 Structural / Slab)', '1:3:6 (M10 Foundation Footing)']
              .map((m) => DropdownMenuItem(value: m, child: Text(m)))
              .toList(),
          onChanged: (v) => setState(() => _concMix = v ?? _concMix),
        ),
      ],
    );
  }

  // --- TAB 6: LAND AREA ---
  Widget _buildLandTab(bool isDark) {
    final res = _calcLand();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              flex: 2,
              child: ModernTextField(
                label: 'Land Quantity',
                controller: _landInputCtrl,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                initialValue: _landFromUnit,
                decoration: InputDecoration(labelText: 'Unit', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                items: ['Acres', 'Cents', 'Hectares', 'Square Feet', 'Square Meters', 'Guntha', 'Ground', 'Bigha (Standard)']
                    .map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 13))))
                    .toList(),
                onChanged: (v) => setState(() => _landFromUnit = v ?? _landFromUnit),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text('Converted Land Units', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...res.entries.map((e) {
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(e.value, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.catHomeTravel)),
              ],
            ),
          );
        }),
      ],
    );
  }

  // --- TAB 7: WATER TANK ---
  Widget _buildWaterTankTab(bool isDark) {
    final res = _calcTank();
    return Column(
      children: [
        ResultCard(
          title: 'Tank Water Capacity',
          primaryResult: res['liters'] as String,
          subtitle: '${res['gallons']} • Volume: ${res['vol']}',
          accentColor: AppColors.catHomeTravel,
        ),
        const SizedBox(height: 16),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('Rectangular Tank')),
            ButtonSegment(value: false, label: Text('Cylindrical Tank')),
          ],
          selected: {_isRectTank},
          onSelectionChanged: (set) => setState(() => _isRectTank = set.first),
        ),
        const SizedBox(height: 16),
        if (_isRectTank) ...[
          Row(
            children: [
              Expanded(child: ModernTextField(label: 'Length (m)', controller: _tankLCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
              const SizedBox(width: 8),
              Expanded(child: ModernTextField(label: 'Width (m)', controller: _tankWCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
              const SizedBox(width: 8),
              Expanded(child: ModernTextField(label: 'Height (m)', controller: _tankHCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
            ],
          ),
        ] else ...[
          Row(
            children: [
              Expanded(child: ModernTextField(label: 'Diameter (m)', controller: _tankDiamCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
              const SizedBox(width: 10),
              Expanded(child: ModernTextField(label: 'Height (m)', controller: _tankHCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
            ],
          ),
        ],
      ],
    );
  }

  // --- TAB 8: APPLIANCE POWER ---
  Widget _buildApplianceTab(bool isDark) {
    final res = _calcAppliance();
    return Column(
      children: [
        ResultCard(
          title: 'Monthly Electricity Cost',
          primaryResult: res['monthlyCost'] as String,
          subtitle: '${res['daily']}\n${res['yearly']}',
          accentColor: AppColors.catHomeTravel,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: ModernTextField(label: 'Power Rating (Watts)', controller: _appPowerCtrl, keyboardType: TextInputType.number, hintText: 'e.g. 1500 (AC/Heater)', onChanged: (_) => setState(() {}))),
            const SizedBox(width: 10),
            Expanded(child: ModernTextField(label: 'Hours Used / Day', controller: _appHoursCtrl, keyboardType: TextInputType.number, hintText: 'e.g. 8', onChanged: (_) => setState(() {}))),
          ],
        ),
        const SizedBox(height: 12),
        ModernTextField(
          label: 'Electricity Tariff (\$/kWh)',
          controller: _appRateCtrl,
          keyboardType: TextInputType.number,
          hintText: 'e.g. 0.15',
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  // --- TAB 9: TRIP BUDGET SPLITTER ---
  Widget _buildTripSplitterTab(bool isDark) {
    final res = _calcTripDebts();
    final settlements = res['settlements'] as List<String>;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'Trip Expenses Summary',
          primaryResult: '${res['total']} Total Spend',
          subtitle: '${res['perPerson']} Fair Share per Traveler',
          accentColor: AppColors.catHomeTravel,
        ),
        const SizedBox(height: 16),
        const Text('Who Owes Whom (Settlements)', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (settlements.isEmpty)
          const Text('All expenses are perfectly settled!', style: TextStyle(color: Colors.green))
        else
          ...settlements.map((s) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.catHomeTravel),
                    const SizedBox(width: 8),
                    Text(s, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              )),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: ModernTextField(label: 'Expense', controller: _newExpTitleCtrl, hintText: 'e.g. Museum passes'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ModernTextField(label: 'Amount (\$)', controller: _newExpAmtCtrl, keyboardType: TextInputType.number),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _newExpPayer,
                decoration: InputDecoration(labelText: 'Paid By', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                items: _tripMembers.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                onChanged: (v) => setState(() => _newExpPayer = v ?? _newExpPayer),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.catHomeTravel,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              onPressed: () {
                final title = _newExpTitleCtrl.text.trim();
                final amt = double.tryParse(_newExpAmtCtrl.text) ?? 0;
                if (title.isNotEmpty && amt > 0) {
                  setState(() {
                    _tripExpenses.add(TripExpenseItem(title: title, amount: amt, paidBy: _newExpPayer));
                    _newExpTitleCtrl.clear();
                    _newExpAmtCtrl.clear();
                  });
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  // --- TAB 10: DOWNLOAD TIME ---
  Widget _buildDownloadTimeTab(bool isDark) {
    final res = _calcDownloadTime();
    return Column(
      children: [
        ResultCard(
          title: 'Estimated Download Time',
          primaryResult: res['time'] as String,
          subtitle: res['desc'] as String,
          accentColor: AppColors.catHomeTravel,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: ModernTextField(label: 'File Size', controller: _dlSizeCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {})),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _dlSizeUnit,
                decoration: InputDecoration(labelText: 'Unit', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                items: ['MB', 'GB', 'TB'].map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                onChanged: (v) => setState(() => _dlSizeUnit = v ?? _dlSizeUnit),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: ModernTextField(label: 'Internet Speed', controller: _dlSpeedCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {})),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _dlSpeedUnit,
                decoration: InputDecoration(labelText: 'Unit', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                items: ['Mbps', 'MB/s', 'Gbps'].map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                onChanged: (v) => setState(() => _dlSpeedUnit = v ?? _dlSpeedUnit),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
