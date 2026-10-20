import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/services/cloner_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ClonerService.instance.init();
  runApp(const MobileClonerApp());
}
