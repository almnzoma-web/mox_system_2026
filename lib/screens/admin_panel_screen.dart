// ignore_for_file: use_build_context_synchronously

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
      "https://script.google.com/macros/s/AKfycbycCPFDCesTBzuQWhlpeBiacAuOs9nNz-f65GvcbbDOQ8q-Y2sKR8T40VW6Lwr4AWyO/exec";

  @override
  void initState() {
    super.initState();
    _fetchFromCloud();
  }

  Future<void> _fetchFromCloud() async {
    setState(() => _isLoading = true);
    try {
      final response = await http
          .get(Uri.parse(_scriptUrl))
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
      final queryParameters = {
        'action': 'save',
        'phone': user.phone,
        'password': user.password,
        'name': user.name,
        'address': user.address,
        'storeDescription': user.storeDescription,
        'balance': user.balance.toString(),
        'commission': user.commission.toString(),
        'gender': user.gender,
        'accountType': user.accountType,
        'moxId': user.moxId,
        'role': user.role,
        'customWhatsApp': user.customWhatsApp ?? '',
        'guardianMoxId':
            user.guardianMoxId ?? '', // 🔒 تثبيت الحقل السيادي وعدم ضياعه
        'guardianMoxIdCustomer': user.guardianMoxIdCustomer ?? '',
        'points': user.points.toString(),
        'storePublishDate': user.storePublishDate ?? '',
        'activationDate': user.activationDate ?? '',
        'myAssets': json.encode(user.myAssets.map((a) => a.toJson()).toList()),
      };

      final uri = Uri.parse(
        _scriptUrl,
      ).replace(queryParameters: queryParameters);

      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("تم ترحيل العميل ${user.name} للشيت بنجاح بالمسطرة!"),
            backgroundColor: Colors.green,
          ),
        );
        _fetchFromCloud();
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

  // نافذة تعديل بيانات العميل وإضافة/تحديث الـ guardianMoxId يدوياً ليحفظ في الذاكرة والشيت
  void _showEditClientDialog(UserModel user) {
    final TextEditingController guardianMoxController = TextEditingController(
      text: user.guardianMoxId ?? '',
    );
    final TextEditingController moxIdController = TextEditingController(
      text: user.moxId,
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("تعديل المعرف السيادي: ${user.name}"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: guardianMoxController,
                  decoration: const InputDecoration(
                    labelText: "معرف MOX المضاف يدوياً (guardianMoxId)",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: moxIdController,
                  decoration: const InputDecoration(
                    labelText: "معرف MOX الأساسي (moxId)",
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("إلغاء"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: moxBlue),
              onPressed: () async {
                setState(() {
                  user.guardianMoxId = guardianMoxController.text.trim();
                  user.moxId = moxIdController.text.trim();
                });

                // حفظ محلياً في الذاكرة
                await StorageService.updateUserPartial(user);

                // ترحيل فوري لـ Google Sheets لتأمين البيانات
                Navigator.pop(context);
                await _syncClientToCloud(user);
              },
              child: const Text(
                "حفظ وترحيل",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "لوحة تحكم المدير - السجل السيادي",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
          ? Center(child: CircularProgressIndicator(color: moxBlue))
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
                        "الهوية الأساسية (MOX)",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        "الهوية المضافة (Guardian)",
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
                        DataCell(
                          InkWell(
                            onTap: () => _showEditClientDialog(user),
                            child: Text(
                              user.guardianMoxId?.isNotEmpty == true
                                  ? user.guardianMoxId!
                                  : "اضغط للإضافة ⚙️",
                              style: TextStyle(
                                color: user.guardianMoxId?.isNotEmpty == true
                                    ? Colors.indigo
                                    : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        DataCell(Text(user.balance.toString())),
                        DataCell(Text(user.accountType)),
                        DataCell(
                          Row(
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  minimumSize: const Size(80, 32),
                                ),
                                onPressed: () => _showEditClientDialog(user),
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                label: const Text(
                                  "تعديل",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: moxBlue,
                                  minimumSize: const Size(90, 32),
                                ),
                                onPressed: () => _syncClientToCloud(user),
                                icon: const Icon(
                                  Icons.cloud_upload,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                label: const Text(
                                  "رحّل للشيت",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
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
