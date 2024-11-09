import 'dart:io'; // For File class on non-web platforms
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:image_picker/image_picker.dart';
import 'typewriter_text.dart';

class AnimatedMessage extends StatefulWidget {
  final String text;
  final bool isMe;
  final Function(String)? onExplain;
  final XFile? image;

  AnimatedMessage({
    required this.text,
    required this.isMe,
    this.onExplain,
    this.image,
  });

  @override
  _AnimatedMessageState createState() => _AnimatedMessageState();
}

class _AnimatedMessageState extends State<AnimatedMessage> {
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: EdgeInsets.all(12),
        margin: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: widget.isMe ? Color(0xFFE5E1E1) : Color(0xFF7000FF),
          borderRadius: BorderRadius.circular(12),
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.image != null) // Display the image if it exists
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: kIsWeb
                    ? Image.network(
                        widget.image!.path,
                        width: double.infinity,
                        height: 150,
                        fit: BoxFit.cover,
                      )
                    : Image.file(
                        File(widget.image!.path),
                        width: double.infinity,
                        height: 150,
                        fit: BoxFit.cover,
                      ),
              ),
            if (widget.image != null)
              SizedBox(height: 8), // Space between image and text
            TypewriterText(
              text: widget.text,
              style: TextStyle(
                color: widget.isMe ? Colors.black : Colors.white,
                fontSize: 18,
                fontFamily: 'Amiri',
              ),
              speed: Duration(milliseconds: 10),
              onSelected: (selectedText) {
                if (widget.onExplain != null) {
                  widget.onExplain!(selectedText);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
