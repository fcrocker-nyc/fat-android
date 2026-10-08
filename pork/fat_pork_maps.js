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
 *
 *   supply      — hog inventory by state (USDA NASS) with the permit-regime layer
 *                 and the full state table. The reference view for "where the hogs are".
 *   integrated  — what the supply view does NOT repeat: how much of the herd sits
 *                 outside federal records (computed from the regime layer), the
 *                 North Carolina legal record, ownership and integration, biogas,
 *                 and what reaches the label. It links to the supply view for the
 *                 inventory table rather than duplicating it.
 *   enforcement — North Carolina swine enforcement.
 *
 * The choropleth labels every state NASS publishes with its postal code and head
 * count, and a detail panel under the map shows the selected state's figures on
 * hover or tap. States NASS does not publish separately are grey and say so.
 */
(function () {
  'use strict';

  var DATA_URL = 'https://cdn.jsdelivr.net/gh/fcrocker-nyc/fat-android@main/pork/fat_pork_data.json';
  var ATLAS_URL = 'https://cdn.jsdelivr.net/npm/us-atlas@3/states-10m.json';
  var SUPPLY_MAP_URL = '/pork-supply-chain/pork-supply-map/';
  var INTEGRATED_MAP_URL = '/pork-supply-chain/pork-integrated-model-map/';
  var ENFORCEMENT_MAP_URL = '/pork-supply-chain/pork-enforcement-map/';

  // ---------------------------------------------------------------- palette
  // Sequential ramp for inventory; categorical for permit regime; status colors
  // for the legal-authority view. Chosen to stay legible in both themes.
  var RAMP = ['#F2E9DC', '#E8CFA9', '#DDAE6E', '#C9853C', '#A85D20', '#7A3D12'];
  var NO_DATA_LIGHT = '#D3D1C7';
  var NO_DATA_DARK = '#4A4844';

  var REGIME = {
    state_only: { color: '#7A3D12', label: 'State-only permit is the default', dark: true },
    both: { color: '#C9853C', label: 'Both — state-only default, NPDES on discharge', dark: true },
    npdes: { color: '#2E6B8A', label: 'NPDES is the primary instrument', dark: true },
    unknown: { color: '#9A9791', label: 'Not determined', dark: true }
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
    '.fat-btn{font:inherit;font-size:13px;padding:7px 13px;border-radius:6px;cursor:pointer;background:transparent;color:var(--fat-fg);border:.5px solid var(--fat-line);text-decoration:none;display:inline-block}',
    '.fat-btn[aria-pressed="true"]{background:#7A3D12;color:#fff;border-color:#7A3D12}',
    '.fat-jump{display:flex;gap:8px;flex-wrap:wrap;margin:0 0 16px}',
    '.fat-jump .fat-btn:hover{background:var(--fat-panel)}',
    '.fat-legend{display:flex;flex-wrap:wrap;gap:14px;font-size:12px;color:var(--fat-muted);margin:10px 0 0}',
    '.fat-legend span.k{display:inline-flex;align-items:center;gap:6px}',
    '.fat-sw{width:11px;height:11px;border-radius:2px;display:inline-block;flex:0 0 auto}',
    '.fat-map svg{width:100%;height:auto;display:block}',
    '.fat-map svg path.fat-st{cursor:pointer;transition:opacity .12s}',
    '.fat-map svg path.fat-st.fat-hot{stroke:#111;stroke-width:1.8}',
    '@media (prefers-color-scheme:dark){.fat-map svg path.fat-st.fat-hot{stroke:#fff}}',
    '.fat-map svg text.fat-lbl{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;font-size:11px;font-weight:700;pointer-events:none;text-anchor:middle;paint-order:stroke fill;stroke-linejoin:round}',
    '.fat-map svg text.fat-lbl.on-light{fill:#1b1a18;stroke:rgba(255,255,255,.85);stroke-width:3px}',
    '.fat-map svg text.fat-lbl.on-dark{fill:#fff;stroke:rgba(0,0,0,.55);stroke-width:3px}',
    '.fat-map svg text.fat-lbl tspan.v{font-weight:500;font-size:10px}',
    '.fat-detail{background:var(--fat-panel);border-radius:8px;padding:12px 14px;margin:12px 0 0;min-height:72px;font-size:13px;color:var(--fat-fg)}',
    '.fat-detail-title{font-size:14px;font-weight:600;margin:0 0 4px;display:flex;align-items:center;gap:8px;flex-wrap:wrap}',
    '.fat-detail p{margin:0 0 4px}',
    '.fat-detail .fat-sub{margin:0}',
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
    '.fat-foot a,.fat-sub a,.fat-detail a{color:inherit}',
    '.fat-xref{font-size:13px;color:var(--fat-muted);margin:12px 0 0;padding-top:10px;border-top:.5px solid var(--fat-line)}',
    '.fat-xref a{color:#2E6B8A;font-weight:600}',
    '@media (prefers-color-scheme:dark){.fat-xref a{color:#7FB3CF}}'
  ].join('\n');

  function injectCSS() {
    if (document.getElementById('fat-pork-css')) return;
    var st = document.createElement('style');
    st.id = 'fat-pork-css';
    st.textContent = CSS;
    document.head.appendChild(st);
  }

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
    var dark = isDark();

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
      if (!s) return dark;
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
        .attr('stroke', dark ? 'rgba(255,255,255,.18)' : '#fff')
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

    html += permitWarning(data);
    html += '<p class="fat-xref">Where the hogs are nationally, and which permit each state issues: ' +
      '<a href="' + SUPPLY_MAP_URL + '">Pork Supply Map</a>. Ownership, integration and the legal record in one view: ' +
      '<a href="' + INTEGRATED_MAP_URL + '">Pork Integrated Model Map</a>.</p>';
    html += footer(data) + '</div>';

    el.innerHTML = html;
  }

  function viewSupply(el, data) {
    var n = data.national;
    var html = '<div class="fat-wrap">';

    html += '<div class="fat-panel"><div class="fat-head"><div>' +
      '<h2 class="fat-h2">U.S. hog inventory and permit architecture</h2>' +
      '<p class="fat-sub">Where the hogs are, and what kind of permit each state issues</p></div>' +
      '<div><p class="fat-asof">USDA NASS<br>' + esc(nassAsOf(data)) + '</p></div></div>';

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
      '<a href="' + INTEGRATED_MAP_URL + '">Pork Integrated Model Map</a>. North Carolina permits, inspections and complaints: ' +
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
    html += card('Four largest packers’ share', num(n.cr4_packers.value) + '%',
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
    html += '<p class="fat-xref">Permits, inspection staffing and complaint outcomes for North Carolina: ' +
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
      (b.align_rng.structure ? ' Align RNG is a ' + esc(b.align_rng.structure) + '.' : '') + '</p><div class="fat-tablewrap">' +
      '<table class="fat-table"><thead><tr><th>Project</th><th>Counties</th>' +
      '<th style="text-align:right">Farms</th><th style="text-align:right">Dth / yr</th></tr></thead><tbody>' +
      b.align_rng.projects.map(function (p) {
        return '<tr><td>' + esc(p.name) +
          (p.completion_estimate ? ' <span class="fat-sub">(est. ' + esc(p.completion_estimate) + ')</span>' : '') +
          ' ' + sourceChip(data, p) +
          '</td><td>' + esc(p.counties.join(', ')) + '</td>' +
          '<td class="n">' + num(p.farms) + '</td><td class="n">' + num(p.annual_dth) + '</td></tr>';
      }).join('') + '</tbody></table></div>' +
      '<p class="fat-foot">Certified CARB carbon intensity for dairy and swine manure biomethane runs from ' +
      num(b.lcfs_ci_range.low) + ' to ' + num(b.lcfs_ci_range.high) + ' ' + esc(b.lcfs_ci_range.unit) +
      ' on an avoided-methane basis. ' + esc(b.align_rng.disclosure_note) + ' ' +
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
