import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'app.dart';
import 'core/supabase/supabase_config.dart';
void main() async{
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseConfig.url,
    anonKey: supabaseConfig.key,
  );
  runApp(const MyApp());
}