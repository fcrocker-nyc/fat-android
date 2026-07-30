# FAT — Never Fed Beta Agonists (ractopamine) verification data

`fat_beta_agonists.json` — the lean list the FAT apps fetch (via jsDelivr) to surface a
**positive, plant-level disclosure flag**: an establishment on the USDA AMS *Official Listing of
Approved Never Fed Beta Agonists Programs* runs an AMS-verified line raised without beta-agonists
(ractopamine / zilpaterol). Keyed by numeric establishment-**core** (same normalization as the EPA
layer), value carries entity, species, verified export markets, and any co-packer sponsor.

**Framing — do not weaken (see farmanimaltransparency.com/ractopamine-us-pork-labels-verification/):**
- **Positive only.** Presence ⇒ a verified never-fed line at that establishment. Absence ⇒
  UNVERIFIED / undisclosed — **never** "uses ractopamine." No federal registry of users exists and
  FSIS requires no beta-agonist label disclosure; inferring use would be fabrication.
- **Product-line, not company-wide.** A listed firm may also run conventional (ractopamine) lines.
  Surface at the establishment level, never as a company badge.
- This is **not** a score input — it neither adds nor removes points. It is disclosure context
  shown alongside the FSIS/EPA/OSHA signals. (A plant can be both verified-never-fed and
  EPA-violating; the −3 EPA penalty still applies.)

`beta_agonists_by_est.json` — full per-establishment detail (operation type, per-market effective
dates, sponsoring brand) for transparency and the WordPress parent-company lookup.

Source: USDA AMS `LSOfficialListingNeverFedBetaAgonistsProgram.pdf` (Last Revised July 22, 2026);
41 establishment listings across 26 entities. Regenerate via `fat-supplier-registry/
extract_beta_agonists.py` + `build_beta_agonists_lookup.py` in the FAT project.

App fetch URL: `https://cdn.jsdelivr.net/gh/fcrocker-nyc/fat-android@main/beta-agonists/fat_beta_agonists.json`
