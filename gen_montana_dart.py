import csv, re, os

BASE = "/Users/dirkadams/Documents/Claude/Projects/FAT Website May 2026"
OUT = "/Users/dirkadams/Projects/fat-android/lib/data/montana_data.dart"

def fix(s):
    for _ in range(2):
        try:
            r = s.encode("latin-1").decode("utf-8")
        except Exception:
            break
        if r == s:
            break
        s = r
    return s

def norm(s):
    s = re.sub(r"[^a-z0-9 ]", " ", fix(s).lower())
    return re.sub(r"\s+", " ", s).strip()

def d(s):
    return "'" + fix(s).replace("\\", "\\\\").replace("'", "\\'").replace("$", "\\$") + "'"

ests = {}
with open(os.path.join(BASE, "Montana_processors_FSIS_est_ids.csv")) as f:
    for row in csv.DictReader(f):
        raw = row["fsis_establishment_no"].strip()
        if raw in ("", "—"):
            continue
        for t in raw.split("+"):
            k = re.sub(r"[^0-9]", "", t)
            if k:
                ests.setdefault(k, (row["fsis_name"].strip(), row["town"].strip()))

producers, seen = [], set()
with open(os.path.join(BASE, "AbundantMontana_meat_producers.csv")) as f:
    for row in csv.DictReader(f):
        name = row["name"].strip()
        url = row["listing_url"].strip()
        if not name or not url.startswith("https://abundantmontana.com/"):
            continue
        n = norm(name)
        if len(n) < 6 or n in seen:
            continue
        seen.add(n)
        producers.append((name, row["location"].strip(), row["county"].strip().title(),
                          row["primary_type"].strip(), row["meat_products"].strip(), url, n))

o = ["// montana_data.dart - GENERATED from Abundant Montana + FSIS establishment rosters.",
     "// Source: abundantmontana.com meat/poultry listings; USDA/FSIS MPI establishment directory.",
     "// Mirror of iOS MontanaData.swift. Regenerate via gen_montana_dart.py; do not hand-edit.",
     "",
     "class MontanaProcessorInfo {",
     "  final String fsisName;",
     "  final String town;",
     "  const MontanaProcessorInfo(this.fsisName, this.town);",
     "}",
     "",
     "class AbundantMontanaProducer {",
     "  final String name;",
     "  final String town;",
     "  final String county;",
     "  final String type;",
     "  final String products;",
     "  final String url;",
     "  final String normalizedName;",
     "  const AbundantMontanaProducer({",
     "    required this.name,",
     "    required this.town,",
     "    required this.county,",
     "    required this.type,",
     "    required this.products,",
     "    required this.url,",
     "    required this.normalizedName,",
     "  });",
     "}",
     "",
     "class MontanaData {",
     "  /// Federally inspected (USDA/FSIS) Montana meat/poultry plants that also appear",
     "  /// in the Abundant Montana local-food directory, keyed by EST digits.",
     "  static const Map<String, MontanaProcessorInfo> abundantMontanaEsts = {"]
for k in sorted(ests, key=lambda x: int(x)):
    nm, tw = ests[k]
    o.append("    {}: MontanaProcessorInfo({}, {}),".format(d(k), d(nm), d(tw)))
o += ["  };", "",
      "  /// Montana producers/brands listed in the Abundant Montana directory that sell",
      "  /// meat or poultry. Directory membership - not a federal origin claim.",
      "  static const List<AbundantMontanaProducer> abundantMontanaProducers = ["]
for name, town, county, typ, prods, url, n in producers:
    o.append("    AbundantMontanaProducer(name: {}, town: {}, county: {}, type: {}, products: {}, url: {}, normalizedName: {}),".format(
        d(name), d(town), d(county), d(typ), d(prods), d(url), d(n)))
o += ["  ];", "}", ""]

with open(OUT, "w") as f:
    f.write("\n".join(o))
print("wrote", OUT, "|", len(ests), "ests,", len(producers), "producers")
