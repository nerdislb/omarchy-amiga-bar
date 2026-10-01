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
  const expression = engine.match(/readonly property bool edgeVisible: ([\s\S]*?)\n  Variants/)[1];
  const edgeVisible = (edge, bar, id) => !!vm.runInNewContext(expression,
    {options: {edge}, edgeBar: bar, shell: {barConfig: {id}}});
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
