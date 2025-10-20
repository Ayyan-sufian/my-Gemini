import 'dart:io';
import 'dart:typed_data';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:image_picker/image_picker.dart';

class MyHomeScreen extends StatefulWidget {
  const MyHomeScreen({super.key});

  @override
  State<MyHomeScreen> createState() => _MyHomeScreenState();
}

class _MyHomeScreenState extends State<MyHomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Gemini gemini = Gemini.instance;
  List<ChatMessage> messages = [];
  bool _isTypingPlaceholderShown = false;
  String? _pendingImagePath;

  final ChatUser geminiUser = ChatUser(id: "1", firstName: "Gemini");
  final ChatUser geminiTypingUser = ChatUser(
    id: "gemini_typing",
    firstName: "Gemini",
  );

  final ChatUser currentUser = ChatUser(id: "0", firstName: "User");

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startTypingAnimation() {
    if (!_isTypingPlaceholderShown) {
      _controller.repeat();
      setState(() {
        _isTypingPlaceholderShown = true;
      });
    } else {
      _controller.repeat();
    }
  }

  void _stopTypingAnimation() {
    _controller.stop();
    setState(() {
      _isTypingPlaceholderShown = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Center(child: Text("Gemini App"))),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DashChat(
                inputOptions: InputOptions(
                  trailing: [
                    IconButton(
                      onPressed: _sendMediaMessage,
                      icon: const Icon(Icons.photo),
                    ),
                  ],
                ),
                currentUser: currentUser,
                onSend: _sendMessage,
                messages: messages,
                messageOptions: MessageOptions(
                  avatarBuilder: (user, onTap, onLongPress) {
                    if (user.id == geminiTypingUser.id) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: RotationTransition(
                          turns: _controller,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.blueAccent,
                                    width: 3,
                                  ),
                                ),
                              ),
                              const CircleAvatar(
                                radius: 12,
                                backgroundImage: AssetImage(
                                  "assets/icon/gemini_logo.png",
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    if (user.id == geminiUser.id) {
                      return const Padding(
                        padding: EdgeInsets.only(right: 8.0),
                        child: CircleAvatar(
                          radius: 18,
                          backgroundImage: AssetImage(
                            "assets/icon/gemini_logo.png",
                          ),
                        ),
                      );
                    }
                    return const CircleAvatar(child: Icon(Icons.person));
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _sendMessage(ChatMessage chatMessage) {
    FocusScope.of(context).unfocus();

    ChatMessage messageToSend = chatMessage;
    if (_pendingImagePath != null) {
      messageToSend = ChatMessage(
        user: currentUser,
        createdAt: DateTime.now(),
        text: chatMessage.text,
        medias: [
          ChatMedia(
            url: _pendingImagePath!,
            fileName: _pendingImagePath!.split('/').last,
            type: MediaType.image,
          ),
        ],
      );

      setState(() {
        _pendingImagePath = null;
      });
    }

    setState(() {
      messages.insert(0, messageToSend);
    });

    ChatMessage typingMessage = ChatMessage(
      user: geminiTypingUser,
      createdAt: DateTime.now(),
      text: "Gemini is typing...",
    );

    setState(() {
      messages.removeWhere((m) => m.user.id == geminiTypingUser.id);
      messages.insert(0, typingMessage);
    });

    _startTypingAnimation();

    try {
      String question = messageToSend.text;
      List<Uint8List>? images;
      if (messageToSend.medias?.isNotEmpty ?? false) {
        images = [File(messageToSend.medias!.first.url).readAsBytesSync()];
      }

      StringBuffer responseBuffer = StringBuffer();

      gemini
          .streamGenerateContent(question, images: images)
          .listen(
            (event) {
              String chunk =
                  event.content?.parts?.fold(
                    "",
                    (previous, current) =>
                        "$previous ${(current as dynamic).text ?? ''}",
                  ) ??
                  '';
              responseBuffer.write(chunk);
            },
            onDone: () {
              _stopTypingAnimation();

              setState(() {
                messages.removeWhere((m) => m.user.id == geminiTypingUser.id);

                messages.insert(
                  0,
                  ChatMessage(
                    user: geminiUser,
                    createdAt: DateTime.now(),
                    text: responseBuffer.toString().trim().isEmpty
                        ? "..."
                        : responseBuffer.toString().trim(),
                  ),
                );
              });
            },
            onError: (error) {
              _stopTypingAnimation();
              setState(() {
                messages.removeWhere((m) => m.user.id == geminiTypingUser.id);
              });
              debugPrint("Gemini Error: $error");
            },
          );
    } catch (e) {
      _stopTypingAnimation();
      debugPrint("$e");
    }
  }

  void _sendMediaMessage() async {
    ImagePicker picker = ImagePicker();
    XFile? file = await picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      setState(() {
        _pendingImagePath = file.path;
      });
    }
  }
}
