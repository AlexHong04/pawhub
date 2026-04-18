import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'app.dart';
import 'core/supabase/supabase_config.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  await Hive.openBox('pets');

  await Supabase.initialize(
    url: supabaseConfig.url,
    anonKey: supabaseConfig.key,
  );
  runApp(const MyApp());
}
