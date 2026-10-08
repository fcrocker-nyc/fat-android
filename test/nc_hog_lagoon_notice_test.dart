// North Carolina hog-lagoon informational card trigger.
// Fixtures are real fat/v1/establishments responses (captured 2026-10-07):
// 413 = M413 Smithfield Fresh Meats Corp., Clinton NC (one plant);
// 18079 = M18079+P27232 + V18079 Smithfield Fresh Meats Corp., Tar Heel NC
// (shared number, every candidate in NC); 79 = I79 Kapolei HI + M79C Wilson NC
// (shared number, mixed states).
// Mirrors iOS FATAppMVP2Tests/NCHogLagoonNoticeTests.swift.
import 'package:flutter_test/flutter_test.dart';
import 'package:fat_app/models/fat_models.dart';
import 'package:fat_app/services/establishments_service.dart';
import 'package:fat_app/services/fsis_plant_names.dart';
import 'package:fat_app/services/nc_hog_lagoon_notice.dart';

import 'establishment_fixtures.dart';

const r413 = r'''{"query":"413","mode":"number","count":1,"establishments":[{"establishment_id":"560","establishment_number":"M413","name":"Smithfield Fresh Meats Corp.","dba":"814 America; Aberdeen; Agar Foods; American Farms; Ark Valley; Armour; Armour Eckrich Meats, LLC; Armour Food Company; Carando; Clougherty Packing, LLC; Cook's Ham; Cook's Ham, Inc.; Country Lean; Curly's; Curly's Foods; Decker Food Company; Eastbay Packing Co.; Eckrich; FJ Foodservice, LLC; Farmer John; Farmland; Farmland Foods, Inc.; Farmstead; Golden Crisp Premium Foods; Gwaltney; Healthy Ones; Hunter Krey Packing Co.; Hunter Packing Co.; Jamestown; John Morrell; John Morrell & Co.; Kansas City Sausage; Kneip; Krakus; Krakus Foods International; Kretschmar; Kretschmar Brands, Inc.; Kretschmar Deli; Krey Packing Co.; Lakeview; Lundy's; Maple River Brand; Margherita; Mohawk Packing; Mohawk Provision, Inc.; Moseys; Moyer Packing Co.; Northside Foods; OhSe; Partridge Meats, Inc.; Patrick Cudahy, Inc.; Patrick Cudahy, LLC; Peyton Packing Co., Inc.; Pine Ridge Farms; Premium Farms; Premium Pet Health; Premium Standard Farms; Pruden Packing Co.; Pure Farms; Quick-To-Fix; Racorn, Inc.; Rath Blackhawk, Inc.; Rodeo Meats; Rodeo Meats, Inc.; Roegelein; Saag's Products, LLC; Selective Petfood Services, Inc.; Smithfield ; Smithfield Farmland Corp.; Smithfield Farmland Sales Corp.; Smithfield Foods; Smithfield Foods, Inc.; Smithfield Fresh Meats; Smithfield Fresh Meats Corp.; Smithfield Fresh Meats Sales Corp.; Smithfield Packaged Meats Corp.; Smithfield Packaged Meats Sales Corp.; Smithfield Packing Co.; Smithfield Pet; Spring Hill Brand; Stefano Foods; Stefano's; Sweet Applewood Farms, Inc.; The Smithfield Packing Co., Incorporated; Tiffany Springs Packing Co.; Tobin's First Prize Meat Co., Inc.; Valleydale, Inc.; Village Butcher; Windsor","address":"424 East Railroad Street","city":"Clinton","state":"NC","zip":"28328","size":"Large","grant_date":"2021-05-28","county":"Sampson County","latitude":34.993816947096,"longitude":-78.310104011702,"activities":"Meat Processing; Meat Slaughter","parent_company":"Smithfield Foods","recalls":0,"public_health_alerts":0,"latest_recall":null,"inspection_tasks":224,"noncompliance_records":0,"memoranda_of_interview":0,"residue_violations":0,"salmonella":null,"record_url":"https:\/\/farmanimaltransparency.com\/processor\/413\/#est-560","data_dates":{"mpi_data_date":"2026-10-06","salmonella_period":"Sample Collection Period August 31, 2025 through August 29, 2026","inspection_task_quarters":{"GCP":["FY2026Q3","FY2026Q2"],"LHH":["FY2026Q3","FY2026Q2"]}}}],"note":""}''';
const r18079 = r'''{"query":"18079","mode":"number","count":2,"establishments":[{"establishment_id":"728","establishment_number":"M18079+P27232","name":"Smithfield Fresh Meats Corp.","dba":"814 America; Aberdeen; Agar Foods; American Farms; Ark Valley; Armour; Armour Eckrich Meats, LLC; Armour Food Company; Carando; Clougherty Packing, LLC; Cook's Ham; Cook's Ham, Inc.; Country Lean; Curly's; Curly's Foods; Decker Food Company; Eastbay Packing Co.; Eckrich; FJ Foodservice, LLC; Farmer John; Farmland; Farmland Foods, Inc.; Farmstead; Golden Crisp Premium Foods; Gwaltney; Healthy Ones; Hunter Krey Packing Co.; Hunter Packing Co.; Jamestown; John Morrell; John Morrell & Co.; Kansas City Sausage; Kneip; Krakus; Krakus Foods International; Kretschmar; Kretschmar Brands, Inc.; Kretschmar Deli; Krey Packing Co.; Lakeview; Lundy's; Maple River Brand; Margherita; Mohawk Packing; Mohawk Provision, Inc.; Moseys; Moyer Packing Co.; Northside Foods; OhSe; Partridge Meats, Inc.; Patrick Cudahy; Patrick Cudahy, LLC; Peyton Packing Co., Inc.; Pine Ridge Farms; Premium Farms; Premium Pet Health; Premium Standard Farms; Pruden Packing Co.; Pure Farms; Quick-To-Fix; Racorn, Inc.; Rath Blackhawk, Inc.; Rodeo Meats; Rodeo Meats, Inc.; Roegelein; Saag's Products, LLC; Selective Petfood Services, Inc.; Smithfield; Smithfield Farmland Corp; Smithfield Farmland Sales Corp.; Smithfield Foods; Smithfield Foods, Inc.; Smithfield Fresh Meats; Smithfield Fresh Meats Corp.; Smithfield Fresh Meats Sales Corp.; Smithfield Packaged Meats Corp.; Smithfield Packaged Meats Sales Corp.; Smithfield Packing Co.; Smithfield Pet; Spring Hill Brand; Stefano Foods; Stefano's; Sweet Applewood Farms, Inc; The Smithfield Packing Co., Incorporated; Tiffany Springs Packing Co.; Tobin's First Prize Meat Co., Inc.; Valleydale, Inc.; Village Butcher; Windsor","address":"15855 Highway 87 West","city":"Tar Heel","state":"NC","zip":"28392","size":"Large","grant_date":"2021-05-28","county":"Bladen County","latitude":34.746813785633,"longitude":-78.803299553135,"activities":"Meat Processing; Meat Slaughter","parent_company":"Smithfield Foods","recalls":0,"public_health_alerts":0,"latest_recall":null,"inspection_tasks":676,"noncompliance_records":3,"memoranda_of_interview":1,"residue_violations":0,"salmonella":null,"record_url":"https:\/\/farmanimaltransparency.com\/processor\/18079\/#est-728","data_dates":{"mpi_data_date":"2026-10-06","salmonella_period":"Sample Collection Period August 31, 2025 through August 29, 2026","inspection_task_quarters":{"GCP":["FY2026Q3","FY2026Q2"],"LHH":["FY2026Q3","FY2026Q2"]}}},{"establishment_id":"6162299","establishment_number":"V18079","name":"Smithfield Fresh Meats Corp.","dba":"","address":"15855 HIGHWAY 87 WEST","city":"TAR HEEL","state":"NC","zip":"28392","size":"N \/ A","grant_date":"2021-11-30","county":"Bladen County","latitude":34.746813785633,"longitude":-78.803299553135,"activities":"Certification - Export; Identification - Meat","parent_company":"Smithfield Foods","recalls":0,"public_health_alerts":0,"latest_recall":null,"inspection_tasks":0,"noncompliance_records":0,"memoranda_of_interview":0,"residue_violations":0,"salmonella":null,"record_url":"https:\/\/farmanimaltransparency.com\/processor\/18079\/#est-6162299","data_dates":{"mpi_data_date":"2026-10-06","salmonella_period":"Sample Collection Period August 31, 2025 through August 29, 2026","inspection_task_quarters":{"GCP":["FY2026Q3","FY2026Q2"],"LHH":["FY2026Q3","FY2026Q2"]}}}],"note":"This number belongs to more than one FSIS establishment. Match the full number and the city on the package's USDA mark of inspection."}''';
const r79 = r'''{"query":"79","mode":"number","count":2,"establishments":[{"establishment_id":"123521","establishment_number":"I79","name":"Palama Holdings LLC","dba":"","address":"2029 Lauwiliwili Street","city":"Kapolei","state":"HI","zip":"96707","size":"N \/ A","grant_date":"2022-02-11","county":"Honolulu County","latitude":21.323577017208,"longitude":-158.091230019038,"activities":"Imported Product","parent_company":null,"recalls":0,"public_health_alerts":0,"latest_recall":null,"inspection_tasks":0,"noncompliance_records":0,"memoranda_of_interview":0,"residue_violations":0,"salmonella":null,"record_url":"https:\/\/farmanimaltransparency.com\/processor\/79\/#est-123521","data_dates":{"mpi_data_date":"2026-10-06","salmonella_period":"Sample Collection Period August 31, 2025 through August 29, 2026","inspection_task_quarters":{"GCP":["FY2026Q3","FY2026Q2"],"LHH":["FY2026Q3","FY2026Q2"]}}},{"establishment_id":"555","establishment_number":"M79C","name":"Smithfield Packaged Meats Corp.","dba":"814 America; Aberdeen; Agar Foods; American Farms; Ark Valley; Armour; Armour Food Company; Armour-Eckrich Meats LLC; Carando; Clougherty Packing, LLC; Cook's Ham; Cook's Ham, Inc.; Country Lean; Curly's; Curly's Foods; Decker Food Company; Eastbay Packing Co.; Eckrich; FJ Foodservice, LLC; Farmer John; Farmland; Farmland Foods, Inc.; Farmstead; Golden Crisp Premium Foods; Gwaltney; Healthy Ones; Hunter Krey Packing Co.; Hunter Packing Co.; Jamestown; John Morrell; John Morrell & Co.; Kneip; Krakus; Krakus Foods International; Kretschmar; Kretschmar Brands, Inc.; Kretschmar Deli; Krey Packing Co.; Lakeview; Lundy's; Maple River Brand; Margherita; Mohawk Packing; Mohawk Provision, Inc.; Moseys; Moyer Packing Co.; Northside Foods; OhSe; Partridge Meats, Inc.; Patrick Cudahy; Patrick Cudahy, LLC; Peyton Packing Co., Inc.; Premium Farms; Premium Pet Health; Premium Standard Farms; Pruden Packing Co.; Pure Farms; Quick-To-Fix; Racorn, Inc.; Rath Blackhawk, Inc.; Rodeo Meats; Rodeo Meats, Inc.; Roegelein; Saag's Products, LLC; Selective Petfood Services, Inc.; Smithfield; Smithfield Farmland Corp.; Smithfield Farmland Sales Corp.; Smithfield Foods; Smithfield Foods, Inc.; Smithfield Fresh Meats; Smithfield Fresh Meats Corp.; Smithfield Fresh Meats Sales Corp.; Smithfield Packaged Meats Corp.; Smithfield Packaged Meats Sales Corp.; Smithfield Packing Co.; Smithfield Pet; Spring Hill Brand; Stefano Foods; Stefano's; Sweet Applewood Farms, Inc.; The Smithfield Packing Co., Incorporated; Tiffany Springs Packing Co.; Tobin's First Prize Meat Co., Inc.; Valleydale, Inc.; Village Butcher; Windsor","address":"2401 Wilco Blvd.","city":"Wilson","state":"NC","zip":"27893","size":"Large","grant_date":"2021-06-16","county":"Wilson County","latitude":35.693528626903,"longitude":-77.919940835759,"activities":"Meat Processing","parent_company":"Smithfield Foods","recalls":0,"public_health_alerts":0,"latest_recall":null,"inspection_tasks":0,"noncompliance_records":0,"memoranda_of_interview":0,"residue_violations":0,"salmonella":null,"record_url":"https:\/\/farmanimaltransparency.com\/processor\/79\/#est-555","data_dates":{"mpi_data_date":"2026-10-06","salmonella_period":"Sample Collection Period August 31, 2025 through August 29, 2026","inspection_task_quarters":{"GCP":["FY2026Q3","FY2026Q2"],"LHH":["FY2026Q3","FY2026Q2"]}}}],"note":"This number belongs to more than one FSIS establishment. Match the full number and the city on the package's USDA mark of inspection."}''';

EstablishmentsResponse resp(String s) => EstablishmentsService.decode(s)!;

FATResult meat(String species,
    {String est = '413',
    bool prepared = false,
    ProductType type = ProductType.meat}) {
  final cats = <FATCategory, FATCategoryResult>{
    for (final c in FATCategory.values) c: FATCategoryResult.missing,
  };
  cats[FATCategory.species] =
      FATCategoryResult(status: DisclosureStatus.known, value: species);
  cats[FATCategory.processor] =
      FATCategoryResult(status: DisclosureStatus.known, value: 'EST. $est');
  return FATResult(
      scannedText: '${species.toUpperCase()} EST. $est',
      categories: cats,
      detectedEstablishmentNumber: est,
      isPreparedFood: prepared,
      productType: type);
}

ScanOutcome outcome(String json, String mark) =>
    EstablishmentsService.scanOutcome(null, mark, resp(json));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await FsisPlantNames.ensureLoaded();
  });

  test('pork + resolved NC plant → shown', () {
    final o = outcome(r413, '413');
    expect(o.record, isNotNull);
    expect(o.shared, isEmpty);
    expect(o.record!.resolvedPlant?.state, 'NC');
    expect(NcHogLagoonNotice.applies(meat('Pork'), processor: o.record), isTrue);
  });

  test('pork + non-NC plant → not shown', () {
    final o = outcome(r245C, '245C');
    expect(o.record!.resolvedPlant?.state, 'NE');
    expect(
        NcHogLagoonNotice.applies(meat('Pork', est: '245'), processor: o.record),
        isFalse);
  });

  test('beef + NC plant → not shown', () {
    final o = outcome(r413, '413');
    expect(NcHogLagoonNotice.applies(meat('Beef'), processor: o.record), isFalse);
  });

  test('prepared-food lane and seafood → not shown', () {
    final o = outcome(r413, '413');
    expect(
        NcHogLagoonNotice.applies(meat('Pork', prepared: true),
            processor: o.record),
        isFalse);
    expect(
        NcHogLagoonNotice.applies(meat('Pork', type: ProductType.seafood),
            processor: o.record),
        isFalse);
  });

  test('ambiguous shared number, all NC → shown', () {
    final o = outcome(r18079, '18079');
    expect(o.record, isNull);
    expect(o.shared.length, 2);
    expect(
        NcHogLagoonNotice.applies(meat('Pork', est: '18079'), shared: o.shared),
        isTrue);
  });

  test('ambiguous shared number, mixed states → not shown', () {
    final plants = resp(r79).establishments;
    expect(plants.map((p) => p.state).toSet(), {'HI', 'NC'});
    expect(
        NcHogLagoonNotice.applies(meat('Pork', est: '79'), shared: plants),
        isFalse);
  });

  test('no plant → not shown', () {
    expect(NcHogLagoonNotice.applies(meat('Pork')), isFalse);
    expect(NcHogLagoonNotice.applies(meat('Pork'), offlineMark: '  '), isFalse);
  });

  test('offline: bundled FSIS map state for the mark', () {
    expect(NcHogLagoonNotice.plantState(null, '413'), 'NC');
    expect(NcHogLagoonNotice.applies(meat('Pork'), offlineMark: '413'), isTrue);
    expect(
        NcHogLagoonNotice.applies(meat('Pork', est: '245'), offlineMark: '245C'),
        isFalse);
  });

  test('statuses and count unchanged with vs without the card', () {
    final o = outcome(r413, '413');
    final r = meat('Pork');
    final before = FATCategory.values.map((c) => r.categories[c]?.status).toList();
    final countBefore = r.knownCount;
    expect(NcHogLagoonNotice.applies(r, processor: o.record), isTrue);
    expect(FATCategory.values.map((c) => r.categories[c]?.status).toList(), before);
    expect(r.knownCount, countBefore);
    expect(meat('Pork', est: '245').knownCount, countBefore);
  });

  test('copy: banned words absent; permit sentence in body and share text', () {
    final all = [
      NcHogLagoonNotice.title,
      NcHogLagoonNotice.body,
      NcHogLagoonNotice.caveat,
      NcHogLagoonNotice.sourceLabel,
      NcHogLagoonNotice.permitListLabel,
      NcHogLagoonNotice.nassLabel,
      NcHogLagoonNotice.courtLabel,
    ].join(' ').toLowerCase();
    for (final w in [
      'score', 'grade', 'avoid', 'fails', 'poor', 'hides', 'conceals',
      'refuses', 'unsafe', 'unhealthy'
    ]) {
      expect(RegExp('\\b$w\\b').hasMatch(all), isFalse, reason: w);
    }
    expect(
        NcHogLagoonNotice.body.contains(
            "so existing lagoon farms continue to operate. NC DEQ's April 2026 list of permitted animal facilities includes 1,962 swine permits, 1,944 of them with at least one lagoon, permitted for about 8.7 million hogs at a time. North Carolina had 7.20 million hogs on June 1, 2026, the third most of any state. In October 2025 the N.C. Supreme Court ruled that DEQ could not enforce the swine general permit's annual reporting requirement without formal rulemaking."),
        isTrue);
    expect(NcHogLagoonNotice.body.endsWith('without formal rulemaking.'), isTrue);
    expect(NcHogLagoonNotice.body.contains('1,880'), isFalse);
    expect(NcHogLagoonNotice.nassUrl,
        'https://www.nass.usda.gov/Newsroom/2026/06-25-2026.php');
    expect(NcHogLagoonNotice.courtUrl,
        'https://appellate.nccourts.org/opinions/?c=1&pdf=45263');
    expect(NcHogLagoonNotice.caveat,
        "The package doesn't say which farm raised this pork. The plant's location is only a clue: hogs can travel long distances to slaughter.");
    expect(NcHogLagoonNotice.shareParagraph.contains(NcHogLagoonNotice.body), isTrue);
    expect(NcHogLagoonNotice.shareParagraph.contains(NcHogLagoonNotice.caveat), isTrue);
  });
}
