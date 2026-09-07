import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/big_four_ownership.dart';

/// Shows the ownership chain the record actually supports: plant → operating
/// company → ultimate parent, with the foreign-ownership line, the sibling
/// plants under the same parent, and a basis string naming the source.
///
/// Deliberately separate from the market-share card: that one answers "how
/// concentrated is this market", this one answers "who owns THIS plant, and
/// how do we know".
class CorporateStructureCard extends StatefulWidget {
  final OwnershipDisclosure disclosure;
  const CorporateStructureCard({super.key, required this.disclosure});

  @override
  State<CorporateStructureCard> createState() => _CorporateStructureCardState();
}

class _CorporateStructureCardState extends State<CorporateStructureCard> {
  bool _showSiblings = false;

  static const _ink = Color(0xFF1B2938);
  static const _cardBg = Color(0xFFF8F9F6);
  static const _alertInk = Color(0xFFB45309);
  static const _alertBg = Color(0xFFFFF8F0);

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.disclosure;
    final steps = d.ownershipChain;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _ink.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.account_balance, size: 18, color: _ink),
              SizedBox(width: 8),
              Text('Who Owns This Plant',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w900, color: _ink)),
            ],
          ),
          const SizedBox(height: 10),

          // Ownership chain
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: EdgeInsets.only(left: i * 10.0, bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                        i == steps.length - 1
                            ? Icons.flag
                            : Icons.subdirectory_arrow_right,
                        size: 14,
                        color: i == 0 ? Colors.black54 : _ink),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(steps[i],
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: i == steps.length - 1
                                ? FontWeight.bold
                                : FontWeight.w600,
                            color: Colors.black)),
                  ),
                ],
              ),
            ),

          if (d.isForeignOwned && d.country != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: _alertBg, borderRadius: BorderRadius.circular(8)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.public, size: 16, color: _alertInk),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Foreign-owned: this plant is ultimately controlled from ${d.country}. The package label is not required to say so.',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _alertInk),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (d.controlNote != null) ...[
            const SizedBox(height: 10),
            Text(d.controlNote!,
                style: const TextStyle(fontSize: 13, color: Colors.black54)),
          ],

          // Sibling plants — only the site database supplies these.
          if ((d.totalRelated ?? 0) > 1 && d.siblings.isNotEmpty) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => setState(() => _showSiblings = !_showSiblings),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_showSiblings ? Icons.expand_more : Icons.chevron_right,
                      size: 16, color: _ink),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'This parent operates ${d.totalRelated} USDA-inspected establishments',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _ink),
                    ),
                  ),
                ],
              ),
            ),
            if (_showSiblings) ...[
              const SizedBox(height: 6),
              for (final s in d.siblings)
                Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${s.name} — ${s.location}',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.black)),
                      Text('EST ${s.estNumber}',
                          style: const TextStyle(
                              fontSize: 10.5, color: Colors.black54)),
                    ],
                  ),
                ),
              if (d.siblings.length < (d.totalRelated ?? 0))
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Text(
                    '… and ${(d.totalRelated ?? 0) - d.siblings.length} more not listed by the API.',
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                ),
            ],
          ],

          if (d.disclosedEntities.length > 1) ...[
            const SizedBox(height: 10),
            Text(
              'Entities on the FSIS record: ${d.disclosedEntities.join(' • ')}',
              style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54),
            ),
          ],

          const SizedBox(height: 8),
          Text('Source: ${d.source.label}. ${d.basis}',
              style: const TextStyle(fontSize: 11, color: Colors.black54)),

          if (d.profileURL != null) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _open(d.profileURL!),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.public, size: 16, color: Colors.blue),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text('${d.parentName} → company site',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
