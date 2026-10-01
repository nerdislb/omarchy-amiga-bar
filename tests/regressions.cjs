const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const ctx = {};
vm.createContext(ctx);
vm.runInContext(fs.readFileSync(path.join(root, 'Presets.js'), 'utf8').replace('.pragma library', ''), ctx);
const plain = value => JSON.parse(JSON.stringify(value));
const base = {left: ['omarchy.menu', 'omarchy.workspaces', 'nerdibeard.ai-usage'], center: ['nerdibeard.amiga-island', 'omarchy.weather'], right: [{id:'omarchy.tailscale', recentMullvadRegions:['old']}, 'omarchy.network', 'flux', 'omamail', 'io.github.moizibnyousaf.omawhatsapp', 'omarchy.audio']};
for (const preset of ctx.PRESETS) {
 const original = JSON.stringify(base);
 const built = ctx.build(base, preset.options, '/plugin/modules');
 assert.equal(JSON.stringify(base), original);
 assert(built.right.some(e => ctx.entryId(e) === 'omamail'));
 assert(built.right.some(e => ctx.entryId(e) === 'io.github.moizibnyousaf.omawhatsapp'));
 if (preset.id === 'heute') assert.deepEqual(plain(built), base);
 else assert(ctx.hasOwn(built));
}
const current = ctx.build(base, ctx.presetById('k1').options, '/plugin/modules');
current.right.find(e => e.id === 'amiga.status').embeds['omarchy.tailscale'].recentMullvadRegions = ['new'];
const merged = ctx.mergeEmbeddedSettings(base, current);
assert.deepEqual(plain(ctx.build(merged, ctx.presetById('heute').options, '/plugin/modules')).right[0].recentMullvadRegions, ['new']);
assert.deepEqual(base.right[0].recentMullvadRegions, ['old']);
// Actual QML functions in isolation: each scope gets an independent startup baseline.
function functionSource(text, name) {
 const from=text.indexOf('  function '+name+'(');
 assert(from >= 0, name);
 const to=text.indexOf('\n  }', from)+4;
 return text.slice(from,to);
}
const failuresPath = path.resolve(root, '../omarchy-amiga-island/sources/Failures.qml');
const failures=fs.readFileSync(failuresPath,'utf8');
const alarms=[];
const failureCtx={initializedScopes:{},knownUnits:null,island:{showGuru:e=>alarms.push(e)}};
vm.createContext(failureCtx);
vm.runInContext(functionSource(failures,'quote')+'\n'+functionSource(failures,'scanned'),failureCtx);
failureCtx.scanned('user','old-user.service failed');
failureCtx.scanned('system','old-system.service failed');
assert.equal(alarms.length,0);
failureCtx.scanned('system','old-system.service failed\nfoo\\x2dbar.service failed');
assert.equal(alarms.length,1);
assert(alarms[0].command.includes("'foo\\x2dbar.service'"));
const cp=require('node:child_process');
for (const value of ["foo\\x2dbar.service", "strange'name.service", '$(echo nope).service']) {
 const out=cp.execFileSync('sh',['-c','printf %s '+failureCtx.quote(value)],{encoding:'utf8',stdio:['ignore','pipe','pipe']});
 assert.equal(out,value);
}
// Focus routing uses one shared handler and chooses the visible focused output.
const bus=fs.readFileSync(path.join(root,'bridge/ModuleBus.qml'),'utf8');
const mk=name=>({QsWindow:{window:{visible:true,screen:{name}}}});
const a=mk('eDP-1'), b=mk('HDMI-A-1');
const bc={instances:{status:[a,b]},Hyprland:{focusedMonitor:{name:'HDMI-A-1'}}};
vm.createContext(bc); vm.runInContext(functionSource(bus,'pick'),bc);
assert.equal(bc.pick('status'),b);
b.QsWindow.window.visible=false;
assert.equal(bc.pick('status'),a);
console.log('PASS: presets, native-widget preservation, embedded settings round-trip, startup alarms, shell quoting, focused-output routing');
// Layout-induced hover events at a stationary global position must not take
// selection away from keyboard navigation. Local coordinates may change.
const menuSource = fs.readFileSync(path.join(root, 'IntuitionMenu.qml'), 'utf8');
const pointerCtx = {pointerKnown:false, pointerX:0, pointerY:0, win:{contentItem:{}}};
vm.createContext(pointerCtx);
vm.runInContext(functionSource(menuSource, 'pointerMoved'), pointerCtx);
const areaAt = (x,y) => ({mapToItem:(_,mx,my)=>({x:x+mx,y:y+my})});
assert.equal(pointerCtx.pointerMoved(areaAt(0,0), {x:55,y:15}), false);
assert.equal(pointerCtx.pointerMoved(areaAt(40,0), {x:15,y:15}), false);
assert.equal(pointerCtx.pointerMoved(areaAt(40,0), {x:16,y:15}), true);
assert.equal(pointerCtx.pointerMoved(areaAt(40,0), {x:16,y:15}), false);
console.log('PASS: stationary/recreated hover ignored; physical pointer motion accepted');

// Lost base.json: every preset's layout turns back into the same native widgets.
{
  const ids = o => ['left', 'center', 'right'].flatMap(s => o[s].map(e => ctx.entryId(e))).sort();
  const full = {left: ['omarchy.menu', 'omarchy.workspaces', 'nerdibeard.ai-usage', 'omarchy.agents'], center: ['omarchy.weather'],
                right: [{id: 'omarchy.tailscale', keep: 1}, 'omarchy.network', 'flux', 'omamail', 'omarchy.bluetooth', 'omarchy.audio', 'omarchy.power']};
  for (const preset of ctx.PRESETS.concat(['hardware', 'compact'].map(right => ({options: {workspaces: 'cli', ai: 'ondemand', right, centre: 'calm'}})))) {
    const rebuilt = ctx.reconstructBase(ctx.build(full, preset.options, '/plugin/modules'));
    assert.deepEqual(ids(rebuilt), ids(full));
    assert(!ctx.hasOwn(rebuilt));
    const ts = ['left', 'center', 'right'].flatMap(s => rebuilt[s]).find(e => ctx.entryId(e) === 'omarchy.tailscale');
    assert.equal(ts.keep, 1);
  }
  // The desktop font profile is never switched by presets or combinations.
  assert.equal(ctx.keepDesktopFont({font: 'theme'}, {font: 'desktop'}).font, 'desktop');
  assert.equal(ctx.keepDesktopFont({font: 'desktop'}, {font: 'theme'}).font, 'bar');
  assert.equal(ctx.matchPreset(Object.assign({}, ctx.presetById('k1').options, {font: 'desktop'})), 'k1');
  console.log('PASS: base reconstruction, desktop font kept out of presets');
}

// Compact keeps hardware's members/settings; the edge never consumes a bar slot.
{
  assert.equal(ctx.ELEMENTS.right.variants.find(v => v.id === 'compact').label, 'A500 strip, compact');
  assert.equal(ctx.ELEMENTS.edge.variants.find(v => v.id === 'workbench').label, 'Workbench edge');
  assert.equal(ctx.normalizeOptions({}).edge, 'none');
  assert.equal(ctx.normalizeOptions({edge: 'unknown'}).edge, 'none');
  assert.equal(ctx.normalizeOptions({right: 'compact', edge: 'workbench'}).right, 'compact');
  assert.equal(ctx.normalizeOptions({right: 'compact', edge: 'workbench'}).edge, 'workbench');
  assert.equal(ctx.normalizeOptions({right: 'unknown'}).right, 'today');
  for (const preset of ctx.PRESETS) {
    assert.equal(ctx.normalizeOptions(preset.options).edge, 'none');
    assert.equal(ctx.matchPreset(preset.options), preset.id);
  }
  for (const ai of ctx.ELEMENTS.ai.variants.map(v => v.id)) {
    assert.deepEqual(plain(ctx.foldedIds({right: 'compact', ai})), plain(ctx.foldedIds({right: 'hardware', ai})));
  }
  const full = {left: ['omarchy.menu', 'omarchy.workspaces', 'omarchy.agents'], center: ['omarchy.weather'],
    right: plain(ctx.DRAWER).map(id => ({id, keep: id})).concat([{id: 'omarchy.power', keep: 'battery'},
      'omarchy.network', 'omamail', 'io.github.moizibnyousaf.omawhatsapp', 'omarchy.audio'])};
  const original = JSON.stringify(full);
  const compact = ctx.build(full, {right: 'compact', edge: 'workbench'}, '/plugin/modules');
  const hardware = ctx.build(full, {right: 'hardware'}, '/plugin/modules');
  const status = compact.right.find(e => e.id === 'amiga.status');
  assert.equal(status.variant, 'compact');
  assert.equal(status.source, '/plugin/modules/Status.qml');
  assert.deepEqual(plain(status.embeds), plain(hardware.right.find(e => e.id === 'amiga.status').embeds));
  assert.equal(status.embeds['omarchy.power'].keep, 'battery');
  assert.deepEqual(plain(compact.right.map(ctx.entryId)),
    ['omarchy.network', 'omamail', 'io.github.moizibnyousaf.omawhatsapp', 'amiga.status', 'omarchy.audio']);
  assert.equal(JSON.stringify(full), original);
  assert.deepEqual(plain(ctx.build(full, {edge: 'workbench'}, '/plugin/modules')), full);
  assert.deepEqual(plain(ctx.build(full, {right: 'compact', edge: 'none'}, '/plugin/modules')), plain(compact));
  status.embeds['omarchy.power'].keep = 'edited';
  const restored = ctx.build(ctx.mergeEmbeddedSettings(full, compact), {}, '/plugin/modules');
  assert.equal(restored.right.find(e => e.id === 'omarchy.power').keep, 'edited');
  assert.equal(ctx.keepDesktopFont({right: 'compact', edge: 'workbench'}, {}).edge, 'workbench');
  console.log('PASS: compact normalisation, folding, build/restoration and default-off slot-free edge');
}

// The thin integer surface encloses two physical pixel rows at fractional scale.
{
  const edge = fs.readFileSync(path.join(root, 'WorkbenchEdge.qml'), 'utf8');
  const edgeCtx = {};
  vm.createContext(edgeCtx);
  vm.runInContext(functionSource(edge, 'edgeGeometry'), edgeCtx);
  for (const scale of [0.75, 1, 1.25, 1.5, 1.75, 2, 2.5]) {
    for (const height of [25, 26, 27, 32, 39]) {
      const g = edgeCtx.edgeGeometry(height, scale);
      assert(Number.isInteger(g.top) && Number.isInteger(g.height));
      assert(g.highlightY >= 0 && g.highlightY + 2 / scale <= g.height + 1e-9);
      const firstPixel = Math.round(g.top * scale) + g.highlightY * scale;
      assert(Math.abs(firstPixel - (Math.round(height * scale) - 2)) < 1e-9);
      assert(g.height <= Math.ceil(2 / scale) + 1);
    }
  }
  const engine = fs.readFileSync(path.join(root, 'Engine.qml'), 'utf8');
  const readyExpr = engine.match(/readonly property bool barReady: ([\s\S]*?)\n  \/\//)[1];
  const fogExpr = engine.match(/readonly property bool fogVisible: ([^\n]*)/)[1];
  const expression = engine.match(/readonly property bool edgeVisible: ([^\n]*)/)[1];
  const evalEdge = (expr, edge, bar, id, fog) => {
    const c = {options: {edge, fog}, edgeBar: bar, shell: {barConfig: {id}}};
    c.barReady = !!vm.runInNewContext(readyExpr, c);
    c.fogOn = fog === 'on';
    return !!vm.runInNewContext(expr, c);
  };
  const edgeVisible = (edge, bar, id) => evalEdge(expression, edge, bar, id, 'off');
  // fog on: fog edge instead of the Workbench edge; never over a transparent bar
  assert(!evalEdge(expression, 'workbench', {barSize: 26, position: 'top', barHidden: false}, undefined, 'on'));
  assert(evalEdge(fogExpr, 'workbench', {barSize: 26, position: 'top', barHidden: false}, undefined, 'on'));
  assert(!evalEdge(fogExpr, 'none', {barSize: 26, position: 'top', barHidden: false, transparent: true}, undefined, 'on'));
  assert(!evalEdge(fogExpr, 'none', {barSize: 26, position: 'bottom', barHidden: false}, undefined, 'on'));
  assert(!evalEdge(fogExpr, 'none', {barSize: 26, position: 'top', barHidden: false}, undefined, 'off'));
  const bar = {barSize: 26, position: 'top', barHidden: false};
  assert(edgeVisible('workbench', bar));
  assert(edgeVisible('workbench', bar, 'omarchy.bar'));
  assert(!edgeVisible('none', bar));
  assert(!edgeVisible('workbench', null));
  assert(!edgeVisible('workbench', {...bar, barSize: 0}));
  assert(!edgeVisible('workbench', {...bar, barHidden: true}));
  assert(!edgeVisible('workbench', bar, 'another.bar'));
  for (const position of ['bottom', 'left', 'right']) assert(!edgeVisible('workbench', {...bar, position}));
  console.log('PASS: edge visibility and two device-pixel rows at seven scales');
}

// Stale usage records: a limit past its reset time counts as 0 %, not its last value.
{
  const modelCtx = {};
  vm.createContext(modelCtx);
  vm.runInContext(fs.readFileSync(path.resolve(root, '../omarchy-amiga-island/IslandModel.js'), 'utf8').replace('.pragma library', ''), modelCtx);
  const past = new Date(Date.now() - 2 * 3600e3).toISOString(), future = new Date(Date.now() + 3600e3).toISOString();
  const record = JSON.stringify({id: 'claude', limits: [
    {label: 'Session (5-hour)', percent: 1.0, resetsAt: past},
    {label: 'Weekly (7-day)', percent: 0.07, resetsAt: future}]});
  const limits = modelCtx.usageLimits(record, 'claude');
  assert.equal(limits[0].percent, 0);
  assert.equal(limits[1].percent, 0.07);
  assert.equal(modelCtx.limitPercent({percent: 1, resetsAt: future}, Date.now() + 2 * 3600e3), 0);
  console.log('PASS: expired usage limits read as reset');
}

// Logo option: with native workspaces only the menu logo becomes ours.
{
  const layoutBase = {left: ['omarchy.menu', 'omarchy.workspaces', 'nerdibeard.ai-usage'], center: [], right: ['omarchy.audio']};
  const opts = Object.assign({}, ctx.presetById('heute').options, {logo: 'amiga'});
  const built = ctx.build(layoutBase, opts, '/plugin/modules');
  assert.deepEqual(plain(built.left.map(ctx.entryId)), ['amiga.workspaces', 'omarchy.workspaces', 'nerdibeard.ai-usage']);
  assert.equal(built.left[0].variant, 'none');
  assert.equal(built.left[0].logo, 'amiga');
  assert.deepEqual(plain(ctx.reconstructBase(built).left), layoutBase.left);
  const k2 = ctx.build(layoutBase, ctx.presetById('k2').options, '/plugin/modules');
  assert.equal(k2.left[0].logo, 'amiga');
  assert.equal(ctx.build(layoutBase, ctx.presetById('heute').options, '/plugin/modules').left[0], 'omarchy.menu');
  console.log('PASS: logo option (menu-only module with native workspaces)');
}
// Look options (form, fog) sit on top of presets.
{
 const now = ctx.normalizeOptions({ fog: 'on', form: 'a500', font: 'bar' });
 assert.equal(ctx.keepDesktopFont(ctx.presetById('k1').options, now).fog, 'on');
 assert.equal(ctx.keepDesktopFont(ctx.presetById('k1').options, now).form, 'a500');
 assert.equal(ctx.keepDesktopFont({ fog: 'off' }, now).fog, 'off');
 assert.equal(ctx.matchPreset(Object.assign({}, ctx.normalizeOptions(ctx.presetById('k1').options), { fog: 'on', form: 'a500' })), 'k1');
 assert.equal(ctx.normalizeOptions({}).fog, 'off');
 assert.equal(ctx.normalizeOptions({}).form, 'full');
}

// Control Center model: staging, Save · Use · Cancel plans, search, health.
{
  const cc = {Presets: ctx};
  vm.createContext(cc);
  vm.runInContext(fs.readFileSync(path.join(root, 'ControlCenter.js'), 'utf8')
    .replace('.pragma library', '').replace(/^\.import .*$/m, ''), cc);
  const config = {
    bar: {layout: {left: [], center: [{id: 'nerdibeard.amiga-island', notifications: true, noteStyle: 'workbench'}], right: []}},
    plugins: [{id: 'nerdibeard.amiga-bar', options: {}}, {id: 'nerdibeard.card-picker'}, {id: 'nerdibeard.amiga-island', noteStyle: 'bubble'}]
  };
  const live = cc.liveState({fog: 'off', form: 'full', font: 'theme'}, config, 'enabled');
  // The island's bar.layout entry wins over its plugins[] entry; defaults fill the rest.
  assert.deepEqual(plain(live.island), {notifications: 'true', noteStyle: 'workbench', noteTopaz: 'true'});
  assert.deepEqual(plain(cc.islandValues(cc.islandEntry({plugins: [{id: 'nerdibeard.amiga-island', noteTopaz: false}]}))),
    {notifications: 'false', noteStyle: 'workbench', noteTopaz: 'false'});
  assert.equal(cc.islandEntry({bar: {layout: {center: ['nerdibeard.amiga-island']}}}), null);
  assert.equal(cc.liveState({}, {}, '').island, null);
  assert.equal(cc.liveState({}, {}, 'missing').cards, null);
  assert(cc.listed(config, 'nerdibeard.card-picker'));
  // Registry follows Presets.ELEMENTS (new rows appear automatically).
  assert.deepEqual(plain(cc.barIds()), Object.keys(ctx.ELEMENTS).map(k => 'bar.' + k));
  for (const id of cc.QUICK) assert(cc.setting(id), id);
  assert(cc.setting('bar.font').immediate);
  // Staging is an overlay; staging the live value removes the edit.
  let edits = cc.stage({}, live, 'bar.fog', 'on');
  edits = cc.stage(edits, live, 'island.noteStyle', 'bubble');
  edits = cc.stage(edits, live, 'cards.override', 'disabled');
  assert.deepEqual(plain(edits), {'bar.fog': 'on', 'island.noteStyle': 'bubble', 'cards.override': 'disabled'});
  assert.deepEqual(plain(cc.stage(edits, live, 'bar.fog', 'off')), {'island.noteStyle': 'bubble', 'cards.override': 'disabled'});
  assert.deepEqual(plain(cc.stage({}, cc.liveState({}, {}, ''), 'island.noteStyle', 'bubble')), {});
  assert.equal(cc.pendingState(live, edits).bar.fog, 'on');
  assert.equal(live.bar.fog, 'off');
  assert.deepEqual(plain(cc.changes(edits, live).map(c => c.id)), ['bar.fog', 'island.noteStyle', 'cards.override']);
  // Use/Save plan: island first, card picker next, the bar last as ONE apply.
  edits = cc.stage(edits, live, 'bar.form', 'a500');
  const steps = cc.plan(edits, live);
  assert.deepEqual(plain(steps.map(s => s.domain)), ['island', 'cards', 'bar']);
  assert.deepEqual(plain(steps[0]), {domain: 'island', key: 'noteStyle', value: 'bubble'});
  assert.equal(cc.barOptions(steps[2], live.bar).fog, 'on');
  assert.equal(cc.barOptions(steps[2], live.bar).form, 'a500');
  assert.deepEqual(plain(steps[2].keys), ['form', 'fog']);
  // Computed when the step runs: a font change applied in between survives.
  assert.equal(cc.barOptions(steps[2], Object.assign({}, live.bar, {font: 'topaz'})).font, 'topaz');
  assert.deepEqual(plain(cc.plan({}, live)), []);
  // Presets stage all bar keys, keep look options and never touch the desktop profile.
  const k2 = cc.stageBar({}, live, ctx.keepDesktopFont(ctx.presetById('k2').options, cc.pendingState(live, {'bar.fog': 'on'}).bar));
  assert.equal(cc.pendingState(live, k2).bar.workspaces, 'logo');
  assert.equal(cc.pendingState(live, k2).bar.font, 'bar');
  const desktopLive = cc.liveState({font: 'desktop'}, config, '');
  assert.equal(cc.stage({}, desktopLive, 'bar.font', 'theme')['bar.font'], undefined);
  assert.equal(cc.commitBar({font: 'theme'}, {font: 'desktop'}).font, 'desktop');
  assert.equal(cc.commitBar({font: 'desktop'}, {font: 'topaz'}).font, 'topaz');
  // Cancel after Use: back to the snapshot, only in the domains Use touched.
  const snapshot = cc.copy(live);
  const after = cc.liveState({fog: 'on', form: 'a500', font: 'theme'},
    {bar: {layout: {center: [{id: 'nerdibeard.amiga-island', notifications: true, noteStyle: 'bubble'}]}}}, 'disabled');
  assert.deepEqual(plain(cc.revertPlan(snapshot, after, {})), []);
  const back = cc.revertPlan(snapshot, after, {island: true, cards: true, bar: true});
  assert.deepEqual(plain(back.map(s => s.domain + ':' + (s.key || ''))), ['island:noteStyle', 'cards:override', 'bar:']);
  assert.equal(back[0].value, 'workbench');
  assert.equal(back[1].value, 'enabled');
  assert.equal(cc.barOptions(back[2], after.bar).fog, 'off');
  assert.equal(cc.barOptions(back[2], after.bar).form, 'full');
  // The font row is outside staging: the snapshot follows it, so Cancel keeps it.
  const fontMoved = cc.withValue(snapshot, 'bar.font', 'topaz');
  const liveTopaz = cc.liveState(Object.assign({}, after.bar, {font: 'topaz'}), {}, '');
  assert.equal(cc.barOptions(cc.revertPlan(fontMoved, liveTopaz, {bar: true})[0], liveTopaz.bar).font, 'topaz');
  assert.equal(cc.revertPlan(cc.withValue(snapshot, 'bar.font', 'theme'), cc.liveState({font: 'desktop'}, {}, ''), {bar: true}).length, 0);
  // After Use: applied edits drop out.
  assert.deepEqual(plain(cc.prune(edits, after)), {});
  // Island IPC state confirms what was set.
  assert(cc.islandReports({wants: true, style: 'bubble', topaz: true}, 'notifications', 'true'));
  assert(cc.islandReports({wants: true, style: 'bubble', topaz: true}, 'noteStyle', 'bubble'));
  assert(!cc.islandReports({wants: true, style: 'bubble', topaz: true}, 'noteTopaz', 'false'));
  assert(!cc.islandReports(null, 'noteStyle', 'bubble'));
  // Search: label, value and area matches; every token must match.
  const index = cc.searchIndex(live, {'bar.form': 'a500'}, [{id: 'bar.presets', area: 'bar', label: 'Presets', values: ['Today', 'K1 · Tidy'], current: ''}]);
  assert.equal(cc.search(index, 'fog')[0].id, 'bar.fog');
  const caseHit = cc.search(index, 'case edge')[0];
  assert.equal(caseHit.id, 'bar.form');
  assert.equal(caseHit.value, 'A500 case edge');
  assert(caseHit.matchedValue);
  assert.equal(cc.search(index, 'form')[0].value, 'A500 case edge');   // current = pending value
  assert.equal(cc.search(index, 'bubble')[0].id, 'island.noteStyle');
  {
    const hits = cc.search(index, 'island');
    for (const id of ['island.notifications', 'island.noteStyle', 'island.noteTopaz']) assert(hits.some(h => h.id === id), id);
    assert.equal(hits.find(h => h.id === 'bar.font').value, 'Bar, island & menus');   // value matches count too
  }
  assert.equal(cc.search(index, 'tidy')[0].id, 'bar.presets');
  assert.deepEqual(plain(cc.search(index, 'fog nonsense')), []);
  assert.deepEqual(plain(cc.search(index, '  ')), []);
  assert(cc.search(index, 'a', 3).length <= 3);
  assert(cc.searchIndex(cc.liveState({}, {}, ''), {}, []).every(e => e.area === 'bar'));
  // Health: only real facts; unknown facts are not counted as issues.
  const good = {hasBase: true, profile: 'normal', font: 'theme', usageFolded: true, usageIntervalSec: 900, usageAgeSec: 120,
                islandConfigured: true, islandWants: true, islandState: {serving: true, omarchyDisabled: true}, marker: true,
                cards: 'enabled', cardsConfigured: true, lastResult: 'ok', savedCount: 2};
  assert.deepEqual(plain(cc.healthSummary(cc.healthChecks(good))), {issues: 0, unknown: 0, label: 'OK'});
  const issues = f => cc.healthChecks(Object.assign({}, good, f)).filter(c => c.state === 'issue').map(c => c.id);
  assert.deepEqual(plain(issues({hasBase: false})), ['base']);
  assert.deepEqual(plain(issues({profile: 'partial'})), ['font']);
  assert.deepEqual(plain(issues({font: 'desktop'})), ['font']);
  assert.deepEqual(plain(issues({profile: 'amiga'})), ['font']);
  assert.deepEqual(plain(issues({profile: 'amiga', font: 'desktop'})), []);
  assert.deepEqual(plain(issues({usageAgeSec: 3 * 900})), ['usage']);
  assert.deepEqual(plain(issues({usageAgeSec: -1})), ['usage']);
  assert.deepEqual(plain(issues({usageFolded: false, usageAgeSec: -1})), []);
  assert.deepEqual(plain(issues({marker: false, islandState: {serving: true, omarchyDisabled: false}})), ['notes']);
  assert.deepEqual(plain(issues({marker: false})), []);   // Omarchy's were already off by hand
  assert.deepEqual(plain(issues({islandWants: false})), ['notes']);   // marker left behind
  assert.deepEqual(plain(issues({islandWants: false, marker: false})), []);
  assert.deepEqual(plain(issues({islandState: {serving: false, omarchyDisabled: true}})), ['notes']);
  assert.deepEqual(plain(issues({islandState: false})), ['notes']);
  assert.deepEqual(plain(issues({cards: 'missing'})), ['cards']);
  assert.deepEqual(plain(issues({cards: 'missing', cardsConfigured: false})), []);
  assert.deepEqual(plain(issues({lastResult: 'error: boom'})), ['apply']);
  assert.deepEqual(plain(issues({savedError: 'Cannot read saved combinations'})), ['saved']);
  assert.equal(cc.healthSummary(cc.healthChecks(Object.assign({}, good, {hasBase: false, lastResult: 'error: x'}))).label, '2 issues');
  assert.equal(cc.healthSummary(cc.healthChecks(Object.assign({}, good, {marker: null, profile: 'unknown'}))).label, '…');
  assert(cc.isArea('health') && !cc.isArea('nope'));
  console.log('PASS: control center staging, Save/Use/Cancel plans, search, health');
}

// Control Center wiring: replaces the options window, argv-only processes,
// IPC for areas, fog hook.
{
  const engine = fs.readFileSync(path.join(root, 'Engine.qml'), 'utf8');
  const qml = fs.readFileSync(path.join(root, 'ControlCenter.qml'), 'utf8');
  assert(engine.includes('ControlCenter {') && !engine.includes('OptionsWindow'));
  assert(/function cc\(area: string\): string/.test(engine));
  assert(engine.includes('cc: controlCenter.stateObject()'));
  assert(engine.includes('label: "Control Center …"'));
  assert(qml.includes('["omarchy-shell", "amiga-island", "set", step.key, String(step.value)]'));
  assert(!/"sh",\s*"-c"/.test(qml), 'no shell strings in the Control Center');
  assert(/property real reveal: win\.open \? 1 : 0/.test(qml) && qml.includes('opacity: reveal'));
  // All text goes through the Body/Caption/Moment components (native
  // rendering, plain text); no stray Text items.
  const rawText = [...qml.matchAll(/^(.*)\bText \{/gm)].filter(m => !/component \w+: $/.test(m[1]));
  assert.deepEqual(rawText.map(m => m[0]), []);
  for (const c of ['Body', 'Moment']) {
    const body = qml.slice(qml.indexOf('component ' + c + ': Text {'));
    const block = body.slice(0, body.indexOf('\n  }'));
    assert(block.includes('renderType: Text.NativeRendering') && block.includes('textFormat: Text.PlainText'), c);
  }
  console.log('PASS: control center wiring (engine, IPC, argv processes, fog hook)');
}
