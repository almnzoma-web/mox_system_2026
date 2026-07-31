import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../services/storage_service.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final Color moxBlue = const Color(0xFF33A1C9);
  List<UserModel> _clients = [];
  bool _isLoading = true;

  static const String _scriptUrl =
      "https://script.google.com/macros/s/AKfycbzTLmDM6F2-5dcOrci8AN4-VOn8cwbvFsFd3A-dgNPm36Z5D3Z5RPixK8q5MPdISWk/exec";

  @override
  void initState() {
    super.initState();
    _fetchFromCloud();
  }

  Future<void> _fetchFromCloud() async {
    setState(() => _isLoading = true);
    try {
      final response = await http
          .get(
            Uri.parse('$_scriptUrl?action=save'),
          ) // أو السكربت الافتراضي للجلب
          .timeout(const Duration(seconds: 8));
      if (!mounted) return;
      if (response.statusCode == 200) {
        List<dynamic> cloudList = json.decode(response.body);
        setState(() {
          _clients = cloudList
              .map(
                (item) => UserModel.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList();
        });
      }
    } catch (_) {
      await StorageService.loadUsers();
      if (!mounted) return;
      setState(() {
        _clients = StorageService.registeredUsers;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _syncClientToCloud(UserModel user) async {
    try {
      // إرسال كافة الحقول الخضراء والزرقاء بدقة متناهية بالمسطرة
      final uri = Uri.parse(
        '$_scriptUrl?action=save&phone=${Uri.encodeComponent(user.phone)}&password=${Uri.encodeComponent(user.password)}&name=${Uri.encodeComponent(user.name)}&address=${Uri.encodeComponent(user.address)}&balance=${user.balance}&commission=${user.commission}&gender=${Uri.encodeComponent(user.gender)}&accountType=${Uri.encodeComponent(user.accountType)}&moxId=${Uri.encodeComponent(user.moxId)}&role=${Uri.encodeComponent(user.role)}&customWhatsApp=${Uri.encodeComponent(user.customWhatsApp ?? '')}&guardianMoxId=${Uri.encodeComponent(user.guardianMoxId ?? '')}&points=${user.points}&myAssets=${Uri.encodeComponent(json.encode(user.myAssets))}',
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 6));
      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("تم ترحيل العميل ${user.name} للشيت بنجاح بالمسطرة!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("خطأ في الترحيل: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "لوحة تحكم المدير - السجل السيادي",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: moxBlue,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchFromCloud,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  columns: const [
                    DataColumn(
                      label: Text(
                        "الاسم",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        "الهاتف",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        "الهوية (MOX)",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        "الرصيد",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        "نوع الحساب",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        "الإجراء السيادي",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                  rows: _clients.map((user) {
                    return DataRow(
                      cells: [
                        DataCell(Text(user.name)),
                        DataCell(Text(user.phone)),
                        DataCell(Text(user.moxId)),
                        DataCell(Text(user.balance.toString())),
                        DataCell(Text(user.accountType)),
                        DataCell(
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: moxBlue,
                            ),
                            onPressed: () => _syncClientToCloud(user),
                            icon: const Icon(
                              Icons.cloud_upload,
                              color: Colors.white,
                              size: 16,
                            ),
                            label: const Text(
                              "رحّل للشيت",
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
    );
  }
}
