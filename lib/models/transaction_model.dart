class TransactionModel {
  final String id;
  final String fromMoxId;
  final String toMoxId;
  final double amount;
  final DateTime timestamp;
  final String type; // (خدمة، تحويل، عمولة)

  TransactionModel({
    required this.id,
    required this.fromMoxId,
    required this.toMoxId,
    required this.amount,
    required this.timestamp,
    required this.type,
  });
}

// قائمة عالمية للسجلات (مؤقتة)
List<TransactionModel> transactionLogs = [];
