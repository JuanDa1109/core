import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'controllers/app_controller.dart';
import 'services/core_repository.dart';
import 'ui/dashboard_page.dart';
import 'ui/import_page.dart';
import 'ui/payments_page.dart';

class CoreApp extends StatefulWidget {
  const CoreApp({super.key});

  @override
  State<CoreApp> createState() => _CoreAppState();
}

class _CoreAppState extends State<CoreApp> {
  late final AppController _controller;
  int _index = 0;

  static const _titles = [
    'Dashboard Comercial',
    'Abonos por Contrato',
    'Importar Manifiesto',
  ];

  @override
  void initState() {
    super.initState();
    _controller = AppController(repository: CoreRepository());
    _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1660A7),
        brightness: Brightness.light,
      ),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Core',
      locale: const Locale('es', 'CO'),
      supportedLocales: const [Locale('es', 'CO'), Locale('es', 'ES')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: base.copyWith(
        textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme),
        scaffoldBackgroundColor: const Color(0xFFF2F6FC),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF2F6FED),
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFFAEC4F3),
            disabledForegroundColor: Colors.white,
            textStyle: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF1E3A5F),
            side: const BorderSide(color: Color(0xFFD6E3F6)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFE4EBF5)),
          ),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),
        navigationBarTheme: NavigationBarThemeData(
          indicatorColor: const Color(0xFFDDEBFF),
          backgroundColor: Colors.white,
          height: 66,
          labelTextStyle: WidgetStatePropertyAll(
            GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF8FAFD),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFDCE5F3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFDCE5F3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF2364AA), width: 1.4),
          ),
        ),
      ),
      home: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final pages = <Widget>[
            DashboardPage(controller: _controller),
            PaymentsPage(controller: _controller),
            ImportPage(controller: _controller),
          ];

          final error = _controller.error;
          if (error != null && error.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(error)));
              _controller.clearError();
            });
          }

          return Scaffold(
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(76),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFEFF5FF), Color(0xFFF9FCFF)],
                  ),
                  border: Border(bottom: BorderSide(color: Color(0xFFE0E9F6))),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFF1BAA8B),
                                    Color(0xFF0F7A66),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0x331BAA8B),
                                    blurRadius: 10,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(7),
                                child: SvgPicture.asset(
                                  'assets/branding/core/ui/core_logomark.svg',
                                  colorFilter: const ColorFilter.mode(
                                    Colors.white,
                                    BlendMode.srcIn,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Core',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: const Color(0xFF1E3A5F),
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.2,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _titles[_index],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF1E3A5F),
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            body: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFF7FAFF), Color(0xFFF1F5FC)],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(child: pages[_index]),
              ],
            ),
            bottomNavigationBar: SafeArea(
              minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFDCE6F5)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 14,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: NavigationBar(
                    selectedIndex: _index,
                    onDestinationSelected: (value) =>
                        setState(() => _index = value),
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.analytics_outlined),
                        label: 'Dashboard',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.payments_outlined),
                        label: 'Abonos',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.upload_file_outlined),
                        label: 'Importar',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
