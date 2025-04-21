import 'package:flutter/material.dart';
import 'package:vitag_app/services/wallet_service.dart';
import 'package:vitag_app/models/wallet.dart';

class AllTransactionsScreen extends StatefulWidget {
  const AllTransactionsScreen({super.key});

  @override
  State<AllTransactionsScreen> createState() => _AllTransactionsScreenState();
}

class _AllTransactionsScreenState extends State<AllTransactionsScreen> {
  final WalletService _walletService = WalletService();
  List<Transaction> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final wallet = await _walletService.getCachedWallet();

      if (wallet != null) {
        setState(() {
          // Sort transactions by timestamp (newest first)
          _transactions = [...wallet.transactions]
            ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatCurrency(double amount) {
    final formattedAmount = amount.toStringAsFixed(2);
    return '₹$formattedAmount';
  }

  String _getVendorName(String vendorId) {
    if (vendorId == 'enzo_vendor') return 'Enzo';
    if (vendorId == 'shuttle_vendor') return 'Shuttle';
    if (vendorId == 'system_topup') return 'Top-up';
    if (vendorId == 'user_recipient') return 'Transfer';
    return vendorId;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Today';
    }

    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  IconData _getVendorIcon(String vendor) {
    if (vendor == 'Top-up') {
      return Icons.account_balance_wallet;
    } else if (vendor == 'Transfer') {
      return Icons.send;
    } else if (vendor == 'Shuttle') {
      return Icons.directions_bus;
    }
    return Icons.directions_car;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('All Transactions'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _transactions.isEmpty
              ? const Center(
                child: Text(
                  'No transactions found',
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
              )
              : ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: _transactions.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final transaction = _transactions[index];
                  final vendor = _getVendorName(transaction.vendorId);
                  final isPositive =
                      vendor == 'Top-up'; // Top-up is a positive transaction

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(_getVendorIcon(vendor), color: Colors.black),
                    ),
                    title: Text(
                      vendor,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      _formatDate(transaction.timestamp),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                    trailing: Text(
                      '${isPositive ? "+" : "-"}${_formatCurrency(transaction.amount)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isPositive ? Colors.green : Colors.black,
                      ),
                    ),
                  );
                },
              ),
    );
  }
}
