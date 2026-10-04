import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import '../theme/theme.dart';
import 'common.dart';
import 'modal.dart';

class _Group {
  const _Group(this.title, this.rows);
  final String title;
  final List<(String, String)> rows;
}

const _groups = <_Group>[
  _Group('Navigate', [
    ('Ctrl + 1', 'Dashboard'),
    ('Ctrl + 2', 'Places'),
    ('Ctrl + 3', 'Area Map'),
    ('Ctrl + 4', 'New Assessment'),
    ('Ctrl + 5', 'Assessment framework'),
    ('Esc  /  Alt + \u2190', 'Go back (closes dialogs first)'),
    ('Ctrl + B', 'Show / hide the menu (narrow windows)'),
    ('Ctrl + R  /  F5', 'Reload the current page'),
  ]),
  _Group('Actions', [
    ('Ctrl + K', 'Pick a place (opens the Dashboard for it)'),
    ('Ctrl + N', 'New item for this page (Add Place / New Assessment)'),
    ('Ctrl + S', 'Save the form  /  Save report as PDF'),
    ('Ctrl + P', 'Print the report'),
    ('Ctrl + Shift + P', 'Save the report as PDF'),
    ('Ctrl + H', 'History for the current place'),
    ('Ctrl + F  /  /', 'Focus the search box'),
    ('Ctrl + T', 'Switch light / dark theme'),
    ('Ctrl + Shift + Q', 'Log out'),
    ('F11', 'Full screen'),
    ('F1  /  ?', 'Show this help'),
  ]),
  _Group('Places list', [
    ('\u2191  \u2193  Home  End', 'Move the row selection'),
    ('Enter', 'Open the Dashboard for the selected place'),
    ('E', 'Edit the selected place'),
    ('Delete', 'Delete the selected place'),
    ('Page Up / Page Down', 'Previous / next page of results'),
  ]),
  _Group('Forms', [
    ('Tab  /  Shift + Tab', 'Next / previous field'),
    ('\u2190  \u2192  on a slider', 'Change a score by 1'),
    ('1 \u2013 9, 0 on a slider', 'Jump to that score (0 = 10)'),
    ('Enter / Space on a date', 'Open the calendar'),
  ]),
  _Group('Calendar & place picker', [
    ('Arrow keys', 'Move the day / the highlighted place'),
    ('Page Up / Page Down', 'Previous / next month'),
    ('Home', 'Jump to today'),
    ('Enter', 'Choose'),
    ('Esc', 'Close'),
  ]),
  _Group('Framework page', [
    ('0 \u2013 4', 'All levels / each score level'),
    ('Enter / Space', 'Expand or collapse guidance'),
  ]),
  _Group('Area Map (click the map first)', [
    ('Arrow keys', 'Pan (hold Shift to pan faster)'),
    ('+  /  \u2212', 'Zoom in / out'),
    ('Home', 'Recentre on the Philippines'),
  ]),
];

Future<void> showShortcutHelp(AppState app) async {
  if (app.helpOpen) return;
  app.helpOpen = true;
  try {
    await showLaModal<void>(app, builder: (c) => const _HelpDialog());
  } finally {
    app.helpOpen = false;
  }
}

class _HelpDialog extends StatelessWidget {
  const _HelpDialog();

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final narrow = isNarrow(context);
    final scroll = ScrollController();
    return Focus(
      autofocus: true,
      onKeyEvent: (n, e) {
        if (e is KeyDownEvent &&
            (e.logicalKey == LogicalKeyboardKey.escape ||
                e.logicalKey == LogicalKeyboardKey.f1 ||
                e.logicalKey == LogicalKeyboardKey.enter)) {
          Navigator.of(context).pop();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: LaModal(
        accent: 'info',
        icon: '\u2328',
        title: 'Keyboard shortcuts',
        maxWidth: 720,
        bodyAlignCenter: false,
        body: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: narrow ? 360 : 460),
          child: Scrollbar(
            controller: scroll,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: scroll,
              padding: const EdgeInsets.only(right: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final g in _groups) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 8),
                      child: Text(g.title.toUpperCase(),
                          style: ts(context, size: 11, weight: FontWeight.w700, color: p.teal, spacing: 1)),
                    ),
                    for (final r in g.rows)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Container(
                            constraints: BoxConstraints(minWidth: narrow ? 130 : 170),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: p.ink600,
                              border: Border.all(color: p.line),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(r.$1,
                                style: TextStyle(
                                    fontFamily: 'Consolas',
                                    fontFamilyFallback: const ['Cascadia Code', 'Courier New', 'monospace'],
                                    fontSize: 12,
                                    color: p.textHi,
                                    fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Padding(padding: const EdgeInsets.only(top: 2), child: Text(r.$2, style: ts(context, size: 13)))),
                        ]),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
        actions: [LaButton(label: 'Close', minWidth: 120, onTap: () => Navigator.of(context).pop())],
      ),
    );
  }
}
