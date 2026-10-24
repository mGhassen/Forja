import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/sync/auth/account_vault.dart';

/// Accounts remembered on this device, most recently used first. Mirrors
/// [AccountVault.entries] so account chrome rebuilds on every vault change.
final accountVaultProvider =
    NotifierProvider<AccountVaultNotifier, List<AccountVaultEntry>>(
      AccountVaultNotifier.new,
    );

class AccountVaultNotifier extends Notifier<List<AccountVaultEntry>> {
  @override
  List<AccountVaultEntry> build() {
    final n = AccountVault.instance.entries;
    void listener() => state = n.value;
    n.addListener(listener);
    ref.onDispose(() => n.removeListener(listener));
    return n.value;
  }
}
