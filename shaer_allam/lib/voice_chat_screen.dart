// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'package:permission_handler/permission_handler.dart';

class VoiceChatScreen extends StatefulWidget {
  @override
  _VoiceChatScreenState createState() => _VoiceChatScreenState();
}

class _VoiceChatScreenState extends State<VoiceChatScreen>
    with SingleTickerProviderStateMixin {
  bool _isAIResponding = false;
  bool _isMuted = false;
  bool _isAudioPlaying = false;
  final AudioPlayer _audioPlayer = AudioPlayer();
  Timer? _silenceTimer;
  bool _hasSentToBackend = false;

  // تعريف الألوان المستخدمة
  final Color backgroundColor = Color(0xFF0b0218);
  final Color aiMessageColor = Color(0xFFda2b89);
  final Color userMessageColor = Color(0xFFb47fff);
  final Color inputFieldColor = Color(0xFF1f1f1f); // لون خلفية حقل الإدخال

  // متغيرات للتحكم في حجم الظل بناءً على مستوى الصوت
  double _shadowRadius = 50.0;
  double _shadowOpacity = 0.5;
  Color _shadowColor = Colors.blue;

  // Animation Controller للتحكم في تأثير الظل
  late AnimationController _animationController;
  late Animation<double> _animation;

  // Speech to Text
  stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _recognizedText = '';

  @override
  void initState() {
    super.initState();
    _animationController =
        AnimationController(vsync: this, duration: Duration(milliseconds: 500));
    _animation =
        Tween<double>(begin: 50.0, end: 70.0).animate(_animationController)
          ..addListener(() {
            setState(() {
              _shadowRadius = _animation.value;
            });
          });

    // طلب الأذونات وتهيئة SpeechToText
    _initializeSpeechToText();
  }

  Future<void> _initializeSpeechToText() async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        // إذا لم يتم منح الإذن، عرض رسالة للمستخدم
        setState(() {
          _isAIResponding = false;
        });
        _showPermissionDeniedDialog();
        return;
      }
    }

    bool available = await _speech.initialize(
      onStatus: _onSpeechStatus,
      onError: _onSpeechError,
    );

    if (available) {
      setState(() {
        _isListening = true;
        _startListening();
      });
    } else {
      _showErrorDialog('لم يتمكن من الوصول إلى الميكروفون.');
    }
  }

  void _onSpeechStatus(String status) {
    if (status == 'notListening') {
      setState(() {
        _isListening = false;
      });
    }
  }

  void _onSpeechError(SpeechRecognitionError error) {
    print('Speech recognition error: ${error.errorMsg}');
    setState(() {
      _isListening = false;
    });
    _showErrorDialog('حدث خطأ أثناء التعرف على الصوت.');
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('إذن الميكروفون مرفوض'),
          content: Text(
              'نحتاج إلى الوصول إلى الميكروفون لتسجيل الصوت. يمكنك تعديل الإعدادات من جهازك للسماح بذلك.'),
          actions: [
            TextButton(
              child: Text('إلغاء'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('إعدادات'),
              onPressed: () {
                openAppSettings();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _startListening() async {
    setState(() {
      _isListening = true;
      _recognizedText = '';
      _hasSentToBackend = false; // إعادة تعيين المتغير هنا
    });
    _speech.listen(
      onResult: _onSpeechResult,
      listenMode: stt.ListenMode.dictation,
      localeId: 'ar_SA', // تأكد من استخدام رمز اللغة العربية المناسب
    );
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!_isListening || _isAIResponding || _isAudioPlaying) {
      return; // Ignore if not listening, AI is responding, or audio is playing
    }

    setState(() {
      _recognizedText = result.recognizedWords;
    });

    _silenceTimer?.cancel();
    _silenceTimer = Timer(Duration(seconds: 4), () {
      if (!_hasSentToBackend) {
        _speech.stop();
        _silenceTimer?.cancel();
        setState(() {
          _isListening = false;
          _isAIResponding = true;
          _shadowColor = Colors.blue;
        });
        _sendTextToBackend(_recognizedText);
        _hasSentToBackend = true;
      }
    });
  }

  Future<void> _sendTextToBackend(String text) async {
    if (_hasSentToBackend) {
      return; // إذا تم الإرسال بالفعل، لا تفعل شيئًا
    }
    _hasSentToBackend = true;
    try {
      // إرسال النص إلى الباك اند
      final apiUrl = Uri.parse(
          "https://3aa6-85-194-96-74.ngrok-free.app/api/generate_poetry_audio/"); // استبدلها بعنوان الباك اند الخاص بك
      final response = await http.post(
        apiUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text}),
      );

      if (response.statusCode == 200) {
        // استلام الصوت من الباك اند
        Uint8List audioBytes = response.bodyBytes;

        setState(() {
          _isAudioPlaying = true;
          _shadowColor = Colors.purple; // تغيير لون الظل عند الرد
        });

        // تشغيل الصوت
        await _playAudio(audioBytes);
      } else {
        print("فشل في تحميل الرد: ${response.body}");
        // عرض رسالة خطأ للمستخدم
        _showErrorDialog("فشل في تحميل الرد من الخادم.");
      }
    } catch (e) {
      print("خطأ في إرسال النص: $e");
      // عرض رسالة خطأ للمستخدم
      _showErrorDialog("حدث خطأ أثناء إرسال النص.");
    } finally {
      setState(() {
        _isAIResponding = false;
        _shadowColor = Colors.blue; // إعادة لون الظل للحالة الافتراضية
        _startListening(); // إعادة بدء الاستماع
      });
    }
  }

  Future<void> _playAudio(Uint8List audioBytes) async {
    try {
      // Stop listening to avoid repeating recognized text
      _speech.stop();
      setState(() {
        _isListening = false;
        _isAudioPlaying = true;
        _shadowColor = Colors.purple;
      });

      if (kIsWeb) {
        await _audioPlayer.play(BytesSource(audioBytes));
      } else {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/response_audio.mp3');
        await tempFile.writeAsBytes(audioBytes, flush: true);
        await _audioPlayer.play(DeviceFileSource(tempFile.path));
      }

      _audioPlayer.onPlayerComplete.listen((event) {
        if (mounted) {
          setState(() {
            _isAudioPlaying = false;
            _shadowColor = Colors.blue;
          });
        }
        _startListening(); // Restart listening after audio completes
      });
    } catch (e) {
      print("Error in playing audio: $e");
      _showErrorDialog("An error occurred while playing the audio.");
      setState(() {
        _isAudioPlaying = false;
      });
      _startListening();
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('خطأ'),
          content: Text(message),
          actions: [
            TextButton(
              child: Text('إغلاق'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _silenceTimer?.cancel();
    _animationController.dispose();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          title: Text(
            "محادثة صوتية",
            style: TextStyle(
              fontFamily: 'Amiri',
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: aiMessageColor,
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(
                _isMuted ? Icons.volume_off : Icons.volume_up,
                color: Colors.white,
              ),
              onPressed: () {
                setState(() {
                  _isMuted = !_isMuted;
                });
                if (_isMuted && _isAIResponding) {
                  // إذا تم تفعيل الميوت أثناء استجابة AI، قم بإيقاف الاستجابة
                  setState(() {
                    _isAIResponding = false;
                  });
                }
              },
            ),
          ],
        ),
        body: SafeArea(
          child: Stack(
            children: [
              // الأيقونة المركزية مع الظل المتحرك
              Center(
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isAIResponding
                        ? Colors.green
                        : _isAudioPlaying
                            ? Colors.purple
                            : aiMessageColor,
                    boxShadow: [
                      BoxShadow(
                        color: _shadowColor.withOpacity(_shadowOpacity),
                        blurRadius: _shadowRadius,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Icon(
                    _isAIResponding
                        ? Icons.mic // يظهر رمز الميكروفون أثناء الاستماع
                        : _isAudioPlaying
                            ? Icons.headset
                            : Icons.mic_none,
                    color: Colors.white,
                    size: 60,
                  ),
                ),
              ),
              // الرسائل السفلية
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    if (_isAudioPlaying)
                      Column(
                        children: [
                          Text(
                            "الذكاء الاصطناعي يتحدث...",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontFamily: 'Amiri',
                            ),
                          ),
                        ],
                      )
                    else if (_isAIResponding)
                      Column(
                        children: [
                          CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(aiMessageColor),
                          ),
                          SizedBox(height: 10),
                          Text(
                            "الذكاء الاصطناعي يستجيب...",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontFamily: 'Amiri',
                            ),
                          ),
                        ],
                      ),
                    if (!_isAIResponding &&
                        _isListening &&
                        _recognizedText.isNotEmpty)
                      Text(
                        'النص المعترف به: $_recognizedText',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontFamily: 'Amiri',
                        ),
                        textAlign: TextAlign.center,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
