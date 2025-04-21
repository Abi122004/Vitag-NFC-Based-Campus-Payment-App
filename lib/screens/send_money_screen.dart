import 'package:flutter/material.dart';
import 'package:vitag_app/services/wallet_service.dart';
import 'package:vitag_app/models/wallet.dart';
import 'package:vitag_app/screens/transfer_receipt_screen.dart';
import 'package:vitag_app/services/notification_service.dart';

class SendMoneyScreen extends StatefulWidget {
  const SendMoneyScreen({super.key});

  @override
  State<SendMoneyScreen> createState() => _SendMoneyScreenState();
}

class _SendMoneyScreenState extends State<SendMoneyScreen> {
  String _amount = '0';
  bool _isProcessing = false;
  final WalletService _walletService = WalletService();
  final NotificationService _notificationService = NotificationService();

  void _updateAmount(String digit) {
    setState(() {
      if (_amount == '0' && digit != '.') {
        _amount = digit;
      } else {
        // Check if trying to add a second decimal point
        if (digit == '.' && _amount.contains('.')) {
          return;
        }
        _amount += digit;
      }
    });
  }

  void _backspace() {
    setState(() {
      if (_amount.length > 1) {
        _amount = _amount.substring(0, _amount.length - 1);
      } else {
        _amount = '0';
      }
    });
  }

  void _clear() {
    setState(() {
      _amount = '0';
    });
  }

  Future<void> _sendMoney() async {
    if (_amount == '0' || _amount == '0.00') {
      // Show error for zero amount
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Parse amount
      final amountToSend = double.parse(_amount);

      // Use the new wallet service method to send money via Firebase
      final success = await _walletService.sendMoney(
        amountToSend,
        'user_vendor', // Shortened recipient ID
        'Payment from mobile app',
      );

      if (!success) {
        throw Exception('Failed to send money');
      }

      // Add notification for money sent
      await _notificationService.addTransactionNotification(
        title: 'Money Sent',
        message: 'You have sent ₹$_amount successfully',
      );

      if (mounted) {
        // Navigate to transfer receipt screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => TransferReceiptScreen(amount: _amount),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send money: $e')));
      }
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Format amount with Indian Rupee symbol and proper decimal places
    String formattedAmount = '₹$_amount';
    if (!_amount.contains('.')) {
      formattedAmount = '₹$_amount.00';
    } else {
      // Ensure two decimal places
      final parts = _amount.split('.');
      if (parts.length > 1) {
        if (parts[1].isEmpty) {
          formattedAmount = '₹${parts[0]}.00';
        } else if (parts[1].length == 1) {
          formattedAmount = '₹${parts[0]}.${parts[1]}0';
        }
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFF9F0),
      appBar: AppBar(
        title: const Text('Send Money'),
        backgroundColor: const Color(0xFFFFF9F0),
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // Implement search functionality
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Recipient info
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 30.0,
            ),
            child: Column(
              children: [
                const Text(
                  '(Name)',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                Text(
                  'z2BC5cxx',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),

          // Amount
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 15.0),
            color: Colors.white,
            child: Center(
              child: Text(
                formattedAmount,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // Keypad
          Expanded(
            child: Container(
              color: Colors.white,
              child: Column(
                children: [
                  _buildKeypadRow(['1', '2', '3']),
                  _buildKeypadRow(['4', '5', '6']),
                  _buildKeypadRow(['7', '8', '9']),
                  _buildKeypadRow(['-', '0', 'backspace']),
                ],
              ),
            ),
          ),

          // Send button
          Container(
            width: double.infinity,
            height: 60,
            color: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 10.0,
            ),
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _sendMoney,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                disabledBackgroundColor: Colors.grey,
              ),
              child:
                  _isProcessing
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                      : const Text(
                        'Send',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeypadRow(List<String> keys) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children:
            keys.map((key) {
              if (key == 'backspace') {
                return Expanded(
                  child: InkWell(
                    onTap: _backspace,
                    child: const Center(
                      child: Icon(Icons.backspace_outlined, size: 24),
                    ),
                  ),
                );
              } else if (key == '-') {
                return const Expanded(child: SizedBox());
              } else {
                return Expanded(
                  child: InkWell(
                    onTap: () => _updateAmount(key),
                    child: Center(
                      child: Text(
                        key,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              }
            }).toList(),
      ),
    );
  }
}
