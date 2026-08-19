import 'package:superapp_user/design_system/components/layout/app_refresh_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:superapp_user/core/utils/haptics.dart';
import 'package:superapp_user/shared/wallet/data/wallet_model.dart';
import 'package:superapp_user/design_system/tokens/app_colors.dart';
import 'package:superapp_user/design_system/components/feedback/app_snackbar.dart';
import 'package:superapp_user/shared/wallet/presentation/viewmodels/wallet_state.dart';
import 'package:superapp_user/shared/wallet/presentation/viewmodels/wallet_viewmodel.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  final TextEditingController _customAmountController = TextEditingController();

  @override
  void dispose() {
    _customAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final walletState = ref.watch(walletViewModelProvider);
    final viewModel = ref.read(walletViewModelProvider.notifier);

    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final backgroundColor = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
          onPressed: () {
            Haptics.light();
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/profile');
            }
          },
        ),
        title: Text(
          'K9 Wallet',
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: AppColors.primary, size: 22),
            tooltip: 'Refresh Wallet',
            onPressed: () {
              Haptics.light();
              viewModel.loadWallet();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: AppRefreshIndicator(
          onRefresh: () async => viewModel.loadWallet(isRefresh: true),
          child: _buildBody(
            context,
            walletState,
            viewModel,
            isDark,
            textColor,
            secondaryColor,
            cardColor,
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WalletState state,
    WalletViewModel viewModel,
    bool isDark,
    Color textColor,
    Color secondaryColor,
    Color cardColor,
  ) {
    if (state.status == WalletStatus.loading) {
      return _buildLoadingState(isDark);
    }

    if (state.status == WalletStatus.error) {
      return _buildErrorState(state.errorMessage ?? 'Something went wrong', viewModel, textColor, secondaryColor);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // 1. Current Wallet Balance Card
        _buildBalanceCard(context, state.wallet.balance, state.wallet.referralEarnings, isDark, viewModel),

        if (state.cashbackSettings?.isEnabled == true) ...[
          const SizedBox(height: 14),
          _buildCashbackBanner(state.cashbackSettings!, isDark),
        ],

        const SizedBox(height: 20),

        // 2. Wallet Usage & Benefit Cards
        _buildWalletBenefitsSection(isDark, cardColor, textColor, secondaryColor),

        const SizedBox(height: 24),

        // 3. Transaction History Header & Filter Tabs
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Transaction History',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            Text(
              '${state.filteredTransactions.length} Items',
              style: TextStyle(fontSize: 12.5, color: secondaryColor, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildFilterTabs(state.selectedTab, viewModel, isDark),

        if (state.selectedTab == WalletFilterTab.creditsAndCashback && state.totalCashbackEarned > 0) ...[
          const SizedBox(height: 10),
          _buildTotalStat('Total cashback earned', state.totalCashbackEarned, isDark, secondaryColor),
        ] else if (state.selectedTab == WalletFilterTab.refunds && state.totalRefunded > 0) ...[
          const SizedBox(height: 10),
          _buildTotalStat('Total refunded', state.totalRefunded, isDark, secondaryColor),
        ],

        const SizedBox(height: 16),

        // 4. Transaction List or Empty State
        if (state.filteredTransactions.isEmpty)
          _buildEmptyState(state.selectedTab, cardColor, isDark, textColor, secondaryColor)
        else
          ...state.filteredTransactions.map(
            (txn) => _buildTransactionCard(txn, isDark, cardColor, textColor, secondaryColor),
          ),
      ],
    );
  }

  /// 1. Main Wallet Balance Card
  Widget _buildBalanceCard(
    BuildContext context,
    double balance,
    double cashback,
    bool isDark,
    WalletViewModel viewModel,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF7A00), Color(0xFFFF9D3B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF7A00).withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Available Balance',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified_user_rounded, color: Colors.white, size: 13),
                    SizedBox(width: 4),
                    Text(
                      'K9 Pay',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '₹${balance.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.stars_rounded, color: Colors.white.withValues(alpha: 0.9), size: 15),
              const SizedBox(width: 6),
              Text(
                'Includes ₹${cashback.toStringAsFixed(2)} Cashback Rewards',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFFFF7A00),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {
                Haptics.light();
                _showAddMoneySheet(context, viewModel, isDark);
              },
              icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
              label: const Text(
                'ADD MONEY TO WALLET',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Cashback offer banner — built entirely from
  /// `GET /food/admin/cashback-settings/public`; hidden by the caller when
  /// disabled, and never showing a guessed percentage/cap.
  Widget _buildCashbackBanner(CashbackSettings settings, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: isDark ? 0.16 : 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.card_giftcard_rounded, color: AppColors.success, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              settings.bannerText,
              style: const TextStyle(color: AppColors.success, fontSize: 12.5, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  /// Small real total shown above the active tab's list — sourced from the
  /// dedicated cashback/refund endpoints rather than re-derived client-side.
  Widget _buildTotalStat(String label, double amount, bool isDark, Color secondaryColor) {
    return Row(
      children: [
        Icon(Icons.summarize_outlined, size: 14, color: secondaryColor),
        const SizedBox(width: 6),
        Text(
          '$label: ₹${amount.toStringAsFixed(2)}',
          style: TextStyle(fontSize: 12.5, color: secondaryColor, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  /// 2. Wallet Usage & Benefits Grid/Row
  Widget _buildWalletBenefitsSection(
    bool isDark,
    Color cardColor,
    Color textColor,
    Color secondaryColor,
  ) {
    final benefits = [
      {'icon': Icons.bolt_rounded, 'title': 'Instant Refunds', 'desc': 'Direct to wallet'},
      {'icon': Icons.flash_on_rounded, 'title': '1-Click Pay', 'desc': 'Zero payment failures'},
      {'icon': Icons.security_rounded, 'title': '100% Safe', 'desc': 'Razorpay protected'},
      {'icon': Icons.card_giftcard_rounded, 'title': 'No Expiry', 'desc': 'Cashback rewards'},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark
            ? []
            : [
                const BoxShadow(
                  color: AppColors.shadow1,
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                'Why use K9 Wallet?',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: benefits.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisExtent: 64,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemBuilder: (context, index) {
              final b = benefits[index];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : AppColors.secondarySurfaceLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(b['icon'] as IconData, color: AppColors.primary, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            b['title'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                          Text(
                            b['desc'] as String,
                            style: TextStyle(fontSize: 10.5, color: secondaryColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// 3. Filter Tabs (All, Credits & Cashback, Refunds)
  Widget _buildFilterTabs(WalletFilterTab selectedTab, WalletViewModel viewModel, bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _filterChip('All History', WalletFilterTab.all, selectedTab, viewModel, isDark),
          const SizedBox(width: 8),
          _filterChip('Credits & Cashback', WalletFilterTab.creditsAndCashback, selectedTab, viewModel, isDark),
          const SizedBox(width: 8),
          _filterChip('Refund History', WalletFilterTab.refunds, selectedTab, viewModel, isDark),
        ],
      ),
    );
  }

  Widget _filterChip(
    String label,
    WalletFilterTab tab,
    WalletFilterTab currentTab,
    WalletViewModel viewModel,
    bool isDark,
  ) {
    final isSelected = tab == currentTab;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          Haptics.light();
          viewModel.setFilterTab(tab);
        }
      },
      selectedColor: AppColors.primary,
      backgroundColor: isDark ? AppColors.cardDark : AppColors.secondarySurfaceLight,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
        fontSize: 12.5,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? AppColors.primary : Colors.transparent,
        ),
      ),
      showCheckmark: false,
    );
  }

  /// 4. Transaction Item Card
  Widget _buildTransactionCard(
    WalletTransaction txn,
    bool isDark,
    Color cardColor,
    Color textColor,
    Color secondaryColor,
  ) {
    final isCredit = txn.isCredit;
    final isRefund = txn.isRefund;
    final amountColor = isCredit ? AppColors.success : textColor;

    IconData iconData;
    Color iconBg;
    Color iconColor;

    if (isRefund) {
      iconData = Icons.replay_circle_filled_rounded;
      iconBg = AppColors.primary.withValues(alpha: 0.12);
      iconColor = AppColors.primary;
    } else if (isCredit) {
      iconData = Icons.arrow_downward_rounded;
      iconBg = AppColors.success.withValues(alpha: 0.12);
      iconColor = AppColors.success;
    } else {
      iconData = Icons.arrow_upward_rounded;
      iconBg = Colors.grey.withValues(alpha: 0.15);
      iconColor = secondaryColor;
    }

    final dateFormatted = txn.date != null
        ? '${txn.date!.day} ${_monthName(txn.date!.month)}, ${_timeFormatted(txn.date!)}'
        : 'Recent';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? []
            : [
                const BoxShadow(
                  color: AppColors.shadow2,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(iconData, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  txn.description,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  dateFormatted,
                  style: TextStyle(fontSize: 11.5, color: secondaryColor),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isCredit ? "+" : "-"}₹${txn.amount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: amountColor,
                ),
              ),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  txn.status.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Empty State Widget
  Widget _buildEmptyState(
    WalletFilterTab tab,
    Color cardColor,
    bool isDark,
    Color textColor,
    Color secondaryColor,
  ) {
    String message = 'No transactions found';
    if (tab == WalletFilterTab.creditsAndCashback) {
      message = 'No credits or cashback transactions yet';
    } else if (tab == WalletFilterTab.refunds) {
      message = 'No refund history found';
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.receipt_long_outlined,
              size: 44,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your future transactions, cashback rewards & order refunds will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: secondaryColor),
          ),
        ],
      ),
    );
  }

  /// Loading State Widget
  Widget _buildLoadingState(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Container(
            height: 190,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(24),
            ),
          );
        }
        return Container(
          height: 72,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(16),
          ),
        );
      },
    );
  }

  /// Error State Widget
  Widget _buildErrorState(
    String errorMsg,
    WalletViewModel viewModel,
    Color textColor,
    Color secondaryColor,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 54),
            const SizedBox(height: 16),
            Text(
              'Unable to Load Wallet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor),
            ),
            const SizedBox(height: 8),
            Text(
              errorMsg,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: secondaryColor),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Haptics.medium();
                viewModel.loadWallet();
              },
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              label: const Text('RETRY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  /// Interactive Add Money Bottom Sheet Modal
  void _showAddMoneySheet(
    BuildContext context,
    WalletViewModel viewModel,
    bool isDark,
  ) {
    double selectedAmount = 200.0;
    _customAmountController.text = '200';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final modalTextColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
            final modalSecondaryColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.borderDark : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Add Money to K9 Wallet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: modalTextColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Top up instantly using UPI, Cards, or NetBanking',
                    style: TextStyle(fontSize: 12.5, color: modalSecondaryColor),
                  ),
                  const SizedBox(height: 20),

                  // Amount TextField
                  TextField(
                    controller: _customAmountController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: modalTextColor,
                    ),
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.currency_rupee_rounded, color: AppColors.primary, size: 24),
                      labelText: 'Enter Amount',
                      hintText: '100',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: AppColors.primary, width: 2),
                      ),
                    ),
                    onChanged: (val) {
                      final parsed = double.tryParse(val) ?? 0;
                      setModalState(() => selectedAmount = parsed);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Quick Amount Chips
                  Text(
                    'Recommended Amounts',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: modalSecondaryColor),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [100.0, 200.0, 500.0, 1000.0].map((amt) {
                      final isChipSelected = selectedAmount == amt;
                      return ActionChip(
                        label: Text('₹${amt.toInt()}'),
                        backgroundColor: isChipSelected
                            ? AppColors.primary
                            : (isDark ? AppColors.cardDark : AppColors.secondarySurfaceLight),
                        labelStyle: TextStyle(
                          color: isChipSelected ? Colors.white : modalTextColor,
                          fontWeight: isChipSelected ? FontWeight.w600 : FontWeight.w500,
                          fontSize: 13,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: isChipSelected ? AppColors.primary : Colors.transparent),
                        ),
                        onPressed: () {
                          Haptics.light();
                          setModalState(() {
                            selectedAmount = amt;
                            _customAmountController.text = amt.toInt().toString();
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: selectedAmount < 10
                          ? null
                          : () async {
                              Haptics.success();
                              Navigator.pop(modalCtx);
                              final message = await viewModel.addMoney(selectedAmount);
                              if (context.mounted) {
                                AppSnackbar.info(
                                  context,
                                  message,
                                  duration: const Duration(seconds: 3),
                                );
                              }
                            },
                      child: Text(
                        'PROCEED TO PAY ₹${selectedAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _monthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[(month - 1).clamp(0, 11)];
  }

  /// Server timestamps are UTC; convert before reading the clock fields.
  String _timeFormatted(DateTime utc) {
    final dt = utc.toLocal();
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }
}
