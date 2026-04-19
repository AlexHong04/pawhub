import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'app.dart';
import 'core/supabase/supabase_config.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  await Hive.openBox('pets');

  Stripe.publishableKey = "pk_test_51TL6AwRwursbSQXLg6LeHDBz8NVd9yhNP15GljafY0TJR2Uw3PenES1sERdWZ6bPb6KM9w1M5MvsR9oOSjhpHdUp00olwn9dRB";
  await Stripe.instance.applySettings();

  await Supabase.initialize(
    url: supabaseConfig.url,
    anonKey: supabaseConfig.key,
  );
  runApp(const MyApp());
}