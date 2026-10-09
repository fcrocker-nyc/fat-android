# FAT — hog operations near pork plants (per-plant aggregates)

`fat_swine_nearby.json` — for each FSIS establishment, counts of state swine (hog) operation
permit and registration records within 50 miles. The FAT apps (iOS + Android) fetch it via
jsDelivr, cache it on the device and refresh it weekly, to add lines to the "Nearby Hog Farm"
card on pork scans ("State permit records list N hog operations within 50 miles of this
plant…", the lagoon and federal-permit (NPDES) lines) and a Cat. 16 parent-company detail line.
Informational only: it never changes a category status or the disclosure count.

Prepared by Dirk Adams with the assistance of AI. Built 2026-10-09.

App fetch URL: `https://cdn.jsdelivr.net/gh/fcrocker-nyc/fat-android@main/swine-permits/fat_swine_nearby.json`

## Privacy

This file holds **aggregates only**. It contains no farm names, owner names, farm coordinates
or permit numbers. Many permit holders are individuals, so facility-level rows are not
published here; they stay in a local, unpublished build folder. The only identifiers are FSIS
establishment ids (public plant records). The earlier row-level file
`fat_swine_permits.json` was removed on 2026-10-09.

## Format

- `radiusMiles` — 50.
- `states.<ST>` — agency, source URL, data date, operation count, whether the state publishes
  lagoon data (`lagoon`) and an NPDES flag (`npdes`), statewide `lagoonCount` / `npdesCount`,
  and the filter used (`basis`).
- `plants.<establishment_id>` — `n` operations within 50 miles; `s` operations by published
  state the circle reaches (0 = reached, none listed); `l` operations listing at least one
  waste lagoon (lagoon states only); `np` operations holding a federal Clean Water Act (NPDES)
  permit (NPDES-flag states only); `ph` permits held by an entity mapped to a processor parent,
  by state; `u` states the circle reaches that publish no usable data (not counted).
- Plants with no operation within 50 miles and no not-published state in range are omitted.
- `method`, `parents`, `notPublished` — method notes, parent keys, and states without data.

## Sources

| State | Agency / source | Data date | Operations | NPDES | Filter |
|---|---|---|---|---|---|
| NC | NC DEQ Division of Water Resources — [Animal Feeding Operation Permits FeatureServer](https://services2.arcgis.com/kCu40SDxsCGcuUWO/arcgis/rest/services/Animal_Feed_Operation_Permits_(View)/FeatureServer/0); lagoons from the [List of Permitted Animal Facilities, 2026-04-23](https://www.deq.nc.gov/listpermittedanimalfacilities20260423xlsx/open) | 2024-01-04 (layer last edited) | 1,987 | 1 | Active, DESC_ LIKE 'Swine%', one per permit number; no expiration-date filter. Lagoon = Number Of Lagoons > 0 on the April 2026 list (1,868); 106 layer permits are not on that list and have no lagoon data. NPDES = NCA/NC0 permit numbers. |
| MN | Minnesota Pollution Control Agency — [Feedlots in Minnesota CSV](https://operations.gis.data.mn.gov/api/publicdownload/download/299/feedlots.csv) | 2026-10-09 (downloaded) | 5,543 | 605 | Active records with swine head > 0, one per permit (or registration) number; 2 Tyson hog buying stations and the Hormel Austin plant holding pens removed (not farms). NPDES = `npdes_sds` is NPDES/SDS. |
| MO | Missouri DNR — [NPDES Animal Feeding Operations MapServer](https://gis.dnr.mo.gov/host/rest/services/waste/NPDES_AnimalFeedingOperations/MapServer/0) | 2026-10-06 | 254 | 22 | Effective Class I CAFO permits with swine, one per permit. Lagoon = storage or wastewater-treatment lagoon listed (61). NPDES = MOG01 / MO-0 numbers; MOGS state no-discharge permits are not NPDES and are not in EPA ECHO (checked 2026-10-09). |
| IA | Iowa DNR — [AFO geodatabase (AFO.zip)](https://iowageodata2.s3.us-east-2.amazonaws.com/farming/AFO.zip) | 2024-04-05 | 8,816 | 37 | Facilities with any swine; covers facilities of 300+ animal units. NPDES = an NPDES permit issue date is listed. Same basis as FAT's pork maps. No head or animal-unit figures are used. |
| NE | Nebraska DWEE — [LWC Facility Locations MapServer](https://giscat.ne.gov/agencyext/rest/services/NDEE_LWC_Facility_Locations/MapServer) | 2026-10-07 | 2,914 | unknown | Facilities with an active swine LWC program record. No usable NPDES field. |
| IN | IDEM — [Confined Feeding Operations FeatureServer](https://gisdata.in.gov/server/rest/services/Hosted/Confined_Feeding_Operations/FeatureServer/2080) | 2026-04-19 | 1,274 | 400 | Approvals with at least one pig, one per approval number. NPDES = an NPDES coverage type is recorded. |
| MI | EGLE — [CAFO FeatureServer](https://gisagoegle.state.mi.us/arcgis/rest/services/EGLE/ConcentratedAnimalFeedingOperations/FeatureServer/0) | 2024 report year | 110 | 110 | CAFO permits reporting swine; all are NPDES permits (MIG01 / MI00). |

Plants: FSIS [MPI Directory by Establishment Number](https://www.fsis.usda.gov/inspection/establishments/meat-poultry-and-egg-product-inspection-directory)
CSV, downloaded 2026-10-09 (7,246 establishments with coordinates; 7,043 included).

Not included: **TX** (TCEQ CAFO permits carry no species field), KS, OK, OH, IL, SD (no public
facility list), PA (address only, not geocoded), WI (no coordinates), and all other states.

## Ownership

Permit holders are mapped to a processor parent only on an exact (normalised) entity name,
verified against the parent's own SEC subsidiary list:

- Smithfield Foods ← "Murphy-Brown LLC", "Murphy-Brown of Missouri LLC" (both listed "d/b/a
  Smithfield Hog Production"), "Smithfield Hog Production" — Smithfield Foods 10-K Exhibit
  21.1 (filed 2026): https://investors.smithfieldfoods.com/sec-filings/sec-filings/content/0000091388-26-000014/a10-kexhibit211.htm
- Seaboard Foods ← "Seaboard Foods LLC" — Seaboard Corp. FY2025 10-K Exhibit 21:
  https://www.sec.gov/Archives/edgar/data/88121/000008812126000012/seb-20251231xex21.htm

Contract-grower farms are permitted under the grower's own name, so a parent-company count
is a minimum. Name look-alikes that are not the packer never match.

Rebuild (local only): `build/pull_nearby.py` + `build/build_nearby.py` in the FAT project's
`research/hog-permits-2026-10/` folder.
