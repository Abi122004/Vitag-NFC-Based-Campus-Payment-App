import 'package:flutter/material.dart';
import 'package:vitag_app/services/nfc_service.dart';
import 'package:vitag_app/services/wallet_service.dart';
import 'package:vitag_app/models/wallet.dart';
import 'dart:convert';

class TapToPayScreen extends StatefulWidget {
  final double paymentAmount;

  const TapToPayScreen({super.key, required this.paymentAmount});

  @override
  State<TapToPayScreen> createState() => _TapToPayScreenState();
}

class _TapToPayScreenState extends State<TapToPayScreen> {
  final NfcService _nfcService = NfcService();
  final WalletService _walletService = WalletService();
  bool _isScanning = false;
  String _statusMessage = 'Ready to scan';
  bool _transactionComplete = false;

  @override
  void initState() {
    super.initState();
    _checkNfcAvailability();
  }

  @override
  void dispose() {
    _stopNfcScan();
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

  Future<void> _startNfcScan() async {
    setState(() {
      _isScanning = true;
      _statusMessage = 'Scanning for NFC tag...';
      _transactionComplete = false;
    });

    await _nfcService.startNfcSession(
      onTagRead: (payload) {
        _processTransaction(payload);
      },
      onError: (error) {
        setState(() {
          _isScanning = false;
          _statusMessage = 'Error: $error';
        });
      },
    );
  }

  Future<void> _stopNfcScan() async {
    if (_isScanning) {
      await _nfcService.stopNfcSession();
      setState(() {
        _isScanning = false;
      });
    }
  }

  Future<void> _processTransaction(String vendorData) async {
    setState(() {
      _statusMessage = 'Processing transaction...';
    });

    try {
      // Get current wallet
      final wallet = await _walletService.getCachedWallet();

      if (wallet == null) {
        throw Exception('Wallet not found');
      }

      // Check if wallet has sufficient balance
      if (wallet.balance < widget.paymentAmount) {
        throw Exception('Insufficient balance');
      }

      // Create the transaction metadata with sender details
      final Map<String, dynamic> transactionMetadata = {
        'amount': widget.paymentAmount,
        'senderName': wallet.name,
        'senderId': wallet.userId,
        'senderWalletId': wallet.id,
        'timestamp': DateTime.now().toIso8601String(),
        'note': 'Payment using NFC',
      };

      // Encode metadata to JSON for NFC transmission
      final String encodedData = jsonEncode(transactionMetadata);

      // In a real app, you would transmit this data to the vendor's NFC reader
      print('DEBUG: NFC payload for vendor: $encodedData');

      // Create our transaction record
      final transaction = Transaction(
        id: 'nfc_${DateTime.now().millisecondsSinceEpoch}',
        walletId: wallet.id,
        vendorId: vendorData,
        amount: widget.paymentAmount,
        timestamp: DateTime.now(),
        status: 'completed',
        isOffline: false,
        senderName: wallet.name,
        senderId: wallet.userId,
        note: 'Payment using NFC',
      );

      // Use Firebase transaction method to record the payment
      await _walletService.addTransaction(transaction);

      setState(() {
        _statusMessage =
            'Transaction complete!\nVendor device will show "${wallet.name} sent ₹${widget.paymentAmount.toStringAsFixed(2)}"';
        _transactionComplete = true;
        _isScanning = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Transaction failed: $e';
        _isScanning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tap to Pay'),
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
              // Payment amount
              Text(
                'Payment Amount: ₹${widget.paymentAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 20,
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
                      _isScanning
                          ? Colors.blue.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.nfc,
                  size: 60,
                  color: _isScanning ? Colors.blue : Colors.grey,
                ),
              ),
              const SizedBox(height: 40),

              // Status message
              Text(
                _statusMessage,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Action buttons
              if (!_transactionComplete) ...[
                ElevatedButton(
                  onPressed: _isScanning ? _stopNfcScan : _startNfcScan,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isScanning ? Colors.red : Colors.black,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(200, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    _isScanning ? 'Cancel' : 'Start Scanning',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ] else ...[
                // Simulated vendor receipt
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
                        'VENDOR RECEIPT',
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
                        'Payment Received',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      FutureBuilder<Wallet?>(
                        future: _walletService.getCachedWallet(),
                        builder: (context, snapshot) {
                          final walletName = snapshot.data?.name ?? 'Customer';
                          return Text(
                            'From: $walletName',
                            style: const TextStyle(fontSize: 16),
                          );
                        },
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Amount: ₹${widget.paymentAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Date: ${DateTime.now().toString().substring(0, 16)}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Transaction ID: NFC-PAYMENT',
                        style: TextStyle(fontSize: 14),
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
