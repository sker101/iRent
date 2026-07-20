import 'package:flutter/material.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  String _selectedRole = 'tenant';

  @override
  Widget build(BuildContext context) {
    final roles = <String, String>{
      'tenant': 'Tenant',
      'dalali': 'Dalali',
      'landlord': 'Landlord',
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Create your iRent account')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Choose how you want to use iRent and continue to the next step.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                children: roles.entries.map((entry) {
                  final isSelected = entry.key == _selectedRole;
                  return ChoiceChip(
                    label: Text(entry.value),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() {
                        _selectedRole = entry.key;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Welcome, ${roles[_selectedRole]}! Your account flow is ready.',
                      ),
                    ),
                  );
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.verified_user_outlined),
                label: const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
