import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'chat_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await rootBundle.load('assets/Amiri-Regular.ttf');
  await rootBundle.load('assets/Amiri-Bold.ttf');
  await dotenv.load(fileName: ".env");

  HttpOverrides.global = MyHttpOverrides();
  runApp(ArabicPoetryChatApp());
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

class ArabicPoetryChatApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Arabic Poetry Chat',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Amiri',
      ),
      home: ChatScreen(),
    );
  }
}
