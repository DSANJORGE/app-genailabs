import 'package:flutter/material.dart';
import 'admin_api.dart';
import 'admin_models.dart';

/// Stub — Task 9 fills this in.
class AdminPeople extends StatelessWidget {
  const AdminPeople({super.key, required this.api, required this.me});
  final AdminApi api;
  final AdminMe me;
  @override
  Widget build(BuildContext c) => const Center(child: Text('People'));
}
