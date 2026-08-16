class TransactionModel {
  final String id;
  final String fromguardianMoxId;
  final String toguardianMoxId;
  final double amount;
  final DateTime timestamp;
  final String type; // (خدمة، تحويل، عمولة)

  TransactionModel({
    required this.id,
    required this.fromguardianMoxId,
    required this.toguardianMoxId,
    required this.amount,
    required this.timestamp,
    required this.type,
  });
}

// قائمة عالمية للسجلات (مؤقتة)
List<TransactionModel> transactionLogs = [];
