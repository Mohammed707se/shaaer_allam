// ignore_for_file: prefer_const_constructors

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data'; // Import for Uint8List
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'animated_message.dart';
import 'voice_chat_screen.dart';

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage; // Change File? to XFile?
  List<Map<String, dynamic>> messages = [];
  bool _isLoading = false;

  // Colors
  final Color backgroundColor = Color(0xFF0b0218);
  final Color userMessageColor = Color(0xFFE5E1E1);
  final Color aiMessageColor = Color(0xFF7000FF);
  final Color inputFieldColor = Color(0xFF1f1f1f);

  // Function to send messages to the server
  Future<void> sendMessage(String message, {XFile? image}) async {
    if (message.trim().isEmpty && image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('يجب كتابة نص أو اختيار صورة لإرسال الرسالة')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      messages.add({
        "user": "Me",
        "text": message,
        "image": image,
        "explanation": null,
      });
      _selectedImage = null;
      _controller.clear();
    });
    _scrollToBottom();

    if (image != null) {
      try {
        // Send the image to OpenAI
        String description = await sendImageToOpenAI(image);

        print(description);

        if (description == "الصورة غير واضحة.") {
          setState(() {
            messages.add({
              "user": "AI",
              "text": description,
              "explanation": null,
            });
          });
          _scrollToBottom();
        } else {
          // Send the combined description to the backend to generate poetry
          final apiUrl = Uri.parse(dotenv.env['BACKEND_API_URL']!);

          final body = json.encode({
            "question": "$message $description",
          });

          print(body);

          final headers = {
            "Accept": "application/json",
            "Content-Type": "application/json",
          };

          final response = await http
              .post(apiUrl, headers: headers, body: body)
              .timeout(Duration(seconds: 60));

          if (response.statusCode == 200) {
            final data = json.decode(utf8.decode(response.bodyBytes));
            setState(() {
              messages.add({
                "user": "AI",
                "text": data["response"] ?? "لا يوجد رد",
                "explanation": null,
              });
            });
            _scrollToBottom();
          } else {
            throw Exception("فشل في تحميل الرد: ${response.body}");
          }
        }
      } catch (e) {
        print("خطأ: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء إرسال الرسالة'),
          ),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      // Send the message directly to the backend if no image
      final apiUrl = Uri.parse(dotenv.env['BACKEND_API_URL']!);

      final body = json.encode({
        "question": 'اكتب قصيدة $message',
      });

      final headers = {
        "Accept": "application/json",
        "Content-Type": "application/json",
      };

      try {
        final response = await http
            .post(apiUrl, headers: headers, body: body)
            .timeout(Duration(seconds: 60));

        if (response.statusCode == 200) {
          final data = json.decode(utf8.decode(response.bodyBytes));
          setState(() {
            messages.add({
              "user": "AI",
              "text": data["response"] ?? "لا يوجد رد",
              "explanation": null,
            });
          });
          _scrollToBottom();
        } else {
          throw Exception("فشل في تحميل الرد: ${response.body}");
        }
      } catch (e) {
        print("خطأ: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء إرسال الرسالة'),
          ),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Function to send image to OpenAI GPT-4 Vision API
  Future<String> sendImageToOpenAI(XFile image) async {
    final apiUrl = 'https://api.openai.com/v1/chat/completions';
    final apiKey = dotenv.env['OPENAI_API_KEY']!;

    final bytes = await image.readAsBytes(); // Read bytes from XFile
    final base64Image = base64Encode(bytes);

    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };

    final body = json.encode({
      "model": "gpt-4o",
      "messages": [
        {
          "role": "system",
          "content":
              "أنت خبير في تحليل الصور باللغة العربية. إذا كانت الصورة غير واضحة، أعد فقط عبارة 'الصورة غير واضحة'."
        },
        {
          "role": "user",
          "content": [
            {
              "type": "text",
              "text": "اشرحلي الصورة في ٢٠ كلمة بحد اقصى واذا لم تكن واضحة فقط اجب بـ الصورة غير واضحة \"\" \n"
                  "اذا كان هناك امرأة او رجل اوصفهم بحشمه ولو كان هناك مكان اوصف المكان بتفاصيله والوانه \"\" \n"
            },
            {
              "type": "image_url",
              "image_url": {"url": "data:image/png;base64,$base64Image"}
            }
          ]
        },
      ],
    });

    final response = await http.post(
      Uri.parse(apiUrl),
      headers: headers,
      body: body,
    );

    if (response.statusCode == 200) {
      final data =
          json.decode(utf8.decode(response.bodyBytes)); // Decode as UTF-8
      final description = data['choices'][0]['message']['content'];
      return description;
    } else {
      print('فشل في تحليل الصورة: ${response.body}');
      throw Exception('فشل في تحليل الصورة');
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = pickedFile; // Store XFile
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Function to explain the selected text
  Future<void> explainText(String text, int messageIndex) async {
    setState(() {
      _isLoading = true;
    });

    final apiUrl = Uri.parse(dotenv.env['BACKEND_API_URL']!);
    final body = json.encode({
      "question": "اشرح لي معنى هذا النص باختصار شديد: $text",
    });
    final headers = {
      "Accept": "application/json",
      "Content-Type": "application/json",
    };

    try {
      final response = await http
          .post(apiUrl, headers: headers, body: body)
          .timeout(Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          messages[messageIndex]["explanation"] =
              data["response"] ?? "لا يوجد شرح متاح";
        });
        _scrollToBottom();
      } else {
        throw Exception("فشل في تحميل الشرح: ${response.body}");
      }
    } catch (e) {
      print("خطأ: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء شرح النص')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildImageDisplay(XFile? image) {
    if (image == null) return Container();

    if (kIsWeb) {
      // On web, use Image.network with image.path (a data URL)
      return Image.network(
        image.path,
        height: 150,
        fit: BoxFit.cover,
      );
    } else {
      // On mobile platforms, convert XFile to File and use Image.file
      return Image.file(
        File(image.path),
        height: 150,
        fit: BoxFit.cover,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage(
                        'assets/background_image.png'), // Background image
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final isMe = message["user"] == "Me";
                        return Column(
                          crossAxisAlignment: isMe
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            AnimatedMessage(
                              text: message["text"] ?? "",
                              image: message["image"], // Pass the XFile image
                              isMe: isMe,
                              onExplain: (selectedText) {
                                explainText(selectedText, index);
                              },
                            ),
                            if (message["explanation"] != null)
                              Padding(
                                padding: EdgeInsets.symmetric(
                                    vertical: 4, horizontal: 8),
                                child: Text(
                                  message["explanation"],
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Amiri',
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                  if (_isLoading)
                    Center(
                      child: Lottie.asset('assets/loading.json',
                          width: 80, height: 80, fit: BoxFit.cover),
                    )
                  else
                    Container(
                      padding: EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: Color(0xff5A318E),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                      child: Column(
                        children: [
                          SizedBox(
                            height: 50,
                          ),
                          if (_selectedImage != null)
                            Padding(
                              padding: EdgeInsets.only(bottom: 8),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: _buildImageDisplay(_selectedImage),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedImage = null;
                                        });
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        padding: EdgeInsets.all(4),
                                        child: Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _controller,
                                  textAlign: TextAlign.right,
                                  decoration: InputDecoration(
                                    hintText: "أدخل رسالتك",
                                    hintStyle: TextStyle(
                                      fontFamily: 'Amiri',
                                      fontSize: 16,
                                      color: Colors.white54,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Colors.white,
                                        width: 1.5,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Colors.white,
                                        width: 1.5,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: Colors.transparent,
                                  ),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Amiri',
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.photo, color: Colors.white),
                                onPressed: _pickImage, // Button to pick image
                              ),
                              IconButton(
                                icon: Icon(Icons.send, color: Colors.white),
                                onPressed: () => sendMessage(
                                  _controller.text,
                                  image: _selectedImage,
                                ), // Send message with image
                              ),
                            ],
                          ),
                          SizedBox(
                            height: 20,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              if (_isLoading == false)
                if (_selectedImage == null)
                  Positioned(
                    bottom: 100,
                    left: 0,
                    right: 0,
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => VoiceChatScreen(),
                          ),
                        );
                      },
                      child: Image.asset(
                        'assets/mic.png',
                        width: 100,
                        height: 100,
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
