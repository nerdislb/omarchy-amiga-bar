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
 const out=cp.execFileSync('sh',['-c','printf %s '+failureCtx.quote(value)],{encoding:'utf8'});
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
  for (const preset of ctx.PRESETS.concat([{options: {workspaces: 'cli', ai: 'ondemand', right: 'hardware', centre: 'calm'}}])) {
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
