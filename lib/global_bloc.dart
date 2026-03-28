import 'package:cu_app/Features/ReportScreen/Bloc/user_report_bloc.dart';
import 'package:cu_app/Features/Splash/Bloc/get_started_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// This widget provides a global bloc context for the application, allowing access to various blocs throughout the app.
class GlobalBloc extends StatelessWidget {
  final Widget child;

  const GlobalBloc({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(providers: [
      BlocProvider(create: (_) => GetStartedBloc()),
      BlocProvider(create: (_) => UserReportBloc()),
    ], child: child);
  }
}
