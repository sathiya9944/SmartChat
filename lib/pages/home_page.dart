import 'dart:io';
import 'dart:typed_data';

import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:image_picker/image_picker.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() {
    return _HomePageState();
  }
}

class _HomePageState extends State<HomePage> {
  final Gemini gemini = Gemini.instance;
  List<ChatMessage> messages = [];

  ChatUser currentUser = ChatUser(
    id: "0",
    firstName: "User",
  );

  ChatUser botUser = ChatUser(
    id: "1",
    firstName: "Bot",
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Chat'),
      ),
      body: _buildUI(),
    );
  }

  Widget _buildUI() {
    return DashChat(
      inputOptions: InputOptions(trailing: [
        IconButton(
          icon: const Icon(Icons.image),
          onPressed: _sendMediaMsg,
        )
      ]),
      currentUser: currentUser,
      onSend: sendMsg,
      messages: messages,
    );
  }

  void sendMsg(ChatMessage chatMessage) {
    setState(() {
      messages = [chatMessage, ...messages];
    });

    try {
      String question = chatMessage.text;
      String buffer = "";

      // Create parts list
      List<Part> parts = [];
      
      // Add text part
      parts.add(Part.text(question));

      // Add image parts if present
      if (chatMessage.medias?.isNotEmpty ?? false) {
        for (var media in chatMessage.medias!) {
          if (media.type == MediaType.image) {
            try {
              Uint8List imageBytes = File(media.url).readAsBytesSync();
              // Use Part.data for images
              parts.add(Part.bytes(imageBytes));
            } catch (e) {
              print("Error reading image file: $e");
            }
          }
        }
      }

      // Use promptStream with parts
      gemini.promptStream(
        parts: parts,
      ).listen((event) {
        final chunk = event?.content?.parts
                ?.whereType<TextPart>()
                .map((p) => p.text ?? "")
                .join(" ")
                .trim() ??
            "";

        if (chunk.isEmpty) return;

        buffer += " $chunk";

        ChatMessage? lastMessage = messages.isNotEmpty ? messages.first : null;

        if (lastMessage != null && lastMessage.user == botUser) {
          // Update existing bot message
          messages.removeAt(0);
          lastMessage.text = buffer.trim();

          setState(() {
            messages = [lastMessage, ...messages];
          });
        } else {
          // Add first bot message
          ChatMessage message = ChatMessage(
            user: botUser,
            createdAt: DateTime.now(),
            text: buffer.trim(),
          );

          setState(() {
            messages = [message, ...messages];
          });
        }
      }, onError: (err) {
        print("Gemini error: $err");
        setState(() {
          messages = [
            ChatMessage(
              user: botUser,
              createdAt: DateTime.now(),
              text: "Sorry, I encountered an error processing your request.",
            ),
            ...messages
          ];
        });
      });
    } catch (e) {
      print("Error: $e");
    }
  }

  void _sendMediaMsg() async {
    ImagePicker picker = ImagePicker();
    XFile? file = await picker.pickImage(
      source: ImageSource.gallery,
    );
    
    if (file != null) {
      ChatMessage chatMessage = ChatMessage(
        user: currentUser,
        createdAt: DateTime.now(),
        text: "Describe this image",
        medias: [
          ChatMedia(
            url: file.path,
            fileName: file.name,
            type: MediaType.image,
          )
        ]
      );
      sendMsg(chatMessage);
    }
  }
}
