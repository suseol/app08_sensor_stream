import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'data/sensor_repository.dart';
import 'data/sensor_service.dart';
import 'viewmodels/sensor_dashboard_view_model.dart';
import 'views/sensor_dashboard_page.dart';

void main() => runApp(const SensorApp());

class SensorApp extends StatelessWidget {
  const SensorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SensorDashboardViewModel(
        SensorRepository(SensorService()),
      ),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true),
        home: const SensorDashboardPage(),
      ),
    );
  }
}
