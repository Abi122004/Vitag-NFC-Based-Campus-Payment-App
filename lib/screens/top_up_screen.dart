import 'package:flutter/material.dart';
import 'package:vitag_app/services/wallet_service.dart';
import 'package:vitag_app/models/wallet.dart';
import 'package:vitag_app/screens/top_up_success_screen.dart';
import 'package:vitag_app/services/notification_service.dart';

class TopUpScreen extends StatefulWidget {
  const TopUpScreen({super.key});

  @override
  State<TopUpScreen> createState() => _TopUpScreenState();
}

class _TopUpScreenState extends State<TopUpScreen> {
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

  Future<void> _processTopUp() async {
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
      // Get current wallet for the userId
      final wallet = await _walletService.getCachedWallet();

      if (wallet == null) {
        throw Exception('Wallet not found');
      }

      // Use the new Firebase top-up method
      final success = await _walletService.addTopUp(
        double.parse(_amount),
        wallet.userId,
      );

      if (!success) {
        throw Exception('Failed to process top-up');
      }

      // Add notification for top-up
      await _notificationService.addTransactionNotification(
        title: 'Top-up Successful',
        message: 'Your wallet has been topped up with ₹$_amount',
      );

      if (mounted) {
        // Navigate to success screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => TopUpSuccessScreen(amount: _amount),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to process top-up: $e')));
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('VITAG'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          // Title
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.0),
            child: Align(
              alignment: Alignment.center,
              child: Text(
                'Enter the amount',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Amount display
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 10.0,
            ),
            child: Text(
              formattedAmount,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 16),

          // Keypad
          Expanded(
            child: Column(
              children: [
                _buildKeypadRow(['1', '2', '3']),
                _buildKeypadRow(['4', '5', '6']),
                _buildKeypadRow(['7', '8', '9']),
                _buildKeypadRow(['.', '0', 'backspace']),
              ],
            ),
          ),

          // Top-up button
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _processTopUp,
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
                          'TOP-UP',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
              ),
            ),
          ),

          // Bottom navigation
          Container(
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, -1),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.home_outlined),
                  onPressed: () {
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.grid_view_outlined),
                  onPressed: () {},
                ),
                IconButton(icon: const Icon(Icons.nfc), onPressed: () {}),
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(Icons.person_outline),
                  onPressed: () {},
                ),
              ],
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
