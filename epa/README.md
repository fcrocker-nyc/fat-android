# FAT — EPA enforcement data

`fat_epa_violations.json` — the lean list the FAT apps fetch (via jsDelivr) to drive the
**EPA −3 penalty** on Category 7 (Processor). It lists the numeric establishment-cores whose
plant has a **high-confidence match** in EPA ECHO **and** current noncompliance / penalties
(SNC flag, quarters-in-noncompliance, or penalties assessed). The app fires the −3 iff the
scanned establishment's numeric core is in `cores`.

`fat_epa_index.json` — full per-establishment detail (match confidence, EPA facility, CWA/CAA/
RCRA status) for transparency.

Source: EPA ECHO_EXPORTER bulk (echo.epa.gov). Regenerate via `fat-epa/match_bulk.py` +
`fat-epa/make_epa_bundle.py` in the FAT project. 327 establishments matched (300 high / 30
medium), 65 with high-confidence violations as of 2026-07-05.

App fetch URL: `https://cdn.jsdelivr.net/gh/fcrocker-nyc/fat-android@main/epa/fat_epa_violations.json`
