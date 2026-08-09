// © 2024-2026 Бутаев Алексей Юрьевич. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
import 'package:flutter/material.dart';

class GroupManagementScreen extends StatefulWidget {
  final String chatId;
  final String chatTitle;
  final String? avatarUrl;

  const GroupManagementScreen({
    super.key,
    required this.chatId,
    this.chatTitle = 'Группа',
    this.avatarUrl,
  });

  @override
  State<GroupManagementScreen> createState() => _GroupManagementScreenState();
}

class _GroupManagementScreenState extends State<GroupManagementScreen> {
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
