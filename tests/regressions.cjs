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
