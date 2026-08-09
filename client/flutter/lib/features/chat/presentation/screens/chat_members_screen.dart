// © 2024-2026 Бутаев Алексей Юрьевич. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
import 'package:flutter/material.dart';

class ChatMembersScreen extends StatefulWidget {
  final String chatId;
  final String chatTitle;

  const ChatMembersScreen({
    super.key,
    required this.chatId,
    this.chatTitle = 'Чат',
  });

  @override
  State<ChatMembersScreen> createState() => _ChatMembersScreenState();
}

class _ChatMembersScreenState extends State<ChatMembersScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.chatTitle)),
      body: const Center(
        child: Text('В разработке'),
      ),
    );
  }
}
