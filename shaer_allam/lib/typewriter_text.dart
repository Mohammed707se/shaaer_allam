// typewriter_text.dart

// ignore_for_file: deprecated_member_use, prefer_const_constructors

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TypewriterText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final Duration speed;
  final Function(String)? onSelected;

  TypewriterText({
    required this.text,
    required this.style,
    this.speed = const Duration(milliseconds: 50),
    this.onSelected,
  });

  @override
  _TypewriterTextState createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> {
  String _displayedText = "";
  Timer? _timer;
  bool _isCompleted = false;

  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _startTyping();
  }

  void _startTyping() {
    int index = 0;
    _timer = Timer.periodic(widget.speed, (timer) {
      if (index < widget.text.length) {
        setState(() {
          _displayedText += widget.text[index];
        });
        index++;
      } else {
        _timer?.cancel();
        setState(() {
          _isCompleted = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _removeOverlay();
    super.dispose();
  }

  void _copyText(String selectedText) {
    Clipboard.setData(ClipboardData(text: selectedText));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم النسخ')),
    );
  }

  void _explainText(String selectedText) {
    if (widget.onSelected != null) {
      widget.onSelected!(selectedText);
    }
  }

  void _showOverlay(
      BuildContext context, Rect selectionRect, String selectedText) {
    _removeOverlay();

    final overlay = Overlay.of(context)!;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: selectionRect.right + 10,
        top: selectionRect.top - 40, // تعديل الموضع حسب الحاجة
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () {
                    _explainText(selectedText);
                    _removeOverlay();
                  },
                  child: Text(
                    "أشرحلي",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    _copyText(selectedText);
                    _removeOverlay();
                  },
                  child: Text(
                    "نسخ",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    overlay.insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  // Helper function to get the selection rectangle
  Rect? _getSelectionRect(
      TextSelection selection, TextPainter textPainter, BuildContext context) {
    if (selection.isCollapsed) return null;

    // احصل على النقاط الرئيسية للنص المحدد
    final startOffset = textPainter.getOffsetForCaret(
        TextPosition(offset: selection.start), Rect.zero);
    final endOffset = textPainter.getOffsetForCaret(
        TextPosition(offset: selection.end), Rect.zero);

    // احسب المستطيل للنص المحدد
    final startRect = Rect.fromLTWH(startOffset.dx, startOffset.dy, 1, 1);
    final endRect = Rect.fromLTWH(endOffset.dx, endOffset.dy, 1, 1);

    // استخدم موقع نهاية التحديد كموقع للقائمة السياقية
    return endRect;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textPainter = TextPainter(
          text: TextSpan(text: _displayedText, style: widget.style),
          textDirection: TextDirection.rtl,
        )..layout(maxWidth: constraints.maxWidth);

        return SelectableText(
          _displayedText,
          style: widget.style,
          onSelectionChanged: (selection, cause) {
            if (_isCompleted && !selection.isCollapsed) {
              String selectedText = selection.textInside(_displayedText);
              // احصل على المستطيل المحدد
              final selectionRect =
                  _getSelectionRect(selection, textPainter, context);
              if (selectionRect != null) {
                // احصل على موقع المستطيل في الشاشة
                final RenderBox box = context.findRenderObject() as RenderBox;
                final Offset topLeft = box.localToGlobal(selectionRect.topLeft);
                final Rect globalSelectionRect = selectionRect.shift(topLeft);

                _showOverlay(context, globalSelectionRect, selectedText);
              }
            } else {
              _removeOverlay();
            }
          },
          toolbarOptions: ToolbarOptions(
            copy: false,
            selectAll: false,
            cut: false,
            paste: false,
          ),
          enableInteractiveSelection: true,
          cursorWidth: 0,
          showCursor: false,
        );
      },
    );
  }
}
