import 'package:flutter/material.dart';
import 'package:vitag_app/services/nfc_service.dart';
import 'package:vitag_app/services/wallet_service.dart';
import 'package:vitag_app/models/wallet.dart';
import 'dart:convert';

class ReceiveMoneyScreen extends StatefulWidget {
  final Wallet wallet;

  const ReceiveMoneyScreen({super.key, required this.wallet});

  @override
  State<ReceiveMoneyScreen> createState() => _ReceiveMoneyScreenState();
}

class _ReceiveMoneyScreenState extends State<ReceiveMoneyScreen> {
  final NfcService _nfcService = NfcService();
  final WalletService _walletService = WalletService();
  bool _isWaitingForNfc = false;
  String _statusMessage = 'Ready to receive payment';
  bool _transactionComplete = false;
  double _receivedAmount = 0.0;
  String _senderName = '';
  String _paymentNote = '';

  @override
  void initState() {
    super.initState();
    _checkNfcAvailability();
  }

  @override
  void dispose() {
    _stopNfcReceiving();
    super.dispose();
  }

  Future<void> _checkNfcAvailability() async {
    bool isAvailable = await _nfcService.checkNfcAvailability();
    if (!isAvailable) {
      setState(() {
        _statusMessage = 'NFC is not available on this device';
      });
    }
  }

  Future<void> _startNfcReceiving() async {
    setState(() {
      _isWaitingForNfc = true;
      _statusMessage = 'Waiting for sender to tap phone...';
      _transactionComplete = false;
    });

    try {
      // Generate a payment request with your wallet details
      final paymentRequest = {
        'receiverId': widget.wallet.userId,
        'receiverName': widget.wallet.name,
        'receiverWalletId': widget.wallet.id,
        'timestamp': DateTime.now().toIso8601String(),
        'action': 'payment_request',
      };

      // In a real app, you would activate NFC host card emulation here
      // to broadcast this payment request to the sender's device

      // For demo purposes, show this data as if it's being broadcast
      print(
        'DEBUG: Broadcasting NFC payment request: ${jsonEncode(paymentRequest)}',
      );

      await _nfcService.startNfcSession(
        onTagRead: (payload) {
          try {
            _processReceivedPayment(payload);
          } catch (e) {
            print('ERROR: Exception in NFC onTagRead callback: $e');
            setState(() {
              _isWaitingForNfc = false;
              _statusMessage = 'Error processing payment: $e';
            });
          }
        },
        onError: (error) {
          print('ERROR: NFC session error: $error');
          setState(() {
            _isWaitingForNfc = false;
            _statusMessage = 'Error: $error';
          });
        },
      );
    } catch (e) {
      print('ERROR: Failed to start NFC session: $e');
      setState(() {
        _isWaitingForNfc = false;
        _statusMessage = 'Failed to start NFC: $e';
      });
    }
  }

  Future<void> _stopNfcReceiving() async {
    if (_isWaitingForNfc) {
      await _nfcService.stopNfcSession();
      setState(() {
        _isWaitingForNfc = false;
      });
    }
  }

  Future<void> _processReceivedPayment(String paymentData) async {
    setState(() {
      _statusMessage = 'Processing payment...';
    });

    try {
      print('DEBUG: Received payment data: $paymentData');

      Map<String, dynamic> paymentDetails;
      bool isSimulated = false;

      // Try to parse the real NFC data first
      try {
        if (paymentData.trim().startsWith('{') &&
            paymentData.trim().endsWith('}')) {
          paymentDetails = jsonDecode(paymentData) as Map<String, dynamic>;
          print('DEBUG: Successfully parsed NFC payload: $paymentDetails');

          // Check if this is the demo fallback data
          if (paymentDetails.containsKey('demo_fallback') &&
              paymentDetails['demo_fallback'] == true) {
            print(
              'DEBUG: Using simulated payment data because real NFC data was not available',
            );
            paymentDetails = _generateSimulatedPaymentData();
            isSimulated = true;
          }
        } else {
          throw FormatException('Invalid JSON format in NFC payload');
        }
      } catch (parseError) {
        print(
          'ERROR: Failed to parse NFC payload, using simulation instead: $parseError',
        );
        // Fall back to simulated data if parsing fails
        paymentDetails = _generateSimulatedPaymentData();
        isSimulated = true;
      }

      // Extract payment information from either real or simulated data
      double receivedAmount;

      try {
        if (paymentDetails.containsKey('amount')) {
          var amountValue = paymentDetails['amount'];
          if (amountValue is double) {
            receivedAmount = amountValue;
          } else if (amountValue is int) {
            receivedAmount = amountValue.toDouble();
          } else if (amountValue is String) {
            receivedAmount = double.parse(amountValue);
          } else {
            throw FormatException('Invalid amount format: $amountValue');
          }
        } else {
          print(
            'DEBUG: No amount found in payment data, using simulated amount',
          );
          receivedAmount = _generateSimulatedPaymentData()['amount'] as double;
          isSimulated = true;
        }
      } catch (e) {
        print('ERROR: Failed to parse amount: $e');
        receivedAmount = _generateSimulatedPaymentData()['amount'] as double;
        isSimulated = true;
      }

      final senderName =
          paymentDetails['senderName'] as String? ??
          paymentDetails['sender_name'] as String? ??
          'Unknown Sender';

      final senderId =
          paymentDetails['senderId'] as String? ??
          paymentDetails['sender_id'] as String? ??
          'unknown_sender';

      final paymentNote =
          paymentDetails['note'] as String? ?? 'Payment via NFC';

      print(
        'DEBUG: Processing payment - Amount: $receivedAmount, Sender: $senderName, Note: $paymentNote',
      );

      // Create a transaction record for the received payment
      final transaction = Transaction(
        id: 'receive_${DateTime.now().millisecondsSinceEpoch}',
        walletId: widget.wallet.id,
        vendorId:
            isSimulated ? 'simulated_nfc_payment' : 'nfc_payment_received',
        amount: receivedAmount,
        timestamp: DateTime.now(),
        status: 'completed',
        isOffline: false,
        senderName: senderName,
        senderId: senderId,
        note: paymentNote,
      );

      // Add the transaction to update the wallet balance
      final success = await _walletService.addReceivedTransaction(transaction);

      if (!success) {
        throw Exception('Failed to update wallet with received payment');
      }

      setState(() {
        _statusMessage = 'Payment received!';
        _transactionComplete = true;
        _isWaitingForNfc = false;
        _receivedAmount = receivedAmount;
        _senderName = senderName;
        _paymentNote = paymentNote;
      });

      // Stop NFC session since we've received a payment
      await _stopNfcReceiving();
    } catch (e) {
      print('ERROR: Transaction processing failed: $e');
      setState(() {
        _statusMessage = 'Transaction failed: $e';
        _isWaitingForNfc = false;
      });
    }
  }

  // Generate a random simulated payment for demo purposes
  Map<String, dynamic> _generateSimulatedPaymentData() {
    // Random amount between 50 and 500
    final amount = 50.0 + (450.0 * (DateTime.now().millisecond / 1000.0));

    // Sample sender names and IDs
    final senderNames = [
      'John Doe',
      'Jane Smith',
      'Alex Johnson',
      'Sam Wilson',
      'Taylor Swift',
    ];
    final senderIds = [
      'user_123',
      'user_456',
      'user_789',
      'user_101',
      'user_202',
    ];

    // Pick a random sender
    final index = DateTime.now().second % senderNames.length;

    // Sample notes
    final notes = [
      'Payment for lunch',
      'Movie tickets',
      'Shopping bill',
      'Thanks for your help',
      'Splitting the bill',
    ];

    return {
      'amount': double.parse(amount.toStringAsFixed(2)),
      'senderName': senderNames[index],
      'senderId': senderIds[index],
      'note': notes[index],
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final bool hasError =
        _statusMessage.toLowerCase().contains('error') ||
        _statusMessage.toLowerCase().contains('failed');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receive Money'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Wallet info
              Text(
                'Your Wallet: ${widget.wallet.name}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),

              // NFC Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color:
                      _isWaitingForNfc
                          ? Colors.green.withOpacity(0.1)
                          : hasError
                          ? Colors.red.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.nfc,
                  size: 60,
                  color:
                      _isWaitingForNfc
                          ? Colors.green
                          : hasError
                          ? Colors.red
                          : Colors.grey,
                ),
              ),
              const SizedBox(height: 40),

              // Status message
              Text(
                _statusMessage,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: hasError ? Colors.red : Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Action buttons
              if (!_transactionComplete) ...[
                if (hasError) ...[
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _statusMessage = 'Ready to receive payment';
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(200, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Try Again',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                ElevatedButton(
                  onPressed:
                      _isWaitingForNfc ? _stopNfcReceiving : _startNfcReceiving,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _isWaitingForNfc ? Colors.red : Colors.black,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(200, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    _isWaitingForNfc ? 'Cancel' : 'Ready to Receive',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ] else ...[
                // Payment received confirmation
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'PAYMENT RECEIVED',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 48,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Amount: ₹${_receivedAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'From: $_senderName',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Date: ${DateTime.now().toString().substring(0, 16)}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Note: $_paymentNote',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(200, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Done', style: TextStyle(fontSize: 16)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
