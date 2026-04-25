import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/database_helper.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/table_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/waiter_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/customer_provider.dart';
import '../../models/waiter.dart';
import '../main_layout/main_layout.dart';
import '../../features/settings/connection_settings_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String _enteredPin = '';

  // Waiter login flow
  bool _isWaiterMode = false;
  Waiter? _selectedWaiter;

  void _handlePinPress(String value) {
    if (value == '⌫') {
      if (_enteredPin.isNotEmpty) {
        setState(
          () => _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1),
        );
      }
    } else if (value == 'C') {
      setState(() => _enteredPin = '');
    } else {
      if (_enteredPin.length < 4) {
        setState(() => _enteredPin += value);
        if (_enteredPin.length == 4) {
          _verifyPin();
        }
      }
    }
  }

  void _verifyPin() async {
    final connectivity = context.read<ConnectivityProvider>();

    // Waiter PIN verification
    if (_isWaiterMode && _selectedWaiter != null) {
      final waiter = _selectedWaiter!;
      if (waiter.pinCode == null || waiter.pinCode!.isEmpty) {
        // No PIN required — log in directly
        _loginAsWaiter(waiter);
        return;
      }
      if (_enteredPin == waiter.pinCode) {
        _loginAsWaiter(waiter);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PIN kod noto\'g\'ri!'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _enteredPin = '');
        }
      }
      return;
    }

    if (connectivity.mode == ConnectivityMode.client) {
      final success = await connectivity.login(_enteredPin);
      if (success) {
        if (mounted) {
          _loadAllDataAndNavigate(connectivity);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PIN xato yoki serverga ulanib bo\'lmadi!'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _enteredPin = '');
        }
      }
    } else {
      // Local or Server mode
      final db = DatabaseHelper.instance;
      final userResults = await db.queryByColumn('users', 'pin', _enteredPin);

      if (userResults.isNotEmpty) {
        final user = userResults.first;
        if (user['is_active'] == 1) {
          connectivity.setCurrentUser(user);
          if (mounted) {
            _loadAllDataAndNavigate(connectivity);
          }
          return;
        }
      }

      // Fallback for settings login pin (admin)
      final settings = context.read<AppSettingsProvider>();
      if (_enteredPin == settings.loginPin) {
        connectivity.setCurrentUser({'name': 'Admin', 'role': 'admin'});
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const MainLayout()),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Noto\'g\'ri PIN kod!'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _enteredPin = '');
        }
      }
    }
  }

  void _loginAsWaiter(Waiter waiter) {
    final connectivity = context.read<ConnectivityProvider>();
    connectivity.setCurrentUser({
      'id': waiter.id,
      'name': waiter.name,
      'role': 'waiter',
      'permissions': waiter.permissions.join(','),
      'is_active': waiter.isActive,
    });
    if (mounted) {
      _loadAllDataAndNavigate(connectivity);
    }
  }

  void _loadAllDataAndNavigate(
    ConnectivityProvider connectivity, {
    bool? forceRemote,
  }) {
    final fr =
        forceRemote ?? (connectivity.mode == ConnectivityMode.client);
    context.read<ProductProvider>().loadProducts(
      connectivity: connectivity,
      forceRemote: fr,
    );
    context.read<CategoryProvider>().loadCategories(
      connectivity: connectivity,
      forceRemote: fr,
    );
    context.read<TableProvider>().loadTables(
      connectivity: connectivity,
      forceRemote: fr,
    );
    context.read<LocationProvider>().loadLocations(
      connectivity: connectivity,
      forceRemote: fr,
    );
    context.read<WaiterProvider>().loadWaiters(
      connectivity: connectivity,
      forceRemote: fr,
    );
    context.read<UserProvider>().loadUsers(
      connectivity: connectivity,
      forceRemote: fr,
    );
    context.read<ExpenseProvider>().loadCategories(
      connectivity: connectivity,
      forceRemote: fr,
    );
    context.read<ExpenseProvider>().loadExpenses(
      connectivity: connectivity,
      forceRemote: fr,
    );
    context.read<CustomerProvider>().loadCustomers(
      connectivity: connectivity,
      forceRemote: fr,
    );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const MainLayout()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Row(
        children: [
          // Left: PIN pad or Waiter selection
          Expanded(
            flex: 5,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _isWaiterMode && _selectedWaiter == null
                  ? _buildWaiterGrid(theme)
                  : _buildPinPad(theme),
            ),
          ),

          // Right: Brand Image
          Expanded(
            flex: 6,
            child: Container(
              margin: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                color: const Color(0xFF0F172A),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 40,
                    offset: const Offset(10, 10),
                  ),
                ],
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: settings.brandImagePath != null
                        ? Image.file(
                            File(settings.brandImagePath!),
                            fit: BoxFit.cover,
                          )
                        : Image.asset(
                            'assets/images/login_default.png',
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                Container(color: const Color(0xFF1E293B)),
                          ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.1),
                          Colors.black.withValues(alpha: 0.6),
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.all(60),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          settings.restaurantName.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          child: const Text(
                            'Smart POS & Business Automation',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Waiter grid ────────────────────────────────────────────────────────────
  Widget _buildWaiterGrid(ThemeData theme) {
    final waiterProvider = context.watch<WaiterProvider>();
    final waiters = waiterProvider.waiters
        .where((w) => w.name != 'Kassa' && w.isActive == 1)
        .toList();

    return Container(
      key: const ValueKey('waiter_grid'),
      color: theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(32, 40, 32, 24),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => setState(() => _isWaiterMode = false),
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    color: theme.colorScheme.onSurface,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor:
                        theme.colorScheme.onSurface.withValues(alpha: 0.06),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ofitsiantlar',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: theme.colorScheme.onSurface,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'Ismingizni tanlang',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Grid
          Expanded(
            child: waiterProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : waiters.isEmpty
                ? _buildNoWaiters(theme)
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 8,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.88,
                        ),
                    itemCount: waiters.length,
                    itemBuilder: (context, index) {
                      return _buildWaiterCard(theme, waiters[index]);
                    },
                  ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildWaiterCard(ThemeData theme, Waiter waiter) {
    // Generate avatar color from name hash
    final colors = [
      const Color(0xFF6366F1),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
      const Color(0xFF3B82F6),
      const Color(0xFF8B5CF6),
      const Color(0xFF14B8A6),
      const Color(0xFFF97316),
    ];
    final color = colors[waiter.name.hashCode.abs() % colors.length];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedWaiter = waiter;
            _enteredPin = '';
          });
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.brightness == Brightness.light
                  ? const Color(0xFFE2E8F0)
                  : theme.colorScheme.onSurface.withValues(alpha: 0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Avatar
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    waiter.name.isNotEmpty
                        ? waiter.name[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Name
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  waiter.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                    letterSpacing: -0.2,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 6),

              // PIN badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: waiter.pinCode != null && waiter.pinCode!.isNotEmpty
                      ? const Color(0xFFF1F5F9)
                      : const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      waiter.pinCode != null && waiter.pinCode!.isNotEmpty
                          ? Icons.lock_outline_rounded
                          : Icons.lock_open_rounded,
                      size: 11,
                      color:
                          waiter.pinCode != null && waiter.pinCode!.isNotEmpty
                          ? const Color(0xFF64748B)
                          : const Color(0xFF10B981),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      waiter.pinCode != null && waiter.pinCode!.isNotEmpty
                          ? 'PIN bilan'
                          : 'PINsiz',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: waiter.pinCode != null &&
                                waiter.pinCode!.isNotEmpty
                            ? const Color(0xFF64748B)
                            : const Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoWaiters(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline_rounded,
            size: 64,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
          ),
          const SizedBox(height: 16),
          Text(
            'Ofitsiantlar topilmadi',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ─── PIN pad ─────────────────────────────────────────────────────────────────
  Widget _buildPinPad(ThemeData theme) {
    return Container(
      key: const ValueKey('pin_pad'),
      color: theme.scaffoldBackgroundColor,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 8),

              // Waiter avatar (if selected)
              if (_isWaiterMode && _selectedWaiter != null) ...[
                _buildSelectedWaiterHeader(theme),
                const SizedBox(height: 32),
              ] else ...[
                Consumer<ConnectivityProvider>(
                  builder: (context, connectivity, _) {
                    final isClient =
                        connectivity.mode == ConnectivityMode.client;
                    return Column(
                      children: [
                        Text(
                          isClient ? 'Ofitsiant Tizimi' : 'Xush kelibsiz',
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w900,
                            color: theme.colorScheme.onSurface,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (connectivity.lastError != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              connectivity.lastError!,
                              style: const TextStyle(
                                color: Color(0xFFEF4444),
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  'Tizimga kirish uchun shaxsiy PIN kodni kiriting',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // PIN Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  4,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _enteredPin.length > index
                          ? (_isWaiterMode
                              ? const Color(0xFF10B981)
                              : theme.colorScheme.primary)
                          : theme.colorScheme.onSurface.withValues(alpha: 0.1),
                      boxShadow: _enteredPin.length > index
                          ? [
                              BoxShadow(
                                color: (_isWaiterMode
                                        ? const Color(0xFF10B981)
                                        : theme.colorScheme.primary)
                                    .withValues(alpha: 0.3),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ]
                          : [],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 48),

              // Numpad
              SizedBox(
                width: 320,
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 3,
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 20,
                  childAspectRatio: 1.1,
                  children: [
                    ...['1', '2', '3', '4', '5', '6', '7', '8', '9']
                        .map((n) => _buildPinButton(context, n)),
                    _buildPinButton(
                      context,
                      'C',
                      color: const Color(0xFFF1F5F9),
                      textColor: const Color(0xFF64748B),
                    ),
                    _buildPinButton(context, '0'),
                    _buildPinButton(
                      context,
                      '⌫',
                      color: const Color(0xFFFEF2F2),
                      textColor: const Color(0xFFEF4444),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Waiter mode: back button | Normal mode: waiter login + settings
              if (_isWaiterMode && _selectedWaiter != null)
                TextButton.icon(
                  onPressed: () =>
                      setState(() {
                        _selectedWaiter = null;
                        _enteredPin = '';
                      }),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Boshqa ofitsiant tanlash'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                )
              else
                Column(
                  children: [
                    // Waiter login button
                    OutlinedButton.icon(
                      onPressed: () {
                        context.read<WaiterProvider>().loadWaiters(
                          connectivity: context.read<ConnectivityProvider>(),
                        );
                        setState(() {
                          _isWaiterMode = true;
                          _selectedWaiter = null;
                          _enteredPin = '';
                        });
                      },
                      icon: const Icon(
                        Icons.people_alt_outlined,
                        size: 18,
                      ),
                      label: const Text('Ofitsiant sifatida kirish'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF10B981),
                        side: const BorderSide(color: Color(0xFF10B981)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const ConnectionSettingsScreen(),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.settings_input_component_rounded,
                        size: 18,
                      ),
                      label: const Text('Ulanish sozlamalari'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedWaiterHeader(ThemeData theme) {
    final waiter = _selectedWaiter!;
    final colors = [
      const Color(0xFF6366F1),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
      const Color(0xFF3B82F6),
      const Color(0xFF8B5CF6),
      const Color(0xFF14B8A6),
      const Color(0xFFF97316),
    ];
    final color = colors[waiter.name.hashCode.abs() % colors.length];

    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.4), width: 3),
          ),
          child: Center(
            child: Text(
              waiter.name.isNotEmpty ? waiter.name[0].toUpperCase() : '?',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          waiter.name,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: theme.colorScheme.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'PIN kodni kiriting',
          style: TextStyle(
            fontSize: 14,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildPinButton(
    BuildContext context,
    String text, {
    Color? color,
    Color? textColor,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color:
          color ?? (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: () => _handlePinPress(text),
        borderRadius: BorderRadius.circular(24),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: textColor ?? theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
