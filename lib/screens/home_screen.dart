import 'package:flutter/material.dart';
import 'package:vitag_app/screens/top_up_screen.dart';
import 'package:vitag_app/screens/all_transactions_screen.dart';
import 'package:vitag_app/screens/profile_screen.dart';
import 'package:vitag_app/screens/payment_amount_screen.dart';
import 'package:vitag_app/screens/receive_money_screen.dart';
import 'package:vitag_app/services/wallet_service.dart';
import 'package:vitag_app/services/notification_service.dart';
import 'package:vitag_app/models/wallet.dart';
import 'package:vitag_app/services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final WalletService _walletService = WalletService();
  final NotificationService _notificationService = NotificationService();
  final AuthService _authService = AuthService();
  Wallet? _wallet;
  bool _isLoading = true;
  List<Transaction> _recentTransactions = [];
  int _notificationCount = 0;

  @override
  void initState() {
    super.initState();
    _loadWalletData();
    _loadNotificationCount();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh data when screen becomes visible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadWalletData();
      _loadNotificationCount();
    });
  }

  Future<void> _loadNotificationCount() async {
    try {
      final notifications = await _notificationService.getNotifications();
      setState(() {
        _notificationCount = notifications.length;
      });
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _loadWalletData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Try to get cached wallet
      Wallet? wallet = await _walletService.getCachedWallet();

      // If no wallet exists and user is logged in, create one
      if (wallet == null) {
        try {
          // Get user information from our custom auth service
          String userId = "default_user";
          String userName = "Default User";

          try {
            final user = _authService.currentUser;
            if (user.isValid) {
              userId = user.uid;
              userName = user.displayName ?? user.email ?? 'User';
            }
          } catch (authError) {
            print("Error getting currentUser: $authError");
            // Continue with default values if there's an error
          }

          // Create wallet with the extracted data
          wallet = await _walletService.ensureWalletExists(userId, userName);
        } catch (e) {
          print('Error creating wallet: $e');
          // Create a fallback wallet
          wallet = Wallet(
            id: 'fallback_wallet_${DateTime.now().millisecondsSinceEpoch}',
            userId: 'fallback_user',
            balance: 0.0,
            transactions: [],
            name: 'Fallback Wallet',
          );
          await _walletService.cacheWallet(wallet);
        }
      }

      // Get recent transactions
      List<Transaction> transactions = [];
      try {
        transactions = await _walletService.getRecentTransactions(5);
      } catch (e) {
        print('Error loading transactions: $e');
      }

      if (mounted) {
        setState(() {
          _wallet = wallet;
          _recentTransactions = transactions;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error in _loadWalletData: $e');
      if (mounted) {
        setState(() {
          _wallet = Wallet(
            id: 'error_wallet_${DateTime.now().millisecondsSinceEpoch}',
            userId: 'error_user',
            balance: 0.0,
            transactions: [],
            name: 'Error Wallet',
          );
          _recentTransactions = [];
          _isLoading = false;
        });
      }
    }
  }

  String _formatCurrency(double amount) {
    // Format currency with commas for thousands
    final formattedAmount = amount.toStringAsFixed(2);
    return '₹$formattedAmount';
  }

  void _showNotifications() async {
    // Show loading dialog first
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => const AlertDialog(
            title: Text('Loading Notifications'),
            content: SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
    );

    // Fetch notifications
    final notifications = await _notificationService.getNotifications();

    // Close loading dialog
    if (mounted) {
      Navigator.of(context).pop();
    }

    // Show notifications dialog
    if (mounted) {
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Notifications'),
              content: SizedBox(
                height: 300,
                width: double.maxFinite,
                child:
                    notifications.isEmpty
                        ? const Center(
                          child: Text(
                            'No notifications yet',
                            style: TextStyle(color: Colors.black54),
                          ),
                        )
                        : ListView.builder(
                          itemCount: notifications.length,
                          itemBuilder: (context, index) {
                            final notification = notifications[index];
                            return _buildNotificationItem(
                              notification.title,
                              notification.message,
                              notification.timestamp,
                            );
                          },
                        ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    // Refresh notification count
                    _loadNotificationCount();
                  },
                  child: const Text('Close'),
                ),
                if (notifications.isNotEmpty)
                  TextButton(
                    onPressed: () async {
                      await _notificationService.clearNotifications();
                      if (mounted) {
                        Navigator.of(context).pop();
                        // Refresh notification count
                        setState(() {
                          _notificationCount = 0;
                        });
                      }
                    },
                    child: const Text(
                      'Clear All',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
      );
    }
  }

  Widget _buildNotificationItem(
    String title,
    String message,
    DateTime timestamp,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                _formatTimeAgo(timestamp),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(message, style: const TextStyle(fontSize: 14)),
          const Divider(),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('VITAG'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none),
                onPressed: _showNotifications,
              ),
              if (_notificationCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      _notificationCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  ),
                ).then((_) {
                  // Refresh when returning from profile
                  _loadWalletData();
                  _loadNotificationCount();
                }),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to payment amount screen first
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const PaymentAmountScreen(),
            ),
          ).then((_) => _loadWalletData());
        },
        backgroundColor: Colors.black,
        child: const Icon(Icons.nfc, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Main content in a card
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child:
                      _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // VITAG title and top-up button
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Hi${_wallet?.name != null ? ", ${_formatName(_wallet!.name)}" : ""}',
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Greeting and balance
                                const Text(
                                  'Your available balance',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _wallet != null
                                          ? _formatCurrency(_wallet!.balance)
                                          : '₹0.00',
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () async {
                                        // Navigate to top-up screen
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (context) =>
                                                    const TopUpScreen(),
                                          ),
                                        );
                                        // Refresh wallet data when returning from top-up
                                        _loadWalletData();
                                      },
                                      icon: const Icon(
                                        Icons.account_balance_wallet,
                                        size: 16,
                                      ),
                                      label: const Text('Top-up'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.black,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),

                                // Tap to pay button
                                SizedBox(
                                  width: double.infinity,
                                  height: 56,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      // Navigate to payment amount screen first
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) =>
                                                  const PaymentAmountScreen(),
                                        ),
                                      ).then((_) => _loadWalletData());
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.black,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.nfc, size: 20),
                                        SizedBox(width: 8),
                                        Text(
                                          'Tap to Pay',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Send Money button
                                SizedBox(
                                  width: double.infinity,
                                  height: 56,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      // Navigate to NFC receive money screen
                                      if (_wallet != null) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (context) => ReceiveMoneyScreen(
                                                  wallet: _wallet!,
                                                ),
                                          ),
                                        ).then((_) => _loadWalletData());
                                      } else {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Unable to load wallet data',
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.black,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        side: const BorderSide(
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.nfc, size: 20),
                                        SizedBox(width: 8),
                                        Text(
                                          'Receive Money',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // Recent transactions header
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Recent Transaction',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        // Navigate to all transactions screen
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (context) =>
                                                    const AllTransactionsScreen(),
                                          ),
                                        ).then((_) => _loadWalletData());
                                      },
                                      child: const Text(
                                        'See All',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Transaction list
                                if (_recentTransactions.isEmpty)
                                  const Center(
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 16.0,
                                      ),
                                      child: Text(
                                        'No transactions yet',
                                        style: TextStyle(
                                          color: Colors.black54,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  Expanded(
                                    child: ListView.separated(
                                      itemCount: _recentTransactions.length,
                                      separatorBuilder:
                                          (context, index) =>
                                              const SizedBox(height: 8),
                                      itemBuilder: (context, index) {
                                        final transaction =
                                            _recentTransactions[index];
                                        return _buildTransactionItem(
                                          vendor: _getVendorName(
                                            transaction.vendorId,
                                          ),
                                          date: _formatDate(
                                            transaction.timestamp,
                                          ),
                                          amount: _formatCurrency(
                                            transaction.amount,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getVendorName(String vendorId) {
    // Convert vendorId to a readable name
    if (vendorId == 'enzo_vendor') return 'Enzo';
    if (vendorId == 'shuttle_vendor') return 'Shuttle';
    if (vendorId == 'system_topup') return 'Top-up';
    if (vendorId == 'user_recipient') return 'Transfer';
    return vendorId;
  }

  String _formatDate(DateTime date) {
    // Format date to a readable string
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Today';
    }

    // Get month name
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

  Widget _buildTransactionItem({
    required String vendor,
    required String date,
    required String amount,
  }) {
    // Choose icon based on vendor
    IconData iconData = Icons.directions_car;
    if (vendor == 'Top-up') {
      iconData = Icons.account_balance_wallet;
    } else if (vendor == 'Transfer') {
      iconData = Icons.send;
    } else if (vendor == 'Shuttle') {
      iconData = Icons.directions_bus;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(iconData, color: Colors.black),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vendor,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  date,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ],
        ),
        Text(
          amount,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  String _formatName(String name) {
    // Truncate long names to 15 characters and add ellipsis
    const int maxLength = 15;
    if (name.length > maxLength) {
      return '${name.substring(0, maxLength)}...';
    }
    return name;
  }
}
