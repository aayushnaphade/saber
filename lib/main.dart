import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:onyxsdk_pen/onyxsdk_pen.dart';
import 'package:path_to_regexp/path_to_regexp.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:printing/printing.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:saber/components/canvas/pencil_shader.dart';
import 'package:saber/components/theming/dynamic_material_app.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/models/dashboard_models.dart';
import 'package:saber/data/models/patient.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/routes.dart';
import 'package:saber/data/sentry/sentry_init.dart';
import 'package:saber/data/services/connectivity_service.dart';
import 'package:saber/data/services/sync_worker.dart';
import 'package:saber/data/supabase/supabase_auth_service.dart';
import 'package:saber/data/supabase/supabase_client.dart';
import 'package:saber/data/tools/stroke_properties.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:saber/pages/editor/editor.dart';
import 'package:saber/pages/home/dashboard/consultation_history_page.dart';
import 'package:saber/pages/home/dashboard/dashboard_page.dart';
import 'package:saber/pages/home/dashboard/team_management_page.dart';
import 'package:saber/pages/home/home.dart';
import 'package:saber/pages/home/patient_browse.dart';
import 'package:saber/pages/home/patient_profile.dart';
import 'package:saber/pages/home/recent_notes.dart';
import 'package:saber/pages/home/settings.dart';
import 'package:saber/pages/home/settings_subpages/app_settings_page.dart';
import 'package:saber/pages/home/settings_subpages/professional_profile_page.dart';
import 'package:saber/pages/home/whiteboard.dart';
import 'package:saber/pages/home/widgets/session_viewer.dart';
import 'package:saber/pages/logs.dart';
import 'package:saber/pages/user/supabase_login.dart';
import 'package:window_manager/window_manager.dart';
import 'package:worker_manager/worker_manager.dart';

Future<void> main(List<String> args) async {
  /// To set the flavor config e.g. for the Play Store, use:
  /// flutter build \
  ///   --dart-define=FLAVOR="Google Play" \
  ///   --dart-define=APP_STORE="Google Play" \
  ///   --dart-define=UPDATE_CHECK="false"
  FlavorConfig.setupFromEnvironment();

  await dotenv.load(fileName: '.env');

  await initSentry(() => appRunner(args));
}

Future<void> appRunner(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Force loading of Battery class to avoid "Class: Battery which is not loaded yet" crash on some Android devices
  // We use runZonedGuarded to catch potential MissingPluginException during init
  runZonedGuarded(
    () {
      try {
        Battery();
      } catch (_) {}
    },
    (error, stack) {
      debugPrint('Main: Battery service init skipped: $error');
    },
  );

  final parser = ArgParser()..addFlag('verbose', abbr: 'v', negatable: false);
  final parsedArgs = parser.parse(args);

  Logger.root.level = (kDebugMode || parsedArgs.flag('verbose'))
      ? Level.INFO
      : Level.WARNING;
  Logger.root.onRecord.listen((record) {
    logsHistory.add(record);

    if (!isSentryEnabled) {
      // ignore: avoid_print
      print('${record.level.name}: ${record.loggerName}: ${record.message}');
    }
  });

  // For some reason, logging errors breaks hot reload while debugging.
  if (!kDebugMode && !isSentryEnabled) {
    final errorLogger = Logger('ErrorLogger');
    FlutterError.onError = (details) {
      errorLogger.severe(
        details.exceptionAsString(),
        details.exception,
        details.stack,
      );
      FlutterError.presentError(details);
    };
    PlatformDispatcher.instance.onError = (error, stackTrace) {
      errorLogger.severe(error, stackTrace);
      // Returns false in debug mode so the error is printed to stderr
      return !kDebugMode;
    };
  }

  StrokeOptionsExtension.setDefaults();
  Stows.markAsOnMainIsolate();

  // Initialize Supabase client
  await SupabaseClientConfig.initialize();

  // Initialize connectivity monitoring
  ConnectivityService.initialize();

  await Future.wait([
    stows.customDataDir.waitUntilRead().then((_) => FileManager.init()),
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS)
      windowManager.ensureInitialized(),
    workerManager.init(),
    stows.locale.waitUntilRead(),
    stows.url.waitUntilRead(),
    stows.allowInsecureConnections.waitUntilRead(),
    // Load Supabase auth preferences
    stows.supabaseUserId.waitUntilRead(),
    stows.supabaseAccessToken.waitUntilRead(),
    stows.supabaseRefreshToken.waitUntilRead(),
    stows.supabaseUserEmail.waitUntilRead(),
    PencilShader.init(),
    Printing.info().then((info) {
      Editor.canRasterPdf = info.canRaster;
    }),
    OnyxSdkPenArea.init(),
  ]);

  // Try to restore Supabase session
  await SupabaseAuthService.tryRestoreSession();

  setLocale();
  stows.locale.addListener(setLocale);
  stows.customDataDir.addListener(FileManager.migrateDataDir);
  pdfrxFlutterInitialize(dismissPdfiumWasmWarnings: true);

  LicenseRegistry.addLicense(() async* {
    for (final licenseFile in const [
      'assets/google_fonts/Atkinson_Hyperlegible_Next/OFL.txt',
      'assets/google_fonts/Dekko/OFL.txt',
      'assets/google_fonts/Fira_Mono/OFL.txt',
      'assets/google_fonts/Neucha/OFL.txt',
    ]) {
      final license = await rootBundle.loadString(licenseFile);
      yield LicenseEntryWithLineBreaks(const ['google_fonts'], license);
    }
  });

  runApp(SentryWidget(child: TranslationProvider(child: const App())));
  startSyncAfterLoaded();
}

void startSyncAfterLoaded() async {
  await stows.supabaseUserId.waitUntilRead();
  await stows.supabaseAccessToken.waitUntilRead();

  stows.supabaseUserId.removeListener(startSyncAfterLoaded);
  stows.supabaseAccessToken.removeListener(startSyncAfterLoaded);
  if (!stows.loggedIn) {
    // try again when logged in
    stows.supabaseUserId.addListener(startSyncAfterLoaded);
    stows.supabaseAccessToken.addListener(startSyncAfterLoaded);
    return;
  }

  // wait for other prefs to load
  await Future.delayed(const Duration(milliseconds: 100));

  // Initialize offline sync worker to drain the outbox when online
  SyncWorker.initialize();
}

void setLocale() {
  if (stows.locale.value.isNotEmpty &&
      AppLocaleUtils.supportedLocalesRaw.contains(stows.locale.value)) {
    LocaleSettings.setLocaleRaw(stows.locale.value);
  } else {
    LocaleSettings.useDeviceLocale();
  }
}

// Background sync removed - will be reimplemented with Supabase
// See SYNAPSEAI_ROADMAP.md for sync infrastructure plan

// Background sync removed - will be reimplemented with Supabase
// See SYNAPSEAI_ROADMAP.md Phase 4 for sync infrastructure plan

class App extends StatefulWidget {
  const App({super.key});

  static final log = Logger('App');
  static final rootNavigatorKey = GlobalKey<NavigatorState>();
  static final shellNavigatorKey = GlobalKey<NavigatorState>();

  static String getInitialLocation() {
    // Check if user is authenticated
    if (SupabaseAuthService.isAuthenticated) {
      return pathToFunction(RoutePaths.home)({
        'subpage': HomePage.dashboardSubpage,
      });
    }
    return RoutePaths.login;
  }

  static final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: getInitialLocation(),
    redirect: (context, state) {
      final isAuthenticated = SupabaseAuthService.isAuthenticated;
      final isLoginRoute = state.matchedLocation == RoutePaths.login;

      // If not authenticated and not on login page, redirect to login
      if (!isAuthenticated && !isLoginRoute) {
        return RoutePaths.login;
      }

      // If authenticated, check role for tablet access
      if (isAuthenticated) {
        final role = stows.userRole.value;
        // Note: For existing sessions, role might be empty initially
        // until tryRestoreSession completes, but the router refresh
        // will trigger again once the role is synced.

        // RELAXED: Rely on Login page check. Don't kick out mid-session.
        /*
        if (role.isNotEmpty && role != 'doctor') {
          // Force logout and redirect if not a doctor
          SupabaseAuthService.signOut();
          return RoutePaths.login;
        }
        */

        // If authenticated and on login page, redirect to home
        if (isLoginRoute) {
          return pathToFunction(RoutePaths.home)({
            'subpage': HomePage.dashboardSubpage,
          });
        }
      }

      // No redirect needed
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        redirect: (context, state) {
          return SupabaseAuthService.isAuthenticated
              ? pathToFunction(RoutePaths.home)({
                  'subpage': HomePage.dashboardSubpage,
                })
              : RoutePaths.login;
        },
      ),
      ShellRoute(
        navigatorKey: App.shellNavigatorKey,
        builder: (context, state, child) {
          var subpage = state.pathParameters['subpage'];
          final uri = state.uri.path;
          App.log.info('🐚 [DEBUG] ShellRoute builder called for path: $uri');

          // Fallback subpage detection for routes without :subpage parameter
          if (subpage == null) {
            if (uri.contains('/patients')) {
              subpage = HomePage.browseSubpage;
            } else {
              subpage = HomePage.dashboardSubpage;
            }
          }

          return HomePage(
            subpage: subpage,
            navigatorKey: App.shellNavigatorKey,
            currentPath: state.uri.path,
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: RoutePaths.home,
            pageBuilder: (context, state) {
              final subpage =
                  state.pathParameters['subpage'] ?? HomePage.dashboardSubpage;

              Widget child;
              switch (subpage) {
                case HomePage.dashboardSubpage:
                  child = const DashboardPage();
                case HomePage.browseSubpage:
                  child = const PatientBrowsePage();
                case HomePage.whiteboardSubpage:
                  child = const Whiteboard();
                case HomePage.settingsSubpage:
                  child = const SettingsPage();
                case HomePage.historySubpage:
                  child = const ConsultationHistoryPage();
                case HomePage.teamManagementSubpage:
                  child = const TeamManagementPage();
                case HomePage.professionalSubpage:
                  child = const ProfessionalProfilePage();
                case HomePage.appSettingsSubpage:
                  child = const AppSettingsPage();
                default:
                  child = const RecentPage();
              }

              return NoTransitionPage(child: child);
            },
          ),
          GoRoute(
            path: RoutePaths.patientDocuments,
            builder: (context, state) => PatientBrowsePage(
              patientId: state.pathParameters['patientId'],
              documentType: state.pathParameters['documentType'],
            ),
          ),
          GoRoute(
            path: RoutePaths.patientDetail,
            builder: (context, state) => PatientProfilePage(
              patientId: state.pathParameters['patientId']!,
              autoStartSession:
                  state.uri.queryParameters['autoStartSession'] == 'true',
            ),
          ),
          GoRoute(
            path: RoutePaths.patients,
            builder: (context, state) => const PatientBrowsePage(),
          ),
          GoRoute(
            path: RoutePaths.sessionViewer,
            builder: (context, state) {
              final patientId = state.pathParameters['patientId']!;
              final sessionNumber = int.parse(
                state.pathParameters['sessionNumber']!,
              );
              final extra = state.extra as Map<String, dynamic>;
              final allSessions = extra['allSessions'] as List<SessionInfo>;
              final viewOnlyNotes = extra['viewOnlyNotes'] as bool? ?? false;

              return SessionViewerPage(
                patientId: patientId,
                initialSessionNumber: sessionNumber,
                allSessions: allSessions,
                viewOnlyNotes: viewOnlyNotes,
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: RoutePaths.edit,
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return CustomTransitionPage(
            key: state.pageKey,
            child: Editor(
              path: state.uri.queryParameters['path'],
              pdfPath: state.uri.queryParameters['pdfPath'],
              consultationId: state.uri.queryParameters['consultation_id'],
              patientName: state.uri.queryParameters['patient_name'],
              patientId: state.uri.queryParameters['patient_id'],
              readOnly: state.uri.queryParameters['readOnly'] == 'true',
              openReportReview: extra?['open_report_review'] == true,
              reportToReview: extra?['report'] as ClinicalReport?,
            ),
            transitionDuration: const Duration(milliseconds: 380),
            reverseTransitionDuration: const Duration(milliseconds: 300),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  // No fade/slide here - returning child allows the Hero widget
                  // to be the primary visual transition.
                  return child;
                },
          );
        },
      ),
      GoRoute(
        path: RoutePaths.login,
        builder: (context, state) => const SupabaseLoginPage(),
      ),
      GoRoute(path: '/profile', redirect: (context, state) => RoutePaths.login),
      GoRoute(
        path: RoutePaths.logs,
        builder: (context, state) => const LogsPage(),
      ),
    ],
  );

  static void openFile(SharedMediaFile file) async {
    log.info('Opening file: (${file.type}) ${file.path}');

    if (file.type != SharedMediaType.file) return;

    final String extension;
    if (file.path.contains('.')) {
      extension = file.path.split('.').last.toLowerCase();
    } else {
      extension = 'sbn2';
    }

    if (extension == 'sbn' || extension == 'sbn2' || extension == 'sba') {
      final path = await FileManager.importFile(
        file.path,
        null,
        extension: '.$extension',
      );
      if (path == null) return;

      // allow file to finish writing
      await Future.delayed(const Duration(milliseconds: 100));

      router.push(RoutePaths.editFilePath(path));
    } else if (extension == 'pdf' && Editor.canRasterPdf) {
      final fileNameWithoutExtension = file.path
          .split(RegExp(r'[\\/]'))
          .last
          .substring(0, file.path.length - '.pdf'.length);
      final sbnFilePath = await FileManager.suffixFilePathToMakeItUnique(
        '/$fileNameWithoutExtension',
      );
      router.push(RoutePaths.editImportPdf(sbnFilePath, file.path));
    } else {
      log.warning('openFile: Unsupported file type: $extension');
    }
  }

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  StreamSubscription? _intentDataStreamSubscription;
  StreamSubscription? _authStateSubscription;

  @override
  void initState() {
    setupSharingIntent();
    setupAuthListener();
    super.initState();
  }

  void setupAuthListener() {
    // Listen to auth state changes and refresh router
    _authStateSubscription = SupabaseAuthService.onAuthStateChange.listen((
      data,
    ) {
      // Refresh the router to trigger redirect logic
      App.router.refresh();
    });
  }

  void setupSharingIntent() {
    if (Platform.isAndroid || Platform.isIOS) {
      // for files opened while the app is closed
      ReceiveSharingIntent.instance.getInitialMedia().then((
        List<SharedMediaFile> files,
      ) {
        for (final file in files) {
          App.openFile(file);
        }
      });

      // for files opened while the app is open
      final stream = ReceiveSharingIntent.instance.getMediaStream();
      _intentDataStreamSubscription = stream.listen((
        List<SharedMediaFile> files,
      ) {
        for (final file in files) {
          App.openFile(file);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DynamicMaterialApp(title: 'SynapseAi', router: App.router);
  }

  @override
  void dispose() {
    _intentDataStreamSubscription?.cancel();
    _authStateSubscription?.cancel();
    super.dispose();
  }
}
