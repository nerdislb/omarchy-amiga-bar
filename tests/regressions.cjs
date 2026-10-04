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

// Edge "theme": light and shadow from the theme's bar-material.json (Tusche & Papier, 03.10.2026).
{
  assert.equal(ctx.ELEMENTS.edge.variants.find(v => v.id === 'theme').label, 'From the theme (light & shadow)');
  assert.equal(ctx.normalizeOptions({edge: 'theme'}).edge, 'theme');
  assert.ok(plain(ctx.LOOK).includes('edge'), 'the edge is a look option, kept by presets');
  assert.equal(ctx.matchPreset(Object.assign({}, ctx.presetById('k1').options, {edge: 'theme'})), 'k1');
  const te = fs.readFileSync(path.join(root, 'ThemeEdge.qml'), 'utf8');
  assert.match(te, /bottom - px - 1/, 'the line surface keeps a transparent device pixel (1 px surfaces are never drawn)');
  assert.match(te, /WlrLayershell\.layer: WlrLayer\.Overlay/, 'the line sits over the bar');
  assert.match(te, /WlrLayershell\.layer: WlrLayer\.Top/, 'shadow/haze on Top: Bottom blends additively here');
  assert.doesNotMatch(te, /WlrLayer\.Bottom/);
  assert.match(te, /Math\.min\(depth \+ top, root\.gap\)/, 'with windows on the workspace only the gap above them');
  const fp = fs.readFileSync(path.join(root, 'FogPanel.qml'), 'utf8');
  assert.match(fp, /matOn: !fog && !!mat/, 'material only without fog');
  assert.match(fp, /if \(!rolls\) \{ rollOut\.stop\(\); rollIn\.stop\(\); return \}/, 'never write roll through a releasing Binding');
  assert.match(fp, /property: "gap"; value: 0; when: fp\.rolls/, 'the rolling card hangs flush from the bar');
  assert.match(fp, /rolling: rolls && roll < 0\.999 && \(panel\.open \|\| roll > 0\.001 \|\| \(!!card && card\.opacity > 0\.001\)\)/,
    'the roll mask stays until the rolled-in card has faded (no full-height flash on closing)');
  assert.match(fp, /height: parent\.height \* fp\.roll; color: "white"/, 'a rolled-in card shows nothing (no 1 px rest)');
  assert.match(fp, /presence: rolls \? roll : active \? grow : \(card \? card\.opacity : 0\)/, 'how far the card is out');
  // a panel that drops content on closing (Omarchy's audio panel) rolls in as it was while open
  assert.match(fp, /rollingIn: rolls && !panel\.open && roll > 0\.001/);
  assert.match(fp, /function keepSnap\(\) \{ Qt\.callLater\(fp\.takeSnap\) \}/, 'the snapshot geometry settles before it is taken');
  assert.match(fp, /live: !!fp\.panel && fp\.panel\.open\n\s*hideSource: fp\.rollingIn/, 'the snapshot freezes on closing and stands in for the card');
  assert.match(fp, /height: fp\.rollingIn \? fp\.snapH \* fp\.roll : 0\n\s*clip: true/, 'cut to the part that is still out');
  assert.match(fp, /x: fp\.frameX - spread/, 'the shadow follows the frozen frame');
  const wsTab = fs.readFileSync(path.join(root, 'modules/Workspaces.qml'), 'utf8');
  assert.match(wsTab, /inverted: !!source && \(root\.dropOpen \|\| \(!!dropLoader\.item && dropLoader\.item\.cardPresence > 0\.01\)\)/,
    'the logo stays the menu\'s tab until the card is back in the bar');
  assert.match(fs.readFileSync(path.join(root, 'DropMenu.qml'), 'utf8'), /readonly property real cardPresence: fogPanel\.presence/);
  const island = path.resolve(root, '../omarchy-amiga-island/views/FogPanel.qml');
  if (fs.existsSync(island)) {
    const strip = t => t.replace(/^\/\/ \(Same component in the Amiga (Island|Bar): keep both copies alike\.\)$/m, '');
    assert.equal(strip(fs.readFileSync(island, 'utf8')), strip(fp), 'both FogPanel copies alike');
  }
  const engine = fs.readFileSync(path.join(root, 'Engine.qml'), 'utf8');
  assert.match(engine, /current\/theme\.name/, 'reloads the material on theme switch');
  assert.match(engine, /materialOn: options\.edge === "theme" && !fogOn && !!material/);
  assert.match(engine, /themeEdgeVisible: materialOn && !!material\.edge && options\.form !== "a500" && barReady/);
  assert.match(engine, /property: "material"; value: root\.materialOn \? root\.material : null/);
  assert.match(fp, /bloomWanted: !fog && !!material && !!material\.card && material\.card\.bloom === true/, 'Lavur cards bloom');
  assert.match(fp, /matOn: !fog && !!mat && mat\.bloom !== true/, 'a bloom never rolls');
  assert.doesNotMatch(fp, /scallop/, 'no scallops: the dried rim replaced them (frame round, recommendation 6)');
  assert.match(fp, /InkSheet \{\n\s*visible: fp\.bloom\n/, 'a bloom is one sheet of wet paper');
  assert.match(fp, /FogLayer \{\n\s*visible: fp\.edge && !fp\.bloom\n/, 'the fog keeps its rim line, a bloom has none');
  const dm = fs.readFileSync(path.join(root, 'DropMenu.qml'), 'utf8');
  assert.match(dm, /visible: row\.hot && menu\.inverting && \(!menu\.brushFile \|\| brushImage\.status !== Image\.Ready\)/, 'hard inversion (Tusche/Papier, or while the brush is missing)');
  assert.match(fp, /if \(active && \(opening\.running \|\| closing\.running\)\) \{ opening\.stop\(\); closing\.stop\(\); follow\(\) \}/, 'reduced motion mid-bloom jumps to the end');
  assert.match(dm, /themeStamp/, 'the brush reloads on a theme switch');
  const ws = fs.readFileSync(path.join(root, 'modules/Workspaces.qml'), 'utf8');
  assert.match(ws, /tones\.strong/, 'logo and active number in the strong tone');
  // wet bloom: the shader and its compiled form ship next to FogPanel in both repos
  for (const dir of [root, path.resolve(root, '../omarchy-amiga-island/views')]) {
    if (!fs.existsSync(dir)) continue;
    assert.ok(fs.existsSync(path.join(dir, 'shaders/wetink.frag.qsb')), `compiled wet-ink shader in ${dir}`);
    const frag = fs.readFileSync(path.join(dir, 'shaders/wetink.frag'), 'utf8');
    for (const u of ['size', 'center', 'region', 'ink', 'front', 'band', 'body', 'ridge', 'resid', 'jitter', 'seed'])
      assert.match(frag, new RegExp(`\\b${u};`), `uniform ${u}`);
  }
  assert.match(fp, /if \(bloom\) \{ wetting\.stop\(\); clearing = 0; wet = 1; phase = 0; wetting\.start\(\) \}/, 'all ink from the first frame');
  assert.match(fp, /if \(wetting\.running\) settle\(\)/, 'reduced motion dries at once');
  // the dried rim (frame round 03.10.2026, recommendation 6): InkSheet and its shaders, alike in both repos
  const ink = fs.readFileSync(path.join(root, 'InkSheet.qml'), 'utf8');
  const islandInk = path.resolve(root, '../omarchy-amiga-island/views/InkSheet.qml');
  if (fs.existsSync(islandInk)) {
    const strip = t => t.replace(/^\/\/ \(Same component in the Amiga (Island|Bar): keep both copies alike\.\)$/m, '');
    assert.equal(strip(fs.readFileSync(islandInk, 'utf8')), strip(ink), 'both InkSheet copies alike');
  }
  for (const s of ['wetink', 'gauss', 'bloomcut', 'restink', 'halo'])
    assert.match(ink, new RegExp(`fragmentShader: Qt\\.resolvedUrl\\("shaders/${s}\\.frag\\.qsb"\\)`), `InkSheet uses ${s}`);
  assert.doesNotMatch(ink, /function smooth\(/, 'no method named like the Item property `smooth`');
  assert.doesNotMatch(ink, /MultiEffect/, 'the halo is exact (analytic Gaussian), no blurred layers');
  assert.match(ink, /wetAlpha: clearing < 0\.999 \? 1 : sstep\(0, 0\.7, wet\)/, 'the wet residue evaporates with the water');
  assert.match(ink, /show: sstep\(0\.55, 1, clearing\)/, 'the rim comes in as the front reaches the edge');
  assert.match(ink, /sourceItem: cut\n/, 'the paper itself is the mask of ink and pigment (one mask per sheet)');
  const uniforms = {
    gauss: ['dir', 's1', 's2', 'first'],
    bloomcut: ['size', 'origin', 'drift', 'lo', 'hi', 'amp', 'paper'],
    restink: ['size', 'origin', 'ink', 'ridge', 'pool', 'echo', 'resid', 'show', 'dry', 'barY'],
    halo: ['size', 'box', 'radius', 'sigma', 'tint', 'alpha'],
  };
  for (const dir of [root, path.resolve(root, '../omarchy-amiga-island/views')]) {
    if (!fs.existsSync(dir)) continue;
    for (const [s, list] of Object.entries(uniforms)) {
      const file = path.join(dir, `shaders/${s}.frag`);
      assert.ok(fs.existsSync(file + '.qsb'), `compiled ${s} shader in ${dir}`);
      const frag = fs.readFileSync(file, 'utf8');
      for (const u of list) assert.match(frag, new RegExp(`\\b${u};`), `${s}: uniform ${u}`);
      if (dir !== root) assert.equal(frag, fs.readFileSync(path.join(root, `shaders/${s}.frag`), 'utf8'), `${s} alike in both repos`);
    }
  }
  const rest = fs.readFileSync(path.join(root, 'shaders/restink.frag'), 'utf8');
  assert.match(rest, /\(d\.r - \(0\.53 \+ 0\.1 \* wN\)\)/, 'the rim just inside the edge (σ 2.2 distance)');
  assert.match(rest, /\(d\.g - 0\.82\) \/ 0\.045/, 'the drying line ~3–4 px further in (σ 4 distance)');
  assert.match(rest, /smoothstep\(barY \+ 2\.0, barY \+ 16\.0, px\.y\)/, 'no rim up into the bar');
  const gauss = fs.readFileSync(path.join(root, 'shaders/gauss.frag'), 'utf8');
  assert.match(gauss, /for \(int i = -24; i <= 24; i\+\+\)/, 'constant loop bounds (GLSL ES 100 target)');
  console.log('PASS: theme edge option, material wiring, rolling cards, blooms, hover, tones, wet ink, dried rim');
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
  // reveal shows the card: a plain fade, or after the fog has grown (fog look)
  assert(qml.includes('id: fogOpening') && qml.includes('opacity: reveal'));
  assert(fs.readFileSync(path.join(root, 'Engine.qml'), 'utf8').includes('fog: root.fogOn'));
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

// Nested drop-down menu (0.7.0): Apps, fonts and the questions of the actions
// it runs (omarchy-menu-select / -input) open inside the drop-down, never in
// the centred menu.
{
  const os = require('node:os');
  const shellQuote = v => "'" + String(v || '').replace(/'/g, "'\\''") + "'";   // qs.Commons Util.shellQuote
  const manifest = JSON.parse(fs.readFileSync(path.join(root, 'manifest.json'), 'utf8'));
  const [major, minor] = manifest.version.split(/[.-]/).map(Number);
  assert.ok(major > 0 || minor >= 7, `nested drop-down since 0.7.0 (version ${manifest.version})`);
  assert.deepEqual(manifest.kinds, ['panel', 'menu'], '"menu" brings the app-library facade; "panel" keeps the loader');
  // omarchy-plugin-validate: every kind needs its entry point
  const entryFor = {bar: 'bar', 'bar-widget': 'barWidget', menu: 'menu', overlay: 'overlay', panel: 'panel', service: 'service'};
  for (const k of manifest.kinds) assert.equal(manifest.entryPoints[entryFor[k]], 'Engine.qml', k);

  const dm = fs.readFileSync(path.join(root, 'DropMenu.qml'), 'utf8');
  const oms = fs.readFileSync(path.join(root, 'OmarchyMenuSource.qml'), 'utf8');
  const en = fs.readFileSync(path.join(root, 'Engine.qml'), 'utf8');
  const ws = fs.readFileSync(path.join(root, 'modules/Workspaces.qml'), 'utf8');
  const providersOf = text => {
    const from = text.indexOf('readonly property var providers: ');
    const c = {Util: {shellQuote}};
    vm.createContext(c);
    return vm.runInContext(text.slice(text.indexOf('({', from), text.indexOf('\n  })', from) + 5), c);
  };

  // Omarchy's own shell, where installed: the plugin still loads as the same
  // keep-loaded panel; only its scoped shell gains the application library.
  const omarchy = [process.env.OMARCHY_PATH, path.join(os.homedir(), '.local/share/omarchy'), path.join(os.homedir(), 'omarchy'), '/usr/share/omarchy']
    .find(d => d && fs.existsSync(path.join(d, 'shell/shell.qml')));
  if (omarchy) {
    const shellQml = fs.readFileSync(path.join(omarchy, 'shell/shell.qml'), 'utf8');
    const sc = {};
    vm.createContext(sc);
    vm.runInContext(['manifestHasKind', 'pluginShellCapabilityProfile', 'computePanelEntries', 'isBarWidgetPanelPlugin']
      .map(n => functionSource(shellQml, n)).join('\n'), sc);
    sc.shell = {manifestHasKind: sc.manifestHasKind, pluginRegistry: {installedPlugins: {}, isEnabled: () => true}};
    const before = Object.assign({}, manifest, {kinds: ['panel'], entryPoints: {panel: 'Engine.qml'}});
    for (const m of [before, manifest]) {
      sc.shell.pluginRegistry.installedPlugins = {[m.id]: m};
      assert.deepEqual(plain(sc.computePanelEntries().map(e => [e.id, e.kind, e.keepLoaded])), [[m.id, 'panel', true]]);
      assert.equal(sc.isBarWidgetPanelPlugin(m.id), false);
    }
    assert.equal(sc.pluginShellCapabilityProfile(before, true, false), 'own-service|no-bar|no-menu');
    assert.equal(sc.pluginShellCapabilityProfile(manifest, true, false), 'own-service|no-bar|menu');
    assert.match(shellQml, /appLibrary: shell\.manifestHasKind\(manifest, "menu"\)/, 'menu plugins get the app library facade');
    // the providers are the native menu's, unchanged
    const mine = providersOf(oms), native = providersOf(fs.readFileSync(path.join(omarchy, 'shell/plugins/menu/Menu.qml'), 'utf8'));
    assert.deepEqual(Object.keys(mine), Object.keys(native));
    for (const k of Object.keys(native)) {
      assert.equal(mine[k].script, native[k].script, k);
      assert.equal(mine[k].icon, native[k].icon, k);
      assert.equal(!!mine[k].volatile, !!native[k].volatile, k);
      assert.equal(mine[k].actionFor("Fira Code's"), native[k].actionFor("Fira Code's"), k);
    }
    assert.equal(fs.readFileSync(path.join(root, 'vendor/MenuModel.js'), 'utf8'),
      fs.readFileSync(path.join(omarchy, 'shell/plugins/menu/MenuModel.js'), 'utf8'), 'vendor/MenuModel.js: refresh the copy (vendor/README.md)');
  } else console.log('(no Omarchy shell source found: shell checks skipped)');

  // Questions, read the native way: the glyph never comes back, a subtext does.
  const dc = {menu: {requestSerial: 0, query: ''}};
  vm.createContext(dc);
  vm.runInContext(['choiceRow', 'makeRequest', 'listRows'].map(n => functionSource(dm, n)).join('\n'), dc);
  assert.deepEqual(plain(dc.choiceRow('Berlin', 0)), {kind: 'choice', id: 'choice.0', icon: '', label: 'Berlin', note: '', answer: 'Berlin'});
  assert.deepEqual(plain(dc.choiceRow('G\tOnly', 1)), {kind: 'choice', id: 'choice.1', icon: 'G', label: 'Only', note: '', answer: 'Only'});
  assert.deepEqual(plain(dc.choiceRow('\u{f0431}\tAmiga Bar\tnerdibeard.amiga-bar', 2)),
    {kind: 'choice', id: 'choice.2', icon: '\u{f0431}', label: 'Amiga Bar', note: 'nerdibeard.amiga-bar', answer: 'Amiga Bar\tnerdibeard.amiga-bar'});
  assert.equal(dc.choiceRow('G\tL\tsub\tmore', 3).answer, 'L\tsub\tmore');
  const rq = dc.makeRequest({mode: 'select', prompt: 'Set timezone', options: ['A', 'B'], selectionFile: '/t/s', doneFile: '/t/d', width: 520, maxHeight: '400', token: 'tok'});
  assert.deepEqual([rq.id, rq.mode, rq.rows.length, rq.width, rq.maxHeight, rq.token], [1, 'select', 2, 520, 400, 'tok']);
  const inp = dc.makeRequest({mode: 'input', doneFile: '/t/d'});
  assert.deepEqual([inp.id, inp.prompt, inp.rows.length, inp.width, inp.token], [2, 'Input', 0, 0, '']);
  assert.equal(dc.makeRequest({mode: 'other', doneFile: '/t/d'}).prompt, 'Select');
  // typing inside a list level filters it by label and subtext
  const zones = ['a\tEurope/Berlin\tCET', 'b\tAmerica/New_York\tEST', 'c\tAsia/Tokyo'].map(dc.choiceRow);
  dc.menu.query = 'est';
  assert.deepEqual(plain(dc.listRows(zones).map(r => r.label)), ['America/New_York']);
  dc.menu.query = ' TOKYO ';
  assert.deepEqual(plain(dc.listRows(zones).map(r => r.label)), ['Asia/Tokyo']);
  dc.menu.query = 'browser';
  assert.equal(dc.listRows([{kind: 'app', label: 'Zen', sub: 'Web Browser'}])[0].label, 'Zen');
  dc.menu.query = 'zzz';
  assert.deepEqual(plain(dc.listRows(zones).map(r => [r.label, r.disabled])), [['No matches', true]]);
  dc.menu.query = '';
  assert.equal(dc.listRows(zones).length, 3);
  assert.equal(dc.listRows([])[0].label, 'Nothing here');

  // Actions that ask, providers, apps (OmarchyMenuSource).
  const MenuModel = require(path.join(root, 'vendor/MenuModel.js'));
  const sc2 = {MenuModel, Util: {shellQuote}, askWords: {}, providers: providersOf(oms)};
  vm.createContext(sc2);
  vm.runInContext(['firstWord', 'asks', 'askScript', 'providerList', 'appRow', 'loadApps', 'appHits'].map(n => functionSource(oms, n)).join('\n'), sc2);
  assert.equal(sc2.firstWord('omarchy-menu-plugin enable'), 'omarchy-menu-plugin');
  assert.equal(sc2.firstWord('  omarchy-menu-keybindings'), 'omarchy-menu-keybindings');
  assert.equal(sc2.firstWord("omarchy-launch-webapp 'https://x'"), 'omarchy-launch-webapp');
  assert.equal(sc2.firstWord('background=$(omarchy-theme-bg-switcher); x'), '');
  sc2.askWords = {'omarchy-menu-plugin': true, 'omarchy-capture-screenrecording-with-webcam': true};
  assert(sc2.asks('omarchy-menu-plugin enable'));
  assert(!sc2.asks('omarchy-menu-plugins enable'));
  assert(!sc2.asks('omarchy-capture-screenrecording-with-webcam'), 'screen captures never wait in the drop-down');
  const fonts = sc2.providerList('style.font', 'fonts', 'Fira Code\tFira Code\tJetBrains Mono\nJetBrains Mono\tJetBrains Mono\tJetBrains Mono\n\nFira-Code\tFira-Code\tJetBrains Mono\n');
  assert.deepEqual(plain(fonts.map(r => [r.label, r.checked, r.id, r.kind])), [
    ['Fira Code', false, 'style.font.fira-code', 'action'], ['JetBrains Mono', true, 'style.font.jetbrains-mono', 'action'],
    ['Fira-Code', false, 'style.font.fira-code-', 'action']]);
  assert.equal(fonts[0].action, "omarchy-font-set 'Fira Code'");
  assert.equal(fonts[0].icon, '\ue659');
  assert.deepEqual(plain(sc2.providerList('x', 'unknown', 'a\tb')), []);
  const entries = [{id: 'zen', name: 'Zen Browser', genericName: 'Web Browser', icon: 'zen'},
    {id: 'alacritty', name: 'Alacritty', genericName: 'Terminal', icon: '/x/a.svg'}, {id: 'zen', name: 'Zen Browser', icon: 'zen'}, {id: '', name: 'Nameless'}];
  sc2.appLibrary = {
    sortedEntries: q => entries.filter(e => !q || e.name.toLowerCase().includes(q.toLowerCase())).map(entry => ({entry})),
    entryName: e => e.name, entrySubtext: e => e.genericName || ''
  };
  sc2.loadApps();
  assert.deepEqual(plain(sc2.appRows.map(r => [r.id, r.appId, r.label, r.sub, r.path, r.appIcon])), [
    ['apps.alacritty', 'alacritty', 'Alacritty', 'Terminal', 'Terminal', '/x/a.svg'], ['apps.zen', 'zen', 'Zen Browser', 'Web Browser', 'Web Browser', 'zen']]);
  assert.deepEqual(plain(sc2.appHits('browser', 8).map(r => [r.label, r.path])), [['Zen Browser', 'Apps']]);
  assert.equal(sc2.appHits('a', 1).length, 1);
  assert.deepEqual(plain(sc2.appHits(' ', 8)), []);
  sc2.appLibrary = null;
  sc2.loadApps();
  assert.deepEqual(plain(sc2.appRows), []);
  assert.deepEqual(plain(sc2.appHits('zen', 8)), []);

  // The engine routes a question to a drop-down, or refuses (the shim then
  // runs Omarchy's own command).
  const ec = {};
  vm.createContext(ec);
  vm.runInContext(['screenOf', 'dropTarget', 'ask'].map(n => functionSource(en, n)).join('\n'), ec);
  const inst = (name, more) => Object.assign({QsWindow: {window: {visible: true, screen: {name}}}, dropAvailable: true, dropOpen: false,
    tracked: [], asked: [], accepts: true, dropTracks(t) { return this.tracked.includes(t) }, dropAsk(p) { this.asked.push(p); return this.accepts }}, more || {});
  const A = inst('eDP-1'), B = inst('HDMI-A-1'), C = inst('DP-2', {dropAvailable: false});
  ec.Bridge = {ModuleBus: {instances: {workspaces: [C, A, B]}, pick: () => B}};
  ec.root = {lastDropScreen: '', dropTarget: t => ec.dropTarget(t), screenOf: i => ec.screenOf(i)};
  const payload = more => JSON.stringify(Object.assign({mode: 'select', prompt: 'P', options: ['a'], selectionFile: '/tmp/s', doneFile: '/tmp/d'}, more));
  for (const bad of ['not json', '"text"', payload({mode: 'menu'}), payload({doneFile: ''}), payload({doneFile: 'rel/d'}), payload({selectionFile: 'rel/s'})])
    assert.equal(ec.ask(bad), 'invalid payload', bad);
  assert.equal(ec.ask(payload({})), 'ok');
  assert.equal(B.asked.length, 1, 'no history: the focused screen');
  ec.root.lastDropScreen = 'eDP-1';
  assert.equal(ec.ask(payload({mode: 'input', selectionFile: undefined})), 'ok');
  assert.equal(A.asked.length, 1, 'the screen that had it last');
  B.dropOpen = true;
  ec.ask(payload({}));
  assert.equal(B.asked.length, 2, 'an open drop-down');
  A.tracked = ['tok'];
  ec.ask(payload({token: 'tok'}));
  assert.equal(A.asked.length, 2, 'the drop-down that launched the asking action');
  assert.equal(C.asked.length, 0, 'never one that is not available');
  A.accepts = false;
  assert.equal(ec.ask(payload({token: 'tok'})), 'no drop-down');
  ec.Bridge.ModuleBus = {instances: {workspaces: [C]}, pick: () => null};
  assert.equal(ec.ask(payload({})), 'no drop-down');
  assert.match(en, /function ask\(payload: string\): string \{ return root\.ask\(payload\) \}/);
  assert.match(en, /readonly property string shimDir: pluginDir \+ "\/bin\/menu-shim"/);
  assert.match(en, /ask: root\.askState\(\)/);
  assert.match(ws, /if \(!dropAvailable \|\| !m \|\| !m\.takeRequest\(request\)\) return false\n    if \(m\.hasPending\(\)\) open\(\)/,
    'opens only for a pending question (an abandoned one is cancelled quietly)');

  // DropMenu wiring: nested levels, look kept, every close cancels.
  assert.match(dm, /readonly property bool opens: r\.kind === "menu" \|\| r\.kind === "group" \|\| r\.kind === "provider" \|\| r\.asks === true/, 'chevrons for the new levels');
  assert.match(dm, /ListView \{\n        id: list/);
  assert.doesNotMatch(dm, /Repeater/);
  assert.match(dm, /else if \(r\.kind === "app"\) \{ var lib = appLibrary; finish\(function\(\) \{ if \(lib\) lib\.launch\(r\.appId, r\.label\) \}\) \}/, 'close, then launch');
  assert.match(dm, /if \(!source\.hasProvider\(r\.provider\)\) \{\n      finish\(function\(\) \{ Util\.execDetached\("omarchy-menu summon " \+ Util\.shellQuote\(r\.id\)\) \}\)/,
    'unknown providers (or Apps without the library) keep the native menu');
  assert.match(dm, /function runAction\(action\) \{\n    Util\.execDetached\(prefixed\(action, ""\)\)/, 'every action gets the shims');
  assert.match(dm, /proc\.command = launchCommand\(r\.action, token\)/);
  assert.match(dm, /if \(!menu\.open\) \{ menu\.dropClosed\(\); return \}/, 'every close cancels what is pending');
  assert.match(dm, /Component\.onDestruction: cancelAll\(\)/);
  assert.match(dm, /visible: row\.isApp && status === Image\.Ready/, "an app's own icon, the glyph until it is there");

  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'amiga-bar-test-'));
  try {
    const put = (dir, name, text, mode = 0o755) => {
      fs.mkdirSync(dir, {recursive: true});
      fs.writeFileSync(path.join(dir, name), text);
      fs.chmodSync(path.join(dir, name), mode);
    };
    const clean = {HOME: tmp, LANG: 'C.UTF-8'};
    const shimDir = path.join(root, 'bin/menu-shim');

    // The PATH prefix and the tracked launch: shims first, the token along,
    // the action waited for – and still running after its waiter is killed.
    const lc = {Util: {shellQuote}, shimDir: "/x/it's dir"};
    vm.createContext(lc);
    vm.runInContext(functionSource(dm, 'prefixed') + '\n' + functionSource(dm, 'launchCommand'), lc);
    const sh = (cmd, env) => cp.execFileSync('bash', ['-c', cmd], {encoding: 'utf8', env: Object.assign({PATH: '/usr/bin:/bin'}, clean, env)});
    assert.equal(sh(lc.prefixed('printf "%s|%s" "${PATH%%:*}" "${AMIGA_BAR_ASK_TOKEN-unset}"', 'tok')), "/x/it's dir|tok");
    assert.equal(sh(lc.prefixed('printf "%s" "${AMIGA_BAR_ASK_TOKEN-unset}"', '')), 'unset');
    lc.shimDir = shimDir;
    const timed = Date.now();
    const waited = cp.spawnSync(...(a => [a[0], a.slice(1)])(lc.launchCommand('sleep 0.3; exit 7', 't')), {env: Object.assign({PATH: '/usr/bin:/bin'}, clean)});
    assert.equal(waited.status, 7, 'the waiter ends with the action');
    assert(Date.now() - timed >= 300);
    const marker = path.join(tmp, 'marker');
    const argv = lc.launchCommand('sleep 0.6; printf "%s|%s" "$(command -v omarchy-menu-select)" "$AMIGA_BAR_ASK_TOKEN" > ' + shellQuote(marker), 'tok9');
    const survived = cp.execFileSync('bash', ['-c', '"$@" & w=$!; sleep 0.2; kill -9 $w; wait $w 2>/dev/null; sleep 1; cat ' + shellQuote(marker), 'bash', ...argv],
      {encoding: 'utf8', env: Object.assign({PATH: '/usr/bin:/bin'}, clean)});
    assert.equal(survived, path.join(shimDir, 'omarchy-menu-select') + '|tok9', 'the action outlives its waiter');

    // The drop-down's writes, run as the QML runs them: the answer, then the
    // done file; a cancel is the done file alone; nothing once the asker left.
    const writes = [];
    const wc = {Quickshell: {execDetached: argv => writes.push(argv)}};
    vm.createContext(wc);
    vm.runInContext(functionSource(dm, 'writeAnswer') + '\n' + functionSource(dm, 'writeCancel'), wc);
    const runWrite = () => { const a = writes.pop(); cp.execFileSync(a[0], a.slice(1)); return a };
    const sel = path.join(tmp, 'sel'), done = path.join(tmp, 'done');
    fs.writeFileSync(sel, '');
    wc.writeAnswer({selectionFile: sel, doneFile: done}, 'Europe/Berlin\tCET');
    const answerArgv = runWrite();
    assert.equal(fs.readFileSync(sel, 'utf8'), 'Europe/Berlin\tCET\n');
    assert(fs.existsSync(done));
    fs.writeFileSync(sel, ''); fs.rmSync(done);
    wc.writeCancel({selectionFile: sel, doneFile: done});
    const cancelArgv = runWrite();
    assert.equal(fs.readFileSync(sel, 'utf8'), '');
    assert(fs.existsSync(done));
    fs.rmSync(done);
    wc.writeAnswer({selectionFile: sel, doneFile: done}, "$(echo nope) 'q' \\n");
    runWrite();
    assert.equal(fs.readFileSync(sel, 'utf8'), "$(echo nope) 'q' \\n\n", 'answers stay literal');
    fs.rmSync(sel); fs.rmSync(done);
    wc.writeAnswer({selectionFile: sel, doneFile: done}, 'x'); runWrite();
    wc.writeCancel({selectionFile: sel, doneFile: done}); runWrite();
    assert(!fs.existsSync(sel) && !fs.existsSync(done), 'the asker has gone: nothing written');

    // The detection: only `#!` scripts that call omarchy-menu-select / -input.
    const bin = path.join(tmp, 'detect');
    put(bin, 'asker', '#!/bin/bash\nx=$(omarchy-menu-select "Pick" a b)\n');
    put(bin, 'typer', '#!/bin/sh\nomarchy-menu-input Name\n');
    put(bin, 'quiet', '#!/bin/bash\necho hello\n');
    put(bin, 'binary', '\x7fELF omarchy-menu-select\n');
    put(bin, 'plain', '#!/bin/bash\nomarchy-menu-select x\n', 0o644);
    const asking = cp.execFileSync('bash', ['-c', sc2.askScript(), 'bash', 'asker', 'typer', 'quiet', 'binary', 'plain', 'missing', 'echo', path.join(bin, 'asker')],
      {encoding: 'utf8', env: Object.assign({PATH: bin + ':/usr/bin:/bin'}, clean)});
    assert.deepEqual(asking.split('\n').filter(Boolean).sort(), [path.join(bin, 'asker'), 'asker', 'typer'].sort());

    // The shims end to end: a fake omarchy-shell that answers as the
    // drop-down does (with its own write commands), one that fails, one that
    // refuses; a fake original for the fallback.
    const tmpdir = path.join(tmp, 't'), log = path.join(tmp, 'payload.json');
    fs.mkdirSync(tmpdir);
    const fakeOk = '#!/bin/bash\n'
      + '[[ ${1:-} == amiga-bar && ${2:-} == ask ]] || { echo "Function not found." >&2; exit 1; }\n'
      + 'printf "%s" "$3" > "$FAKE_LOG"\n'
      + 'sel=$(perl -MJSON::PP -e \'print decode_json($ARGV[0])->{selectionFile}\' "$3")\n'
      + 'done=$(perl -MJSON::PP -e \'print decode_json($ARGV[0])->{doneFile}\' "$3")\n'
      + '( sleep 0.2\n'
      + '  if [[ -n ${FAKE_ANSWER+x} ]]; then sh -c "$FAKE_WRITE_ANSWER" sh "$sel" "$done" "$FAKE_ANSWER"\n'
      + '  else sh -c "$FAKE_WRITE_CANCEL" sh "$sel" "$done"; fi ) >/dev/null 2>&1 &\n'
      + 'echo ok\n';
    put(path.join(tmp, 'shell-ok'), 'omarchy-shell', fakeOk);
    put(path.join(tmp, 'shell-fail'), 'omarchy-shell', '#!/bin/bash\necho "omarchy-shell is not running" >&2\nexit 1\n');
    put(path.join(tmp, 'shell-refuse'), 'omarchy-shell', '#!/bin/bash\necho "no drop-down"\n');
    const fakeOriginal = '#!/bin/bash\n'
      + 'printf "original"; for a in "$@"; do printf " [%s]" "$a"; done; printf "\\n"\n'
      + 'case ":$PATH:" in *":$SHIM_DIR"*|*":$SHIM_LINK"*) echo "shim still on PATH" ;; esac\n'
      + 'if [[ ! -t 0 ]]; then while IFS= read -r line; do printf "stdin [%s]\\n" "$line"; done; fi\n'
      + 'exit "${FAKE_EXIT:-0}"\n';
    put(path.join(tmp, 'orig'), 'omarchy-menu-select', fakeOriginal);
    put(path.join(tmp, 'orig'), 'omarchy-menu-input', fakeOriginal);
    const link = path.join(tmp, 'shim-link');
    fs.symlinkSync(shimDir, link);
    const shim = (name, args, mode, opts = {}) => {
      fs.rmSync(log, {force: true});
      const r = cp.spawnSync(name, args, {input: opts.input || '', encoding: 'utf8', timeout: 20000,
        env: Object.assign({}, clean, {TMPDIR: tmpdir, SHIM_DIR: shimDir, SHIM_LINK: link, FAKE_LOG: log,
          FAKE_WRITE_ANSWER: answerArgv[2], FAKE_WRITE_CANCEL: cancelArgv[2],
          PATH: [opts.lead || shimDir, path.join(tmp, 'shell-' + mode), path.join(tmp, 'orig'), '/usr/bin', '/bin'].join(':')}, opts.env || {})});
      assert.equal(r.error, undefined, String(r.error));
      assert.deepEqual(fs.readdirSync(tmpdir), [], 'no temp file left behind');
      return r;
    };
    const sent = () => JSON.parse(fs.readFileSync(log, 'utf8'));
    for (const name of ['omarchy-menu-select', 'omarchy-menu-input']) {
      const file = path.join(shimDir, name), text = fs.readFileSync(file, 'utf8');
      assert(fs.statSync(file).mode & 0o111, name + ' is executable');
      cp.execFileSync('bash', ['-n', file]);
      assert.match(text, /^#!\/bin\/bash\n/);
      assert.match(text, /\nset -euo pipefail\n/);
    }
    // select, answered in the drop-down (options as arguments, menu arguments, token)
    let r = shim('omarchy-menu-select', ['Set timezone', 'Europe/Berlin', 'Asia/Tokyo', '--', '--width', '520', '--height', '400'], 'ok',
      {env: {FAKE_ANSWER: 'Asia/Tokyo', AMIGA_BAR_ASK_TOKEN: 'tok1'}});
    assert.equal(r.status, 0, r.stderr);
    assert.equal(r.stdout, 'Asia/Tokyo\n');
    let p = sent();
    assert.deepEqual([p.mode, p.prompt, p.options, p.width, p.maxHeight, p.token], ['select', 'Set timezone', ['Europe/Berlin', 'Asia/Tokyo'], 520, 400, 'tok1']);
    assert(path.isAbsolute(p.selectionFile) && path.isAbsolute(p.doneFile) && !fs.existsSync(p.selectionFile));
    // options from stdin, with glyph and subtext; the answer keeps the subtext
    r = shim('omarchy-menu-select', ['Enable plugin'], 'ok', {input: '\u{f0431}\tAmiga Bar\tnerdibeard.amiga-bar\nplain\n', env: {FAKE_ANSWER: 'Amiga Bar\tnerdibeard.amiga-bar'}});
    assert.equal(r.status, 0, r.stderr);
    assert.equal(r.stdout, 'Amiga Bar\tnerdibeard.amiga-bar\n');
    p = sent();
    assert.deepEqual(p.options, ['\u{f0431}\tAmiga Bar\tnerdibeard.amiga-bar', 'plain']);
    assert(!('token' in p) && !('width' in p) && !('maxHeight' in p));
    // cancelled in the drop-down: exit 1, nothing printed (as the original)
    r = shim('omarchy-menu-select', ['Pick'], 'ok', {input: 'a\nb\n'});
    assert.deepEqual([r.status, r.stdout], [1, '']);
    // usage errors stay the original's, without asking anyone
    r = shim('omarchy-menu-select', ['Pick'], 'ok', {input: ''});
    assert.equal(r.status, 1);
    assert.match(r.stderr, /Usage: omarchy-menu-select/);
    assert(!fs.existsSync(log));
    r = shim('omarchy-menu-select', [], 'ok');
    assert.equal(r.status, 1);
    // input, answered (an empty answer is an answer, as in the native menu)
    r = shim('omarchy-menu-input', ['Reminder in minutes', '--width', '400'], 'ok', {env: {FAKE_ANSWER: '15'}});
    assert.deepEqual([r.status, r.stdout], [0, '15\n']);
    p = sent();
    assert.deepEqual([p.mode, p.prompt, p.width, 'options' in p], ['input', 'Reminder in minutes', 400, false]);
    r = shim('omarchy-menu-input', [], 'ok', {env: {FAKE_ANSWER: ''}});
    assert.deepEqual([r.status, r.stdout, sent().prompt], [0, '\n', 'Input']);
    r = shim('omarchy-menu-input', ['Name'], 'ok');
    assert.deepEqual([r.status, r.stdout], [1, '']);
    // no drop-down (shell failing or refusing): the original, same arguments, same stdin
    for (const mode of ['fail', 'refuse']) {
      r = shim('omarchy-menu-select', ['Pick', 'a b', 'c', '--', '--width', '520'], mode);
      assert.deepEqual([r.status, r.stdout], [0, 'original [Pick] [a b] [c] [--] [--width] [520]\n'], mode);
      r = shim('omarchy-menu-select', ['Pick', '--', '--maxheight', '300'], mode, {input: 'one\n--\n  spaced  \n\u{f0431}\tlabel\tsub\n', env: {FAKE_EXIT: '3'}});
      assert.equal(r.status, 3, 'the original\'s exit status');
      assert.equal(r.stdout, 'original [Pick] [--] [--maxheight] [300]\nstdin [one]\nstdin [--]\nstdin [  spaced  ]\nstdin [\u{f0431}\tlabel\tsub]\n');
      r = shim('omarchy-menu-input', ['Name', '--width', '300'], mode);
      assert.deepEqual([r.status, r.stdout], [0, 'original [Name] [--width] [300]\n'], mode);
      r = shim('omarchy-menu-input', [], mode);
      assert.deepEqual([r.status, r.stdout], [0, 'original\n'], mode);
    }
    // the shim directory spelled three ways on PATH: still no loop, and the
    // original never sees it
    r = shim('omarchy-menu-select', ['Pick', 'x'], 'fail', {lead: [link, shimDir + '/', shimDir].join(':')});
    assert.deepEqual([r.status, r.stdout], [0, 'original [Pick] [x]\n']);
  } finally {
    fs.rmSync(tmp, {recursive: true, force: true});
  }
  console.log('PASS: nested drop-down (manifest kind, shell facade, providers, questions, routing, writes, detection, shims end to end)');
}

// Omarchy's own popups (native widgets folded into the status groups) take
// the theme material: NativeMaterial finds their KeyboardPanel and hangs a
// FogPanel into its content holder; without material/fog nothing changes.
{
  const nm = fs.readFileSync(path.join(root, 'NativeMaterial.qml'), 'utf8');
  const st = fs.readFileSync(path.join(root, 'modules/Status.qml'), 'utf8');
  assert(nm.includes('readonly property Component fogComponent: Component { FogPanel {} }'));
  assert(nm.includes('fogComponent.createObject(holder, {'));
  assert(nm.includes('edge: false'), 'no extra line or shadow on Omarchy popups without material');
  assert(/o\.borderSpec !== undefined && o\.anchorItem !== undefined/.test(nm));
  assert(nm.includes('h.parent.borderSpec !== undefined'), 'the holder sits in the card, as FogPanel expects');
  assert(nm.includes('dressed.indexOf(p) !== -1'), 'never two FogPanels in one popup');
  assert(st.includes('Root.NativeMaterial { id: nativeMaterial }'));
  assert(st.includes('Qt.callLater(function() { nativeMaterial.attach(it) })'));
  // Omarchy's widgets in its own bar keep their trusted bar; only their popups are dressed
  assert(nm.includes('function dressBar(from)') && st.includes('nativeMaterial.dressBar(root)'));
  assert(/nativeIds: \["omarchy\.audio", "omarchy\.power"/.test(nm), 'only Omarchy panel widgets');
  assert(nm.includes('o.activeItem !== undefined && o.region !== undefined'), 'bar slots recognised by their API');
  console.log('PASS: native popups take the theme material');
}

// Logos from the logo design round (04.10.): Arch (the official mark,
// unaltered) and the Nerdibeard seal, each with the reviewed motion.
{
  const logoIds = ctx.ELEMENTS.logo.variants.map(v => v.id);
  for (const id of ['omarchy', 'arch', 'nerdibeard', 'amiga', 'boing']) assert(logoIds.includes(id), id);
  const layoutBase = {left: ['omarchy.menu', 'omarchy.workspaces'], center: [], right: []};
  for (const logo of ['arch', 'nerdibeard']) {
    const built = ctx.build(layoutBase, Object.assign({}, ctx.presetById('heute').options, {logo}), '/plugin/modules');
    assert.equal(built.left[0].id, 'amiga.workspaces');
    assert.equal(built.left[0].variant, 'none');
    assert.equal(built.left[0].logo, logo);
  }
  // the seal: 16 × 16, 169 ink pixels; rank 0 = the letters' edges (80), 1…89 the rest, each once
  const seal = fs.readFileSync(path.join(root, 'modules/SealLogo.qml'), 'utf8');
  const rows = JSON.parse(seal.match(/readonly property var rows: (\[[\s\S]*?\])\n/)[1]);
  const ranks = JSON.parse(seal.match(/readonly property var ranks: (\[[\s\S]*?\])\n/)[1]);
  assert.equal(rows.length, 16);
  assert(rows.every(r => r.length === 16 && /^[.#x]+$/.test(r)));
  assert.equal(ranks.length, 256);
  const cells = rows.join('');
  assert(ranks.every((r, i) => (cells[i] === '#') === (r >= 0)), 'a rank exactly for every ink pixel');
  assert.equal(ranks.filter(r => r === 0).length, 80);
  const rest = ranks.filter(r => r > 0).sort((a, b) => a - b);
  assert.deepEqual(rest, Array.from({length: 89}, (_, i) => i + 1));
  assert(seal.includes('readonly property int restCount: 89'));
  assert(/duration: 320/.test(seal) && /1 - Math\.pow\(1 - p, 1\.6\)/.test(seal), 'one impression in 0.32 s');
  assert(/if \(Style\.reduceMotion\) \{ p = 1; opacity = 0; fadeIn\.start\(\) \}/.test(seal), 'reduced motion: a cross-fade');
  // Arch: the first path of the filesystem package's archlinux-logo.svg, one even-odd fill, a fade only
  const arch = fs.readFileSync(path.join(root, 'modules/ArchLogo.qml'), 'utf8');
  const archPath = arch.match(/PathSvg \{ path: "([^"]+)" \}/)[1];
  const svgFile = '/usr/share/pixmaps/archlinux-logo.svg';
  if (fs.existsSync(svgFile)) assert.equal(archPath, fs.readFileSync(svgFile, 'utf8').match(/ d="([^"]+)"/)[1], 'the mark unaltered');
  assert(arch.includes('fillRule: ShapePath.WindingFill'), 'one contour without holes: winding = the SVG\'s even-odd');
  assert(!/m[0-9.]+ [0-9.]+[^z]*z\s*m/i.test(archPath), 'a single closed contour');
  assert(/duration: Style\.reduceMotion \? 120 : 220/.test(arch));
  assert(!/Behavior on (x|y|scale)/.test(arch), 'motion only as a whole: no movement');
  // Workspaces: only the chosen logo is loaded; the seal's tab bleeds once; the menu title follows
  const ws = fs.readFileSync(path.join(root, 'modules/Workspaces.qml'), 'utf8');
  assert(ws.includes('active: root.variant !== "logo" && root.logo === "arch"'));
  assert(ws.includes('active: root.variant !== "logo" && root.logo === "nerdibeard"'));
  assert(ws.includes('visible: menuSlot.inverted && (root.logo !== "nerdibeard" || root.variant === "logo")'), 'the seal brings its own tab; the numbered frame keeps the plain one');
  assert(/property: "bleed"; from: 0; to: 1; duration: 240; easing\.type: Easing\.OutCubic/.test(ws));
  assert(ws.includes('pressed: menuMouse.pressed && !root.dropOpen'), 'press feedback in both motion modes');
  assert(ws.includes('readonly property bool target: reduced ? on && root.dropOpen : on'));
  assert(ws.includes('tab: sealTab.target'), 'the seal changes colour in step with its tab');
  assert(/Behavior on color \{ enabled: Style\.reduceMotion; ColorAnimation \{ duration: 120 \} \}/.test(seal), 'reduced motion: colour cross-fades');
  const dm = fs.readFileSync(path.join(root, 'DropMenu.qml'), 'utf8');
  const titleBody = dm.match(/readonly property string rootTitle: \{([\s\S]*?)\n  \}/)[1];
  const rootTitle = new Function('owner', titleBody);
  assert.equal(rootTitle({logo: 'arch', variant: 'none'}), 'Arch Linux');
  assert.equal(rootTitle({logo: 'nerdibeard', variant: 'stack'}), 'Nerdibeard');
  assert.equal(rootTitle({logo: 'nerdibeard', variant: 'logo'}), 'Omarchy', 'the numbered frame shows no mark');
  assert.equal(rootTitle({logo: 'amiga', variant: 'pips'}), 'Omarchy');
  assert.equal(rootTitle(null), 'Omarchy');
  assert(dm.includes('(menu.level ? menu.level.title : menu.rootTitle).toUpperCase()'));
  console.log('PASS: logos Arch and Nerdibeard seal (variants, seal raster and order, unaltered Arch path, tab, menu title)');
}
