# FAT — state swine permit records

`fat_swine_permits.json` — hog-operation permit and registration records from state
environmental agencies. The FAT apps (iOS + Android) fetch it via jsDelivr, cache it on the
device and refresh it weekly, to add a line to the "Nearby Hog Farm" card on pork scans:
"State permit records list N hog operations within 75 miles of this plant". Informational
only: it never changes a category status or the disclosure count.

Prepared by Dirk Adams with the assistance of AI. Built 2026-10-08.

App fetch URL: `https://cdn.jsdelivr.net/gh/fcrocker-nyc/fat-android@main/swine-permits/fat_swine_permits.json`

## Format

- `states.<ST>` — agency, source URL, data date, record count, animal unit label, whether the
  source publishes lagoon and owner data, and the filter used (`basis`).
- `r` — one array per record, in the order given by `fields`:
  `[state, permit/facility id, facility name, owner (null if not published), lat, lon,
  animals (null if not published), lagoon (1/0, null if not published)]`. Coordinates are
  rounded to 4 decimal places.
- `notPublished` — states with no usable public list (not counted).
- `grid` — run-length-encoded 0.1-degree grid of the state each cell centre falls in (Census
  TIGERweb state boundaries, simplified). The apps use it only to say which states a 75-mile
  radius reaches, so they can say "Data not published by <state> — not counted".

## Sources

| State | Agency / source | Data date | Records | Filter |
|---|---|---|---|---|
| NC | NC DEQ Division of Water Resources — [List of Permitted Animal Facilities XLSX](https://www.deq.nc.gov/listpermittedanimalfacilities20260423xlsx/open) | 2026-04-23 | 1,962 | All swine permits (rows grouped by permit; head = sum of Allowable Count; lagoon = Number Of Lagoons > 0). Expiration dates not used: the swine general permit was extended by legislation to 2028. |
| MN | Minnesota Pollution Control Agency — [Feedlots in Minnesota CSV](https://operations.gis.data.mn.gov/api/publicdownload/download/299/feedlots.csv) | 2026-10-08 (daily) | 4,623 | Active sites with swine as primary stock; 2 Tyson hog buying stations and the Hormel Austin plant holding pens removed (not farms). |
| MO | Missouri DNR — [NPDES Animal Feeding Operations MapServer](https://gis.dnr.mo.gov/host/rest/services/waste/NPDES_AnimalFeedingOperations/MapServer/0) | 2026-10-06 | 254 | Effective permits with swine; features grouped by PERMIT_ID; PRIMARY_PF = 'Y' point (5 permits without one use their first feature); lagoon = storage lagoon or wastewater treatment lagoon flag. |
| IA | Iowa DNR — [AFO MapServer layer 3](https://programs.iowadnr.gov/geospatial/rest/services/Agriculture/AnimalFeedingOperations/MapServer/3) | 2026-10-08 | 9,410 | opStatus Active and Swine > 0. No owner in bulk data. |
| NE | Nebraska DWEE (formerly NDEE) — [LWC Facility Locations MapServer](https://giscat.ne.gov/agencyext/rest/services/NDEE_LWC_Facility_Locations/MapServer) | 2026-10-07 | 2,914 | Facilities with an active swine LWC program record. No owner or head counts. |
| IN | IDEM — [Confined Feeding Operations FeatureServer](https://gisdata.in.gov/server/rest/services/Hosted/Confined_Feeding_Operations/FeatureServer/2080) | 2026-04-19 | 1,305 | Approvals with at least one pig. No owner field. |
| MI | EGLE — [CAFO FeatureServer](https://gisagoegle.state.mi.us/arcgis/rest/services/EGLE/ConcentratedAnimalFeedingOperations/FeatureServer/0) | 2024 report year | 110 | CAFO permits reporting swine. Coordinates rounded by EGLE to about 1 km. |

Not included: **TX** (TCEQ CAFO permits carry no species field, so swine permits cannot be
identified), KS, OK, OH, IL, SD (no public facility list), PA (address only, not geocoded),
WI (no coordinates).

## Ownership

The apps map a permit's owner to a processor parent only on an exact (normalised) entity
name, verified against the parent's own SEC subsidiary list:

- Smithfield Foods ← "Murphy-Brown LLC", "Murphy-Brown of Missouri LLC" (both listed "d/b/a
  Smithfield Hog Production"), "Smithfield Hog Production" — Smithfield Foods 10-K Exhibit
  21.1 (filed 2026): https://investors.smithfieldfoods.com/sec-filings/sec-filings/content/0000091388-26-000014/a10-kexhibit211.htm
- Seaboard Foods ← "Seaboard Foods LLC" — Seaboard Corp. FY2025 10-K Exhibit 21:
  https://www.sec.gov/Archives/edgar/data/88121/000008812126000012/seb-20251231xex21.htm

Contract-grower farms are permitted under the grower's own name, so a parent-company count
is a minimum. Name look-alikes that are NOT the packer ("Tyson Five LLC", "Triumph Associates
LLC", "Hanor Multiplier", "Smithfield Ridge Lc", "Smithfield Enterprises LLC") never match.

Rebuild: `build/pull.py` + `build/build.py` in the FAT project's
`research/hog-permits-2026-10/` folder.
