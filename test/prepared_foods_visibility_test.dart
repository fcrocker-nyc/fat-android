// Prepared foods visibility: Home scan button copy, the Learn section and
// its Table of Contents rows, and the deep links that open them. Strings are
// identical to iOS PreparedFoodsVisibilityTests.swift.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fat_app/screens/home_screen.dart';
import 'package:fat_app/screens/how_fat_works_screen.dart';
import 'package:fat_app/screens/learn_screen.dart';

const sectionTitle = 'Prepared Foods: When Meat Is One Ingredient';
const movedTopic = 'Prepared & Multi-Ingredient Foods';
const companionTopic = 'What a prepared-food scan shows you';

const companionText =
    'When FAT reads a label as a prepared food, the results look a little different from a package of steak. Here is what you will see.\n\n'
    'The ingredient statement line.\nOn a meat or poultry prepared food, the card opens with a line about the ingredient list. If FAT read one, it says “Ingredient statement: on the label — lists: beef, pork”, naming each meat, poultry or seafood ingredient it found. If it didn’t, it says “Ingredient statement: not found in the photos (it may be on a panel you didn’t photograph)”. The line is information only. It doesn’t change the count.\n\n'
    'The not-applicable reason.\nCategories that don’t apply show in blue and come out of the count, and the card says how many and why, for example: “8 not applicable — prepared / multi-ingredient food: no U.S. labeling rule requires these details for ingredient meat”. The count then reads “of 8 applicable categories disclosed”.\n\n'
    'What is set aside.\nBreed, farm or ranch, age at slaughter, feed, animal welfare, medicine, hormones and supply-chain intermediaries, when the label is silent on them. If the label does say something about one of them, such as “organic chicken”, it still counts.\n\n'
    'What still counts.\nThe USDA required language (Category 1), species, processor, brand, owner, country of origin claims, quality, and organic. Any other voluntary claim on the label still counts and still shows its credibility tier.\n\n'
    'More than one animal.\nSpecies lists every meat, poultry or seafood ingredient FAT finds: “Contains: Beef, Pork, Chicken” on a pepperoni pizza, “Contains: Clam, Pork” on a clam chowder made with bacon.\n\n'
    'USDA or FDA.\nIf the label carries the USDA inspection legend or an establishment number, FAT reads it as a USDA-inspected product. Category 1 and the processor count, and the establishment number is described as the plant that made the product, not the slaughterhouse of the meat inside. If neither mark is found, FAT infers that FDA regulates the product. Labels don’t state how much meat is in them, so this is an inference. Category 1 and the processor are then set aside too (for example, “10 not applicable”), and FAT doesn’t flag a missing establishment number. If the legend is on a panel you didn’t photograph, rescan with that panel included.\n\n'
    'Prepared seafood.\nChowders, crab cakes, fish sticks and similar foods go through the seafood side. FAT lists every fish and shellfish named. When the label is silent on them, it sets aside strain, vessel or farm, harvest timing, wild-or-farmed and feed, welfare, medicine, hormones, supply-chain intermediaries and country of origin. Processed seafood is outside seafood origin labeling, so no origin statement is required. The card counts “of N applicable categories” and a note near the top explains why. The ingredient statement line appears on meat and poultry prepared foods only.\n\n'
    'No meat at all.\nIf the ingredient list names no meat, poultry or seafood, as on a cheese pizza, FAT doesn’t score the label and says so on the Scan screen.';

final _acronym = RegExp(r'\b(?:COOL|SIMP|AMS|FSIS(?!-GD-)|HACCP|NOP)\b');

void main() {
  test('Home scan button copy', () {
    expect(HomeScanText.title, 'Scan a Label');
    expect(HomeScanText.subtitle,
        'Meat, poultry or seafood — or food made with them: stew, pizza, soup, fish sticks.');
    expect(HomeScanText.learnMore, 'How FAT reads prepared foods — Learn more');
    final src = File('lib/screens/home_screen.dart').readAsStringSync();
    expect(src, isNot(contains('Meat/Seafood Label')));
    expect(src, isNot(contains('Also reads prepared foods')));
    expect(src, contains('Reads food where meat is just one of the ingredients'));
  });

  test('Learn TOC: Prepared Foods section right after How FAT Reads a Label',
      () {
    final toc = learnTableOfContents();
    expect(toc[0].$1, 'How FAT Reads a Label');
    expect(toc[1].$1, sectionTitle);
    expect(toc[1].$2, [movedTopic, companionTopic]);
    // Moved, not copied: the topic appears exactly once.
    final all = toc.expand((s) => s.$2).toList();
    expect(all.where((t) => t == movedTopic).length, 1);
    expect(toc.firstWhere((s) => s.$1.startsWith('Meat & Poultry')).$2,
        isNot(contains(movedTopic)));
  });

  test('companion topic text', () {
    expect(learnTopicText(companionTopic), companionText);
    expect(_acronym.hasMatch(companionText), isFalse);
    final moved = learnTopicText(movedTopic)!;
    expect(_acronym.hasMatch(moved), isFalse);
    expect(moved, contains('hormones, supply-chain intermediaries) are marked'));
    expect(moved, contains('The missing marks are shown as “not applicable”'));
    expect(moved, contains('9 CFR 301.2'));
    expect(moved, contains('21 U.S.C. 601(j)'));
    expect(moved, contains('21 U.S.C. 453(f)'));
  });

  test('How FAT Works link copy', () {
    expect(HowFATWorksText.preparedLearnMore,
        'Learn more: “Prepared Foods: When Meat Is One Ingredient”');
  });

  testWidgets('Learn more opens the Prepared Foods section; its rows open topics',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => openPreparedFoodsLearnSection(context),
          child: const Text('go'),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text(sectionTitle.toUpperCase()), findsOneWidget);
    expect(find.text(movedTopic), findsOneWidget);
    expect(find.text(companionTopic), findsOneWidget);
    await tester.tap(find.text(companionTopic));
    await tester.pumpAndSettle();
    expect(find.textContaining('The ingredient statement line.'), findsOneWidget);
  });

  testWidgets('old topic deep link still lands on the moved topic',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => openPreparedFoodLearnTopic(context),
          child: const Text('go'),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text(movedTopic), findsWidgets);
  });
}
