import 'dart:convert';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class NfcService {
  static final NfcService _instance = NfcService._internal();
  factory NfcService() => _instance;
  NfcService._internal();

  bool _isNfcAvailable = false;

  // Check if NFC is available on the device
  Future<bool> checkNfcAvailability() async {
    _isNfcAvailable = await NfcManager.instance.isAvailable();
    return _isNfcAvailable;
  }

  // Start listening for NFC events
  Future<void> startNfcSession({
    required Function(String) onTagRead,
    required Function(String) onError,
  }) async {
    if (!_isNfcAvailable) {
      onError('NFC is not available on this device');
      return;
    }

    try {
      print('DEBUG: Starting NFC session in payment receiving mode');

      NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          try {
            print('DEBUG: NFC tag discovered: ${tag.data}');

            // FOR DEMO: If using this between two phones, one of these approaches will work

            // Approach 1: Read NDEF data from tag
            final ndefTag = Ndef.from(tag);
            if (ndefTag != null) {
              // Read NDEF message from tag if available
              final cachedMessage = ndefTag.cachedMessage;
              if (cachedMessage != null) {
                String? payload = _decodeNdefPayload(cachedMessage);
                if (payload != null) {
                  print('DEBUG: Successfully read NDEF payload: $payload');
                  onTagRead(payload);
                  return;
                }
              }
            }

            // Approach 2: Try to read raw tag data as fallback
            // This is useful when the sending device doesn't format as NDEF
            if (tag.data.isNotEmpty) {
              String rawData = jsonEncode(tag.data);
              print('DEBUG: Using raw tag data: $rawData');
              onTagRead(rawData);
              return;
            }

            // If we reach here, create a simple default payload for demo purposes
            // In production, you would properly handle this with an error
            print('DEBUG: Creating demo fallback payment data');
            onTagRead('{"demo_fallback":true}');
          } catch (e) {
            print('ERROR: Exception reading NFC tag: $e');
            onError('Error reading NFC tag: $e');
          }
        },
        // Use the NfcErrorCallback type as expected by the NFC package
        onError: (error) => onError(error.message),
      );
    } catch (e) {
      print('ERROR: Failed to start NFC session: $e');
      onError('Failed to start NFC session: $e');
    }
  }

  // Stop listening for NFC events
  Future<void> stopNfcSession() async {
    NfcManager.instance.stopSession();
  }

  // Process wallet transaction with minimal internet requirement
  Future<Map<String, dynamic>> processTransaction({
    required String walletId,
    required String vendorId,
    required double amount,
    required String senderName,
    required String senderId,
    String? note,
  }) async {
    final transactionData = {
      'wallet_id': walletId,
      'vendor_id': vendorId,
      'amount': amount,
      'timestamp': DateTime.now().toIso8601String(),
      'sender_name': senderName,
      'sender_id': senderId,
      'note': note ?? 'Payment via NFC',
    };

    // 1. First try to use cached offline transaction if there's no internet
    if (!await _checkInternetConnection()) {
      return _processOfflineTransaction(transactionData);
    }

    // 2. If internet is available, process online
    try {
      final response = await http
          .post(
            Uri.parse('https://example.vitag.api/transaction'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(transactionData),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        // Add success message for vendor display
        responseData['vendor_message'] = '$senderName sent ₹$amount';
        return responseData;
      } else {
        // Fallback to offline mode if server responds with error
        return _processOfflineTransaction(transactionData);
      }
    } catch (e) {
      // Fallback to offline mode on any error
      return _processOfflineTransaction(transactionData);
    }
  }

  // Process transaction offline with local caching
  Future<Map<String, dynamic>> _processOfflineTransaction(
    Map<String, dynamic> transactionData,
  ) async {
    try {
      final transaction = {
        ...transactionData,
        'status': 'pending',
        'offline': true,
        'transaction_id': DateTime.now().millisecondsSinceEpoch.toString(),
        'vendor_message':
            '${transactionData['sender_name']} sent ₹${transactionData['amount']}',
      };

      // Save offline transaction to sync later
      await _saveOfflineTransaction(transaction);

      return transaction;
    } catch (e) {
      print('ERROR: Failed to process offline transaction: $e');
      // Return a minimal transaction to prevent crashes
      return {
        'status': 'error',
        'offline': true,
        'error_message': 'Failed to process: $e',
        'transaction_id': DateTime.now().millisecondsSinceEpoch.toString(),
      };
    }
  }

  // Save an offline transaction to sync later
  Future<void> _saveOfflineTransaction(Map<String, dynamic> transaction) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> offlineTransactions =
        prefs.getStringList('offline_transactions') ?? [];

    offlineTransactions.add(jsonEncode(transaction));
    await prefs.setStringList('offline_transactions', offlineTransactions);
  }

  // Sync offline transactions when internet becomes available
  Future<void> syncOfflineTransactions() async {
    if (!await _checkInternetConnection()) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    List<String> offlineTransactions =
        prefs.getStringList('offline_transactions') ?? [];

    if (offlineTransactions.isEmpty) {
      return;
    }

    List<String> failedTransactions = [];

    for (final transaction in offlineTransactions) {
      try {
        final response = await http
            .post(
              Uri.parse('https://example.vitag.api/sync'),
              headers: {'Content-Type': 'application/json'},
              body: transaction,
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode != 200) {
          failedTransactions.add(transaction);
        }
      } catch (e) {
        failedTransactions.add(transaction);
      }
    }

    // Save back any failed transactions
    await prefs.setStringList('offline_transactions', failedTransactions);
  }

  // Check if internet connection is available
  Future<bool> _checkInternetConnection() async {
    try {
      final response = await http
          .get(Uri.parse('https://example.vitag.api/ping'))
          .timeout(const Duration(seconds: 2));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Decode NDEF payload to string
  String? _decodeNdefPayload(NdefMessage message) {
    try {
      if (message.records.isEmpty) return null;

      for (final record in message.records) {
        if (record.typeNameFormat == NdefTypeNameFormat.nfcWellknown &&
            record.payload.isNotEmpty) {
          // Skip the language code (first byte)
          return String.fromCharCodes(record.payload.skip(1));
        } else if (record.payload.isNotEmpty) {
          // Try to get any payload as a fallback
          return String.fromCharCodes(record.payload);
        }
      }

      return null;
    } catch (e) {
      print('ERROR: Failed to decode NDEF payload: $e');
      // Return a simple fallback payload for demo purposes
      return '{"demo_fallback":true}';
    }
  }
}
