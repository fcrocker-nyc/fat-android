/*!
 * FAT Pork Maps — renderer for farmanimaltransparency.com
 * Farm Animal Transparency (FAT) · farmanimaltransparency.com
 *
 * Reads every figure from fat_pork_data.json. Nothing in this file hard-codes a
 * metric, and every ratio and share is computed here rather than typed. To change
 * a number, edit the JSON — never this file, and never the page.
 *
 * Usage in an Elementor HTML widget (or any page):
 *   <div data-fat-pork-map="enforcement"></div>
 *   <script src="https://cdnjs.cloudflare.com/ajax/libs/d3/7.8.5/d3.min.js"></script>
 *   <script src="https://cdnjs.cloudflare.com/ajax/libs/topojson/3.0.2/topojson.min.js"></script>
 *   <script src="https://cdn.jsdelivr.net/gh/fcrocker-nyc/fat-android@main/pork/fat_pork_maps.js"></script>
 *
 * Views: "enforcement" | "integrated" | "supply"
 */
(function () {
  'use strict';

  var DATA_URL = 'https://cdn.jsdelivr.net/gh/fcrocker-nyc/fat-android@main/pork/fat_pork_data.json';
  var ATLAS_URL = 'https://cdn.jsdelivr.net/npm/us-atlas@3/states-10m.json';

  // ---------------------------------------------------------------- palette
  // Sequential ramp for inventory; categorical for permit regime; status colors
  // for the legal-authority view. Chosen to stay legible in both themes.
  var RAMP = ['#F2E9DC', '#E8CFA9', '#DDAE6E', '#C9853C', '#A85D20', '#7A3D12'];
  var NO_DATA_LIGHT = '#D3D1C7';
  var NO_DATA_DARK = '#4A4844';

  var REGIME = {
    state_only: { color: '#7A3D12', label: 'State-only permit is the default' },
    both: { color: '#C9853C', label: 'Both — state-only default, NPDES on discharge' },
    npdes: { color: '#2E6B8A', label: 'NPDES is the primary instrument' },
    unknown: { color: '#9A9791', label: 'Not determined' }
  };

  var STATUS = {
    unenforceable: { color: '#B3261E', label: 'Struck — unenforceable' },
    repealed: { color: '#7A1710', label: 'Repealed' },
    exempt: { color: '#B3261E', label: 'Statutory exemption' },
    exempt_on_appeal: { color: '#C9853C', label: 'Exempt — on appeal' },
    stalled: { color: '#C9853C', label: 'Stalled' },
    not_initiated: { color: '#8A6A2F', label: 'Not initiated' },
    open: { color: '#2E6B8A', label: 'Open proceeding' }
  };

  // ---------------------------------------------------------------- helpers
  function isDark() {
    try { return window.matchMedia('(prefers-color-scheme: dark)').matches; }
    catch (e) { return false; }
  }
  function noDataColor() { return isDark() ? NO_DATA_DARK : NO_DATA_LIGHT; }

  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }

  function num(n, digits) {
    if (n == null || isNaN(n)) return '—';
    return Number(n).toLocaleString('en-US', {
      minimumFractionDigits: digits || 0,
      maximumFractionDigits: digits == null ? 0 : digits
    });
  }

  // Thousand-head to a readable million-head string.
  function headM(thousands) {
    if (thousands == null) return '—';
    return num(thousands / 1000, 2) + 'M';
  }

  function fmtDate(iso) {
    if (!iso) return '';
    var p = String(iso).split('-');
    var months = ['January', 'February', 'March', 'April', 'May', 'June', 'July',
      'August', 'September', 'October', 'November', 'December'];
    if (p.length === 1) return p[0];
    var m = months[parseInt(p[1], 10) - 1] || '';
    if (p.length === 2) return m + ' ' + p[0];
    return m + ' ' + parseInt(p[2], 10) + ', ' + p[0];
  }

  // Resolve a {value, source, ...} metric to its source record.
  function srcOf(data, metric) {
    if (!metric) return null;
    if (metric.needs_source) return { __needs: true };
    var key = metric.source;
    if (!key) return null;
    return data.sources[key] || null;
  }

  function sourceChip(data, metric) {
    var s = srcOf(data, metric);
    if (!s) return '';
    if (s.__needs) {
      return '<span class="fat-chip fat-chip-warn" title="This figure has no citation and should not be treated as verified.">source needed</span>';
    }
    var t = s.type === 'primary' ? 'primary' : (s.type === 'fat' ? 'FAT' : 'press');
    return '<a class="fat-chip fat-chip-' + esc(s.type) + '" href="' + esc(s.url) +
      '" target="_blank" rel="noopener noreferrer" title="' + esc(s.label) + '">' + esc(t) + '</a>';
  }

  // Public-facing explanatory text. `basis` may carry internal editorial
  // instructions, so `public_note` wins whenever it is present.
  function pub(metric) {
    if (!metric) return '';
    return metric.public_note || metric.basis || '';
  }

  function card(label, value, sub, chip, tone) {
    return '<div class="fat-card' + (tone ? ' fat-card-' + tone : '') + '">' +
      '<p class="fat-card-label">' + esc(label) + '</p>' +
      '<p class="fat-card-value">' + value + '</p>' +
      (sub ? '<p class="fat-card-sub">' + sub + '</p>' : '') +
      (chip ? '<p class="fat-card-chip">' + chip + '</p>' : '') +
      '</div>';
  }

  // ---------------------------------------------------------------- styles
  var CSS = [
    '.fat-wrap{--fat-bg:#fff;--fat-fg:#111;--fat-muted:#666;--fat-line:rgba(0,0,0,.15);--fat-panel:#f6f4f0;font:14px/1.5 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;color:var(--fat-fg)}',
    '@media (prefers-color-scheme:dark){.fat-wrap{--fat-bg:#1b1a18;--fat-fg:#ece9e4;--fat-muted:#a5a09a;--fat-line:rgba(255,255,255,.16);--fat-panel:#232120}}',
    '.fat-panel{background:var(--fat-bg);border:.5px solid var(--fat-line);border-radius:12px;padding:16px 20px;margin-bottom:16px}',
    '.fat-head{display:flex;justify-content:space-between;align-items:flex-start;gap:16px;flex-wrap:wrap;margin-bottom:14px}',
    '.fat-h2{font-size:18px;font-weight:600;margin:0 0 4px}',
    '.fat-h3{font-size:15px;font-weight:600;margin:0 0 10px}',
    '.fat-sub{font-size:13px;color:var(--fat-muted);margin:0}',
    '.fat-asof{font-size:12px;color:var(--fat-muted);margin:0;text-align:right}',
    '.fat-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(160px,1fr));gap:12px;margin-bottom:14px}',
    '.fat-card{background:var(--fat-panel);border-radius:8px;padding:12px 14px}',
    '.fat-card-warn{outline:1px solid #C9853C}',
    '.fat-card-label{font-size:12px;color:var(--fat-muted);margin:0 0 4px;text-transform:uppercase;letter-spacing:.04em}',
    '.fat-card-value{font-size:26px;font-weight:600;margin:0;line-height:1.15}',
    '.fat-card-sub{font-size:12px;color:var(--fat-muted);margin:6px 0 0}',
    '.fat-card-chip{margin:8px 0 0}',
    '.fat-chip{display:inline-block;font-size:10px;letter-spacing:.06em;text-transform:uppercase;padding:2px 7px;border-radius:999px;text-decoration:none;border:.5px solid var(--fat-line);color:var(--fat-muted)}',
    '.fat-chip-primary{color:#2E6B8A;border-color:#2E6B8A}',
    '.fat-chip-secondary{color:#8A6A2F;border-color:#8A6A2F}',
    '.fat-chip-fat{color:#7A3D12;border-color:#7A3D12}',
    '.fat-chip-warn{color:#B3261E;border-color:#B3261E}',
    '.fat-note{border-left:3px solid #C9853C;background:var(--fat-panel);border-radius:0 8px 8px 0;padding:12px 14px;margin:0 0 16px}',
    '.fat-note-title{font-size:13px;font-weight:600;margin:0 0 6px}',
    '.fat-note-body{font-size:13px;color:var(--fat-muted);margin:0}',
    '.fat-btns{display:flex;gap:8px;flex-wrap:wrap;margin-bottom:4px}',
    '.fat-btn{font:inherit;font-size:13px;padding:7px 13px;border-radius:6px;cursor:pointer;background:transparent;color:var(--fat-fg);border:.5px solid var(--fat-line)}',
    '.fat-btn[aria-pressed="true"]{background:#7A3D12;color:#fff;border-color:#7A3D12}',
    '.fat-legend{display:flex;flex-wrap:wrap;gap:14px;font-size:12px;color:var(--fat-muted);margin:10px 0 0}',
    '.fat-legend span.k{display:inline-flex;align-items:center;gap:6px}',
    '.fat-sw{width:11px;height:11px;border-radius:2px;display:inline-block;flex:0 0 auto}',
    '.fat-map svg{width:100%;height:auto;display:block}',
    '.fat-tablewrap{overflow-x:auto;-webkit-overflow-scrolling:touch}',
    '.fat-table{width:100%;border-collapse:collapse;font-size:13px;min-width:520px}',
    '.fat-table th,.fat-table td{text-align:left;padding:8px 10px;border-bottom:.5px solid var(--fat-line);vertical-align:top}',
    '.fat-table th{font-size:11px;text-transform:uppercase;letter-spacing:.04em;color:var(--fat-muted);font-weight:600}',
    '.fat-table td.n{text-align:right;font-variant-numeric:tabular-nums}',
    '.fat-mech{display:grid;gap:10px}',
    '.fat-mech-row{display:grid;grid-template-columns:minmax(0,1.3fr) minmax(0,2fr) auto;gap:12px;align-items:start;padding:10px 0;border-bottom:.5px solid var(--fat-line)}',
    '@media (max-width:640px){.fat-mech-row{grid-template-columns:1fr}}',
    '.fat-mech-name{font-weight:600;font-size:13px;margin:0}',
    '.fat-mech-scope{font-size:12px;color:var(--fat-muted);margin:3px 0 0}',
    '.fat-mech-detail{font-size:13px;color:var(--fat-muted);margin:0}',
    '.fat-pill{display:inline-block;font-size:11px;font-weight:600;padding:3px 9px;border-radius:999px;color:#fff;white-space:nowrap}',
    '.fat-err{border:.5px solid #B3261E;border-radius:12px;padding:16px 20px;font-size:13px}',
    '.fat-foot{font-size:12px;color:var(--fat-muted);margin:14px 0 0}',
    '.fat-foot a{color:inherit}'
  ].join('\n');

  function injectCSS() {
    if (document.getElementById('fat-pork-css')) return;
    var st = document.createElement('style');
    st.id = 'fat-pork-css';
    st.textContent = CSS;
    document.head.appendChild(st);
  }

  // ---------------------------------------------------------------- choropleth
  // mode: "inventory" | "regime"
  function drawMap(container, data, mode) {
    if (!window.d3 || !window.topojson) {
      container.innerHTML = '<p class="fat-sub">Map library unavailable.</p>';
      return;
    }
    var byName = {};
    data.states.forEach(function (s) { byName[s.name] = s; });

    var maxInv = d3.max(data.states, function (s) { return s.inventory; });
    var scale = d3.scaleQuantize().domain([0, maxInv]).range(RAMP);

    container.innerHTML = '';
    var svg = d3.select(container).append('svg')
      .attr('viewBox', '0 0 900 540')
      .attr('role', 'img')
      .attr('aria-label', mode === 'regime'
        ? 'US map shaded by swine permit regime'
        : 'US map shaded by hog inventory');

    var path = d3.geoPath(d3.geoAlbersUsa().scale(1120).translate([450, 270]));

    d3.json(ATLAS_URL).then(function (us) {
      var feats = topojson.feature(us, us.objects.states).features;
      svg.selectAll('path').data(feats).join('path')
        .attr('d', path)
        .attr('stroke', isDark() ? 'rgba(255,255,255,.18)' : '#fff')
        .attr('stroke-width', 0.8)
        .attr('fill', function (d) {
          var s = byName[d.properties.name];
          if (!s) return noDataColor();
          if (mode === 'regime') return (REGIME[s.permit_regime] || REGIME.unknown).color;
          return scale(s.inventory);
        })
        .append('title')
        .text(function (d) {
          var s = byName[d.properties.name];
          if (!s) return d.properties.name + '\nNot separately published by NASS';
          var lines = [s.name, headM(s.inventory) + ' head (June 1, 2026)'];
          lines.push((REGIME[s.permit_regime] || REGIME.unknown).label);
          if (s.permit_program) lines.push(s.permit_program);
          return lines.join('\n');
        });
    }).catch(function () {
      container.innerHTML = '<p class="fat-sub">Base map could not be loaded.</p>';
    });
  }

  function legendFor(mode, data) {
    if (mode === 'regime') {
      var keys = ['state_only', 'both', 'npdes', 'unknown'];
      return '<div class="fat-legend">' + keys.map(function (k) {
        return '<span class="k"><span class="fat-sw" style="background:' + REGIME[k].color +
          '"></span>' + esc(REGIME[k].label) + '</span>';
      }).join('') +
        '<span class="k"><span class="fat-sw" style="background:' + noDataColor() +
        '"></span>Not separately published</span></div>';
    }
    var maxInv = Math.max.apply(null, data.states.map(function (s) { return s.inventory; }));
    var step = maxInv / RAMP.length;
    return '<div class="fat-legend">' + RAMP.map(function (c, i) {
      var lo = i * step, hi = (i + 1) * step;
      var lbl = i === 0 ? 'under ' + headM(hi)
        : (i === RAMP.length - 1 ? headM(lo) + ' and above'
          : headM(lo) + ' \u2013 ' + headM(hi));
      return '<span class="k"><span class="fat-sw" style="background:' + c + '"></span>' +
        lbl + '</span>';
    }).join('') +
      '<span class="k"><span class="fat-sw" style="background:' + noDataColor() +
      '"></span>Not separately published</span></div>';
  }

  function stateTable(data) {
    var rows = data.states.slice().sort(function (a, b) { return b.inventory - a.inventory; });
    var body = rows.map(function (s) {
      var r = REGIME[s.permit_regime] || REGIME.unknown;
      return '<tr><td>' + esc(s.name) + '</td>' +
        '<td class="n">' + headM(s.inventory) + '</td>' +
        '<td><span class="fat-pill" style="background:' + r.color + '">' + esc(r.label) + '</span></td>' +
        '<td>' + (s.permit_program
          ? (s.regime_source
            ? '<a href="' + esc(s.regime_source) + '" target="_blank" rel="noopener noreferrer">' + esc(s.permit_program) + '</a>'
            : esc(s.permit_program))
          : '<span class="fat-sub">Not determined</span>') +
        (s.regime_note ? '<br><span class="fat-sub">' + esc(s.regime_note) + '</span>' : '') +
        '</td></tr>';
    }).join('');

    var other = data.states_not_separately_published;
    var otherRow = '<tr><td><em>All other states</em></td><td class="n">' + headM(other.inventory) +
      '</td><td colspan="2"><span class="fat-sub">' +
      esc(other.public_note || other.basis) + '</span></td></tr>';

    return '<div class="fat-tablewrap"><table class="fat-table">' +
      '<thead><tr><th>State</th><th style="text-align:right">Hogs, June 1 2026</th>' +
      '<th>Permit regime</th><th>Program</th></tr></thead>' +
      '<tbody>' + body + otherRow + '</tbody></table></div>';
  }

  function permitWarning(data) {
    var w = data.permit_regime_warning;
    return '<div class="fat-note"><p class="fat-note-title">' + esc(w.headline) + '</p>' +
      '<p class="fat-note-body">' + esc(w.body) + '</p></div>';
  }

  function footer(data) {
    var b = data.sources.fat_nc_briefing;
    return '<p class="fat-foot">Data last updated ' + esc(fmtDate(data.updated)) +
      '. Every figure on this page is drawn from a single published data file; ' +
      'ratios are computed, not entered. ' +
      (b ? 'Background: <a href="' + esc(b.url) + '" target="_blank" rel="noopener noreferrer">' +
        esc(b.label) + '</a>.' : '') + '</p>';
  }

  // ---------------------------------------------------------------- views
  function viewEnforcement(el, data) {
    var e = data.nc_enforcement;
    var c = data.nc_facility_counts;

    // COMPUTED — never typed.
    var ratio = e.operations_covered.value / e.inspectors.value;
    var ratioAlt = c.deq_reported_all_operations.value / e.inspectors.value;
    var vioPct = e.violation_rate.value * 100;
    var vioCount = Math.round(e.complaints_investigated.value * e.violation_rate.value);

    var html = '<div class="fat-wrap">';

    html += '<div class="fat-panel"><div class="fat-head"><div>' +
      '<h2 class="fat-h2">North Carolina swine enforcement</h2>' +
      '<p class="fat-sub">Permitted facilities, inspection capacity, and complaint outcomes</p></div>' +
      '<div><p class="fat-asof">NC DEQ complaint records<br>' +
      esc(fmtDate(e.complaint_window.start)) + ' – ' + esc(fmtDate(e.complaint_window.end)) +
      '</p></div></div>';

    html += '<div class="fat-grid">';
    html += card('Permitted swine operations', num(c.active_swine_permits.value),
      esc(pub(c.active_swine_permits)), sourceChip(data, c.active_swine_permits));
    html += card('Inspection staff', num(e.inspectors.value),
      esc(pub(e.inspectors)), sourceChip(data, e.inspectors));
    html += card('Operations per inspector', num(ratio, 0) + ':1',
      'All ' + num(e.operations_covered.value) + ' permitted operations these inspectors cover — ' +
      'swine, cattle and wet-litter poultry — divided by ' + num(e.inspectors.value) +
      '. On DEQ&rsquo;s own all-operations count the figure is ' + num(ratioAlt, 0) +
      ':1. Both understate the load, because these staff also work other programs.',
      sourceChip(data, e.operations_covered));
    html += card('Complaints investigated', num(e.complaints_investigated.value),
      'Violations found in about ' + num(vioPct, 0) + '% of cases — roughly ' + num(vioCount) +
      ' verified. NC DEQ complaint records, not EPA ECHO.', sourceChip(data, e.complaints_investigated));
    html += '</div>';

    html += '<div class="fat-note"><p class="fat-note-title">What the complaint count does and does not show</p>' +
      '<p class="fat-note-body">' + esc(e.confidentiality_note) + ' ' + esc(e.unpermitted_gap_note) +
      '</p></div>';
    html += '</div>';

    // Legal authority summary — the point the old map missed entirely.
    var la = data.nc_legal_authority;
    html += '<div class="fat-panel"><h3 class="fat-h3">' + esc(la.headline) + '</h3>' +
      '<p class="fat-sub" style="margin-bottom:12px">' + esc(la.body) + '</p>' +
      '<div class="fat-mech">';
    la.mechanisms.forEach(function (m) {
      var st = STATUS[m.status] || { color: '#9A9791', label: m.status };
      var s = data.sources[m.source];
      html += '<div class="fat-mech-row"><div>' +
        '<p class="fat-mech-name">' + esc(m.name) + '</p>' +
        '<p class="fat-mech-scope">' + esc(m.scope) + '</p></div>' +
        '<p class="fat-mech-detail">' + esc(m.detail) +
        (s ? ' <a class="fat-chip fat-chip-' + esc(s.type) + '" href="' + esc(s.url) +
          '" target="_blank" rel="noopener noreferrer">source</a>' : '') + '</p>' +
        '<div><span class="fat-pill" style="background:' + st.color + '">' + esc(st.label) + '</span>' +
        '<p class="fat-mech-scope">' + esc(fmtDate(m.date)) + '</p></div></div>';
    });
    html += '</div></div>';

    // Counts reconciliation — honest about the four disagreeing numbers.
    var countKeys = ['active_swine_permits', 'all_swine_permits', 'deq_reported_swine_facilities',
      'deq_reported_all_operations', 'digester_permits'].filter(function (k) { return c[k]; });
    var words = ['Zero', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight'];
    html += '<div class="fat-panel"><h3 class="fat-h3">' +
      (words[countKeys.length] || countKeys.length) + ' counts, none reconciling</h3>' +
      '<div class="fat-tablewrap"><table class="fat-table"><thead><tr>' +
      '<th>Count</th><th style="text-align:right">Value</th><th>What it counts</th><th>As of</th>' +
      '</tr></thead><tbody>';
    countKeys.forEach(function (k) {
      var m = c[k];
      html += '<tr><td>' + esc(m.label || k.replace(/_/g, ' ')) + ' ' + sourceChip(data, m) + '</td>' +
        '<td class="n">' + num(m.value) + '</td><td>' + esc(m.basis) + '</td>' +
        '<td>' + esc(fmtDate(m.asof)) + '</td></tr>';
    });
    html += '</tbody></table></div>' +
      '<p class="fat-foot">' + esc(c.reconciliation_gap.note) + '</p></div>';

    html += permitWarning(data);
    html += footer(data) + '</div>';

    el.innerHTML = html;
  }

  function viewSupply(el, data) {
    var n = data.national;
    var html = '<div class="fat-wrap">';

    html += '<div class="fat-panel"><div class="fat-head"><div>' +
      '<h2 class="fat-h2">U.S. hog inventory and permit architecture</h2>' +
      '<p class="fat-sub">Where the hogs are, and what kind of permit each state issues</p></div>' +
      '<div><p class="fat-asof">USDA NASS<br>June 1, 2026</p></div></div>';

    html += '<div class="fat-grid">';
    html += card('All hogs and pigs', headM(n.inventory_total.value), esc(pub(n.inventory_total)),
      sourceChip(data, n.inventory_total));
    html += card('Market hogs', headM(n.inventory_market.value), esc(pub(n.inventory_market)),
      sourceChip(data, n.inventory_market));
    html += card('Breeding hogs', headM(n.inventory_breeding.value), esc(pub(n.inventory_breeding)),
      sourceChip(data, n.inventory_breeding));
    html += '</div>';

    html += '<div class="fat-btns" role="group" aria-label="Map layer">' +
      '<button class="fat-btn" type="button" data-mode="inventory" aria-pressed="true">Hog inventory</button>' +
      '<button class="fat-btn" type="button" data-mode="regime" aria-pressed="false">Permit regime</button>' +
      '</div>';
    html += '<div class="fat-map" id="fat-map-supply"></div>';
    html += '<div id="fat-legend-supply"></div>';
    html += '</div>';

    html += permitWarning(data);
    html += '<div class="fat-panel"><h3 class="fat-h3">States NASS publishes individually</h3>' +
      stateTable(data) + '</div>';
    html += footer(data) + '</div>';

    el.innerHTML = html;

    var mapEl = el.querySelector('#fat-map-supply');
    var legEl = el.querySelector('#fat-legend-supply');
    function set(mode) {
      drawMap(mapEl, data, mode);
      legEl.innerHTML = legendFor(mode, data);
      Array.prototype.forEach.call(el.querySelectorAll('.fat-btn[data-mode]'), function (b) {
        b.setAttribute('aria-pressed', String(b.getAttribute('data-mode') === mode));
      });
    }
    Array.prototype.forEach.call(el.querySelectorAll('.fat-btn[data-mode]'), function (b) {
      b.addEventListener('click', function () { set(b.getAttribute('data-mode')); });
    });
    set('inventory');
  }

  function viewIntegrated(el, data) {
    var n = data.national, o = data.ownership, ig = data.integration, b = data.biogas;
    var html = '<div class="fat-wrap">';

    html += '<div class="fat-panel"><div class="fat-head"><div>' +
      '<h2 class="fat-h2">U.S. pork — integrated analysis</h2>' +
      '<p class="fat-sub">Inventory, permit architecture, legal authority, ownership and integration</p></div>' +
      '<div><p class="fat-asof">Updated ' + esc(fmtDate(data.updated)) + '</p></div></div>';

    html += '<div class="fat-btns" role="group" aria-label="Analysis layer">' +
      ['inventory|Hog inventory', 'regime|Permit regime', 'authority|Legal authority',
        'ownership|Ownership &amp; integration'].map(function (p, i) {
        var kv = p.split('|');
        return '<button class="fat-btn" type="button" data-layer="' + kv[0] + '" aria-pressed="' +
          (i === 0) + '">' + kv[1] + '</button>';
      }).join('') + '</div>';

    html += '<div id="fat-int-body"></div></div>';
    html += footer(data) + '</div>';
    el.innerHTML = html;

    var body = el.querySelector('#fat-int-body');

    function renderLayer(layer) {
      var h = '';
      if (layer === 'inventory' || layer === 'regime') {
        h += '<div class="fat-grid">' +
          card('All hogs and pigs', headM(n.inventory_total.value), esc(pub(n.inventory_total)),
            sourceChip(data, n.inventory_total)) +
          card('States published individually', num(data.states.length),
            'NASS aggregates the remaining states into a single figure of ' +
            headM(data.states_not_separately_published.inventory) + ' head.',
            sourceChip(data, n.inventory_total)) +
          card('Packer concentration', num(n.cr3_packers.value) + '%',
            esc(pub(n.cr3_packers)), sourceChip(data, n.cr3_packers), 'warn') +
          '</div>';
        h += '<div class="fat-map" id="fat-map-int"></div><div id="fat-legend-int"></div>';
        h += permitWarning(data);
        h += stateTable(data);
      } else if (layer === 'authority') {
        var la = data.nc_legal_authority;
        h += '<div class="fat-note"><p class="fat-note-title">' + esc(la.headline) + '</p>' +
          '<p class="fat-note-body">' + esc(la.body) + '</p></div>';
        h += '<div class="fat-mech">';
        la.mechanisms.forEach(function (m) {
          var st = STATUS[m.status] || { color: '#9A9791', label: m.status };
          var s = data.sources[m.source];
          h += '<div class="fat-mech-row"><div>' +
            '<p class="fat-mech-name">' + esc(m.name) + '</p>' +
            '<p class="fat-mech-scope">' + esc(m.scope) + '</p></div>' +
            '<p class="fat-mech-detail">' + esc(m.detail) +
            (s ? ' <a class="fat-chip fat-chip-' + esc(s.type) + '" href="' + esc(s.url) +
              '" target="_blank" rel="noopener noreferrer">source</a>' : '') + '</p>' +
            '<div><span class="fat-pill" style="background:' + st.color + '">' + esc(st.label) +
            '</span><p class="fat-mech-scope">' + esc(fmtDate(m.date)) + '</p></div></div>';
        });
        h += '</div>';
        var op = la.open_proceeding, ops = data.sources[op.source];
        h += '<div class="fat-note" style="border-left-color:' + STATUS.open.color + ';margin-top:16px">' +
          '<p class="fat-note-title">' + esc(op.name) + ' — ' + esc(STATUS.open.label) + '</p>' +
          '<p class="fat-note-body">' + esc(op.detail) +
          (ops ? ' <a class="fat-chip fat-chip-' + esc(ops.type) + '" href="' + esc(ops.url) +
            '" target="_blank" rel="noopener noreferrer">source</a>' : '') + '</p></div>';
        var ss = data.nc_statutory_structure;
        h += '<div style="margin-top:16px"><h3 class="fat-h3">Why the lagoons remain</h3>' +
          '<p class="fat-sub">' + esc(ss.moratorium.detail) + ' <a class="fat-chip fat-chip-primary" href="' +
          esc(data.sources[ss.moratorium.source].url) +
          '" target="_blank" rel="noopener noreferrer">' + esc(ss.moratorium.statute) + '</a></p></div>';
      } else if (layer === 'ownership') {
        var sm = o.smithfield;
        h += '<div class="fat-grid">' +
          card('Smithfield parent stake', num(sm.parent_stake_pct.value) + '%',
            esc(sm.parent) + ' (' + esc(sm.parent_domicile) + '), ' + esc(sm.parent_stake_pct.basis),
            sourceChip(data, sm.parent_stake_pct)) +
          card('U.S. listing', esc(sm.listing.ticker),
            esc(sm.listing.exchange) + ', since ' + esc(fmtDate(sm.listing.ipo_date)) + '. ' +
            esc(sm.listing.basis), sourceChip(data, sm.parent_stake_pct)) +
          card('Internal hog production', num(ig.smithfield_internal_production_head_m.value, 1) + 'M',
            'Down from ' + num(ig.smithfield_internal_production_prior_head_m.value, 1) +
            'M head the prior year — about ' + num(ig.smithfield_internal_share_pct.value) +
            '% of the hogs its Fresh Pork segment processes.',
            sourceChip(data, ig.smithfield_internal_production_head_m)) +
          card('Farms', num(ig.smithfield_company_owned_farms.value) + '+ / ' +
            num(ig.smithfield_contract_farms.value) + '+',
            'Company-owned and contract farms, United States.',
            sourceChip(data, ig.smithfield_contract_farms)) +
          '</div>';
        h += '<div class="fat-note"><p class="fat-note-title">Integration is loosening at the production end</p>' +
          '<p class="fat-note-body">' + esc(ig.note) + '</p></div>';
        h += '<h3 class="fat-h3">North Carolina divestitures</h3><div class="fat-tablewrap">' +
          '<table class="fat-table"><thead><tr><th>When</th><th>What</th></tr></thead><tbody>' +
          ig.nc_divestitures.map(function (d) {
            return '<tr><td>' + esc(fmtDate(d.date)) + '</td><td>' + esc(d.detail) + ' ' +
              sourceChip(data, d) + '</td></tr>';
          }).join('') + '</tbody></table></div>';
        h += '<div style="margin-top:16px"><h3 class="fat-h3">Biogas — the second revenue channel</h3>' +
          '<p class="fat-sub">' + esc(b.note) + '</p><div class="fat-tablewrap">' +
          '<table class="fat-table"><thead><tr><th>Project</th><th>Counties</th>' +
          '<th style="text-align:right">Farms</th><th style="text-align:right">Dth / yr</th></tr></thead><tbody>' +
          b.align_rng.projects.map(function (p) {
            return '<tr><td>' + esc(p.name) +
              (p.completion_estimate ? ' <span class="fat-sub">(est. ' + esc(p.completion_estimate) + ')</span>' : '') +
              '</td><td>' + esc(p.counties.join(', ')) + '</td>' +
              '<td class="n">' + num(p.farms) + '</td><td class="n">' + num(p.annual_dth) + '</td></tr>';
          }).join('') + '</tbody></table></div>' +
          '<p class="fat-foot">Certified CARB carbon intensity for dairy and swine manure biomethane runs from ' +
          num(b.lcfs_ci_range.low) + ' to ' + num(b.lcfs_ci_range.high) + ' ' + esc(b.lcfs_ci_range.unit) +
          ' on an avoided-methane basis. ' + esc(b.align_rng.disclosure_note) + ' ' +
          sourceChip(data, { source: 'carb_dsm_lcfs' }) + '</p></div>';

        var ld = data.label_disclosure;
        h += '<div class="fat-note" style="margin-top:16px"><p class="fat-note-title">' +
          esc(ld.headline) + '</p><p class="fat-note-body">' + esc(ld.body) + '</p></div>';
        h += '<div class="fat-tablewrap"><table class="fat-table"><thead><tr>' +
          '<th>FAT category</th><th>Why it is the only route to this information</th></tr></thead><tbody>' +
          ld.categories.map(function (c2) {
            return '<tr><td><strong>' + num(c2.number) + '. ' + esc(c2.name) + '</strong></td><td>' +
              esc(c2.why) + '</td></tr>';
          }).join('') + '</tbody></table></div>' +
          '<p class="fat-foot">' + esc(ld.asymmetry) + '</p>';
      }

      body.innerHTML = h;

      if (layer === 'inventory' || layer === 'regime') {
        var mode = layer === 'regime' ? 'regime' : 'inventory';
        drawMap(body.querySelector('#fat-map-int'), data, mode);
        body.querySelector('#fat-legend-int').innerHTML = legendFor(mode, data);
      }
      Array.prototype.forEach.call(el.querySelectorAll('.fat-btn[data-layer]'), function (bt) {
        bt.setAttribute('aria-pressed', String(bt.getAttribute('data-layer') === layer));
      });
    }

    Array.prototype.forEach.call(el.querySelectorAll('.fat-btn[data-layer]'), function (bt) {
      bt.addEventListener('click', function () { renderLayer(bt.getAttribute('data-layer')); });
    });
    renderLayer('inventory');
  }

  // ---------------------------------------------------------------- boot
  var VIEWS = { enforcement: viewEnforcement, integrated: viewIntegrated, supply: viewSupply };
  var cache = null;

  function fetchData() {
    if (cache) return cache;
    cache = fetch(DATA_URL, { cache: 'no-cache' }).then(function (r) {
      if (!r.ok) throw new Error('HTTP ' + r.status);
      return r.json();
    });
    return cache;
  }

  function render(el) {
    var view = el.getAttribute('data-fat-pork-map');
    var fn = VIEWS[view];
    if (!fn) {
      el.innerHTML = '<div class="fat-wrap"><div class="fat-err">Unknown map view "' +
        esc(view) + '".</div></div>';
      return;
    }
    injectCSS();
    el.innerHTML = '<div class="fat-wrap"><p class="fat-sub">Loading data&hellip;</p></div>';
    fetchData().then(function (data) {
      try { fn(el, data); }
      catch (err) {
        el.innerHTML = '<div class="fat-wrap"><div class="fat-err">This map could not be rendered. ' +
          esc(err && err.message ? err.message : String(err)) + '</div></div>';
      }
    }).catch(function (err) {
      el.innerHTML = '<div class="fat-wrap"><div class="fat-err">' +
        'The pork data file could not be loaded, so no figures are shown rather than stale ones. ' +
        esc(err && err.message ? err.message : String(err)) + '</div></div>';
    });
  }

  function boot() {
    var els = document.querySelectorAll('[data-fat-pork-map]');
    Array.prototype.forEach.call(els, render);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', boot);
  } else {
    boot();
  }

  window.FATPorkMaps = { render: render, boot: boot, dataUrl: DATA_URL };
})();
