import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitag_app/models/wallet.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:firebase_auth/firebase_auth.dart';

class WalletService {
  static final WalletService _instance = WalletService._internal();
  factory WalletService() => _instance;
  WalletService._internal();

  // Firestore references
  final firestore.FirebaseFirestore _firestore =
      firestore.FirebaseFirestore.instance;
  final firestore.CollectionReference _walletsCollection = firestore
      .FirebaseFirestore
      .instance
      .collection('wallets');
  final firestore.CollectionReference _transactionsCollection = firestore
      .FirebaseFirestore
      .instance
      .collection('transactions');

  // Auth reference
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Cache the wallet data locally
  Future<void> cacheWallet(Wallet wallet) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('wallet_data', jsonEncode(wallet.toJson()));
  }

  // Get cached wallet data
  Future<Wallet?> getCachedWallet() async {
    final prefs = await SharedPreferences.getInstance();
    final walletData = prefs.getString('wallet_data');

    if (walletData != null) {
      try {
        return Wallet.fromJson(jsonDecode(walletData));
      } catch (e) {
        return null;
      }
    }

    return null;
  }

  // Fetch wallet data from Firestore
  Future<Wallet?> fetchWalletData(String userId) async {
    try {
      // Try to get from Firestore first
      final walletDoc = await _walletsCollection.doc(userId).get();

      if (walletDoc.exists) {
        // Get wallet data
        final walletData = walletDoc.data() as Map<String, dynamic>;

        // Get transactions from transactions collection
        final transactionsSnapshot =
            await _transactionsCollection
                .where('userId', isEqualTo: userId)
                .orderBy('timestamp', descending: true)
                .get();

        final transactions =
            transactionsSnapshot.docs
                .map(
                  (doc) =>
                      Transaction.fromJson(doc.data() as Map<String, dynamic>),
                )
                .toList();

        // Create complete wallet object
        final wallet = Wallet(
          id: walletData['id'],
          userId: walletData['userId'],
          balance:
              (walletData['balance'] is int)
                  ? (walletData['balance'] as int).toDouble()
                  : walletData['balance'],
          transactions: transactions,
          name: walletData['name'],
        );

        // Cache the wallet locally
        await cacheWallet(wallet);
        return wallet;
      } else {
        // If not in Firestore, return cached
        return getCachedWallet();
      }
    } catch (e) {
      print('Error fetching wallet from Firestore: $e');
      // Return cached data on error
      return getCachedWallet();
    }
  }

  // Add a new transaction and update Firestore
  Future<void> addTransaction(Transaction transaction) async {
    try {
      // Get current wallet
      final wallet = await getCachedWallet();
      print(
        'DEBUG: Adding transaction to Firestore. Wallet found: ${wallet != null}',
      );

      if (wallet == null) {
        print('No wallet found to add transaction');
        return;
      }

      // Update balance based on transaction type
      double newBalance = wallet.balance;

      // For top-up, add to balance. For payments and transfers, subtract
      if (transaction.vendorId == 'system_topup') {
        newBalance += transaction.amount;
        print(
          'DEBUG: Processing top-up of ${transaction.amount}, new balance will be $newBalance',
        );
      } else {
        newBalance -= transaction.amount;
        print(
          'DEBUG: Processing payment of ${transaction.amount}, new balance will be $newBalance',
        );
      }

      // Add transaction to Firestore
      print(
        'DEBUG: Attempting to add transaction to Firestore: ${transaction.id}',
      );
      print('DEBUG: Current user ID: ${wallet.userId}');

      await _transactionsCollection.doc(transaction.id).set({
        'id': transaction.id,
        'walletId': transaction.walletId,
        'userId': wallet.userId,
        'vendorId': transaction.vendorId,
        'amount': transaction.amount,
        'timestamp': transaction.timestamp.toIso8601String(),
        'status': transaction.status,
        'isOffline': transaction.isOffline,
      });
      print('DEBUG: Transaction added to Firestore successfully');

      // Update wallet balance in Firestore
      print(
        'DEBUG: Updating wallet balance in Firestore for user: ${wallet.userId}',
      );
      await _walletsCollection.doc(wallet.userId).update({
        'balance': newBalance,
      });
      print('DEBUG: Wallet balance updated in Firestore successfully');

      // Update local wallet
      final updatedTransactions = [...wallet.transactions, transaction];

      final updatedWallet = Wallet(
        id: wallet.id,
        userId: wallet.userId,
        balance: newBalance,
        transactions: updatedTransactions,
        name: wallet.name,
      );

      // Update local cache
      await cacheWallet(updatedWallet);
      print('DEBUG: Local wallet cache updated successfully');
    } catch (e) {
      print('ERROR: Error adding transaction to Firestore: $e');
      print('ERROR: Stack trace: ${StackTrace.current}');
      // Fall back to local storage if Firestore fails
      await addLocalTransaction(transaction);
    }
  }

  // Add a new transaction locally (fallback)
  Future<void> addLocalTransaction(Transaction transaction) async {
    final wallet = await getCachedWallet();

    if (wallet != null) {
      final updatedTransactions = [...wallet.transactions, transaction];

      // Update balance based on transaction type
      double newBalance = wallet.balance;

      // For top-up, add to balance. For payments and transfers, subtract
      if (transaction.vendorId == 'system_topup') {
        newBalance += transaction.amount;
      } else {
        newBalance -= transaction.amount;
      }

      final updatedWallet = Wallet(
        id: wallet.id,
        userId: wallet.userId,
        balance: newBalance,
        transactions: updatedTransactions,
        name: wallet.name,
      );

      await cacheWallet(updatedWallet);
    }
  }

  // Get recent transactions from Firestore
  Future<List<Transaction>> getRecentTransactions(int limit) async {
    try {
      final wallet = await getCachedWallet();

      if (wallet == null) {
        return [];
      }

      // Try to get transactions from Firestore
      final transactionsSnapshot =
          await _transactionsCollection
              .where('userId', isEqualTo: wallet.userId)
              .orderBy('timestamp', descending: true)
              .limit(limit)
              .get();

      if (transactionsSnapshot.docs.isNotEmpty) {
        return transactionsSnapshot.docs
            .map(
              (doc) => Transaction.fromJson(doc.data() as Map<String, dynamic>),
            )
            .toList();
      }

      // Fallback to local transactions
      if (wallet.transactions.isNotEmpty) {
        // Sort by timestamp and return most recent
        final sorted = [...wallet.transactions]
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

        return sorted.take(limit).toList();
      }
    } catch (e) {
      print('Error getting transactions from Firestore: $e');
      // Fallback to local if Firestore fails
      final wallet = await getCachedWallet();

      if (wallet != null) {
        final sorted = [...wallet.transactions]
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
        return sorted.take(limit).toList();
      }
    }

    return [];
  }

  // Ensure a wallet exists for the user, creating one if needed
  Future<Wallet> ensureWalletExists(String userId, String userName) async {
    try {
      print('DEBUG: Ensuring wallet exists for user: $userId, name: $userName');

      // First try to get from Firestore
      print('DEBUG: Checking if wallet exists in Firestore');
      final walletDoc = await _walletsCollection.doc(userId).get();

      if (walletDoc.exists) {
        print('DEBUG: Wallet found in Firestore');
        // Return existing wallet
        final walletData = walletDoc.data() as Map<String, dynamic>;

        // Get transactions
        print('DEBUG: Fetching transactions for user');
        final transactionsSnapshot =
            await _transactionsCollection
                .where('userId', isEqualTo: userId)
                .orderBy('timestamp', descending: true)
                .get();

        final transactions =
            transactionsSnapshot.docs
                .map(
                  (doc) =>
                      Transaction.fromJson(doc.data() as Map<String, dynamic>),
                )
                .toList();
        print('DEBUG: Found ${transactions.length} transactions');

        final wallet = Wallet(
          id: walletData['id'] ?? 'wallet_$userId',
          userId: walletData['userId'] ?? userId,
          balance:
              (walletData['balance'] is int)
                  ? (walletData['balance'] as int).toDouble()
                  : (walletData['balance'] ?? 0.0),
          transactions: transactions,
          name: walletData['name'] ?? userName,
        );

        // Cache the wallet
        await cacheWallet(wallet);
        print('DEBUG: Existing wallet cached');
        return wallet;
      }

      // If not in Firestore, check cache
      print('DEBUG: Wallet not found in Firestore, checking cache');
      final cachedWallet = await getCachedWallet();

      if (cachedWallet != null) {
        print('DEBUG: Wallet found in cache, syncing to Firestore');
        // Sync cached wallet to Firestore
        try {
          await _walletsCollection.doc(userId).set({
            'id': cachedWallet.id,
            'userId': userId,
            'balance': cachedWallet.balance,
            'name': cachedWallet.name,
            'createdAt': firestore.FieldValue.serverTimestamp(),
          });
          print('DEBUG: Wallet synced to Firestore from cache');

          // Sync transactions
          for (final transaction in cachedWallet.transactions) {
            await _transactionsCollection.doc(transaction.id).set({
              'id': transaction.id,
              'walletId': transaction.walletId,
              'userId': userId,
              'vendorId': transaction.vendorId,
              'amount': transaction.amount,
              'timestamp': transaction.timestamp.toIso8601String(),
              'status': transaction.status,
              'isOffline': transaction.isOffline,
            });
          }
          print(
            'DEBUG: ${cachedWallet.transactions.length} transactions synced to Firestore',
          );
        } catch (e) {
          print('ERROR: Failed to sync wallet to Firestore: $e');
          // Continue with cached wallet even if sync fails
        }

        return cachedWallet;
      }

      // If no wallet exists, create a new one with 0 balance
      print('DEBUG: No wallet found, creating new wallet in Firestore');
      final walletId = 'wallet_${DateTime.now().millisecondsSinceEpoch}';
      final newWallet = Wallet(
        id: walletId,
        userId: userId,
        balance: 0.0, // Ensure balance starts at 0
        transactions: [],
        name: userName,
      );

      // Create in Firestore
      try {
        // First check if the document actually exists to ensure proper creation
        final checkDoc = await _walletsCollection.doc(userId).get();

        if (!checkDoc.exists) {
          print('DEBUG: Creating new wallet document in Firestore');
          await _walletsCollection.doc(userId).set({
            'id': walletId,
            'userId': userId,
            'balance': 0.0,
            'name': userName,
            'createdAt': firestore.FieldValue.serverTimestamp(),
          });
          print('DEBUG: New wallet created in Firestore successfully');
        } else {
          print('DEBUG: Wallet document already exists, using existing');
        }
      } catch (e) {
        print('ERROR: Failed to create wallet in Firestore: $e');
        // Continue with local wallet even if Firestore fails
      }

      // Cache the new wallet
      await cacheWallet(newWallet);
      print('DEBUG: New wallet cached locally');

      return newWallet;
    } catch (e) {
      print('ERROR: Error ensuring wallet exists in Firestore: $e');
      print('ERROR: Stack trace: ${StackTrace.current}');
      // Create a fallback wallet if there's an error
      final fallbackWallet = Wallet(
        id: 'wallet_${DateTime.now().millisecondsSinceEpoch}',
        userId: userId,
        balance: 0.0,
        transactions: [],
        name: userName,
      );
      await cacheWallet(fallbackWallet);
      print('DEBUG: Created fallback wallet due to error');
      return fallbackWallet;
    }
  }

  // Add money to wallet (top-up)
  Future<bool> addTopUp(double amount, String userId) async {
    try {
      print(
        'DEBUG: Starting top-up process for amount: $amount, userId: $userId',
      );

      if (amount <= 0) {
        print('DEBUG: Invalid top-up amount: $amount');
        return false;
      }

      final wallet = await getCachedWallet();
      print('DEBUG: Wallet found for top-up: ${wallet != null}');

      if (wallet == null) {
        print('DEBUG: No wallet found for top-up');
        return false;
      }

      print('DEBUG: Current wallet balance: ${wallet.balance}');

      // Create a top-up transaction
      final transactionId = 'trans_${DateTime.now().millisecondsSinceEpoch}';
      print('DEBUG: Creating top-up transaction with ID: $transactionId');

      final transaction = Transaction(
        id: transactionId,
        walletId: wallet.id,
        vendorId: 'system_topup',
        amount: amount,
        timestamp: DateTime.now(),
        status: 'completed',
        isOffline: false,
      );

      // Add the transaction (this will also update the wallet balance)
      print('DEBUG: Adding top-up transaction to Firestore');
      await addTransaction(transaction);
      print('DEBUG: Top-up transaction added successfully');

      return true;
    } catch (e) {
      print('ERROR: Error adding top-up: $e');
      print('ERROR: Stack trace: ${StackTrace.current}');
      return false;
    }
  }

  // Send money to another user
  Future<bool> sendMoney(double amount, String receiverId, String note) async {
    try {
      print(
        'DEBUG: Starting send money process for amount: $amount, receiverId: $receiverId',
      );

      if (amount <= 0) {
        print('DEBUG: Invalid send amount: $amount');
        return false;
      }

      final senderWallet = await getCachedWallet();
      print(
        'DEBUG: Sender wallet found: ${senderWallet != null}, Balance: ${senderWallet?.balance ?? 0}',
      );

      if (senderWallet == null || senderWallet.balance < amount) {
        print('DEBUG: Insufficient balance or wallet not found');
        return false;
      }

      // Create a transaction for the sender (money out)
      final senderTransactionId =
          'trans_out_${DateTime.now().millisecondsSinceEpoch}';
      print('DEBUG: Creating sender transaction with ID: $senderTransactionId');

      final senderTransaction = Transaction(
        id: senderTransactionId,
        walletId: senderWallet.id,
        vendorId: 'user_vendor',
        amount: amount,
        timestamp: DateTime.now(),
        status: 'completed',
        isOffline: false,
      );

      // Add the sender transaction
      print('DEBUG: Adding sender transaction to database');
      await addTransaction(senderTransaction);
      print('DEBUG: Sender transaction added successfully');

      try {
        // Update the receiver's wallet in Firestore
        print('DEBUG: Checking if receiver exists: $receiverId');
        final receiverDoc = await _walletsCollection.doc(receiverId).get();

        if (receiverDoc.exists) {
          print('DEBUG: Receiver found, updating their balance');
          final receiverData = receiverDoc.data() as Map<String, dynamic>;
          double receiverBalance =
              (receiverData['balance'] is int)
                  ? (receiverData['balance'] as int).toDouble()
                  : (receiverData['balance'] ?? 0.0);

          // Update receiver's balance
          await _walletsCollection.doc(receiverId).update({
            'balance': receiverBalance + amount,
          });
          print('DEBUG: Receiver balance updated successfully');

          // Create a transaction for the receiver (money in)
          final receiverTransactionId =
              'trans_in_${DateTime.now().millisecondsSinceEpoch}';
          print(
            'DEBUG: Creating receiver transaction with ID: $receiverTransactionId',
          );

          final receiverTransaction = Transaction(
            id: receiverTransactionId,
            walletId: receiverId,
            vendorId: 'user_sender',
            amount: amount,
            timestamp: DateTime.now(),
            status: 'completed',
            isOffline: false,
          );

          // Add the receiver transaction to Firestore
          print('DEBUG: Adding receiver transaction to database');
          await _transactionsCollection.doc(receiverTransaction.id).set({
            'id': receiverTransaction.id,
            'walletId': receiverId,
            'userId': receiverId,
            'vendorId': 'user_sender',
            'amount': amount,
            'timestamp': receiverTransaction.timestamp.toIso8601String(),
            'status': 'completed',
            'isOffline': false,
            'note': note,
          });
          print('DEBUG: Receiver transaction added successfully');
        } else {
          // For demo purposes, we'll create a new receiver wallet if it doesn't exist
          print(
            'DEBUG: Receiver does not exist, creating mock receiver wallet',
          );

          // Create a new receiver wallet
          final receiverWalletId =
              'wallet_${DateTime.now().millisecondsSinceEpoch}';
          await _walletsCollection.doc(receiverId).set({
            'id': receiverWalletId,
            'userId': receiverId,
            'balance': amount,
            'name': 'Receiver Wallet',
            'createdAt': firestore.FieldValue.serverTimestamp(),
          });
          print(
            'DEBUG: Created mock receiver wallet with initial balance: $amount',
          );

          // Add transaction record for receiver
          final receiverTransactionId =
              'trans_in_${DateTime.now().millisecondsSinceEpoch}';
          await _transactionsCollection.doc(receiverTransactionId).set({
            'id': receiverTransactionId,
            'walletId': receiverWalletId,
            'userId': receiverId,
            'vendorId': 'user_sender',
            'amount': amount,
            'timestamp': DateTime.now().toIso8601String(),
            'status': 'completed',
            'isOffline': false,
            'note': note,
          });
          print('DEBUG: Added transaction record for new receiver');
        }
      } catch (receiverError) {
        // If we fail to update the receiver, at least log it but don't fail the transaction
        // since the sender's side was processed successfully
        print('ERROR: Failed to update receiver: $receiverError');
        print('ERROR: Stack trace: ${StackTrace.current}');
      }

      print('DEBUG: Send money completed successfully');
      return true;
    } catch (e) {
      print('ERROR: Error sending money: $e');
      print('ERROR: Stack trace: ${StackTrace.current}');
      return false;
    }
  }

  // Clear all wallet data (for logout)
  Future<void> clearWalletData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('wallet_data');
  }

  // Add received money transaction (for NFC receive flow)
  Future<bool> addReceivedTransaction(Transaction transaction) async {
    try {
      print('DEBUG: Processing received payment of ${transaction.amount}');

      // Get the latest wallet data from Firestore
      final userId = await getUserId();
      if (userId == null) {
        print('ERROR: No authenticated user found');
        return false;
      }

      // Get the wallet document snapshot
      final walletDoc = await _walletsCollection.doc(userId).get();
      if (!walletDoc.exists) {
        print('ERROR: Wallet document not found for user $userId');
        return false;
      }

      // Get the current wallet data
      final walletData = walletDoc.data() as Map<String, dynamic>;
      final currentBalance = (walletData['balance'] as num).toDouble();

      print('DEBUG: Current wallet balance before receive: $currentBalance');

      // Calculate the new balance after receiving payment
      final double newBalance = currentBalance + transaction.amount;
      print('DEBUG: New wallet balance after receive: $newBalance');

      // Use a transaction to ensure atomicity
      await _firestore.runTransaction((txn) async {
        // Add transaction to Firestore
        print('DEBUG: Adding received transaction to Firestore');
        txn.set(_transactionsCollection.doc(transaction.id), {
          'id': transaction.id,
          'walletId': transaction.walletId,
          'userId': userId,
          'vendorId': transaction.vendorId,
          'amount': transaction.amount,
          'timestamp': transaction.timestamp.toIso8601String(),
          'status': transaction.status,
          'isOffline': transaction.isOffline,
          'sender_name': transaction.senderName,
          'sender_id': transaction.senderId,
          'note': transaction.note ?? 'Received via NFC',
          'type': 'received',
          'method': 'nfc',
        });

        // Update wallet balance in Firestore
        print('DEBUG: Updating wallet balance in Firestore');
        txn.update(_walletsCollection.doc(userId), {
          'balance': newBalance,
          'lastUpdated': DateTime.now().toIso8601String(),
        });
      });

      // Update local wallet
      final wallet = await getCachedWallet();
      if (wallet != null) {
        final updatedTransactions = [...wallet.transactions, transaction];

        final updatedWallet = Wallet(
          id: wallet.id,
          userId: wallet.userId,
          balance: newBalance,
          transactions: updatedTransactions,
          name: wallet.name,
        );

        // Update local cache
        await cacheWallet(updatedWallet);
        print('DEBUG: Local wallet updated with new balance: $newBalance');
      } else {
        // Refresh the wallet from Firestore
        await refreshWallet();
      }

      return true;
    } catch (e) {
      print('ERROR: Failed to process received payment: $e');
      return false;
    }
  }

  // Get the current authenticated user ID
  Future<String?> getUserId() async {
    final user = _auth.currentUser;
    return user?.uid;
  }

  // Refresh wallet data from Firestore
  Future<Wallet?> refreshWallet() async {
    try {
      final userId = await getUserId();
      if (userId == null) {
        print('ERROR: No authenticated user found');
        return null;
      }

      // Get the wallet from Firestore
      final walletDoc = await _walletsCollection.doc(userId).get();
      if (!walletDoc.exists) {
        print('ERROR: Wallet document not found for user $userId');
        return null;
      }

      // Get transactions for this wallet
      final walletData = walletDoc.data() as Map<String, dynamic>;

      // Get all transactions for this wallet
      final transactionsQuery =
          await _transactionsCollection
              .where('userId', isEqualTo: userId)
              .orderBy('timestamp', descending: true)
              .get();

      // Convert transaction documents to Transaction objects
      final transactions =
          transactionsQuery.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return Transaction.fromJson(data);
          }).toList();

      // Create the wallet object
      final wallet = Wallet(
        id: walletData['id'] as String,
        userId: userId,
        balance: (walletData['balance'] as num).toDouble(),
        name: walletData['name'] as String,
        transactions: transactions,
      );

      // Cache the updated wallet
      await cacheWallet(wallet);
      return wallet;
    } catch (e) {
      print('ERROR: Failed to refresh wallet: $e');
      return null;
    }
  }

  // Update wallet name
  Future<void> updateWalletName(String userId, String newName) async {
    try {
      print('DEBUG: Updating wallet name to: $newName for user: $userId');

      // Update in Firestore
      await _walletsCollection.doc(userId).update({'name': newName});

      // Update in local cache
      final wallet = await getCachedWallet();
      if (wallet != null && wallet.userId == userId) {
        final updatedWallet = Wallet(
          id: wallet.id,
          userId: wallet.userId,
          balance: wallet.balance,
          name: newName,
          transactions: wallet.transactions,
        );

        await cacheWallet(updatedWallet);
      }

      print('DEBUG: Wallet name updated successfully');
    } catch (e) {
      print('ERROR: Failed to update wallet name: $e');
      rethrow;
    }
  }
}
