import 'package:flutter/material.dart';
import 'package:lista_de_compras/screens/login.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // URL e Chave Anon do seu projeto Supabase (Pegue no painel em Project Settings > API)
  await Supabase.initialize(
    url: 'https://ltzpgchylcopgqkcxrmt.supabase.co',
    publishableKey: 'sb_publishable_DItlhuu9mKKJvQ_iIzEgqg_lW8oAqt1',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lista de Supermercado',
      theme: ThemeData(primarySwatch: Colors.green, useMaterial3: true),
      home: const LoginScreen(),
    );
  }
}

