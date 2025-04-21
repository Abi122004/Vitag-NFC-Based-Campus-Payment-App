import 'package:flutter/material.dart';
import 'package:vitag_app/screens/send_money_screen.dart';

class TransferReceiptScreen extends StatelessWidget {
  final String amount;

  const TransferReceiptScreen({super.key, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9F0),
      appBar: AppBar(
        title: const Text('Transfer Receipt'),
        backgroundColor: const Color(0xFFFFF9F0),
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),

            // Person with flag illustration
            SizedBox(
              height: 180,
              child: Center(
                child: Image.asset(
                  'assets/images/transfer_success.png',
                  fit: BoxFit.contain,
                  // If image is not available, use a placeholder
                  errorBuilder: (context, error, stackTrace) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.flag,
                          size: 80,
                          color: Colors.black.withOpacity(0.7),
                        ),
                        const SizedBox(height: 20),
                        const Icon(
                          Icons.directions_run,
                          size: 80,
                          color: Colors.black,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Success message
            const Text(
              'Transfer Success',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your money has been successfully sent',
              style: TextStyle(fontSize: 16, color: Colors.black54),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 30),

            // Amount
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'Total Transfer',
                    style: TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '₹$amount',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Done button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  // Go back to home screen
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Transfer more money button
            TextButton(
              onPressed: () {
                // Navigate back to send money screen
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => const SendMoneyScreen(),
                  ),
                );
              },
              child: const Text(
                'Transfer more money',
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
