import 'package:flutter/material.dart';
import '../models/transaction_model.dart'; // تأكد أن الموديل في lib/models/transaction_model.dart

class TransactionLogScreen extends StatelessWidget {
  const TransactionLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("سجل العمليات"),
        backgroundColor: const Color(0xFF33A1C9),
        foregroundColor: Colors.white, // أضفتها لتوحيد الهوية
      ),
      body: transactionLogs.isEmpty
          ? const Center(child: Text("لا توجد عمليات مسجلة بعد"))
          : ListView.builder(
              itemCount: transactionLogs.length,
              itemBuilder: (context, index) {
                final log = transactionLogs[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  child: ListTile(
                    // تم تعديل الشرط ليطابق نوع العملية "عمولة خدمة"
                    leading: Icon(
                      log.type.contains('عمولة')
                          ? Icons.trending_up
                          : Icons.swap_horiz,
                      color: const Color(0xFF33A1C9),
                    ),
                    title: Text(
                      "من ${log.fromguardianMoxId} إلى ${log.toguardianMoxId}",
                    ),
                    subtitle: Text(
                      "المبلغ: ${log.amount.toStringAsFixed(2)} | ${log.timestamp.toString().substring(0, 16)}",
                    ),
                    trailing: Text(
                      log.type,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
