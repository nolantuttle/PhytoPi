import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:phytopi_dashboard/shared/controllers/smooth_scroll_controller.dart';

import '../../dashboard/screens/dashboard_screen.dart';
import '../models/landing_models.dart';
import 'category_detail_screen.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/login_screen.dart';

/// Landing page with dark hero section that gradually lightens on scroll
/// Inspired by modern tech/DeFi landing pages with e-commerce functionality
class LandingPageScreen extends StatefulWidget {
  const LandingPageScreen({super.key});

  @override
  State<LandingPageScreen> createState() => _LandingPageScreenState();
}

class _LandingPageScreenState extends State<LandingPageScreen> {
  final ScrollController _scrollController = SmoothScrollController(
    pointerScrollDuration: const Duration(milliseconds: 280),
    pointerScrollCurve: Curves.easeOutCubic,
    pointerScrollMultiplier: 0.38,
  );
  
  // Neon green accent color (inspired by Vivosun screenshot)
  static const Color _accentColor = Color(0xFF00FF88); // Bright neon green
  static const Color _darkBackground = Color(0xFF0A0A0A);
  static const Color _lightBackground = Color(0xFF1A1A1A);
  static const double _backgroundTransitionMaxScroll = 800.0;
  static const int _backgroundColorBuckets = 60;

  final ValueNotifier<Color> _backgroundColorNotifier =
      ValueNotifier<Color>(_darkBackground);
  int _currentBackgroundBucket = 0;

  final Map<String, List<CategoryColumnData>> _categoryMenuData = {
    'Smart Box': const [
      CategoryColumnData(
        title: 'Smart Box',
        links: ['Smart Grow Box', 'Smart Curing Box'],
      ),
      CategoryColumnData(
        title: 'Smart Grow Box',
        links: ['VGrow', 'VGrow Accessories'],
      ),
    ],
    'Grow Tent Kits': const [
      CategoryColumnData(
        title: 'Complete Kits',
        links: ['2x2 Kits', '2x4 Kits', '4x4 Kits'],
      ),
      CategoryColumnData(
        title: 'Bundles',
        links: ['Starter Bundle', 'Pro Bundle'],
      ),
    ],
    'Controllers': const [
      CategoryColumnData(
        title: 'Environment',
        links: ['Temp Controller', 'CO₂ Controller'],
      ),
      CategoryColumnData(
        title: 'Automation',
        links: ['Smart Timers', 'Power Strip'],
      ),
    ],
    'Grow Tents': const [
      CategoryColumnData(
        title: 'Frame Sizes',
        links: ['2x2 Tent', '4x4 Tent', '5x5 Tent'],
      ),
      CategoryColumnData(
        title: 'Specialty',
        links: ['Propagation Tent', 'Mylar Tent'],
      ),
    ],
    'Grow Lights': const [
      CategoryColumnData(
        title: 'Light Types',
        links: ['LED Bars', 'Quantum Boards', 'UV Boosters'],
      ),
      CategoryColumnData(
        title: 'Applications',
        links: ['Veg Lighting', 'Bloom Lighting'],
      ),
    ],
    'Ventilation': const [
      CategoryColumnData(
        title: 'Airflow',
        links: ['Inline Fans', 'Ducting Kits'],
      ),
      CategoryColumnData(
        title: 'Filtration',
        links: ['Carbon Filters', 'Intake Filters'],
      ),
    ],
    'Circulation': const [
      CategoryColumnData(
        title: 'Air Movement',
        links: ['Clip Fans', 'Oscillating Fans'],
      ),
      CategoryColumnData(
        title: 'Automation',
        links: ['Smart Fan Kit', 'Rhythm Schedules'],
      ),
    ],
    'Temperature & Humidity': const [
      CategoryColumnData(
        title: 'Monitoring',
        links: ['Climate Sensors', 'Smart Probes'],
      ),
      CategoryColumnData(
        title: 'Conditioning',
        links: ['Humidifiers', 'Dehumidifiers'],
      ),
    ],
    'Accessories': const [
      CategoryColumnData(
        title: 'Plant Care',
        links: ['Trimming Tools', 'Trellis Netting'],
      ),
      CategoryColumnData(
        title: 'Maintenance',
        links: ['Replacement Filters', 'Spare Parts'],
      ),
    ],
  };

  final Map<String, List<CategoryProduct>> _categoryProducts = {
    'Smart Box': const [
      CategoryProduct(
        title: 'VGrow Smart Grow Box',
        description: 'Automated cabinet with adaptive light recipes.',
        price: '\$599',
        icon: Icons.sensors_rounded,
        tags: ['Smart Grow Box', 'VGrow'],
        isNew: true,
      ),
      CategoryProduct(
        title: 'Smart Curing Box',
        description: 'Precision drying chamber with carbon scrubber.',
        price: '\$349',
        icon: Icons.widgets_outlined,
        tags: ['Smart Curing Box'],
      ),
      CategoryProduct(
        title: 'VGrow Accessory Pack',
        description: 'Shelves, trellises, and filter upgrades.',
        price: '\$129',
        icon: Icons.extension_outlined,
        tags: ['VGrow Accessories'],
      ),
    ],
    'Grow Tent Kits': const [
      CategoryProduct(
        title: '2x2 Urban Kit',
        description: 'Compact tent with silent ventilation.',
        price: '\$219',
        icon: Icons.crop_square,
        tags: ['2x2 Kits', 'Starter Bundle'],
      ),
      CategoryProduct(
        title: '2x4 Flex Kit',
        description: 'Balanced kit with controller-ready ports.',
        price: '\$329',
        icon: Icons.view_week,
        tags: ['2x4 Kits', 'Pro Bundle'],
      ),
      CategoryProduct(
        title: '4x4 Pro Kit',
        description: 'Double-layer canvas and upgraded ducting.',
        price: '\$459',
        icon: Icons.crop_din,
        tags: ['4x4 Kits', 'Pro Bundle'],
      ),
    ],
    'Controllers': const [
      CategoryProduct(
        title: 'Temp & Humidity Hub',
        description: 'Dial-in comfort with alerts and automations.',
        price: '\$149',
        icon: Icons.thermostat,
        tags: ['Temp Controller', 'Environment'],
      ),
      CategoryProduct(
        title: 'CO₂ Guardian',
        description: 'Keeps levels safe for you and your plants.',
        price: '\$179',
        icon: Icons.co2,
        tags: ['CO₂ Controller'],
      ),
      CategoryProduct(
        title: 'Smart Timer Strip',
        description: 'Six outlets with scene-based routines.',
        price: '\$99',
        icon: Icons.power,
        tags: ['Smart Timers', 'Automation', 'Power Strip'],
      ),
    ],
    'Grow Tents': const [
      CategoryProduct(
        title: '2x2 Precision Tent',
        description: 'Stealth footprint with reflective lining.',
        price: '\$109',
        icon: Icons.crop_square_outlined,
        tags: ['2x2 Tent', 'Frame Sizes'],
      ),
      CategoryProduct(
        title: '4x4 Flagship Tent',
        description: 'View window, tool rack, and spill tray.',
        price: '\$199',
        icon: Icons.crop_5_4,
        tags: ['4x4 Tent', 'Frame Sizes'],
      ),
      CategoryProduct(
        title: 'Propagation Dome Tent',
        description: 'Controlled humidity for seedlings.',
        price: '\$139',
        icon: Icons.spa,
        tags: ['Propagation Tent', 'Specialty'],
      ),
    ],
    'Grow Lights': const [
      CategoryProduct(
        title: 'LED Bar Array',
        description: 'Uniform PPFD with dimming curve.',
        price: '\$299',
        icon: Icons.lightbulb_outline,
        tags: ['LED Bars', 'Veg Lighting'],
        isNew: true,
      ),
      CategoryProduct(
        title: 'Quantum Board X',
        description: 'High-efficiency full spectrum board.',
        price: '\$249',
        icon: Icons.grid_view,
        tags: ['Quantum Boards', 'Bloom Lighting'],
      ),
      CategoryProduct(
        title: 'UV Boost Rail',
        description: 'Add-on rail for finishing cycles.',
        price: '\$79',
        icon: Icons.wb_incandescent,
        tags: ['UV Boosters'],
      ),
    ],
    'Ventilation': const [
      CategoryProduct(
        title: 'Silent Inline Fan',
        description: 'EC motor with smart ramping.',
        price: '\$129',
        icon: Icons.air,
        tags: ['Inline Fans', 'Airflow'],
      ),
      CategoryProduct(
        title: 'Quick Connect Duct Kit',
        description: 'Insulated ducts with tool-free clamps.',
        price: '\$89',
        icon: Icons.swap_calls,
        tags: ['Ducting Kits'],
      ),
      CategoryProduct(
        title: 'Carbon Scrubber Pro',
        description: '4-layer charcoal filter for smell control.',
        price: '\$149',
        icon: Icons.device_thermostat,
        tags: ['Carbon Filters', 'Filtration'],
      ),
    ],
    'Circulation': const [
      CategoryProduct(
        title: 'Clip Fan Duo',
        description: '360° swivel fans for canopy airflow.',
        price: '\$59',
        icon: Icons.air,
        tags: ['Clip Fans', 'Air Movement'],
      ),
      CategoryProduct(
        title: 'Oscillating Tower Fan',
        description: 'Slim profile for tents and cabinets.',
        price: '\$89',
        icon: Icons.waves,
        tags: ['Oscillating Fans'],
      ),
      CategoryProduct(
        title: 'Smart Fan Rhythm Kit',
        description: 'Automates airflow scenes and presets.',
        price: '\$129',
        icon: Icons.sync,
        tags: ['Smart Fan Kit', 'Automation'],
      ),
    ],
    'Temperature & Humidity': const [
      CategoryProduct(
        title: 'Climate Sensor Trio',
        description: 'Track VPD, dew point, and alerts.',
        price: '\$69',
        icon: Icons.water_drop,
        tags: ['Climate Sensors', 'Monitoring'],
      ),
      CategoryProduct(
        title: 'Smart Probe Kit',
        description: 'Inline probes for substrate moisture.',
        price: '\$99',
        icon: Icons.sensors,
        tags: ['Smart Probes'],
      ),
      CategoryProduct(
        title: 'Hybrid Humidifier',
        description: 'Top-fill with UV sterilization.',
        price: '\$119',
        icon: Icons.cloud,
        tags: ['Humidifiers', 'Conditioning'],
      ),
    ],
    'Accessories': const [
      CategoryProduct(
        title: 'Trellis Net Pack',
        description: 'Reusable trellis for training canopy.',
        price: '\$29',
        icon: Icons.cruelty_free,
        tags: ['Trellis Netting', 'Plant Care'],
      ),
      CategoryProduct(
        title: 'Precision Trimming Kit',
        description: 'Shears, bin, and cleaning brush.',
        price: '\$39',
        icon: Icons.content_cut,
        tags: ['Trimming Tools'],
      ),
      CategoryProduct(
        title: 'Filter Refresh Pack',
        description: 'Replacement HEPA + carbon combo.',
        price: '\$49',
        icon: Icons.rotate_right,
        tags: ['Replacement Filters', 'Maintenance'],
      ),
    ],
  };

  late final List<String> _categoryNames = _categoryMenuData.keys.toList();

  final Map<String, IconData> _categoryIcons = {
    'Smart Box': Icons.devices_other,
    'Grow Tent Kits': Icons.yard_outlined,
    'Controllers': Icons.tune,
    'Grow Tents': Icons.crop_square,
    'Grow Lights': Icons.lightbulb_outline,
    'Ventilation': Icons.air,
    'Circulation': Icons.waves,
    'Temperature & Humidity': Icons.thermostat,
    'Accessories': Icons.extension,
  };

  String? _expandedCategory;
  Timer? _megaMenuTimer;

  String _selectedIntegrationTab = 'Control Hub';

  final Map<String, String> _integrationDescriptions = {
    'Control Hub':
        'Coordinate every device with precision alerts, adaptive recipes, and cloud backups.',
    'Flex Tent':
        'Modular tent layouts that let you scale quickly while keeping airflow balanced.',
    'GrowCam':
        'Always-on monitoring with night vision, annotation markers, and instant share links.',
    'Nutrient Flow':
        'Dial-in irrigation pulses with EC monitoring, nutrient ratios, and fail-safe cutoffs.',
  };

  final Map<String, List<String>> _integrationHighlights = {
    'Control Hub': const [
      'Alerts sync across all devices',
      'Recipe presets from clones to bloom',
      'Automatic firmware rollbacks',
    ],
    'Flex Tent': const [
      'Snap-in panels for every footprint',
      'Cable routing with zero light leaks',
      'Shared ducting without pressure loss',
    ],
    'GrowCam': const [
      'True-color monitoring day or night',
      'Annotate issues for your crew remotely',
      'Share live clips without logins',
    ],
    'Nutrient Flow': const [
      'EC + pH tracked per recipe step',
      'Pulse irrigation with dry-back alerts',
      'Failsafe drain if sensors go offline',
    ],
  };

  final Map<String, IconData> _integrationIcons = {
    'Control Hub': Icons.hub,
    'Flex Tent': Icons.fence,
    'GrowCam': Icons.videocam_outlined,
    'Nutrient Flow': Icons.waterfall_chart,
  };

  final List<_ShowcaseCardData> _vSeriesProducts = const [
    _ShowcaseCardData(
      title: 'VGrow',
      description: 'A guided smart grow box with white-glove automation.',
      buttonLabel: 'Shop VGrow',
      badge: 'Starter',
      icon: Icons.eco_outlined,
    ),
    _ShowcaseCardData(
      title: 'VGrow Accessories',
      description: 'Shelving and climate upgrades compatible with any VSeries unit.',
      buttonLabel: 'Shop Accessories',
      badge: 'Add-ons',
      icon: Icons.extension_off,
    ),
  ];

  final List<_SetupShowcaseData> _setupShowcase = const [
    _SetupShowcaseData(
      title: 'Loft Studio Grow',
      description: 'Aesthetic grow that hides in plain sight and keeps neighbors happy.',
      tags: ['2x4 Flex Tent', 'Silent Ventilation', 'App Control'],
      icon: Icons.chair_alt,
    ),
    _SetupShowcaseData(
      title: 'Backyard Lab',
      description: 'Deploy two tents with shared controllers and remote drain.',
      tags: ['4x4 Flagship', 'Dual Controllers', 'Flood Tray'],
      icon: Icons.cottage,
    ),
  ];

  final List<_GearSpotlightItem> _gearSpotlight = const [
    _GearSpotlightItem(
      title: 'One-Touch Controller',
      description: 'Touch display with Wi-Fi, Bluetooth, and mesh failovers.',
      price: '\$229',
      badge: 'Core Gear',
    ),
    _GearSpotlightItem(
      title: 'Wireless Probes',
      description: 'Stackable sensors for climate, substrate, and reservoirs.',
      price: '\$89',
      badge: 'New Drop',
    ),
    _GearSpotlightItem(
      title: 'Inline Fan Duo',
      description: 'Pair of EC fans tuned for stealth circulation.',
      price: '\$159',
      badge: 'Bundle',
    ),
    _GearSpotlightItem(
      title: 'Stackable Totes',
      description: 'Food-grade totes with cam-lock lids for prep.',
      price: '\$59',
      badge: 'Accessory',
    ),
  ];

  final List<_GrowerStoryData> _growerStories = const [
    _GrowerStoryData(
      author: 'Mara • Chef Grower',
      headline: '“PhytoPi lets me pivot recipes overnight.”',
      excerpt:
          'Running two tents in a Brooklyn loft is tricky. The dashboard made dialing each strain effortless.',
    ),
    _GrowerStoryData(
      author: 'Javier • Botanical Lab',
      headline: '“Students finally get real-time data on every plant.”',
      excerpt:
          'Our campus lab logs every reading so classes can replay crop cycles like game film.',
    ),
  ];

  final List<_ReviewData> _reviewHighlights = const [
    _ReviewData(
      rating: 5,
      quote: 'Game changer for small apartments. Quiet, clean, and smart.',
      author: 'Anika • Verified Grower',
    ),
    _ReviewData(
      rating: 5,
      quote: 'Loved the automated alerts—caught an AC failure before lights out.',
      author: 'Cal • Hydro Enthusiast',
    ),
    _ReviewData(
      rating: 4,
      quote: 'Support team walked me through every step of my first setup.',
      author: 'Rei • New Grower',
    ),
    _ReviewData(
      rating: 5,
      quote: 'Integration tabs make it easy to train new staff quickly.',
      author: 'Devon • Collective Lead',
    ),
  ];

  final List<_InnerCircleData> _innerCirclePerks = const [
    _InnerCircleData(
      title: 'Grow Club',
      description: 'Quarterly live calls with R&D and cultivation coaches.',
      icon: Icons.groups,
    ),
    _InnerCircleData(
      title: 'Launch Lab',
      description: 'First dibs on beta firmware and experimental gear.',
      icon: Icons.science,
    ),
    _InnerCircleData(
      title: 'DIY Vault',
      description: 'Printable templates and wiring diagrams.',
      icon: Icons.handyman,
    ),
    _InnerCircleData(
      title: 'Rewards',
      description: 'Redeem points for accessories and private drops.',
      icon: Icons.card_giftcard,
    ),
  ];

  @override
  void initState() {
    super.initState();
    debugPrint('LandingPageScreen: initState');
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    debugPrint('LandingPageScreen: dispose');
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _megaMenuTimer?.cancel();
    _backgroundColorNotifier.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final offset = _scrollController.offset;
    final progress =
        (offset / _backgroundTransitionMaxScroll).clamp(0.0, 1.0);
    final bucket = (progress * _backgroundColorBuckets).round();
    if (bucket == _currentBackgroundBucket) return;

    _currentBackgroundBucket = bucket;
    final bucketProgress = bucket / _backgroundColorBuckets;
    _backgroundColorNotifier.value =
        Color.lerp(_darkBackground, _lightBackground, bucketProgress) ??
            _darkBackground;
  }

  void _setExpandedCategory(String? category) {
    if (_expandedCategory == category) return;
    setState(() {
      _expandedCategory = category;
    });
  }

  void _handleCategoryTriggerEnter(String category) {
    _cancelMegaMenuHide();
    _setExpandedCategory(category);
  }

  void _scheduleMegaMenuHide() {
    _megaMenuTimer?.cancel();
    _megaMenuTimer = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      setState(() => _expandedCategory = null);
    });
  }

  void _cancelMegaMenuHide() {
    _megaMenuTimer?.cancel();
  }

  void _openCategoryPage(BuildContext context, String category, {String? filterTag}) {
    final products = _categoryProducts[category];
    if (products == null || products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$category catalog is coming soon!')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryDetailScreen(
          categoryName: category,
          products: products,
          filterTag: filterTag,
        ),
      ),
    );
  }

  void _showMobileCategorySheet(BuildContext rootContext, String category) {
    final columns = _categoryMenuData[category];
    if (columns == null) return;

    showModalBottomSheet(
      context: rootContext,
      backgroundColor: _darkBackground,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      category,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _openCategoryPage(rootContext, category);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: _accentColor,
                    foregroundColor: Colors.black,
                  ),
                  child: Text('View $category Shop'),
                ),
                const SizedBox(height: 16),
                for (final column in columns) ...[
                  Text(
                    column.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...column.links.map((link) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _openCategoryPage(rootContext, category, filterTag: link);
                      },
                      leading: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                      title: Text(
                        link,
                        style: const TextStyle(color: Colors.white),
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  double _calculateCardWidth(BuildContext context, {double targetWidth = 360}) {
    final maxWidth = MediaQuery.of(context).size.width - 48;
    if (maxWidth <= 0) {
      return targetWidth;
    }
    return math.min(targetWidth, maxWidth);
  }

  @override
  Widget build(BuildContext context) {
    // Watch auth provider to rebuild on auth state changes
    context.watch<AuthProvider>();
    debugPrint('LandingPageScreen: build');

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: ValueListenableBuilder<Color>(
              valueListenable: _backgroundColorNotifier,
              builder: (_, color, __) {
                return ColoredBox(color: color);
              },
            ),
          ),
          Positioned.fill(
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                // Navigation Bar
                _buildNavigationBar(context),
                
                // Secondary Navigation Bar (Product Categories + Mega Menu)
                _buildSecondaryNavBar(context),
                
                // Black Friday style hero banner
                _buildPromoBanner(context),
                
                // V-Series intro + story
                _buildVSeriesIntro(context),
                
                // Product highlight cards
                _buildVSeriesProductsSection(context),
                
                // Setup showcase grid
                _buildSetupShowcaseSection(context),
                
                // Integration tabs
                _buildIntegrationSection(context),
                
                // Smart grow system hero
                _buildSmartGrowSystemSection(context),
                
                // Gear spotlight cards
                _buildGearSpotlightSection(context),
                
                // Quote badge
                _buildQuoteSection(context),
                
                // Grower story slider
                _buildGrowerStoriesSection(context),
                
                // Reviews
                _buildReviewsSection(context),
                
                // Inner circle CTA
                _buildInnerCircleSection(context),
                
                // Footer
                _buildFooter(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Navigation bar with search, links, and user menu
  Widget _buildNavigationBar(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: _backgroundColorNotifier,
      builder: (_, backgroundColor, __) {
        return SliverAppBar(
          floating: true,
          pinned: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          toolbarHeight: 80,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              color: backgroundColor.withOpacity(0.95),
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 900;
                    final isMedium = constraints.maxWidth > 600;
                    
                    final double searchMaxWidth = math.min(
                      isWide ? 520.0 : 420.0,
                      constraints.maxWidth * 0.5,
                    );
                    final double navSpacing = isWide ? 16.0 : 12.0;
                    
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.eco,
                                  color: Colors.white,
                                  size: 32,
                                ),
                                const SizedBox(width: 12),
                                const Flexible(
                                  child: Text(
                                    'PhytoPi',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (isMedium) ...[
                          const SizedBox(width: 16),
                          Expanded(
                            child: Align(
                              alignment: Alignment.center,
                              child: SizedBox(
                                width: searchMaxWidth,
                                child: Container(
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: TextField(
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      hintText: 'Search PhytoPi',
                                      hintStyle: TextStyle(
                                        color: Colors.white.withOpacity(0.5),
                                      ),
                                      prefixIcon: Icon(
                                        Icons.search,
                                        color: Colors.white.withOpacity(0.7),
                                      ),
                                      border: InputBorder.none,
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                        ] else ...[
                          const SizedBox(width: 16),
                          const Spacer(),
                        ],
                        Flexible(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isMedium) ...[
                                  _buildNavLink(context, 'Support', onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Support page coming soon!')),
                                    );
                                  }),
                                  SizedBox(width: navSpacing),
                                  _buildNavLink(context, 'Guide', onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Guide page coming soon!')),
                                    );
                                  }),
                                  SizedBox(width: navSpacing),
                                  _buildNavLink(context, 'Community', onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Community page coming soon!')),
                                    );
                                  }),
                                  SizedBox(width: navSpacing),
                                ],
                                
                                if (isWide) ...[
                                  InkWell(
                                    onTap: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Currency selector coming soon!')),
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.flag,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'USD',
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.9),
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                
                                PopupMenuButton<String>(
                                  icon: Icon(
                                    Icons.person_outline,
                                    color: Colors.white.withOpacity(0.9),
                                    size: 24,
                                  ),
                                  color: backgroundColor.withOpacity(0.98),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  onSelected: (value) {
                                    if (value == 'dashboard') {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const DashboardScreen(),
                                        ),
                                      );
                                    } else if (value == 'profile') {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Profile page coming soon!')),
                                      );
                                    } else if (value == 'settings') {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Settings page coming soon!')),
                                      );
                                    } else if (value == 'login') {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const LoginScreen(),
                                        ),
                                      );
                                    } else if (value == 'logout') {
                                      context.read<AuthProvider>().signOut();
                                    }
                                  },
                                  itemBuilder: (BuildContext context) {
                                    final authProvider = context.read<AuthProvider>();
                                    final isAuthenticated = authProvider.isAuthenticated;

                                    return [
                                      if (isAuthenticated) ...[
                                        const PopupMenuItem<String>(
                                          value: 'dashboard',
                                          child: Row(
                                            children: [
                                              Icon(Icons.dashboard, size: 20, color: Colors.white),
                                              SizedBox(width: 12),
                                              Text(
                                                'Dashboard',
                                                style: TextStyle(color: Colors.white),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem<String>(
                                          value: 'profile',
                                          child: Row(
                                            children: [
                                              Icon(Icons.person, size: 20, color: Colors.white),
                                              SizedBox(width: 12),
                                              Text(
                                                'Profile',
                                                style: TextStyle(color: Colors.white),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem<String>(
                                          value: 'settings',
                                          child: Row(
                                            children: [
                                              Icon(Icons.settings, size: 20, color: Colors.white),
                                              SizedBox(width: 12),
                                              Text(
                                                'Settings',
                                                style: TextStyle(color: Colors.white),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuDivider(),
                                      ],
                                      PopupMenuItem<String>(
                                        value: isAuthenticated ? 'logout' : 'login',
                                        child: Row(
                                          children: [
                                            Icon(isAuthenticated ? Icons.logout : Icons.login, size: 20, color: Colors.white),
                                            const SizedBox(width: 12),
                                            Text(
                                              isAuthenticated ? 'Logout' : 'Login',
                                              style: const TextStyle(color: Colors.white),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ];
                                  },
                                ),
                                const SizedBox(width: 8),
                                
                                // Shopping Cart Icon
                                Stack(
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        Icons.shopping_cart_outlined,
                                        color: Colors.white.withOpacity(0.9),
                                        size: 24,
                                      ),
                                      onPressed: () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Shopping cart coming soon!')),
                                        );
                                      },
                                    ),
                                    Positioned(
                                      right: 8,
                                      top: 8,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: _accentColor,
                                          shape: BoxShape.circle,
                                        ),
                                        constraints: const BoxConstraints(
                                          minWidth: 16,
                                          minHeight: 16,
                                        ),
                                        child: const Text(
                                          '0',
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Secondary navigation bar with product categories and mega menu
  Widget _buildSecondaryNavBar(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          border: Border(
            bottom: BorderSide(
              color: Colors.white.withOpacity(0.08),
              width: 1,
            ),
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isTablet = constraints.maxWidth > 600;

            if (!isTablet) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: _categoryNames.map((category) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: ActionChip(
                        label: Text(category),
                        onPressed: () => _showMobileCategorySheet(context, category),
                        backgroundColor: Colors.white.withOpacity(0.08),
                        labelStyle: const TextStyle(color: Colors.white),
                        side: BorderSide(color: Colors.white.withOpacity(0.1)),
                      ),
                    );
                  }).toList(),
                ),
              );
            }

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Wrap(
                    spacing: 32,
                    runSpacing: 12,
                    children: _categoryNames.map((category) {
                      return _buildCategoryTrigger(context, category);
                    }).toList(),
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    final slideAnimation = Tween<Offset>(
                      begin: const Offset(0, -0.03),
                      end: Offset.zero,
                    ).animate(animation);
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: slideAnimation,
                        child: child,
                      ),
                    );
                  },
                  child: _expandedCategory == null
                      ? const SizedBox.shrink()
                      : _buildMegaMenu(context, _expandedCategory!),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCategoryTrigger(BuildContext context, String category) {
    final isActive = _expandedCategory == category;

    return MouseRegion(
      onEnter: (_) => _handleCategoryTriggerEnter(category),
      onExit: (_) => _scheduleMegaMenuHide(),
      child: GestureDetector(
        onTap: () => _openCategoryPage(context, category),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: isActive ? Colors.white.withOpacity(0.08) : Colors.transparent,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                category,
                style: TextStyle(
                  color: isActive ? _accentColor : Colors.white.withOpacity(0.9),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down,
                size: 18,
                color: isActive ? _accentColor : Colors.white.withOpacity(0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMegaMenu(BuildContext context, String category) {
    final columns = _categoryMenuData[category];
    if (columns == null) return const SizedBox.shrink();
    final icon = _categoryIcons[category] ?? Icons.inventory_2_outlined;

    return MouseRegion(
      onEnter: (_) => _cancelMegaMenuHide(),
      onExit: (_) => _scheduleMegaMenuHide(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.92),
          border: Border(
            top: BorderSide(color: Colors.white.withOpacity(0.05)),
            bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: columns.map((column) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            column.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...column.links.map((link) {
                            return InkWell(
                              onTap: () => _openCategoryPage(context, category, filterTag: link),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6.0),
                                child: Row(
                                  children: [
                                    Icon(Icons.arrow_right, color: _accentColor, size: 18),
                                    const SizedBox(width: 4),
                                    Text(
                                      link,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.85),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(width: 32),
            Expanded(
              flex: 2,
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: _accentColor, size: 54),
                    const SizedBox(height: 12),
                    Text(
                      'Shop $category',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => _openCategoryPage(context, category),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withOpacity(0.4)),
                      ),
                      child: const Text('View all'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavLink(BuildContext context, String text, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
          softWrap: false,
        ),
      ),
    );
  }

  Widget _buildCTAButton(BuildContext context, String text, {required VoidCallback onPressed}) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: _accentColor,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        minimumSize: const Size(0, 44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        elevation: 0,
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
        overflow: TextOverflow.ellipsis,
        softWrap: false,
      ),
    );
  }

  /// Sale hero banner
  Widget _buildPromoBanner(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF090909), Color(0xFF151515)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: Text(
                'IN ITS BLACK FRIDAY DROP MODE',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'BLACK FRIDAY',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 64,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'UP TO 45% OFF SITEWIDE',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _accentColor,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Lock in your automation stack before the season flips. Hardware, sensors, and cloud upgrades all ship in time for your next harvest.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 12,
              children: [
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentColor,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: const Text(
                    'Claim Coupon',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white, width: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: const Text('View Deals'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Nov 11 - Nov 30 | While supplies last',
              style: TextStyle(color: Colors.white.withOpacity(0.6)),
            ),
          ],
        ),
      ),
    );
  }

  /// Intro section inspired by VSeries layout
  Widget _buildVSeriesIntro(BuildContext context) {
    Widget buildCopy() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'V SERIES',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              letterSpacing: 4,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Reimagining Indoor Growing.\nThe VSeries.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.bold,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Ambient-friendly hardware with pro-grade analytics. VSeries build-outs keep your grow discreet while dialing in every micro-climate.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.75),
              fontSize: 16,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentColor,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: const Text('Explore VSeries'),
              ),
              TextButton(
                onPressed: () {},
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Watch the tour'),
                    SizedBox(width: 4),
                    Icon(Icons.play_circle_outline),
                  ],
                ),
              ),
            ],
          ),
        ],
      );
    }

    Widget buildMock() {
      return Container(
        height: 280,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Center(
          child: Icon(Icons.devices_other, color: _accentColor, size: 120),
        ),
      );
    }

    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isStacked = constraints.maxWidth < 900;
            if (isStacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildCopy(),
                  const SizedBox(height: 32),
                  buildMock(),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: buildCopy()),
                const SizedBox(width: 32),
                Expanded(child: buildMock()),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Product cards for VSeries
  Widget _buildVSeriesProductsSection(BuildContext context) {
    final cardWidth = _calculateCardWidth(context, targetWidth: 380);

    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Wrap(
          spacing: 24,
          runSpacing: 24,
          children: _vSeriesProducts.map((product) {
            return SizedBox(
              width: cardWidth,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: _accentColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          product.badge,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: Colors.white.withOpacity(0.06),
                      child: Icon(product.icon, color: _accentColor, size: 36),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      product.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      product.description,
                      style: TextStyle(color: Colors.white.withOpacity(0.7)),
                    ),
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () {},
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(product.buttonLabel),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward, size: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Setup showcase cards
  Widget _buildSetupShowcaseSection(BuildContext context) {
    final cardWidth = _calculateCardWidth(context, targetWidth: 480);

    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Build the smart setup that fits your grow style.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Pick a layout, layer automation, and keep expanding with zero downtime.',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing: 24,
              runSpacing: 24,
              children: _setupShowcase.map((setup) {
                return SizedBox(
                  width: cardWidth,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.05),
                          Colors.white.withOpacity(0.02),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 32,
                              backgroundColor: Colors.white.withOpacity(0.08),
                              child: Icon(setup.icon, color: _accentColor, size: 32),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                setup.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          setup.description,
                          style: TextStyle(color: Colors.white.withOpacity(0.7)),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: setup.tags.map((tag) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                tag,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  /// Integration tabs with placeholder device preview
  Widget _buildIntegrationSection(BuildContext context) {
    final tabs = _integrationDescriptions.keys.toList();
    final description = _integrationDescriptions[_selectedIntegrationTab] ?? '';
    final highlights = _integrationHighlights[_selectedIntegrationTab] ?? const [];
    final icon = _integrationIcons[_selectedIntegrationTab] ?? Icons.hub;

    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 56),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'All your gear working together in one intelligent system.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: tabs.map((tab) {
                final isActive = tab == _selectedIntegrationTab;
                return ChoiceChip(
                  label: Text(tab),
                  selected: isActive,
                  onSelected: (_) {
                    setState(() => _selectedIntegrationTab = tab);
                  },
                  selectedColor: _accentColor.withOpacity(0.2),
                  labelStyle: TextStyle(
                    color: isActive ? Colors.black : Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  backgroundColor: Colors.white.withOpacity(0.05),
                  side: BorderSide(
                    color: isActive ? _accentColor : Colors.white.withOpacity(0.2),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isStacked = constraints.maxWidth < 900;
                  final content = [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedIntegrationTab,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            description,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.75),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 20),
                          ...highlights.map((point) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6.0),
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle, color: _accentColor, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      point,
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(width: 32, height: 32),
                    Expanded(
                      child: Container(
                        height: 240,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withOpacity(0.08)),
                        ),
                        child: Center(
                          child: Icon(icon, color: _accentColor, size: 96),
                        ),
                      ),
                    ),
                  ];

                  if (isStacked) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        content[0],
                        const SizedBox(height: 24),
                        SizedBox(width: double.infinity, child: content[2]),
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: content,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmartGrowSystemSection(BuildContext context) {
    final features = [
      {
        'icon': Icons.notifications_active_outlined,
        'title': 'Proactive alerts',
        'desc': 'Every trigger captured with context and auto-remediation tips.',
      },
      {
        'icon': Icons.timeline,
        'title': 'Deep timelines',
        'desc': 'Replay entire harvests with sensor overlays and crew notes.',
      },
      {
        'icon': Icons.cloud_sync_outlined,
        'title': 'Cloud + local sync',
        'desc': 'Offline safe modes keep crops protected if Wi-Fi drops.',
      },
      {
        'icon': Icons.security,
        'title': 'Secure sharing',
        'desc': 'Give partners a read-only seat or export audits instantly.',
      },
    ];

    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 56),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.02),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Smart Grow System',
              style: TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'All of your climate, cameras, dosing, and ventilation synced in one neon-green dashboard.',
              style: TextStyle(color: Colors.white.withOpacity(0.75)),
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing: 24,
              runSpacing: 24,
              children: features.map((feature) {
                return SizedBox(
                  width: _calculateCardWidth(context, targetWidth: 320),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.white.withOpacity(0.08),
                          child: Icon(feature['icon'] as IconData, color: _accentColor),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          feature['title'] as String,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          feature['desc'] as String,
                          style: TextStyle(color: Colors.white.withOpacity(0.7)),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGearSpotlightSection(BuildContext context) {
    final cardWidth = _calculateCardWidth(context, targetWidth: 320);

    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 56),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gear spotlight',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Placeholder imagery with iconography so you can wireframe quickly.',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing: 24,
              runSpacing: 24,
              children: _gearSpotlight.map((gear) {
                return SizedBox(
                  width: cardWidth,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _accentColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              gear.badge,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Icon(Icons.inventory_2, color: _accentColor, size: 42),
                        const SizedBox(height: 16),
                        Text(
                          gear.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          gear.description,
                          style: TextStyle(color: Colors.white.withOpacity(0.7)),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          gear.price,
                          style: const TextStyle(
                            color: _accentColor,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () {},
                          style: FilledButton.styleFrom(
                            backgroundColor: _accentColor,
                            foregroundColor: Colors.black,
                          ),
                          child: const Text('Add to cart'),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuoteSection(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '“Sometimes the best harvest isn’t buds, it’s the confidence you grow. '
                'We simplify the process so you can truly love growing green.”',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  height: 1.4,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Love Growing Green.',
                style: TextStyle(
                  color: _accentColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrowerStoriesSection(BuildContext context) {
    final cardWidth = _calculateCardWidth(context, targetWidth: 420);

    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 56),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Backed by our fellow growers.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing: 24,
              runSpacing: 24,
              children: _growerStories.map((story) {
                return SizedBox(
                  width: cardWidth,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          story.headline,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          story.excerpt,
                          style: TextStyle(color: Colors.white.withOpacity(0.75)),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          story.author,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewsSection(BuildContext context) {
    final cardWidth = _calculateCardWidth(context, targetWidth: 280);

    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 56),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reviews',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 24,
              runSpacing: 24,
              children: _reviewHighlights.map((review) {
                return SizedBox(
                  width: cardWidth,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildRatingStars(review.rating),
                        const SizedBox(height: 12),
                        Text(
                          review.quote,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          review.author,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInnerCircleSection(BuildContext context) {
    final cardWidth = _calculateCardWidth(context, targetWidth: 240);

    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 56),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Join the PhytoPi Inner Circle',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Perks, community, and beta hardware access for builders who can’t wait.',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing: 24,
              runSpacing: 24,
              children: _innerCirclePerks.map((perk) {
                return SizedBox(
                  width: cardWidth,
                  child: Column(
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.08),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Icon(perk.icon, color: _accentColor, size: 40),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        perk.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        perk.description,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withOpacity(0.7)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text('Request an invite'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingStars(int rating) {
    return Row(
      children: List.generate(5, (index) {
        final filled = index < rating;
        return Icon(
          filled ? Icons.star : Icons.star_border,
          color: _accentColor,
          size: 16,
        );
      }),
    );
  }

  /// Marketing footer with multiple columns similar to reference
  Widget _buildFooter(BuildContext context) {
    final pillars = [
      {
        'icon': Icons.spa,
        'title': 'We help you grow your best green.',
      },
      {
        'icon': Icons.verified,
        'title': 'We provide the highest quality.',
      },
      {
        'icon': Icons.auto_graph,
        'title': 'We relentlessly pursue the future.',
      },
      {
        'icon': Icons.sentiment_satisfied_alt,
        'title': 'We make growing more enjoyable.',
      },
      {
        'icon': Icons.favorite,
        'title': 'We support every grower.',
      },
    ];

    final footerLinks = {
      'Products': [
        'Smart Box',
        'Grow Tent Kits',
        'Controllers',
        'Grow Lights',
        'Ventilation',
        'Accessories',
      ],
      'Customer Service': [
        'Contact Us',
        'Return Policy',
        'Shipping',
        'Warranty',
        'Track Orders',
      ],
      'Company': [
        'Brand Story',
        'Privacy Policy',
        'Terms of Service',
        'Affiliate Program',
        'Become a Reseller',
      ],
      'Account': [
        'My Account',
        'Order History',
        'Subscriptions',
        'Inner Circle',
      ],
    };

    return SliverToBoxAdapter(
      child: Container(
        color: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 24,
              runSpacing: 24,
              children: pillars.map((pillar) {
                return SizedBox(
                  width: 220,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(pillar['icon'] as IconData, color: _accentColor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          pillar['title'] as String,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            Divider(color: Colors.white.withOpacity(0.1)),
            const SizedBox(height: 32),
            Wrap(
              spacing: 32,
              runSpacing: 32,
              children: footerLinks.entries.map((entry) {
                return SizedBox(
                  width: 200,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.key,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...entry.value.map((link) {
                        return TextButton(
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            alignment: Alignment.centerLeft,
                          ),
                          onPressed: () {},
                          child: Text(
                            link,
                            style: TextStyle(color: Colors.white.withOpacity(0.7)),
                          ),
                        );
                      }),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sign up and get 10% off your first order',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'We drop coupons, recipes, and firmware updates right to your inbox.',
                          style: TextStyle(color: Colors.white.withOpacity(0.7)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: Colors.white.withOpacity(0.2)),
                            ),
                            height: 48,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'you@email.com',
                              style: TextStyle(color: Colors.white.withOpacity(0.4)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accentColor,
                            foregroundColor: Colors.black,
                            fixedSize: const Size(120, 48),
                          ),
                          child: const Text('Subscribe'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Divider(color: Colors.white.withOpacity(0.1)),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.eco, color: Colors.white),
                const SizedBox(width: 8),
                const Text(
                  'PhytoPi',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '© 2024 PhytoPi. All rights reserved.',
                  style: TextStyle(color: Colors.white.withOpacity(0.6)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

}

class _ShowcaseCardData {
  final String title;
  final String description;
  final String buttonLabel;
  final String badge;
  final IconData icon;

  const _ShowcaseCardData({
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.badge,
    required this.icon,
  });
}

class _SetupShowcaseData {
  final String title;
  final String description;
  final List<String> tags;
  final IconData icon;

  const _SetupShowcaseData({
    required this.title,
    required this.description,
    required this.tags,
    required this.icon,
  });
}

class _GearSpotlightItem {
  final String title;
  final String description;
  final String price;
  final String badge;

  const _GearSpotlightItem({
    required this.title,
    required this.description,
    required this.price,
    required this.badge,
  });
}

class _GrowerStoryData {
  final String author;
  final String headline;
  final String excerpt;

  const _GrowerStoryData({
    required this.author,
    required this.headline,
    required this.excerpt,
  });
}

class _ReviewData {
  final int rating;
  final String quote;
  final String author;

  const _ReviewData({
    required this.rating,
    required this.quote,
    required this.author,
  });
}

class _InnerCircleData {
  final String title;
  final String description;
  final IconData icon;

  const _InnerCircleData({
    required this.title,
    required this.description,
    required this.icon,
  });
}

