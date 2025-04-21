class Wallet {
  final String id;
  final String userId;
  final double balance;
  final List<Transaction> transactions;
  final String name;

  Wallet({
    required this.id,
    required this.userId,
    required this.balance,
    required this.transactions,
    required this.name,
  });

  factory Wallet.fromJson(Map<String, dynamic> json) {
    // Handle potential type mismatches
    try {
      double balanceValue = 0.0;
      if (json['balance'] is double) {
        balanceValue = json['balance'];
      } else if (json['balance'] is int) {
        balanceValue = (json['balance'] as int).toDouble();
      } else if (json['balance'] is String) {
        balanceValue = double.tryParse(json['balance']) ?? 0.0;
      }

      final List<Transaction> transactionsList = [];
      if (json['transactions'] is List) {
        final transList = json['transactions'] as List;
        for (var transaction in transList) {
          if (transaction is Map<String, dynamic>) {
            try {
              transactionsList.add(Transaction.fromJson(transaction));
            } catch (e) {
              print('Error parsing transaction: $e');
            }
          }
        }
      }

      return Wallet(
        id: json['id']?.toString() ?? '',
        userId: json['user_id']?.toString() ?? '',
        balance: balanceValue,
        transactions: transactionsList,
        name: json['name']?.toString() ?? 'Wallet',
      );
    } catch (e) {
      print('Error creating wallet from json: $e');
      return Wallet(
        id: 'error_wallet',
        userId: '',
        balance: 0.0,
        transactions: [],
        name: 'Error Wallet',
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'balance': balance,
      'transactions': transactions.map((e) => e.toJson()).toList(),
      'name': name,
    };
  }
}

class Transaction {
  final String id;
  final String walletId;
  final String vendorId;
  final double amount;
  final DateTime timestamp;
  final String status;
  final bool isOffline;
  final String? senderName;
  final String? senderId;
  final String? note;

  Transaction({
    required this.id,
    required this.walletId,
    required this.vendorId,
    required this.amount,
    required this.timestamp,
    required this.status,
    this.isOffline = false,
    this.senderName,
    this.senderId,
    this.note,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    try {
      double amountValue = 0.0;
      if (json['amount'] is double) {
        amountValue = json['amount'];
      } else if (json['amount'] is int) {
        amountValue = (json['amount'] as int).toDouble();
      } else if (json['amount'] is String) {
        amountValue = double.tryParse(json['amount'] ?? '0') ?? 0.0;
      }

      DateTime timestampValue;
      try {
        if (json['timestamp'] is String) {
          timestampValue = DateTime.parse(json['timestamp']);
        } else {
          timestampValue = DateTime.now();
        }
      } catch (e) {
        timestampValue = DateTime.now();
      }

      return Transaction(
        id: json['id']?.toString() ?? '',
        walletId: json['wallet_id']?.toString() ?? '',
        vendorId: json['vendor_id']?.toString() ?? '',
        amount: amountValue,
        timestamp: timestampValue,
        status: json['status']?.toString() ?? 'unknown',
        isOffline: json['offline'] == true,
        senderName: json['sender_name']?.toString(),
        senderId: json['sender_id']?.toString(),
        note: json['note']?.toString(),
      );
    } catch (e) {
      print('Error parsing transaction: $e');
      return Transaction(
        id: 'error_transaction',
        walletId: '',
        vendorId: '',
        amount: 0.0,
        timestamp: DateTime.now(),
        status: 'error',
        isOffline: false,
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'wallet_id': walletId,
      'vendor_id': vendorId,
      'amount': amount,
      'timestamp': timestamp.toIso8601String(),
      'status': status,
      'offline': isOffline,
      if (senderName != null) 'sender_name': senderName,
      if (senderId != null) 'sender_id': senderId,
      if (note != null) 'note': note,
    };
  }
}
