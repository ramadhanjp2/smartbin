part of 'profile_screen.dart';

class _UnlinkDialog extends ConsumerStatefulWidget {
  const _UnlinkDialog();

  @override
  ConsumerState<_UnlinkDialog> createState() => _UnlinkDialogState();
}

class _UnlinkDialogState extends ConsumerState<_UnlinkDialog> {
  final _pw = TextEditingController();
  String? _error;
  bool _busy = false;

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).unlinkCard(_pw.text);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _busy = false;
        _error = errorText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.link_off),
      title: const Text('Lepas tautan KTP?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Setoran dengan KTP lama tidak lagi masuk ke akun ini. Saldo poin Anda tidak berubah.'),
          const SizedBox(height: 16),
          TextField(
            controller: _pw,
            obscureText: true,
            decoration: InputDecoration(hintText: 'Kata sandi akun', prefixIcon: const Icon(Icons.lock_outline), errorText: _error),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: const Text('Batal')),
        TextButton(
          onPressed: _busy ? null : _submit,
          child: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Lepas KTP'),
        ),
      ],
    );
  }
}

class _ChangePasswordDialog extends ConsumerStatefulWidget {
  const _ChangePasswordDialog();

  @override
  ConsumerState<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  final _old = TextEditingController();
  final _new = TextEditingController();
  String? _oldError, _newError;
  bool _busy = false;

  Future<void> _submit() async {
    final pw = _new.text;
    final valid = pw.length >= 8 && RegExp('[A-Za-z]').hasMatch(pw) && RegExp('[0-9]').hasMatch(pw);
    setState(() {
      _oldError = null;
      _newError = valid ? null : 'Min. 8 karakter berisi huruf dan angka';
    });
    if (!valid) return;
    setState(() => _busy = true);
    try {
      await ref.read(repositoryProvider).changePassword(oldPassword: _old.text, newPassword: pw);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _busy = false;
        _oldError = errorText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ganti Kata Sandi'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _old,
            obscureText: true,
            decoration: InputDecoration(hintText: 'Kata sandi lama', errorText: _oldError),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _new,
            obscureText: true,
            decoration: InputDecoration(hintText: 'Kata sandi baru', errorText: _newError),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: const Text('Batal')),
        TextButton(onPressed: _busy ? null : _submit, child: const Text('Simpan')),
      ],
    );
  }
}
