import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import '../theme/theme.dart';
import '../widgets/common.dart';
import '../widgets/icons.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.app});
  final AppState app;
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _userNode = FocusNode();
  final _passNode = FocusNode();
  bool _remember = true;
  bool _busy = false;
  List<String> _errors = [];
  bool _userBad = false;
  bool _passBad = false;

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    _userNode.dispose();
    _passNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final errs = <String>[];
    _userBad = _user.text.trim().isEmpty;
    _passBad = _pass.text.isEmpty;
    if (_userBad) errs.add('The Username field is required.');
    if (_passBad) errs.add('The Password field is required.');
    if (errs.isNotEmpty) {
      setState(() => _errors = errs);
      (_userBad ? _userNode : _passNode).requestFocus();
      return;
    }
    setState(() {
      _busy = true;
      _errors = [];
    });
    final (ok, auth, error) = await widget.app.api.login(_user.text, _pass.text);
    if (!mounted) return;
    if (!ok || auth == null) {
      setState(() {
        _busy = false;
        _errors = [error ?? 'Login failed.'];
      });
      _passNode.requestFocus();
      return;
    }
    await widget.app.signIn(auth, remember: _remember);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final narrow = isNarrow(context);
    final left = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 120,
          height: 120,
          margin: const EdgeInsets.only(bottom: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.asset('assets/images/web_icon.png', width: 120, height: 120, fit: BoxFit.cover, filterQuality: FilterQuality.medium),
          ),
        ),
        Text('Area Incident Tracker',
            textAlign: TextAlign.center,
            style: ts(context, size: 22, weight: FontWeight.w700, color: p.textHi, height: 1.2)),
        const SizedBox(height: 2),
        Text('Database', textAlign: TextAlign.center, style: ts(context, size: 13, color: p.textLow)),
        SizedBox(height: narrow ? 0 : 24),
      ],
    );

    final form = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Welcome Back', style: ts(context, size: 20, weight: FontWeight.w700, color: p.textHi, height: 1.3)),
              const SizedBox(height: 4),
              Text('Sign in to access your dashboard', style: ts(context, size: 13, color: p.textLow)),
            ],
          ),
        ),
        ValidationSummary(_errors),
        const LaLabel('Username', hi: true),
        LaInput(
          controller: _user,
          focusNode: _userNode,
          autofocus: true,
          hint: 'admin',
          icon: LaIcons.user,
          invalid: _userBad,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _passNode.requestFocus(),
          onChanged: (_) {
            if (_userBad) setState(() => _userBad = false);
          },
        ),
        const SizedBox(height: 16),
        const LaLabel('Password', hi: true),
        LaInput(
          controller: _pass,
          focusNode: _passNode,
          hint: '\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022',
          icon: LaIcons.lock,
          obscure: true,
          invalid: _passBad,
          onSubmitted: (_) => _submit(),
          onChanged: (_) {
            if (_passBad) setState(() => _passBad = false);
          },
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: LaCheckbox(
            value: _remember,
            label: 'Keep me signed in',
            labelColor: p.textLow,
            onChanged: (v) => setState(() => _remember = v),
          ),
        ),
        const SizedBox(height: 20),
        LaButton(
          expand: true,
          onTap: _busy ? null : _submit,
          leading: _busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : LaIcon(LaIcons.signIn, size: 16, color: const Color(0xFFF4FFF4)),
          label: _busy ? 'Signing in...' : 'Sign In',
        ),
      ],
    );

    return AppBackgroundSolid(
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(narrow ? 14 : 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: narrow ? 18 : 28, vertical: narrow ? 24 : 34),
              decoration: BoxDecoration(
                color: p.ink700,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: p.teal),
                boxShadow: const [BoxShadow(color: Color.fromRGBO(5, 35, 20, .22), offset: Offset(0, 30), blurRadius: 80)],
              ),
              child: narrow
                  ? Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [left, const SizedBox(height: 24), form])
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        ConstrainedBox(constraints: const BoxConstraints(minWidth: 160), child: left),
                        const SizedBox(width: 40),
                        Expanded(child: form),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Login wrap background: plain ink-900.
class AppBackgroundSolid extends StatelessWidget {
  const AppBackgroundSolid({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => ColoredBox(color: context.pal.ink900, child: child);
}
