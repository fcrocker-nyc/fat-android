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
 *   <script src="https://cdn.jsdelivr.net/gh/fcrocker-nyc/fat-android@<commit>/pork/fat_pork_maps.js"></script>
 *
 * Pin the script to a commit hash rather than @main: jsDelivr caches the branch
 * resolution and can serve a stale file for hours even after a purge, and
 * browsers cache @main for a long time. The data file follows the script's ref.
 *
 * Views: "enforcement" | "integrated" | "supply"
 *
 *   supply      — hog inventory by state (USDA NASS) with the permit-regime layer
 *                 and the full state table. The reference view for "where the hogs are".
 *   integrated  — what the supply view does NOT repeat: how much of the herd sits
 *                 outside federal records (computed from the regime layer), the
 *                 North Carolina legal record, ownership and integration, biogas,
 *                 and what reaches the label. It links to the supply view for the
 *                 inventory table rather than duplicating it.
 *   enforcement — swine enforcement, one state at a time. A selector at the top
 *                 lists the ten largest hog states; North Carolina renders from
 *                 the nc_* blocks, the other nine from state_enforcement. A
 *                 figure an agency does not publish is shown as "Not published",
 *                 never as zero. `?state=IA` or `#state-IA` preselects a state.
 *
 * Design follows the FAT map system used by the beef maps: Georgia serif body,
 * Arial for labels and figures, evergreen header band (#3a4a2d) on #f7f9f5,
 * sage KPI strip (#e8ede4) with white bordered cards, emerald links (#0F6C4F),
 * and the shared tier colors. Light theme only, like the beef maps.
 * Every acronym is spelled out the first time it appears in each view.
 *
 * The choropleth labels every state NASS publishes with its postal code and head
 * count, and a detail panel under the map shows the selected state's figures on
 * hover or tap. States NASS does not publish separately are grey and say so.
 */
(function () {
  'use strict';

  // The data file is loaded from the same place (and the same git ref) this
  // script was loaded from, so pinning the script URL to a commit pins the
  // data with it. Falls back to @main if the script's own URL is unavailable.
  var SELF_URL = (document.currentScript && document.currentScript.src) || '';
  var BASE_URL = /fat_pork_maps\.js/.test(SELF_URL)
    ? SELF_URL.replace(/fat_pork_maps\.js.*$/, '')
    : 'https://cdn.jsdelivr.net/gh/fcrocker-nyc/fat-android@main/pork/';
  var DATA_URL = BASE_URL + 'fat_pork_data.json';
  var ATLAS_URL = 'https://cdn.jsdelivr.net/npm/us-atlas@3/states-10m.json';
  var SUPPLY_MAP_URL = '/pork-supply-chain/pork-supply-map/';
  var INTEGRATED_MAP_URL = '/pork-supply-chain/pork-integrated-model-map/';
  var ENFORCEMENT_MAP_URL = '/pork-supply-chain/pork-enforcement-map/';

  // ---------------------------------------------------------------- palette
  // FAT map design system (shared with the beef maps).
  var C = {
    ink: '#1f2a1a', bg: '#f7f9f5', band: '#3a4a2d', bandText: '#f7f9f5', bandSub: '#dde5d9',
    strip: '#e8ede4', line: '#c9d3c2', olive: '#4a5e3a', link: '#0F6C4F', muted: '#5a6652',
    red: '#a83232', darkRed: '#7a1f1f', orange: '#d9822b', navy: '#1f4e79', green: '#3a7a3a',
    amber: '#b45309', grey: '#8f948a'
  };
  // Sequential sage-to-evergreen ramp for inventory; categorical for permit
  // regime; status colors for the legal-authority view.
  var RAMP = ['#f0f4ec', '#dde5d9', '#b9c9ad', '#8ba57a', '#5f7a4e', '#3a4a2d'];
  var NO_DATA = '#d9d9d4';

  var REGIME = {
    state_only: { color: C.red, label: 'State-only permit is the default' },
    both: { color: C.orange, label: 'Both — state-only default, NPDES on discharge' },
    npdes: { color: C.navy, label: 'NPDES is the primary instrument' },
    unknown: { color: C.grey, label: 'Not determined' }
  };

  var STATUS = {
    unenforceable: { color: C.red, label: 'Struck — unenforceable' },
    repealed: { color: C.darkRed, label: 'Repealed' },
    exempt: { color: C.red, label: 'Statutory exemption' },
    exempt_on_appeal: { color: C.orange, label: 'Exempt — on appeal' },
    stalled: { color: C.orange, label: 'Stalled' },
    not_initiated: { color: C.amber, label: 'Not initiated' },
    open: { color: C.navy, label: 'Open proceeding' }
  };

  // ---------------------------------------------------------------- helpers
  function noDataColor() { return NO_DATA; }

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
  // Shorter form for on-map labels: 24.7M, 1.3M.
  function headMShort(thousands) {
    if (thousands == null) return '';
    return num(thousands / 1000, 1) + 'M';
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

  // The NASS as-of date, read from the data file rather than typed.
  function nassAsOf(data) {
    var m = data.national && data.national.inventory_total;
    return m && m.asof ? fmtDate(m.asof) : '';
  }

  // State evidence entry (permit instrument per operation) for a state, if any.
  function evidenceFor(data, stateName) {
    var w = data.permit_regime_warning || {};
    var evs = w.state_evidence || [];
    if (!Array.isArray(evs)) evs = [evs];
    for (var i = 0; i < evs.length; i++) {
      if (evs[i] && evs[i].state === stateName && evs[i].unique_active_swine_operations) return evs[i];
    }
    return null;
  }

  // ---------------------------------------------------------------- styles
  var SANS = 'Arial,Helvetica,sans-serif';
  var SERIF = 'Georgia,"Times New Roman",serif';
  var CSS = [
    '.fat-wrap{--fat-bg:#fff;--fat-fg:' + C.ink + ';--fat-muted:' + C.muted + ';--fat-line:' + C.line + ';--fat-panel:' + C.strip + ';font:15px/1.5 ' + SERIF + ';color:var(--fat-fg)}',
    '.fat-wrap a{color:' + C.link + '}',
    '.fat-panel{background:var(--fat-bg);border:1px solid var(--fat-line);border-radius:6px;padding:14px 16px;margin-bottom:16px}',
    '.fat-head{display:flex;justify-content:space-between;align-items:flex-start;gap:16px;flex-wrap:wrap;background:' + C.band + ';color:' + C.bandText + ';margin:-14px -16px 14px;padding:12px 16px;border-radius:5px 5px 0 0}',
    '.fat-h2{font:600 1.15rem/1.3 ' + SERIF + ';margin:0 0 4px;color:' + C.bandText + '}',
    '.fat-head .fat-sub{font:13px/1.45 ' + SANS + ';color:' + C.bandSub + ';max-width:1100px}',
    '.fat-h3{font:600 1.05rem/1.3 ' + SERIF + ';color:' + C.band + ';margin:0 0 10px;padding-bottom:6px;border-bottom:1px solid var(--fat-line)}',
    '.fat-sub{font-size:14px;color:var(--fat-muted);margin:0}',
    '.fat-key{font:13px/1.5 ' + SANS + ';color:var(--fat-fg);background:var(--fat-panel);border:1px solid var(--fat-line);border-radius:6px;padding:8px 12px;margin:0 0 14px}',
    '.fat-key b{color:' + C.band + '}',
    '.fat-asof{font:12px/1.4 ' + SANS + ';color:' + C.bandSub + ';margin:0;text-align:right}',
    '.fat-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(160px,1fr));gap:8px;margin-bottom:14px;background:var(--fat-panel);border:1px solid var(--fat-line);border-radius:6px;padding:8px}',
    '.fat-card{background:#fff;border:1px solid var(--fat-line);border-radius:6px;padding:8px 10px}',
    '.fat-card-warn{outline:1px solid ' + C.amber + '}',
    '.fat-card-label{font:11px/1.3 ' + SANS + ';color:' + C.olive + ';margin:0 0 4px;text-transform:uppercase;letter-spacing:.04em}',
    '.fat-card-value{font:600 20px/1.15 ' + SANS + ';margin:0;color:var(--fat-fg)}',
    '.fat-card-sub{font:12px/1.45 ' + SANS + ';color:var(--fat-muted);margin:6px 0 0}',
    '.fat-card-chip{margin:8px 0 0}',
    '.fat-chip{display:inline-block;font:10px/1.4 ' + SANS + ';letter-spacing:.06em;text-transform:uppercase;padding:2px 7px;border-radius:999px;text-decoration:none;border:1px solid var(--fat-line);color:var(--fat-muted)}',
    '.fat-chip-primary{color:' + C.link + ';border-color:' + C.link + '}',
    '.fat-chip-secondary{color:' + C.amber + ';border-color:' + C.amber + '}',
    '.fat-chip-fat{color:' + C.band + ';border-color:' + C.band + '}',
    '.fat-chip-warn{color:' + C.red + ';border-color:' + C.red + '}',
    '.fat-note{border-left:3px solid ' + C.amber + ';background:var(--fat-panel);border-radius:0 6px 6px 0;padding:10px 14px;margin:0 0 16px}',
    '.fat-note-title{font:600 14px/1.4 ' + SERIF + ';color:' + C.band + ';margin:0 0 6px}',
    '.fat-note-body{font-size:14px;color:var(--fat-fg);margin:0}',
    '.fat-btns{display:flex;gap:8px;flex-wrap:wrap;margin-bottom:4px}',
    '.fat-btn{font:13px/1.3 ' + SANS + ';padding:7px 13px;border-radius:6px;cursor:pointer;background:#fff;color:var(--fat-fg);border:1px solid var(--fat-line);text-decoration:none;display:inline-block}',
    '.fat-wrap a.fat-btn{color:var(--fat-fg)}',
    '.fat-btn:hover{background:var(--fat-panel)}',
    '.fat-btn[aria-pressed="true"]{background:' + C.band + ';color:#fff;border-color:' + C.band + '}',
    '.fat-jump{display:flex;gap:8px;flex-wrap:wrap;margin:0 0 14px}',
    '.fat-pick{display:flex;gap:8px;flex-wrap:wrap;margin:10px 0 0}',
    '.fat-pick .fat-btn{font-weight:600}',
    '.fat-pick .fat-btn small{font-weight:400;color:var(--fat-muted);margin-left:5px}',
    '.fat-pick .fat-btn[aria-pressed="true"] small{color:' + C.bandSub + '}',
    '.fat-pick-label{font:11px/1.3 ' + SANS + ';color:' + C.olive + ';text-transform:uppercase;letter-spacing:.04em;margin:14px 0 0}',
    '.fat-card-gap .fat-card-value{color:' + C.amber + ';font-size:16px}',
    '.fat-scope{font-size:15px;color:var(--fat-fg);margin:0 0 6px}',
    '.fat-legend{display:flex;flex-wrap:wrap;gap:14px;font:12px/1.5 ' + SANS + ';color:var(--fat-fg);margin:10px 0 0}',
    '.fat-legend span.k{display:inline-flex;align-items:center;gap:6px}',
    '.fat-sw{width:11px;height:11px;border-radius:2px;display:inline-block;flex:0 0 auto;border:1px solid #333}',
    '.fat-map{background:' + C.bg + ';border:1px solid var(--fat-line);border-radius:6px;padding:6px}',
    '.fat-map svg{width:100%;height:auto;display:block}',
    '.fat-map svg path.fat-st{cursor:pointer}',
    '.fat-map svg path.fat-st.fat-hot{stroke:' + C.ink + ';stroke-width:1.8}',
    '.fat-map svg text.fat-lbl{font-family:' + SANS + ';font-size:11px;font-weight:700;pointer-events:none;text-anchor:middle;paint-order:stroke fill;stroke-linejoin:round}',
    '.fat-map svg text.fat-lbl.on-light{fill:' + C.ink + ';stroke:rgba(255,255,255,.85);stroke-width:3px}',
    '.fat-map svg text.fat-lbl.on-dark{fill:#fff;stroke:rgba(0,0,0,.55);stroke-width:3px}',
    '.fat-map svg text.fat-lbl tspan.v{font-weight:500;font-size:10px}',
    '.fat-detail{background:var(--fat-panel);border:1px solid var(--fat-line);border-radius:6px;padding:10px 14px;margin:12px 0 0;min-height:72px;font:13px/1.5 ' + SANS + ';color:var(--fat-fg)}',
    '.fat-detail-title{font:600 15px/1.3 ' + SERIF + ';color:' + C.band + ';margin:0 0 4px;display:flex;align-items:center;gap:8px;flex-wrap:wrap}',
    '.fat-detail p{margin:0 0 4px}',
    '.fat-detail .fat-sub{margin:0;font-size:13px}',
    '.fat-tablewrap{overflow-x:auto;-webkit-overflow-scrolling:touch}',
    '.fat-table{width:100%;border-collapse:collapse;font:13px/1.45 ' + SANS + ';min-width:520px}',
    '.fat-table th,.fat-table td{text-align:left;padding:8px 10px;border-bottom:1px solid var(--fat-line);vertical-align:top}',
    '.fat-table th{font-size:11px;text-transform:uppercase;letter-spacing:.04em;color:' + C.olive + ';font-weight:600;background:var(--fat-panel)}',
    '.fat-table td.n{text-align:right;font-variant-numeric:tabular-nums}',
    '.fat-mech{display:grid;gap:10px}',
    '.fat-mech-row{display:grid;grid-template-columns:minmax(0,1.3fr) minmax(0,2fr) auto;gap:12px;align-items:start;padding:10px 0;border-bottom:1px solid var(--fat-line)}',
    '@media (max-width:640px){.fat-mech-row{grid-template-columns:1fr}}',
    '.fat-mech-name{font:600 14px/1.4 ' + SERIF + ';color:' + C.band + ';margin:0}',
    '.fat-mech-scope{font:12px/1.45 ' + SANS + ';color:var(--fat-muted);margin:3px 0 0}',
    '.fat-mech-detail{font-size:14px;color:var(--fat-fg);margin:0}',
    '.fat-pill{display:inline-block;font:600 11px/1.4 ' + SANS + ';padding:3px 9px;border-radius:999px;color:#fff;white-space:nowrap}',
    '.fat-err{border:1px solid ' + C.red + ';border-radius:6px;padding:16px 20px;font-size:14px}',
    '.fat-foot{font:12px/1.5 ' + SANS + ';color:var(--fat-muted);margin:14px 0 0}',
    '.fat-xref{font-size:14px;color:var(--fat-fg);margin:12px 0 0;padding-top:10px;border-top:1px solid var(--fat-line)}',
    '.fat-xref a{font-weight:600}'
  ].join('\n');

  function injectCSS() {
    if (document.getElementById('fat-pork-css')) return;
    var st = document.createElement('style');
    st.id = 'fat-pork-css';
    st.textContent = CSS;
    document.head.appendChild(st);
  }

  // ---------------------------------------------------------------- key terms
  // Each view spells out its acronyms once, before any figure uses them.
  function keyTerms(extra) {
    var t = '<p class="fat-key"><b>Key terms.</b> ' +
      'Hog inventory is published by the USDA <b>National Agricultural Statistics Service (NASS)</b>. ' +
      'A federal Clean Water Act permit under the <b>National Pollutant Discharge Elimination System (NPDES)</b> ' +
      'creates a record in the EPA <b>Enforcement and Compliance History Online (ECHO)</b> database; ' +
      'a state-only permit does not. Large operations are <b>concentrated animal feeding operations (CAFOs)</b>.' +
      (extra ? ' ' + extra : '') + '</p>';
    return t;
  }
  var KEY_NC = 'In North Carolina the regulator is the <b>Department of Environmental Quality (DEQ)</b>.';

  // ---------------------------------------------------------------- detail panel
  function detailIdle(data) {
    var other = data.states_not_separately_published;
    return '<p class="fat-detail-title">Hover or tap a state</p>' +
      '<p class="fat-sub">Each labeled state shows its postal code and hogs on hand, ' +
      esc(nassAsOf(data)) + '. Grey states are not published separately by NASS; together they hold ' +
      headM(other.inventory) + ' head.</p>';
  }

  function detailFor(data, s, name) {
    if (!s) {
      var other = data.states_not_separately_published;
      return '<p class="fat-detail-title">' + esc(name) + '</p>' +
        '<p class="fat-sub">' + esc(other.public_note || other.basis) +
        ' The combined figure for those states is ' + headM(other.inventory) + ' head. ' +
        'FAT does not distribute that figure across states, so no state-level count is shown here.</p>';
    }
    var r = REGIME[s.permit_regime] || REGIME.unknown;
    var html = '<p class="fat-detail-title">' + esc(s.name) +
      '<span class="fat-pill" style="background:' + r.color + '">' + esc(r.label) + '</span></p>';
    html += '<p><strong>' + headM(s.inventory) + '</strong> hogs and pigs on ' + esc(nassAsOf(data)) +
      (s.breeding != null && s.market != null
        ? ' — ' + headM(s.breeding) + ' breeding, ' + headM(s.market) + ' market'
        : '') + '. ' + sourceChip(data, data.national.inventory_total) + '</p>';
    if (s.permit_program) {
      html += '<p>' + (s.regime_source
        ? '<a href="' + esc(s.regime_source) + '" target="_blank" rel="noopener noreferrer">' + esc(s.permit_program) + '</a>'
        : esc(s.permit_program)) +
        (s.regime_note ? ' <span class="fat-sub">' + esc(s.regime_note) + '</span>' : '') + '</p>';
    } else {
      html += '<p class="fat-sub">Permit regime not yet determined by FAT.</p>';
    }
    var ev = evidenceFor(data, s.name);
    if (ev) {
      var total = ev.unique_active_swine_operations;
      var pct = 100 * (total - ev.with_npdes) / total;
      html += '<p>Of <strong>' + num(total) + '</strong> swine operations the state lists, <strong>' +
        num(ev.with_npdes) + '</strong> hold an NPDES permit — <strong>' + num(pct, 1) +
        '%</strong> do not, so they have no EPA ECHO entry. ' + sourceChip(data, ev) + '</p>';
    }
    return html;
  }

  // ---------------------------------------------------------------- choropleth
  // mode: "inventory" | "regime"
  // opts: { detailEl } — a panel that shows the hovered / tapped state's figures.
  function drawMap(container, data, mode, opts) {
    opts = opts || {};
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
        ? 'US map shaded by swine permit regime, labeled with hog inventory by state'
        : 'US map shaded by hog inventory, labeled with hog inventory by state');

    var path = d3.geoPath(d3.geoAlbersUsa().scale(1120).translate([450, 270]));

    function fillFor(d) {
      var s = byName[d.properties.name];
      if (!s) return noDataColor();
      if (mode === 'regime') return (REGIME[s.permit_regime] || REGIME.unknown).color;
      return scale(s.inventory);
    }
    // Whether the fill is dark enough to want a white label.
    function fillIsDark(d) {
      var s = byName[d.properties.name];
      if (!s) return false;
      if (mode === 'regime') return true;
      return RAMP.indexOf(scale(s.inventory)) >= 3;
    }

    var detailEl = opts.detailEl || null;
    function showDetail(d) {
      if (!detailEl) return;
      detailEl.innerHTML = detailFor(data, byName[d.properties.name], d.properties.name);
    }
    if (detailEl) detailEl.innerHTML = detailIdle(data);

    d3.json(ATLAS_URL).then(function (us) {
      var feats = topojson.feature(us, us.objects.states).features;
      var paths = svg.append('g').selectAll('path').data(feats).join('path')
        .attr('class', 'fat-st')
        .attr('d', path)
        .attr('stroke', '#fff')
        .attr('stroke-width', 0.8)
        .attr('fill', fillFor)
        .attr('tabindex', function (d) { return byName[d.properties.name] ? 0 : null; })
        .attr('aria-label', function (d) {
          var s = byName[d.properties.name];
          return s ? s.name + ', ' + headM(s.inventory) + ' head' : d.properties.name + ', not separately published';
        });

      paths.append('title').text(function (d) {
        var s = byName[d.properties.name];
        if (!s) return d.properties.name + '\nNot separately published by NASS';
        var lines = [s.name, headM(s.inventory) + ' head (' + nassAsOf(data) + ')'];
        lines.push((REGIME[s.permit_regime] || REGIME.unknown).label);
        if (s.permit_program) lines.push(s.permit_program);
        return lines.join('\n');
      });

      function hot(d, on) {
        paths.classed('fat-hot', function (e) { return on && e === d; });
        if (on) paths.filter(function (e) { return e === d; }).raise();
      }
      paths.on('mouseenter', function (ev, d) { hot(d, true); showDetail(d); })
        .on('focus', function (ev, d) { hot(d, true); showDetail(d); })
        .on('click', function (ev, d) { hot(d, true); showDetail(d); })
        .on('mouseleave', function (ev, d) { hot(d, false); });

      // Labels: postal code and head count for every state NASS publishes.
      var labeled = feats.filter(function (d) { return !!byName[d.properties.name]; });
      var lbl = svg.append('g').selectAll('text').data(labeled).join('text')
        .attr('class', function (d) { return 'fat-lbl ' + (fillIsDark(d) ? 'on-dark' : 'on-light'); })
        .attr('transform', function (d) {
          var c = path.centroid(d);
          return 'translate(' + c[0].toFixed(1) + ',' + c[1].toFixed(1) + ')';
        });
      lbl.append('tspan').attr('x', 0).attr('dy', '-0.15em')
        .text(function (d) { return byName[d.properties.name].code; });
      lbl.append('tspan').attr('class', 'v').attr('x', 0).attr('dy', '1.15em')
        .text(function (d) { return headMShort(byName[d.properties.name].inventory); });
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
          : headM(lo) + ' – ' + headM(hi));
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
      '<thead><tr><th>State</th><th style="text-align:right">Hogs, ' + esc(nassAsOf(data)) + '</th>' +
      '<th>Permit regime</th><th>Program</th></tr></thead>' +
      '<tbody>' + body + otherRow + '</tbody></table></div>';
  }

  function permitWarning(data) {
    var w = data.permit_regime_warning;
    var html = '<div class="fat-note"><p class="fat-note-title">' + esc(w.headline) + '</p>' +
      '<p class="fat-note-body">' + esc(w.body) + '</p>';

    // One block per state that publishes the permit instrument per operation.
    // Shares are COMPUTED here; the data file stores counts only.
    var evs = w.state_evidence || [];
    if (!Array.isArray(evs)) evs = [evs];
    evs.forEach(function (ev) {
      if (!ev || !ev.unique_active_swine_operations) return;
      var total = ev.unique_active_swine_operations;
      var without = total - ev.with_npdes;
      var sharePct = 100 * without / total;

      // Labels may themselves contain commas, so clauses are joined with semicolons.
      var detail = (ev.detail || []).map(function (dd, i, arr) {
        return (i === arr.length - 1 && arr.length > 1 ? 'and ' : '') +
          num(dd.value) + ' ' + esc(dd.label);
      }).join('; ');

      html += '<p class="fat-note-body" style="margin-top:10px">' +
        '<strong>' + esc(ev.headline) + '</strong> Of ' + num(total) + ' ' + esc(ev.state) +
        ' swine operations, ' + num(ev.with_npdes) + ' hold an NPDES permit — ' +
        num(sharePct, 1) + '% do not, and so generate no NPDES record and no EPA ECHO entry.' +
        (detail ? ' Of the total, ' + detail + '.' : '') +
        ' ' + esc(ev.basis) + ' ' + esc(ev.caveat) + ' ' + sourceChip(data, ev) + '</p>';
    });

    return html + '</div>';
  }


  function footer(data) {
    var b = data.sources.fat_nc_briefing;
    return '<p class="fat-foot">Data last updated ' + esc(fmtDate(data.updated)) +
      '. Every figure on this page is drawn from a single published data file; ' +
      'ratios are computed, not entered. ' +
      (b ? 'Background: <a href="' + esc(b.url) + '" target="_blank" rel="noopener noreferrer">' +
        esc(b.label) + '</a>.' : '') + '</p>';
  }

  // Shared block: the North Carolina legal-authority mechanisms list.
  function mechanismRows(data) {
    var la = data.nc_legal_authority;
    var h = '<div class="fat-mech">';
    la.mechanisms.forEach(function (m) {
      var st = STATUS[m.status] || { color: '#9A9791', label: m.status };
      var s = data.sources[m.source];
      h += '<div class="fat-mech-row"><div>' +
        '<p class="fat-mech-name">' + esc(m.name) + '</p>' +
        '<p class="fat-mech-scope">' + esc(m.scope) + '</p></div>' +
        '<p class="fat-mech-detail">' + esc(m.detail) +
        (s ? ' <a class="fat-chip fat-chip-' + esc(s.type) + '" href="' + esc(s.url) +
          '" target="_blank" rel="noopener noreferrer">source</a>' : '') + '</p>' +
        '<div><span class="fat-pill" style="background:' + st.color + '">' + esc(st.label) + '</span>' +
        '<p class="fat-mech-scope">' + esc(fmtDate(m.date)) + '</p></div></div>';
    });
    return h + '</div>';
  }

  // ---------------------------------------------------------------- views
  // The North Carolina record: the original enforcement page, unchanged in
  // substance, returned as a fragment so the selector can swap it in.
  function enforcementNC(data) {
    var e = data.nc_enforcement;
    var c = data.nc_facility_counts;

    // COMPUTED — never typed.
    var ratio = e.operations_covered.value / e.inspectors.value;
    var ratioAlt = c.deq_reported_all_operations.value / e.inspectors.value;
    var vioPct = e.violation_rate.value * 100;
    var vioCount = Math.round(e.complaints_investigated.value * e.violation_rate.value);

    var html = '';

    html += '<div class="fat-panel"><div class="fat-head"><div>' +
      '<h2 class="fat-h2">North Carolina swine enforcement</h2>' +
      '<p class="fat-sub">Permitted facilities, inspection capacity, and complaint outcomes</p></div>' +
      '<div><p class="fat-asof">N.C. Department of Environmental Quality complaint records<br>' +
      esc(fmtDate(e.complaint_window.start)) + ' – ' + esc(fmtDate(e.complaint_window.end)) +
      '</p></div></div>';

    html += keyTerms(KEY_NC);
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
      ' verified. DEQ complaint records, not EPA ECHO.', sourceChip(data, e.complaints_investigated));
    html += '</div>';

    html += '<div class="fat-note"><p class="fat-note-title">What the complaint count does and does not show</p>' +
      '<p class="fat-note-body">' + esc(e.confidentiality_note) + ' ' + esc(e.unpermitted_gap_note) +
      '</p></div>';
    html += '</div>';

    // Legal authority summary — the point the old map missed entirely.
    var la = data.nc_legal_authority;
    html += '<div class="fat-panel"><h3 class="fat-h3">' + esc(la.headline) + '</h3>' +
      '<p class="fat-sub" style="margin-bottom:12px">' + esc(la.body) + '</p>' +
      mechanismRows(data) + '</div>';

    // Counts reconciliation — honest about the disagreeing numbers.
    var countKeys = ['active_swine_permits', 'deduplicated_active_swine_operations',
      'all_swine_permits', 'deq_reported_swine_facilities',
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

    return html;
  }

  // A metric that may be a figure or a documented gap ({value:null, not_published_by}).
  function isGap(mt) { return !mt || mt.value == null; }

  function gapCard(label, mt, data) {
    var sub = mt
      ? '<strong>Not published by ' + esc(mt.not_published_by || 'the agency') + '.</strong> ' + esc(mt.proxy || '')
      : 'Not published.';
    return card(label, 'Not published', sub, mt ? sourceChip(data, mt) : '', 'gap');
  }

  function metricCard(label, mt, data, fmt) {
    if (isGap(mt)) return gapCard(label, mt, data);
    var v = fmt ? fmt(mt.value) : num(mt.value);
    var sub = esc(mt.basis || '') + (mt.asof ? ' <span class="fat-sub">(' + esc(fmtDate(mt.asof)) + ')</span>' : '');
    return card(label, v, sub, sourceChip(data, mt));
  }

  // Latest as-of date among a state's published figures.
  function latestAsOf(s) {
    var keys = ['swine_operations', 'regulated_operations', 'inspectors', 'inspections_per_year',
      'complaints_per_year', 'violations_per_year'];
    var best = '';
    keys.forEach(function (k) {
      var mt = s[k];
      if (mt && mt.value != null && mt.asof && mt.asof > best) best = mt.asof;
    });
    return best;
  }

  // One of the nine other states, rendered from state_enforcement.
  function enforcementState(data, s) {
    var html = '';
    var asof = latestAsOf(s);

    html += '<div class="fat-panel"><div class="fat-head"><div>' +
      '<h2 class="fat-h2">' + esc(s.name) + ' swine enforcement</h2>' +
      '<p class="fat-sub">Permitted operations, inspection capacity, and what ' + esc(s.regulator_short) + ' does and does not publish</p></div>' +
      '<div><p class="fat-asof">' + esc(s.regulator) + '<br>' +
      (asof ? 'Latest published figure ' + esc(fmtDate(asof)) : 'No annual figures published') + '</p></div></div>';

    html += keyTerms(s.key_term || '');

    // COMPUTED — NPDES share of the CAFOs the state reports to EPA.
    var ep = s.epa_cafo_status;
    var npdesPct = ep && ep.total_cafos ? 100 * ep.npdes_permitted / ep.total_cafos : null;

    html += '<div class="fat-grid">';
    html += metricCard('Swine operations', s.swine_operations, data);
    html += metricCard('Permitted operations, all species', s.regulated_operations, data);
    if (ep) {
      html += card('CAFOs with a federal NPDES permit',
        num(ep.npdes_permitted) + ' of ' + num(ep.total_cafos) +
        (npdesPct != null ? ' <span class="fat-sub">(' + num(npdesPct, 0) + '%)</span>' : ''),
        esc(ep.basis) + ' <span class="fat-sub">(' + esc(fmtDate(ep.asof)) + ')</span>', sourceChip(data, ep));
    }
    html += metricCard('Inspection staff', s.inspectors, data, function (v) { return num(v, v % 1 ? 1 : 0); });
    html += metricCard('Inspections per year', s.inspections_per_year, data);
    html += metricCard('Complaints per year', s.complaints_per_year, data);
    html += metricCard('Violations per year', s.violations_per_year, data);
    // Operations per inspector, only when both inputs are published.
    if (!isGap(s.inspectors) && !isGap(s.regulated_operations)) {
      var r = s.regulated_operations.value / s.inspectors.value;
      html += card('Operations per inspector', num(r, 0) + ':1',
        num(s.regulated_operations.value) + ' permitted operations (' + esc(fmtDate(s.regulated_operations.asof)) +
        ') divided by ' + num(s.inspectors.value, s.inspectors.value % 1 ? 1 : 0) + ' staff (' + esc(fmtDate(s.inspectors.asof)) +
        '). The two figures are from different dates, and the staff also work other programs, so this is a rough load, not a measured one.',
        sourceChip(data, s.inspectors));
    }
    html += '</div>';

    if (s.publication_note) {
      html += '<div class="fat-note"><p class="fat-note-title">What ' + esc(s.regulator_short) + ' publishes</p>' +
        '<p class="fat-note-body">' + esc(s.publication_note) + '</p></div>';
    }
    html += '</div>';

    // Permit regime and inspection policy.
    var rs = s.regime_source ? data.sources[s.regime_source] : null;
    html += '<div class="fat-panel"><h3 class="fat-h3">What kind of permit the state requires</h3>' +
      '<p class="fat-scope">' + esc(s.permit_regime_text) +
      (rs ? ' <a class="fat-chip fat-chip-' + esc(rs.type) + '" href="' + esc(rs.url) +
        '" target="_blank" rel="noopener noreferrer" title="' + esc(rs.label) + '">source</a>' : '') + '</p>' +
      '<p class="fat-sub" style="margin-top:8px"><strong>Program.</strong> ' + esc(s.program) + '</p>';
    if (s.inspection_policy) {
      html += '<div class="fat-note" style="margin-top:14px"><p class="fat-note-title">Inspection policy</p>' +
        '<p class="fat-note-body">' + esc(s.inspection_policy.basis) + ' ' + sourceChip(data, s.inspection_policy) + '</p></div>';
    }
    html += '</div>';

    // Recent developments.
    if (s.developments && s.developments.length) {
      html += '<div class="fat-panel"><h3 class="fat-h3">Recent legal and enforcement developments</h3>' +
        '<div class="fat-tablewrap"><table class="fat-table"><thead><tr><th>When</th><th>What</th></tr></thead><tbody>' +
        s.developments.slice().sort(function (a, b) { return a.date < b.date ? 1 : -1; }).map(function (d) {
          return '<tr><td style="white-space:nowrap">' + esc(fmtDate(d.date)) + '</td><td>' + esc(d.detail) + ' ' +
            sourceChip(data, d) + '</td></tr>';
        }).join('') + '</tbody></table></div></div>';
    }

    html += permitWarning(data);
    return html;
  }

  // Selector entries: the ten largest hog states in inventory order, each
  // mapped to the block that renders it. Built from the data, never typed.
  function enforcementStates(data) {
    var byCode = {};
    ((data.state_enforcement && data.state_enforcement.states) || []).forEach(function (s) { byCode[s.code] = s; });
    return data.states.slice()
      .sort(function (a, b) { return b.inventory - a.inventory; })
      .filter(function (s) { return s.code === 'NC' || byCode[s.code]; })
      .slice(0, 10)
      .map(function (s) { return { code: s.code, name: s.name, inventory: s.inventory, entry: byCode[s.code] || null }; });
  }

  function requestedState() {
    var m = /[?&]state=([A-Za-z]{2})/.exec(window.location.search) ||
      /#state-([A-Za-z]{2})/.exec(window.location.hash);
    return m ? m[1].toUpperCase() : '';
  }

  function viewEnforcement(el, data) {
    var se = data.state_enforcement || {};
    var copy = se.scope_copy || {};
    var list = enforcementStates(data);

    // COMPUTED — share of the national herd in the selectable states.
    var natTotal = data.national.inventory_total.value;
    var listed = list.reduce(function (t, s) { return t + s.inventory; }, 0);
    var sharePct = 100 * listed / natTotal;

    var html = '<div class="fat-wrap">';
    html += '<div class="fat-panel"><div class="fat-head"><div>' +
      '<h2 class="fat-h2">Pork enforcement, state by state</h2>' +
      '<p class="fat-sub">' + esc(copy.headline || '') + '</p></div>' +
      '<div><p class="fat-asof">Ranking: USDA National Agricultural Statistics Service (NASS)<br>' +
      esc(nassAsOf(data)) + '</p></div></div>';
    html += '<p class="fat-scope">' + esc(copy.body || '') + '</p>' +
      '<p class="fat-sub">The ' + num(list.length) + ' states below held ' + headM(listed) + ' hogs and pigs on ' +
      esc(nassAsOf(data)) + ', ' + num(sharePct, 0) + '% of the national herd. ' + sourceChip(data, data.national.inventory_total) + '</p>';
    html += '<p class="fat-pick-label">Choose a state</p>' +
      '<div class="fat-pick" role="group" aria-label="Choose a state">' +
      list.map(function (s, i) {
        return '<button class="fat-btn" type="button" data-state="' + esc(s.code) + '" aria-pressed="false" title="' +
          esc(s.name) + ': ' + headM(s.inventory) + ' head, rank ' + (i + 1) + '">' + esc(s.name) +
          '<small>' + headMShort(s.inventory) + '</small></button>';
      }).join('') + '</div>';
    html += '</div>';

    html += '<div id="fat-enf-body" aria-live="polite"></div>';
    html += '<p class="fat-xref">Where the hogs are nationally, and which permit the state requires: ' +
      '<a href="' + SUPPLY_MAP_URL + '">Pork Supply Map</a>. Ownership, integration and the legal record in one view: ' +
      '<a href="' + INTEGRATED_MAP_URL + '">Pork Integrated Model Map</a>.</p>';
    html += footer(data) + '</div>';
    el.innerHTML = html;

    var body = el.querySelector('#fat-enf-body');
    function set(code, scroll) {
      var s = null;
      list.forEach(function (x) { if (x.code === code) s = x; });
      if (!s) return;
      body.innerHTML = s.code === 'NC' ? enforcementNC(data) : enforcementState(data, s.entry);
      Array.prototype.forEach.call(el.querySelectorAll('.fat-btn[data-state]'), function (b) {
        b.setAttribute('aria-pressed', String(b.getAttribute('data-state') === code));
      });
      if (scroll) {
        try { body.scrollIntoView({ behavior: 'smooth', block: 'start' }); } catch (e) { /* no-op */ }
      }
    }
    Array.prototype.forEach.call(el.querySelectorAll('.fat-btn[data-state]'), function (b) {
      b.addEventListener('click', function () { set(b.getAttribute('data-state'), true); });
    });
    var want = requestedState();
    var has = list.some(function (x) { return x.code === want; });
    set(has ? want : 'NC', false);
  }

  function viewSupply(el, data) {
    var n = data.national;
    var html = '<div class="fat-wrap">';

    html += '<div class="fat-panel"><div class="fat-head"><div>' +
      '<h2 class="fat-h2">U.S. hog inventory and permit architecture</h2>' +
      '<p class="fat-sub">Where the hogs are, and what kind of permit the state requires</p></div>' +
      '<div><p class="fat-asof">USDA National Agricultural Statistics Service<br>' + esc(nassAsOf(data)) + '</p></div></div>';

    html += keyTerms();
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
    html += '<div class="fat-detail" id="fat-detail-supply" aria-live="polite"></div>';
    html += '</div>';

    html += permitWarning(data);
    html += '<div class="fat-panel"><h3 class="fat-h3">States NASS publishes individually</h3>' +
      stateTable(data) + '</div>';
    html += '<p class="fat-xref">How much of this herd sits outside federal records, who owns the packers, and what reaches the label: ' +
      '<a href="' + INTEGRATED_MAP_URL + '">Pork Integrated Model Map</a>. Permits, inspections and complaints for the ten largest hog states, one state at a time: ' +
      '<a href="' + ENFORCEMENT_MAP_URL + '">Pork Enforcement Map</a>.</p>';
    html += footer(data) + '</div>';

    el.innerHTML = html;

    var mapEl = el.querySelector('#fat-map-supply');
    var legEl = el.querySelector('#fat-legend-supply');
    var detEl = el.querySelector('#fat-detail-supply');
    function set(mode) {
      drawMap(mapEl, data, mode, { detailEl: detEl });
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

  // The integrated view does not repeat the supply view. It opens on what the
  // regime layer implies for the herd as a whole (computed), then stacks the
  // material no other pork map carries: the North Carolina legal record,
  // ownership and integration, biogas, and what reaches the label.
  function viewIntegrated(el, data) {
    var n = data.national, o = data.ownership, ig = data.integration, b = data.biogas;

    // COMPUTED — inventory by permit regime over the states NASS publishes.
    var byRegime = { state_only: 0, both: 0, npdes: 0, unknown: 0 };
    var published = 0;
    data.states.forEach(function (s) {
      var k = REGIME[s.permit_regime] ? s.permit_regime : 'unknown';
      byRegime[k] += s.inventory;
      published += s.inventory;
    });
    var natTotal = n.inventory_total.value;
    var pctOfNat = function (v) { return 100 * v / natTotal; };
    var outsideEcho = byRegime.state_only + byRegime.both;
    var namesFor = function (k) {
      return data.states.filter(function (s) { return s.permit_regime === k; })
        .sort(function (a, c) { return c.inventory - a.inventory; })
        .map(function (s) { return s.name; });
    };
    var listNames = function (arr) {
      if (arr.length <= 1) return arr.join('');
      return arr.slice(0, -1).join(', ') + ' and ' + arr[arr.length - 1];
    };

    var html = '<div class="fat-wrap">';

    html += '<div class="fat-panel"><div class="fat-head"><div>' +
      '<h2 class="fat-h2">U.S. pork — integrated analysis</h2>' +
      '<p class="fat-sub">How much of the herd federal records can see, who owns the packers, ' +
      'what North Carolina law still reaches, and what gets to the label</p></div>' +
      '<div><p class="fat-asof">Updated ' + esc(fmtDate(data.updated)) + '</p></div></div>';

    // Jump bar — every section is on the page; nothing is hidden behind a tab.
    html += '<div class="fat-jump" role="navigation" aria-label="Sections">' +
      [['fat-int-map', 'Permit map'], ['fat-int-authority', 'Legal authority'],
        ['fat-int-ownership', 'Ownership &amp; integration'], ['fat-int-biogas', 'Biogas'],
        ['fat-int-label', 'What reaches the label']].map(function (p) {
        return '<a class="fat-btn" href="#' + p[0] + '" data-jump="' + p[0] + '">' + p[1] + '</a>';
      }).join('') + '</div>';

    html += keyTerms(KEY_NC);
    html += '<div class="fat-grid">';
    html += card('Herd in state-only-permit states', headM(byRegime.state_only),
      num(pctOfNat(byRegime.state_only), 0) + '% of all U.S. hogs are in ' + esc(listNames(namesFor('state_only'))) +
      ', where the default instrument is a state permit that creates no NPDES record and no EPA ECHO entry.',
      sourceChip(data, n.inventory_total));
    html += card('Herd where NPDES applies only on discharge', headM(byRegime.both),
      num(pctOfNat(byRegime.both), 0) + '% of all U.S. hogs are in ' + esc(listNames(namesFor('both'))) +
      ', where the state permit is the default and NPDES attaches only on a discharge.',
      sourceChip(data, n.inventory_total));
    html += card('Herd in NPDES-primary states', headM(byRegime.npdes),
      num(pctOfNat(byRegime.npdes), 0) + '% of all U.S. hogs are in ' + esc(listNames(namesFor('npdes'))) +
      ', the only published states that route most large swine operations through a federal permit.',
      sourceChip(data, n.inventory_total));
    html += card('Four largest packers’ share of slaughter (CR4)', num(n.cr4_packers.value) + '%',
      esc(pub(n.cr4_packers)), sourceChip(data, n.cr4_packers));
    html += '</div>';

    html += '<div id="fat-int-map"></div>';
    html += '<h3 class="fat-h3">Where the hogs are, and which permit covers them</h3>' +
      '<p class="fat-sub" style="margin-bottom:10px">Shaded by permit regime, labeled with hogs on hand (USDA NASS, ' +
      esc(nassAsOf(data)) + '). Together, ' + headM(outsideEcho) + ' head — ' + num(pctOfNat(outsideEcho), 0) +
      '% of the national herd — are in states where the default permit produces no federal record' +
      (byRegime.unknown ? '; a further ' + headM(byRegime.unknown) + ' head are in states whose regime FAT has not yet determined' : '') +
      '. The grey states are not separately published by NASS and are not shown as zero.</p>';
    html += '<div class="fat-map" id="fat-map-int"></div><div id="fat-legend-int"></div>' +
      '<div class="fat-detail" id="fat-detail-int" aria-live="polite"></div>';
    html += '<p class="fat-xref">Hog inventory by state, the breeding and market split, and the full state table are on the ' +
      '<a href="' + SUPPLY_MAP_URL + '">Pork Supply Map</a>; this page does not repeat them.</p>';
    html += '</div>';

    html += permitWarning(data);

    // Legal authority — North Carolina.
    var la = data.nc_legal_authority;
    html += '<div class="fat-panel" id="fat-int-authority"><h3 class="fat-h3">Legal authority — North Carolina</h3>' +
      '<div class="fat-note"><p class="fat-note-title">' + esc(la.headline) + '</p>' +
      '<p class="fat-note-body">' + esc(la.body) + '</p></div>' + mechanismRows(data);
    var op = la.open_proceeding, ops = data.sources[op.source];
    html += '<div class="fat-note" style="border-left-color:' + STATUS.open.color + ';margin-top:16px">' +
      '<p class="fat-note-title">' + esc(op.name) + ' — ' + esc(STATUS.open.label) + '</p>' +
      '<p class="fat-note-body">' + esc(op.detail) +
      (ops ? ' <a class="fat-chip fat-chip-' + esc(ops.type) + '" href="' + esc(ops.url) +
        '" target="_blank" rel="noopener noreferrer">source</a>' : '') + '</p></div>';
    var ss = data.nc_statutory_structure;
    html += '<div style="margin-top:16px"><h3 class="fat-h3">Why the lagoons remain</h3>' +
      '<p class="fat-sub">' + esc(ss.moratorium.detail) + ' <a class="fat-chip fat-chip-primary" href="' +
      esc(data.sources[ss.moratorium.source].url) +
      '" target="_blank" rel="noopener noreferrer">' + esc(ss.moratorium.statute) + '</a></p></div>';
    html += '<p class="fat-xref">Permits, inspection staffing and complaint outcomes for North Carolina and the nine other largest hog states: ' +
      '<a href="' + ENFORCEMENT_MAP_URL + '">Pork Enforcement Map</a>.</p></div>';

    // Ownership and integration.
    var sm = o.smithfield;
    html += '<div class="fat-panel" id="fat-int-ownership"><h3 class="fat-h3">Ownership &amp; integration</h3>' +
      '<p class="fat-sub" style="margin-bottom:12px">' + esc(o.note) + '</p>';
    html += '<div class="fat-grid">' +
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
    if (o.jbs) {
      html += '<p class="fat-sub" style="margin-bottom:12px"><strong>' + esc(o.jbs.us_pork_subsidiary || 'JBS') +
        '</strong> — parent ' + esc(o.jbs.parent) + ' (' + esc(o.jbs.parent_domicile) + '). ' + esc(o.jbs.note) + '</p>';
    }
    html += '<div class="fat-note"><p class="fat-note-title">Integration is loosening at the production end</p>' +
      '<p class="fat-note-body">' + esc(ig.note) + '</p></div>';
    html += '<h3 class="fat-h3">North Carolina divestitures</h3><div class="fat-tablewrap">' +
      '<table class="fat-table"><thead><tr><th>When</th><th>What</th></tr></thead><tbody>' +
      ig.nc_divestitures.map(function (d) {
        return '<tr><td>' + esc(fmtDate(d.date)) + '</td><td>' + esc(d.detail) + ' ' +
          sourceChip(data, d) + '</td></tr>';
      }).join('') + '</tbody></table></div></div>';

    // Biogas.
    html += '<div class="fat-panel" id="fat-int-biogas"><h3 class="fat-h3">Biogas — the second revenue channel</h3>' +
      '<p class="fat-sub" style="margin-bottom:12px">' + esc(b.note) +
      (b.align_rng.structure ? ' Align RNG (renewable natural gas) is a ' + esc(b.align_rng.structure) + '.' : '') + '</p><div class="fat-tablewrap">' +
      '<table class="fat-table"><thead><tr><th>Project</th><th>Counties</th>' +
      '<th style="text-align:right">Farms</th><th style="text-align:right">Dekatherms (Dth) per year</th></tr></thead><tbody>' +
      b.align_rng.projects.map(function (p) {
        return '<tr><td>' + esc(p.name) +
          (p.completion_estimate ? ' <span class="fat-sub">(est. ' + esc(p.completion_estimate) + ')</span>' : '') +
          ' ' + sourceChip(data, p) +
          '</td><td>' + esc(p.counties.join(', ')) + '</td>' +
          '<td class="n">' + num(p.farms) + '</td><td class="n">' + num(p.annual_dth) + '</td></tr>';
      }).join('') + '</tbody></table></div>' +
      '<p class="fat-foot">Carbon intensity certified by the California Air Resources Board (CARB) for dairy and swine manure biomethane runs from ' +
      num(b.lcfs_ci_range.low) + ' to ' + num(b.lcfs_ci_range.high) + ' ' + esc(b.lcfs_ci_range.unit) +
      ' of carbon dioxide equivalent per megajoule, on an avoided-methane basis. ' + esc(b.align_rng.disclosure_note) + ' ' +
      sourceChip(data, { source: 'carb_dsm_lcfs' }) + '</p></div>';

    // What reaches the label.
    var ld = data.label_disclosure;
    html += '<div class="fat-panel" id="fat-int-label"><h3 class="fat-h3">What reaches the label</h3>' +
      '<div class="fat-note"><p class="fat-note-title">' + esc(ld.headline) + '</p>' +
      '<p class="fat-note-body">' + esc(ld.body) + '</p></div>';
    html += '<div class="fat-tablewrap"><table class="fat-table"><thead><tr>' +
      '<th>FAT category</th><th>Why it is the only route to this information</th></tr></thead><tbody>' +
      ld.categories.map(function (c2) {
        return '<tr><td><strong>' + num(c2.number) + '. ' + esc(c2.name) + '</strong></td><td>' +
          esc(c2.why) + '</td></tr>';
      }).join('') + '</tbody></table></div>' +
      '<p class="fat-foot">' + esc(ld.asymmetry) + '</p></div>';

    html += footer(data) + '</div>';
    el.innerHTML = html;

    // Jump links scroll within whatever container holds the page, without
    // rewriting the URL hash (the standalone map shell scrolls an inner pane).
    Array.prototype.forEach.call(el.querySelectorAll('a[data-jump]'), function (a) {
      a.addEventListener('click', function (ev) {
        var t = el.querySelector('#' + a.getAttribute('data-jump'));
        if (!t) return;
        ev.preventDefault();
        try { t.scrollIntoView({ behavior: 'smooth', block: 'start' }); }
        catch (e) { t.scrollIntoView(); }
      });
    });

    drawMap(el.querySelector('#fat-map-int'), data, 'regime', { detailEl: el.querySelector('#fat-detail-int') });
    el.querySelector('#fat-legend-int').innerHTML = legendFor('regime', data);
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
