import 'package:flutter/material.dart' show IconData, Icons;

import 'menu_explainer.dart';
import 'menu_models.dart';

/// Plain-text write-up of a menu read, for Share and the "Questions?" email.
/// Same wording as iOS MenuShare.
class MenuShare {
  static const appURL = 'https://farmanimaltransparency.com/the-fat-app-label-transparency-in-your-pocket/';

  static String summary(MenuResult result, MenuGlossary glossary) {
    final items = result.visibleItems;
    final withClaims = items.where((i) => MenuClaimExplainer.hasSourcingClaim(i, glossary)).length;
    return '${items.length} ${items.length == 1 ? 'dish' : 'dishes'} with meat or seafood · '
        '$withClaims with a sourcing claim';
  }

  static String text(MenuResult result, MenuGlossary glossary, {DateTime? date}) {
    final d = date ?? DateTime.now();
    final b = StringBuffer()
      ..writeln('RESTAURANT MENU — SOURCING WORDS AND QUESTIONS')
      ..writeln('Read by the Farm Animal Transparency (FAT) App')
      ..writeln('Date: ${_date(d)}');
    if (result.diningState != null) b.writeln('Dining in: ${result.diningState}');
    b.writeln(summary(result, glossary));
    if (result.headerStatements.isNotEmpty) {
      b.writeln();
      b.writeln('From the menu’s header:');
      for (final s in result.headerStatements) {
        b.writeln('  “$s”');
      }
    }
    final items = result.visibleItems;
    for (var n = 0; n < items.length; n++) {
      final item = items[n];
      b.writeln();
      b.writeln('${n + 1}. ${item.dishName}');
      if (item.description.isNotEmpty) b.writeln('   ${item.description}');
      final tags = MenuClaimExplainer.tags(item);
      final claims = [for (final t in tags) if (!t.isNote) t.text];
      final notes = [for (final t in tags) if (t.isNote) t.text];
      b.writeln(claims.isEmpty ? '   No sourcing claim on the menu' : '   Sourcing words: ${claims.join(', ')}');
      if (notes.isNotEmpty) b.writeln('   Also explained: ${notes.join(', ')}');
      final qs = MenuClaimExplainer.askQuestions(item, glossary);
      if (qs.isNotEmpty) {
        b.writeln('   Ask:');
        for (final q in qs) {
          b.writeln('   • $q');
        }
      }
    }
    b.writeln();
    b.writeln('FAT doesn’t check, score, or grade restaurants. The kitchen’s answers are the disclosure.');
    b.writeln('Get the FAT App: $appURL');
    return b.toString();
  }

  static const _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August',
      'September', 'October', 'November', 'December'];

  static String _date(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    return '${_months[d.month - 1]} ${d.day}, ${d.year} at $h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
  }
}

/// "How to get a good read" — photo tips shown from a pill on the Menu screen,
/// before the first capture. Same wording as iOS MenuReadTips.
class MenuReadTips {
  static const pill = 'How to get a good read';
  static const List<(IconData, String, String)> tips = [
    (Icons.view_agenda_outlined, 'One section at a time',
        'Photograph the part of the menu you’re ordering from so the dishes fill the frame. A big menu reads better as two or three close photos than one far away. Add up to six pages.'),
    (Icons.smartphone, 'Hold the phone flat over the page',
        'Square to the menu, not at an angle. FAT straightens a small tilt, but a steep angle shrinks the far side of the page.'),
    (Icons.wb_sunny_outlined, 'Good light, no glare',
        'Move the menu out of a reflection or a shadow. On glossy or laminated menus, tilt the page slightly until the shine is gone.'),
    (Icons.qr_code_2, 'QR-code and online menus',
        'Open the menu on your phone, take a screenshot, then tap Import a Screenshot. Screenshots read cleanly.'),
    (Icons.touch_app_outlined, 'Fix anything that looks off',
        'On Dishes found, swipe a row to remove something that isn’t a dish, or long-press to fix its protein. If dish names ran together, take a closer photo of that section.'),
    (Icons.chat_bubble_outline, 'Then ask',
        'FAT explains the sourcing words and suggests questions. The kitchen’s answers are the disclosure.'),
  ];
}
