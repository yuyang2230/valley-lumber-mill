# 《盐线：度假岛·船厂》引擎剖析 —— 面向"山谷·伐木场"改造

> 剖析对象：`C:/Users/Administrator/Desktop/youxi/valley-lumber-mill/index.html`（6573 行，UTF-8，单文件游戏）。
> 方法：全篇为压缩长行，本文所有行号均来自本会话实际 `grep/sed`（配合字节偏移→行号换算脚本）核验，引用均给出 1–2 行原文作证据。
> 阅读提示：`5701` 等超长行内的"列号"无意义，请直接按行号在编辑器里定位整行后搜索关键词。

---

## 0. 文件结构（实测边界）

| 行号 | 内容 | 证据 |
|---|---|---|
| 1–7 | 文档头（`<title>盐线：度假岛·船厂</title>` 在第 3 行） | `3:<title>盐线：度假岛·船厂</title>` |
| 8–341 | 全部 CSS（`<style>` 8 行起，`</style>` 341 行） | `8:<style>`、`341:</style>` |
| 342–351 | HTML 主体：`#app`/`#view`/`#ui`/`#boot`（"盐线"/"度假岛 · 船厂" 在 346–347） | `342:<div id="app">`、`346:    <div class="boot-mark">盐线</div>` |
| 352 | `<script>` 开始 | `352:<script>` |
| 353–4159 | 压缩 three.js 引擎包（r1xx，模块导出表在 353 行这一条 134KB 长行上） | 353 行长度 134401（awk 实测） |
| 4160–4201 | 引擎尾 + 共享常量（`oi` 世界边界 4184、太阳 `Mn` 4185、天空调色板 `en`/玩家 `Pi`/画质 `Pr`/事件 `Dy`/随机 `il`/降级桩 `dr` 4186） | `4185:Mn={dir:new W(.273,.951,.145).normalize(),color:new Ve(1,.96,.88),intensity:7.4}` |
| 4202–4291 | **SALTLINE_SKY** 天空/天气段（shader 源码 4202–4290 为可读多行；装配函数 `W6/Hy/Vy` 与 **SALTLINE_SHADOW** 起点在 4291 行） | `4202:// SALTLINE_SKY`、`4291:...var Wy="// SALTLINE_SHADOW"...function Gy(` |
| 4291–4737 | 软阴影/体积光/AO/后期 shader 源码（"AgX (Filament/Blender fit)" 注释在 4610，grade 注释 4682–4695，final/FXAA shader ~4696–4738） | `4610:// ---- AgX (Filament/Blender fit, as in three.js) ----` |
| 4738–5538 | 后期链装配 `jy`(4738)、渲染模块 `Hg`(4739)、程序化贴图函数表 `Tn`(4828) | `4738:function jy(i,e,{noiseTex:t})`、`4739:...async function Hg(i){` |
| 5539–5683 | 物理导航 `d3`、材质模块 `Gg`、道具模块 `Yg`、道具尺寸表 `Gi`（同一 70KB 长行） | `5539:...function d3(i){...async function Gg(i){...function Yg(i){` |
| 5684–6192 | **关卡模块** `C1`(5684) 与船厂数据（数据对象在 5701–5703）；背景层 `Eb`(5788) | `5684:async function C1(i){` |
| 6193–6306 | 地面模块 `O1`(6193)（程序化地形高度场） | `6193:...async function O1(i){` |
| 6307–6432 | fx `Cf`、音频 `c_`（含 `SpPick/speakRadio`）、玩家 `x_`、战绩 `zv`、输入 `v_`（151KB 长行） | `6307:...async function Cf(i){...async function c_(i){...function x_(i){` |
| 6433–6454 | 武器 `dm`、敌人 `Em`（含调参 `Ui/Zv/Kv`、Gull `Q_`、Hound `iM`）（61KB 长行） | `6433:...async function dm(i){...async function Em(i){` |
| 6455–6477 | HUD `hM`(6455) + 敌人 showcase `VC` | `6455:...function hM(i){let e=document.getElementById("ui")` |
| 6478–6561 | 菜单/设置面板 `pM`(6478)、设置持久化 `fM="saltline.settings.v1"` | `6478:function pM(i,e){let t=document.getElementById("ui")` |
| 6562–6568 | 流程常量 `Yi`、台词表 `_l`、方位 `jC`、游戏流程 `mM`、showcase 注册表 `gM`、错误钩子、boot `QC`(同一条 25KB 长行) | `6562:...Yi={introSeconds:3.5,...};function mM(i){...var gM={mats:qg,...};async function QC(){` |
| 6569–6573 | bench 起点收尾、输入桩 `tP`、玩家桩 `nP`、启动调用 | 6573 末尾：`QC().catch(i=>bM(i&&i.stack||i));})();` |

---

## 1. 系统地图：boot `QC()` 与模块装配

### 1.1 启动入口

`QC()` 定义在 6562 行（超长行内），文件末尾 6573 行调用：

```js
// 6562（节选）
async function QC(){let i=Object.fromEntries(new URLSearchParams(location.search)),e=!!i.bench||location.hash==="#bench";e&&(i.noaudio="1",i.autostart="1");
let t={THREE:lt,params:i,events:Dy(),rng:il(+(i.seed||4207)),time:{t:0,dt:0,frame:0,real:0},quality:zy(i.q||(i.shot?"test":""))};window.__G=t;
// 6573（行尾）
QC().catch(i=>bM(i&&i.stack||i));})();
```

上下文对象 `t`（即 `window.__G`）：`THREE / params / events / rng(seed=4207) / time / quality / showcase`。每个模块装载后写回 `t.<name>`。

### 1.2 模块总表（入口函数 → 行号 → 对外接口）

装配顺序即 6562 行内的 `await r("name","key",()=>fn(t))` 序列：

| 模块 key | 入口函数 | 行号 | 对外接口（实测自返回对象/消费点） |
|---|---|---|---|
| render | `async function Hg(i)` | 4739 | `{renderer,scene,camera,viewCamera,sun,sky,sunDir,lightPool{flash,acquire,update},post{damage,lowHealth,ads,flash,fade,saturation,focusDist,shake,wet},exposure,env,interiorEnv,resolution,tune,autoExposure,depthTexture,addPrePass,renderWorld,onLevelReady,setQuality,resize,frame,stats}` |
| mats | `async function Gg(i)` | 5539 | `{get(name,opts),emissive(color,int),decal,label,number,names,decalNames,uniforms{wet},update,prewarm,stats,tileOf}` |
| physics | `function d3(i)` | 5539 | `{boxes,bounds,addBox(min,max,{surface,tag,noNav,bulletOnly,playerOnly}),removeBox,build,raycast,lineOfSight,groundHeight,moveCapsule,nav{cell,isWalkable,findPath,randomPoint,clearLine,_grid}}` |
| props | `function Yg(i)` | 5539 | `{names(),has,build(name,opts),…}`；尺寸表 `Gi`（36 种：container20/40、pallet、relay_node、forklift…，逐条清点 5539 行） |
| input | `function v_(i)`（showcase 用桩 `tP` 6569） | 6307 | `{move,look,fire,ads,sprint,crouch,locked,touch,sensitivity,down,pressed,update,endFrame,requestLock,exitLock,setGameplay,describeMode,onModeChange,mode}` |
| level | `async function C1(i)` | 5684 | 见 §2（`playerStart/objectives/extraction/enemySpawns/zones/interiorBoxes/cinematicPath/coverPoints/skylights/shedLights/vantage/stats/placed/groundSurfaceAt/update`） |
| backdrop | `async function pv(i)` → `Eb(i,{})` | 5788（pv 在 5814） | `{update,root,shipA,shipB,gateBox,gulls,lamps,colliders,crane,stats}`（5788 行返回） |
| ground | `async function O1(i)` | 6193 | 程序化地形（`Li={x0:-44,z0:-40,size:80}` 网格 + 高度函数），降级桩为 `{stub,update,wetnessAt,isPuddle}`（`dr` 4186 行） |
| fx | `async function Cf(i)` | 6307 | `{update,clear,muzzleFlash,tracer,impact,sparks,smoke,dust,explosion,shell,splash,addEmitter,debris,decal,wind,root,stats}`（6307 行 return） |
| audio | `async function c_(i)`（`noaudio`/showcase 用 `dr.audio()` 桩） | 6307 | `{ctx,resume,play,loop,update,ready,selfTest,speakRadio(text,opts),stopSpeech,setIntensity,setInterior,setVolume,setPaused,debug,names}`（6307 行 `Object.assign(Re,{...})`） |
| player | `function x_(i)` | 6307 | `{pos,vel,yaw,pitch,health,maxHealth,alive,onGround,sprinting,crouching,ads,speed,eye,forward,enabled,reset,damage,heal,addRecoil,addShake,update}`（6569 行 `nP` 桩形状一致） |
| combat | `function zv(i)` | 6307 | `{stats:{shots,hits,kills},reset,playerShot(origin,dir,{damage=28,range=300,impulse})}`；`playerShot` 先 `physics.raycast` 后 `enemies.raycast`，weak 部位 ×2.2 伤害并 emit `player:hitEnemy`（6307 行实测） |
| weapon | `async function dm(i)` | 6433 | viewmodel（`e.name="viewmodel-pac9"`）；`setVisible/setWetness/reset/update/ammo/magSize/reserve/state/name/ads/spread`；发射时 `i.events.emit("weapon:fire",{origin,dir,muzzle,adsE})`（6433 行） |
| enemies | `async function Em(i)` | 6433 | `{list,TUNE:Ui,spawn(type,pos,opts),raycast,aliveCount,clear,alert(pos,radius),update}` |
| hud | `function hM(i)` | 6455 | `{root,show,setObjective,setRelays,setMarkers,setPrompt,setRelayProgress,message,warn,feed,hitmarker,radio(text,secs),clearRadio,reset,update}` |
| game（menus） | `function pM(i,{deploy,resume,restart,retry,redeploy})` | 6478 | `{applySettings,show(screen),locationCard,setLookMode,setDead,setDebrief,closePanel,panelOpen,screen}` |
| game | `function mM(i)` | 6562 | `{state,flow:Yi,run,menus,start,pause,resume,update,debugCut}` |

### 1.3 装配顺序（QC 内 `await Nr(文案,进度)` 为 boot 进度条）

1. `render`(必装，失败即抛) → 2. `mats` → 3. `physics=d3(t)`、`props`、`input` → 4a. **showcase 分支**（`?show=…`）：造 stub level + 桩模块，跑 `gM[show].showcase(t)`；4b. **正常分支**：`level` → `backdrop` → `ground` → `physics.build()` → `fx` → `audio` → `player` → `combat` → `weapon` → `enemies` → `hud` → `game=mM(t)` → 5. `render.onLevelReady()`（含室内探针/预编译）→ 6. 应用 `?cam/?fov/?exposure` → `?shot/?autostart` 则 `game.start({skipIntro:!0})` → 7. `?bench` 时 `eP(t)` → 8. `setAnimationLoop` 主循环。

boot 文案（6562 行 `Nr` 调用）：唤醒渲染引擎→调和油漆、铁锈与雨水→吊装集装箱→竖起龙门吊→雨水漫上码头→装填曳光弹与烟雾→检查步枪→唤醒安保主脑→等待破晓→就绪。**改造山谷版时这批文案与 346–347 行"盐线/度假岛 · 船厂"及标题卡（6562 行内 loc-card "度假岛 · 船厂区 · 05:42"）需一并改写。**

### 1.4 主循环顺序（6562 行 `setAnimationLoop` 内，实测）

```js
u("input",p); → d=t.game.update(p) → d&&(u("player",p),u("weapon",p),u("enemies",p))
→ 武器湿润度(用 level.interiorBoxes[0] 判定室内) → 非暂停时 u("fx"),u("ground"),u("level"),u("backdrop"),u("mats")
→ u("audio") → u("hud") → shot 机位覆写相机 → bench → t.render.frame(p) → input.endFrame
→ window.__frames++; 第 2 帧置 window.__ready=!0
```

> **改造注意**：若加"队友 AI"，把队友 update 挂进 `enemies.update` 内部即可，主循环不用动；机位覆写在 `render.frame` 之前，保证 QA 相机稳定。

---

## 2. 关卡数据结构（C1，5684–5703）

### 2.1 坐标常量（引用前先核对）

```js
// 5557 行
var uR=Math.PI,ts=uR/2,R1=.535,mt=(i,e,t)=>new W(i,e,t);   // mt=Vec3 简写, ts=π/2
// 5557 行（船厂主车间/总装车间 footprint）
var no={X0:-16,X1:12,Z0:-28,Z1:-11,EAVE:7,RIDGE:9.5,ZR:-19.5,FLOOR:.03}
// 4184 行（世界边界 + 海岸线）
var oi={min:new W(-40,0,-30),max:new W(40,30,30),groundY:0,seaY:-1.6,quayX:30}
```

> **山谷版映射**：`oi.quayX=30` 是"码头/水面"分界，`groundSurfaceAt` 与 `physics.raycast` 都用它决定"掉进水里"——山谷版应改名为 `riverX` 之类并把水面语义换成河谷；`oi.seaY=-1.6` 改为河床高程。

### 2.2 返回的数据对象（5701–5703 行原文摘录）

```js
// 5701 行（玩家起点 + 三个中继目标）
let d={pos:mt(-32,0,6),yaw:-ts},
v=[{id:"relay_a",label:"中继站 A — 干船坞",zone:"quay",pos:mt(23.2,-1.37,-19),object:o},
   {id:"relay_b",label:"中继站 B — 总装车间",zone:"shed",pos:mt(n.relayPos.x,no.FLOOR,n.relayPos.z),object:r},
   {id:"relay_c",label:"中继站 C — 龙门吊",zone:"quay",pos:mt(25.5,13.21,0),object:a}],
// 5701 行（enemySpawns：g()=地面出生点, x()=空中出生点）
g=(z,H,O)=>({pos:mt(z,0,H),zone:O,type:"ground"}),x=(z,H,O,q)=>({pos:mt(z,H,O),zone:q,type:"air"}),
y=[g(-36,-20,"gate"),g(-30,10,"gate"),…(地面 27 个：gate4/yard8/shed7/quay8)…,x(-32,11,6,"gate"),…(空中 19 个：gate2/yard5/shed5/quay7)…],
// 5701 行（zones：[minX,minZ]~[maxX,maxZ] 矩形）
b=[{name:"gate",min:[-40,-30],max:[-24,30]},{name:"yard",min:[-24,-10],max:[16,30]},
   {name:"shed",min:[-24,-30],max:[16,-10]},{name:"quay",min:[16,-30],max:[40,30]}],
// 5701 行（interiorBoxes：室内判定盒，[0] 是总装车间）
m=[{min:mt(no.X0,0,no.Z0),max:mt(no.X1,no.RIDGE,no.Z1)},          // 主车间 -16..12, 0..9.5, -28..-11
   {min:mt(-24,0,-27),max:mt(-16,7.5,-13)},{min:mt(-24,0,14),max:mt(-16,7.5,28)},
   {min:mt(18,-1.6,-26),max:mt(30,1.2,-12)}],
// 5701 行（cinematicPath：标题运镜 12 个点，Catmull-Rom）
A=[{pos:[-34,1.8,6.2],look:[0,2,6]},…{pos:[-20,3.2,18],look:[-34,2,10]}],
// 5701 行（coverPoints：56 个掩体点，随后统一吸附到导航网格）
_=[mt(20.5,-1.4,-24),…];
// 5703 行（最终 return）
return{root:e,playerStart:d,objectives:v,extraction:{pos:mt(29,0,-24),radius:2.5},enemySpawns:y,
zones:b,interiorBoxes:m,cinematicPath:A,coverPoints:_,skylights:n.skylights,shedLights:n.lights,
vantage:{stairsFoot:mt(30.6,0,3.5),roof:mt(25.5,13.21,0)},
stats:{labelsAtlased:h.count,containers:…,props:t.placed.length,tris:…,meshes:…},placed:t.placed,
groundSurfaceAt(z,H){return z>oi.quayX?"water":t.isMetal(z,H)?"metal":isWoodArea(z,H)?"wood":isSandArea(z,H)?"sand":"concrete"},
update(z){n.update(z),h.update(z),PalmU.uTime.value+=…;t.updaters[H](z)}}
```

字段语义与当前坐标值汇总：

| 字段 | 值 | 说明 |
|---|---|---|
| `playerStart` | `pos=(-32,0,6)`, `yaw=-π/2`（朝 +X） | 出生在西端 gate 区 |
| `objectives` | A 干船坞 `(23.2,-1.37,-19)` / B 总装车间 `(n.relayPos.x,0.03,n.relayPos.z)` / C 龙门吊 `(25.5,13.21,0)` | 每项 `{id,label,zone,pos,object}`；`object` 是 `place("relay_node",…)` 产物，`userData.setState("live"/"cutting"/"cut")` 供流程调用（mM 的 `O()` 函数） |
| `extraction` | `pos=(29,0,-24), radius=2.5` | 撤离点（快艇梯口） |
| `enemySpawns` | 地面 27 个 `type:"ground"`（gate4/yard8/shed7/quay8）+ 空中 19 个 `type:"air"`（gate2/yard5/shed5/quay7），共 46 个，均带 `zone`（逐条清点 5701 行） | `g(x,z,zone)` 与 `x(x,y,z,zone)` 两个工厂生成 |
| `zones` | gate/yard/shed/quay 四矩形 | mM 选出生点用 zone 过滤（`N(P)` 按 air/ground 类型过滤，zone 只是标签） |
| `interiorBoxes` | 4 个 AABB（见上） | 用途：室内环境探针（render.K）、室内音效、武器湿润度、体积光尘埃（post vol 的 `uBoxMin/uBoxMax`） |
| `coverPoints` | 56 点（码头金属面 10 + 车间 14 + 露天场 24 + 西侧 4 + 龙门吊顶 2 + 天窗走道 2，逐条清点 5701 行） | Hound 选开火位的候选集（§2.4），构造后用 `nav.isWalkable` 吸附 |
| `groundSurfaceAt(x,z)` | `"water"/"metal"/"wood"/"sand"/"concrete"` | 驱动脚步声/水花/湿润度/尘土颜色，**山谷版要新增 `"dirt"`、`"grass"`、`"gravel"` 等并同步音频表 Go 的 step_* 生成器** |

### 2.3 物理碰撞注册方式

- 唯一注册通道是 `physics.addBox(min,max,{surface,tag,noNav,bulletOnly,playerOnly})`（5539 行 d3）。关卡的建造器 `ob()`（5557 行）提供语法糖 `col(T,D,C,G,j,N,Q="concrete",K)` 直接转调 `addBox`：

```js
// 5557 行
function A(T,D,C,G,j,N,Q="concrete",K={}){return i.physics.addBox([T,D,C],[G,j,N],{surface:Q,...K})}
```

- 道具的碰撞体挂在 `userData.colliders`（局部坐标 [min,max] 对），放置时由 `ob().place()` 变换到世界坐标再经 `M()`（可能沿长轴切分成多段盒）调 `col()` 注册；带 `noNav` 的（如 backdrop 船体）只挡子弹/玩家不进导航图（5788 行 `d({min:[31.8,-2.9,1],max:[41.2,4.3,45.2]},"metal")` 带 `{tag:"backdrop",noNav:!0}`）。
- `physics.build()`（boot 中 level/ground 之后调用，6562 行 `t.physics.build()`）重建导航栅格：5539 行 `a()` 遍历所有 box，`noNav||bulletOnly||max.y<u1+.05||min.y>1.5` 的跳过（`u1=.42` 为台阶高，定义在 5380 行后段 `var u1=.42`），其余栅格化；栅格参数（5539 行）：`Ls=.5`(格距)、`Ya=-40,EA=31,ol=-32,SA=30` → `qt=142,Qs=124` 格，四周边缘与 `x>quayX-yf` 一律封死（水面不可走）。台阶高常量 `u1=.42` 与栅格常量同在 5539 行（`var u1=.42,Ls=.5,Ya=-40,…`）。
- 射线 `raycast(origin,dir,max)`：先测地面（groundY/seaY 双平面，`x≤quayX` 用 groundY，否则 seaY），再 slab 法遍历 box（跳过 playerOnly）；返回 `{dist,point,normal,surface,box}`。`lineOfSight` 即 `raycast` 的布尔封装（5539 行）。`moveCapsule(pos,vel,dt,r=.32,h=1.8,step=true)`：水平推挤迭代 + 台阶(`u1=.42`) + 顶头/落地判定，返回 `{onGround,hitWall,hitCeil,surface}`。

### 2.4 导航数据如何被敌人消费（A*/coverPoints/射线）

- **A\***：5539 行 `nav.findPath(from,to)` — 二叉堆 + 曼哈顿×对角启发（`(1.4142-2)*min(q,U)`），`9e3` 步上限，返回路径后用 `h()`（Bresenham 网格直线）做串点拉直（string-pulling）。
- **coverPoints**：Hound `iM` 的选位函数 `w()`（6433 行）评分所有 `s.level.coverPoints` 与 7 个 `nav.randomPoint`、5 个环玩家随机点：距离在 `[rangeMin,rangeMax]` 内、`isWalkable`、无 LOS 才加分，且对"已在该方向开火的友邻"加罚。最终 `m.firePos`。
- **射线**：感知 `h.think()`（6433 行）用 `i.physics.lineOfSight(T.sensor,N)` + 视锥余弦 `BC=Math.cos(200°/2)` + 近距 3.5m 豁免；开火前还有专用遮挡测试。
- **randomPoint/groundHeight**：Gull 出生高度、Hound 贴地都用 `physics.groundHeight(x,z,y+1)`。

---

## 3. 敌人系统与"友好阵营 AI 队友"扩展（重点）

### 3.1 现有结构（6433 行）

- 调参表 `Ui`（6433 行）：

```js
var Ui={gull:Zv,hound:Kv,sightRange:45,sightCone:200,loseSight:4,searchTime:8,hearRadius:45,
maxTokens:2,maxTokensCrowd:3,tokenGap:1.25,exposureUp:.1,exposureDown:.45,
poolGulls:10,poolHounds:8,maxWrecks:5,maxBolts:32}
```

- 单位参数：Gull `Zv={hp:45,boltDamage:7,boltSpeed:70,burst:3,…,altMin:4,altMax:8,maxSpeed:8,explodeRadius:3,explodeDamage:30}`；Hound `Kv={hp:140,shotDamage:5,burst:4,…,runSpeed:4.5,lungeDamage:15,replan:.6}`（均 6433 行）。
- 单位是**对象池**：`d`=10 架 Gull、`v`=8 条 Hound，均预建于 `Em()` 内，`spawn(type,pos,opts)` 从池里取 `_activate`。状态机：`patrol → investigate → engage → search`（`h.think()` 驱动），"行动令牌"限流（同屏最多 2/3 个单位主动开火，`requestToken/releaseToken`）。
- `_activate(pos, D)` 的 opts（6433 行，Gull/Hound 同形）：

```js
m.mode=D.state==="alert"?"investigate":"patrol"; m.lastKnown.copy(D.target||(s.player?s.player.pos:T));
m.passive=!!D.passive; m.patrolR=D.patrolRadius??7; m.patrolLine=D.patrolLine||null;   // Hound
d.alt=b.hover??Pn.altMin+.8+…; d.hoverFixed=b.hover!=null; d.patrolR=b.patrolRadius??4+o()*5;  // Gull
```

- 命中/伤害路由（改造的关键事实）：
  - 玩家子弹 → `enemies.raycast(origin,dir)` 遍历 `t` 列表（`_raycast` 命中 head=weak/body）→ combat 发 `player:hitEnemy`；
  - 敌方弹道 `fireBolt/射击` 的命中测试是**硬编码对玩家胶囊**：6433 行 `D&&D.alive!==!1&&(…HC(j.pos,oM,cM,uM)<.36*.36&&(ie=!0)),ie){D.damage(Ui.gull.boltDamage,j.from)`；
  - 敌人被击中走 `damage(T,D,C,G)` → `i.provoke(m)`（惊动自己+`rally` 半径内同伙）；
  - 击杀发 `enemy:killed`（HUD 击杀播报用它，6455 行 `ce2=ce==="GULL"?"无人机":ce==="HOUND"?"机器犬":"机器"`）。

### 3.2 扩展"友好阵营 AI 队友"的最小改造方案

**方案 A（推荐）：`friendly` 标志，不新建类。** 池子、rig、动画、寻路全部复用，改动集中在 6 个点：

1. **加标志与登记**：`spawn(type,pos,opts)` 的 opts 增加 `friendly:!0`，透传到 `_activate`：`m.friendly=!!D.friendly`（Q_/iM 两处 `_activate` 各加一行）；默认 `false`，所有存量调用零影响。
2. **目标选择**：`h.think()` 现在写死 `let G=i.player`（6433 行）。改为：
   ```js
   let G = T.friendly
     ? nearestAliveEnemyOf(T)            // 在 t 里找最近 !friendly && alive，沿用同一 LOS/视锥/曝光逻辑
     : i.player;
   ```
   `rally()`/`alert()` 内的"惊动同伙"循环要按阵营过滤：`if(!!j.friendly!==!!T.friendly)continue;`。
3. **伤害/命中路由**：
   - 玩家子弹：`combat`（6307 行 `zv`）在 `enemies.raycast` 返回后检查 `hit.enemy.friendly` → 不扣血、只发 `player:hitFriendly`（防误伤提示）；
   - 敌方弹道：`_(T)` 的胶囊测试（§3.1 硬编码玩家处）改为对"所有非 friendly 单位 + 玩家"各测一次（friendly 队友的命中测试复用 `_raycast`）；
   - friendly 开火：`fireBolt(from,dir,…)` 已参数化 `from`，只需在弹道命中侧排除 `from.friendly` 的同阵营。
4. **结算/波次口径**：`mM` 的 `ne()`（aliveCount）与 `re(P)`（近距离敌人判定）要排除 friendly：`i.enemies.aliveCount()` 在 6433 行统计全部 `alive`，建议给它加参数 `aliveCount({hostileOnly:!0})` 或在 mM 侧 `list.filter(P=>!P.friendly&&P.alive)`（mM 的 `re()` 已有同型过滤可抄）。
5. **表现层**：HUD 击杀播报（6455 行）加 `friendly` 分支文案（如"队友击毁"）；`.comms-who` 显示队友呼号（§5.3）；友军指示标可用 `hud.setMarkers` 加 `kind:"friend"`（6455 行 setMarkers 已按 kind 区分 relay/extract）。
6. **语音**：队友事件走 `o.radio(text,secs)` 但换角色（§5.4）。

**方案 B（派生）**：`Q_/iM` 已经是 `pm(rig)+状态字段` 的工厂，可再写 `function qF(h,f,u,n){let F=Q_(h,f,u,n);F.friendly=!0;…}` 派生并覆盖 `_activate/_update` 中目标选择。代价是复制逻辑、双份维护，仅在需要行为差异大（跟随玩家、不需要 token 限流）时才值得。

**建议还需要的配套**：跟随行为可复用 `patrolLine:[A,B]`（两点巡逻即"待在玩家两侧"）；`passive:!0` 时 `h.think` 直接置 `T.los=!1`（6433 行 `if(T.passive||!G){T.los=!1;return}`），给 friendly 记得**不要**用 passive 抑制感知，而是放宽成"只对敌意单位感知"。

---

## 4. 天空 / 天气：SALTLINE_SKY 段（4202–4291）与改"山谷白天 + 远处雪山"

### 4.1 参数在哪

| 参数 | 位置 | 当前值 |
|---|---|---|
| 太阳方向/颜色/强度 | 4185 行 `Mn={dir:new W(.273,.951,.145).normalize(),color:new Ve(1,.96,.88),intensity:7.4}` | 高度角约 53°，暖白 1/.96/.88 |
| 天空调色板 | 4186 行 `en={zenith:new Ve(.10,.32,.68),horizon:new Ve(.78,.88,.95),horizonAway:new Ve(.55,.72,.88),fog:new Ve(.70,.80,.87)}` | 热带正午 |
| 天空 mesh/材质 | 4291 行 `function Hy(i)`：`new zn({name:"saltline-sky",side:Ki,depthWrite:!1,fog:!1,toneMapped:!1,uniforms:W6(i),vertexShader:V6,fragmentShader:H6})`，Box(2,2,2)、`renderOrder=-1e3` | uniforms 由 `W6()` 从 `Mn/en` 克隆（uSunDir/uZen/uHor/uHorAway/uSunCol/uTime/uEnv/uFlash/uFlashDir） |
| 环境贴图 | 4291 行 `function Vy(i,e)`：`uEnv=1` 克隆材质 → `ia.fromScene` PMREM；`Hg` 中 `r.environment=y.texture,r.environmentIntensity=Jy`(2.3, 4739 行 `var Jy=2.3,Ky=1`) | 改天空后 PMREM 自动跟随 |
| 云层（shader 内常量） | 4216–4290 行 | 卷云甲板：`cuv=d.xz/(h+0.10)*vec2(0.62,0.95)`（东西向滚云）、`wind=vec2(-0.012,0.004)*uTime`、覆盖率 `cov=smoothstep(0.42,0.62,body)`、东方"烧穿缺口" `edge=mix(0.030,0.285,pow(ts,1.7))` |
| 雷暴 | 4739 行 `events.on("thunder")` → `uFlashDir`/`uFlash`；4264 行 sheet lightning `fl=uFlash*pow(max(dot(d,uFlashDir),0.),5.)` | 山谷版可整体删掉 |
| 地平线以下 | 4279 行 `if(d.y<0.)`：海雾/地面反照 `low=mix(uHorAway*0.42,vec3(0.060,0.064,0.070),uEnv)` | 山谷版改为"远谷底"色 |

### 4.2 改成"山谷白天 + 远处雪山"的具体动作

1. **调色板（4186 行 `en`）**：白天山地建议 `zenith≈(.30,.50,.85)`、`horizon≈(.80,.88,.96)`、`horizonAway≈(.72,.80,.90)`、`fog≈(.74,.82,.90)`（雾更白、更冷）。
2. **太阳（4185 行 `Mn`）**：上午山谷光可取 `dir=(.42,.72,.55)`、`color=(1,.98,.92)`、`intensity 6.5~7.5`。注意 `Gy()`（4291 行）按 `Mn.dir` 定阴影相机位姿，改方向后只需确认 `Hg` 里 `Gy(h,new W(-44,-2,-34),new W(43,28,46),…)` 的包围盒仍罩住新关卡（换山谷布局时同步改这四个角点）。
3. **云（4216–4290）**：
   - 保留 fbm 云但把 `cov=smoothstep(0.42,0.62,body)` 阈值上移（如 `.55,.75`）→ 云量变少变高；
   - 删除/削弱"东方烧穿缺口"两行（`edge`、`hole`），`warm` 暖光项系数 ×0.3 —— 那是"黄昏火云"的来源；
   - `midC`（4217 行 `vec3(0.55,0.72,0.88)→(0.70,0.82,0.92)`）换成的正午蓝可调更饱和。
4. **远处雪山（推荐新增，不动 shader 主体）**：雪山属于"背景层"职责，最合适的落点是 backdrop 模块（5788 行 `Eb`，现在分支是 `_R=["crane","ships","gulls","hills"]`，5726 行）。做法：把 `resortHills` 换成 `valleyMountains`——两三层用 `mats.get("concrete")` 变体或专用 MeshStandard（vertexColors + 顶点高度混合雪线），**雪线以上把 albedo 拉白 (0.9,0.93,0.97)、roughness 0.55**；距离 300~600m，`fog` 自带空气透视。若想要"雪顶反光"更强，可给雪山单独 `envMapIntensity=1.2`。注意：天空 shader 本身不画山（4279 行以下是"sea haze"），山必须走几何体。
5. **雾**：场景雾色直接用 `en.fog`（`v()` 4739 行把 `en.fog` 注入 vol 的 `uAmb`），改 `en.fog` 一处即可联动。
6. **标志性文案**：4202 行注释头 `// SALTLINE_SKY` 与 4291 行 `Wy="// SALTLINE_SHADOW"`、材质 patch 前缀 `SALTLINE_POST`（4739 行 `re.match(/SALTLINE_POST (\S+)/)`）、阴影 chunk 标记（`Yy`，即材质里的 soft-shadow 注释串）可以留着（是编译错误定位用的哨兵串），但注释建议改成 `// VALLEY_SKY` 系，便于后续 grep。

---

## 5. 光照 / 阴影 / 后期 / 材质

### 5.1 光照与阴影（`Hg`，4739 行）

```js
let h=new W0(Mn.color,Mn.intensity);h.name="sun",h.castShadow=!0;
let f=Gy(h,new W(-44,-2,-34),new W(43,28,46),new W(-44,-3,-34),new W(43,28,46)),   // 阴影相机按包围盒拟合
p=()=>Math.min(i.quality.shadow||2048,n.capabilities.maxTextureSize);
h.shadow.mapSize.set(p(),p()),h.shadow.bias=-8e-5,h.shadow.normalBias=.05,h.shadow.radius=1.5,h.shadow.autoUpdate=!0
```

- 渲染器：`new gf({canvas,antialias:!1,powerPreference:"high-performance"})`；`outputColorSpace=Vn`(SRGBColorSpace)、`toneMapping=ys`(实测 `ys=0` → **NoToneMapping**，色调映射在后链做)、`shadowMap.type=Eh`(实测 `Eh=2` → **PCFSoftShadowMap**)、`shadowMap.autoUpdate=!1`（手动逐帧置 needsUpdate，非 ultra 每 2 帧更新一次）。
- **阴影分辨率**：`quality.shadow`——`Pr` 表（4186 行）：`test/low:2048，medium/high/ultra:4096`；类型 PCFSoft + **自定义软阴影 chunk `qy()`**（4291 行）：`taps: low?10 : high/ultra?20 : 16, searchTaps:8`（PCSS 式可变半径，源码注释 `// SALTLINE_SHADOW`）；驱动不支持时自动回退 stock PCF 并把 `radius` 提到 2（4739 行 `Xy(),d=!1,…h.shadow.radius=2`）。
- 点光池：6 个 `PointLight`（`flash()/acquire()`）， muzzle flash / 爆炸 / Gull 探照灯共用。
- 环境光：`environment` = 天空 PMREM（`Vy`），`environmentIntensity=Jy=2.3`；室内切 `interiorEnv`（`K()`：CubeCamera 128px 拍 `interiorBoxes[0]` 中心，PMREM 后赋给所有 `userData.interior===!0` 的材质，`envMapIntensity=Ky=1`）。
- 双相机：主相机 `fov=Pi.fov=74` near .08 far 900（layer 0）；viewmodel 相机 `Pi.viewFov=54` near .01 far 10（layer 1，`zc=1`）。

### 5.2 后期链（`jy` 4738，TUNE `g` 4739）

HDR 目标：`js`(HalfFloat) RGBA + MSAA（quality.msaa）+ depthTexture；pass 顺序（`P()` run 函数，4739 行内）：

```
depthhalf → AO(12~16 taps + 双向边缘感知模糊) → 体积光 VOL_STEPS 16~40(太阳 shadowmap 采样 + interiorBoxes 尘埃 uBoxDust)
→ composite(场景+AO+VOL) → motionBlur(可选) → bloom(6 down + 5 up) → streak(2) → adapt(1×1 自适应曝光 ping-pong)
→ grade(主调色) → final(FXAA+锐化+胶片颗粒+抖动) → 屏幕
```

TUNE 全量（4739 行 `g={...}`）：

```js
g={volSunScale:.75,volAmbient:.26,volSigma:.0034,volMaxDist:170,volFarHaze:.42,volInteriorDust:26,
aoRadius:.81,aoIntensity:1.6,aoStrength:.95,bloom:.065,bloomMix:.5,dirt:.06,streak:.02,streakThreshold:1.15,
flare:.16,key:.14,minExposure:.85,maxExposure:1.3,adaptTau:1.5,agxMix:.55,ca:.0013,vignette:.3,
grain:.014,sharpen:.3,lookPower:1.18,lookSat:1.22}
```

- **AgX/曝光**：grade shader 注释在 4610 行（`// ---- AgX (Filament/Blender fit, as in three.js) ----`），"punchy"变体 4621 行；实际是 **ACES(Hill fit) 拉 AgX 混合 `uAgxMix=.55`**（4682 行注释 `// filmic curve: ACES (Hill fit) … pulled toward AgX`）；曝光 = 手动 `N.exposure` × 自适应（`key=.14, min/max .85/1.3, tau 1.5`）。前向回退路径用 `xc=4`(ACESFilmic) × `exposure*.6`。
- grade 还带：split-tone（4687 行 teal 阴影/暖高光，正午减半）、S 曲线、青黑抬升、`uDamage/uLowHealth/uAds/uFade/uSaturation` 游戏驱动项；final 有 FXAA+unsharp(`sharpen=.3`)+grain(`.014`)。
- URL 微调（4739 行 Hg 开头）：`?post=0`（回退前向）、`?ao=0`、`?vol=0`、`?bloom=0`、`?mb=1`、`?dynres=0`。动态分辨率 `S`（>21.5ms 降 scale 至 .6，两次触底自动降档 quality，`quality:auto` 事件）。
- **山谷版建议**：白天场景把 `flare:.16→.05`、`bloom:.065→.045`（正午没有黄昏强眩光）；`agxMix` 可升到 .7（更"胶片感"）；`lookSat:1.22→1.05`（雪山场景色彩本身淡）。

### 5.3 材质模块（`Gg` 5539；材质表 `l1`/纹理集 `c3` 5380；程序化函数 `Tn` 4828）

- 机制：所有 albedo/ORM/Normal 由 **GPU shader 现场烘焙**（MRT 3 目标，Mipmap 链后拷出），`mats.get(name,opts)` 缓存 `MeshStandardMaterial`，注入 onBeforeCompile patch `h3`（湿度 `uSlWet`、macro 变化、triplanar `SL_TRIPLANAR`、alphaCut `SL_ACUT`）。`?tex=` 控制烘焙尺寸（≤1024，hero 集合 2048）。
- **`mats.get` 支持的 51 个材质名**（`l1` 表 5380 行，逐字摘录）：
  `asphalt, concrete, concrete_dirty, concrete_painted, brick, floor_epoxy, paint_red, paint_blue, paint_green, paint_yellow, paint_orange, paint_white, paint_grey, paint_teal, steel_galv, steel_dark, steel_worn, steel_bare, steel_rust, diamond_plate, corrugated_roof, chainlink, safety_net, aluminium, brass, hazard_stripes, gunmetal, anodized_black, polymer_black, polymer_tan, rubber, carbon, glove_fabric, armor_white, armor_orange, palm_leaf, palm_bark, wood_pallet, wood_dark, plastic_blue, plastic_red, plastic_grey, tarp, cardboard, rope, tire, glass, glass_dirty, hull_paint, hull_red, water_dark`（未知名回退 `fA` metal 并告警 `[mats] unknown material`）。
- **程序化贴图函数**（`Tn` 4828 行 + `c3` 纹理集 5380 行，28 个 fn / 32 个 set）：`asphalt, concrete, brick, palm_leaf, wood, epoxy, paint, hull, galv, metal, brushed, rust, diamond, corrugated, chainlink, hazard, gunmetal, polymer, carbon, fabric, armor, plastic, tarp, cardboard, rope, tire, glass, water`。每个 fn 是 `void surf(vec2 uv)`（内含 `fbm/vor/noise` 库），`c3` 定义 `{fn,size,tile,bump,seed,p:[…]}`（`safety_net` 复用 `chainlink` fn、`glass_dirty` 复用 `glass` fn、`anodized` 复用 `gunmetal` fn）。
- **山谷版新增材质的建议路径**：加针叶林木皮/刨花板/碎石土路，只需 (a) `Tn` 加 2~3 个 `surf()`（抄 `wood`/`asphalt` 改参数），(b) `c3` 加 set，(c) `l1` 加名字（`Nt("wood2",…)`），零改动引擎管线。`mats.get("concrete")` 的室内变体 `mats.get(name,{interior:!0})` 已内建（5539 行 `w()` 的 `q.interior` 分支）。
- 材质 showcase：`?show=mats`（wA，5539 行；`?only=a,b` 过滤，`?wet=0.8` 预览湿度）。

---

## 6. 音频系统（`c_` 6307；radio/字幕 6455；台词 `_l` 6562）

### 6.1 结构

- 全程序化合成（WebAudio），音效表 `Go`（6307 行，读至 `music_brass` 已 54 条，另有 `radio_click/radio_bed` 等）：`rifle_shot, step_concrete/metal/water, impact_*, gull_fire, hound_fire, hound_step, gull_die, hound_die, telegraph, alert, explosion, relay_cut, thunder, foghorn, gull_cry, container_bang, ui_click, objective, complete, death, gull_rotor(loop), hound_servo(loop), relay_hum(loop), rain(loop), wind(loop), sea(loop), music_drone/ost/perc/brass…`。每条 `{gen,n,sr,peak,bus:"near|world|dry|music",max,pri,ref,roll,loop}`——优先级+上限的 voice 管理。
- 环境逻辑：按玩家所站 surface（`level.groundSurfaceAt`）混 rain/sea/surf/wind（6307 行 `bAmb`，`bSurfS==="water"` 时 surf 增益最高——山谷版换成"靠近河谷渐强"）；室内（interiorBoxes）切 `rain_interior`。
- BGM：`music_drone/ost/perc/brass` 按 `setIntensity(0..1)` 分层（mM 的 `c.intensity` 驱动）。

### 6.2 radio → 字幕 → 语音链路

```js
// 6455 行（HUD）
radio(k,ce=4.5){k&&(me.push({text:k,secs:ce}),i.audio&&i.audio.speakRadio&&i.audio.speakRadio(k))},
clearRadio(){me.length=0,…i.audio.stopSpeech&&i.audio.stopSpeech()},
// 6455 行（字幕条 DOM，呼号是写死的）
let j=li("div","comms",'<span class="comms-who">指挥部</span><span class="comms-t"></span>');
// 6455 行（打字机式字幕：58 字/秒，secs 后消失；广播开始时发事件）
function ae(k){if(!ee){…ee=me.shift(),…N.textContent="",j.classList.add("on"),i.events.emit("radio:line",{text:ee.text})}
  …P+=k*58;… V-=k,V<=0&&(ee=null,me.length||j.classList.remove("on"))}
```

### 6.3 `speakRadio` 的 speechSynthesis 实现（6307 行）

```js
function SpPick(){…let pe=te.getVoices()||[];…ke.indexOf("zh")===0&&(ye=ye||Le,ke.indexOf("cn")>=0&&!ge&&(ge=Le));
  …let Le=/xiaoxiao|yaoyao|huihui|kangkang|yunyang|yunxi|xiaoyi|xiaohan|xiaomo|yunhong|yunfeng|liang/i;
  for(let ke of pe)Le.test(ke.name||"")&&(sVoice=ke);…}
function speakRadio(te,he){…let ye=new window.SpeechSynthesisUtterance(te);
  ye.lang=(ge.lang||"zh-CN").replace("_","-"); try{ye.voice=ge}catch{}
  ye.rate=(he&&he.rate)||1.08, ye.pitch=(he&&he.pitch)||.92, ye.volume=pi(me*1.18,0,1);
  …ze("radio_click",{gain:.5,jitter:0}), sBed.setGain(.85), sBed.setPitch(.94+s()*.1)…}
```

要点：单语音槽（`sUt`，播新前 `cancel()`）；"电台底噪" `radio_bed` + 前后 `radio_click` 哔声；无可用中文 voice 时只播哔声。**`he={rate,pitch}` 参数已实现但 HUD 的 `radio()` 没有传**（6455 行只传了 text）。

### 6.4 按角色设不同 pitch/rate/voice 的最小改法

1. 在 6455 行 HUD 顶部建角色表（voice 可留 null 由 SpPick 兜底，pitch/rate 即可区分）：
   ```js
   var VOICES={hq:{who:"伐木场调度",pitch:.92,rate:1.08},mech:{who:"机师老葛",pitch:.78,rate:.95},
               scout:{who:"观察哨小鹿",pitch:1.18,rate:1.14},med:{who:"医护阿岩",pitch:1.05,rate:1.0}};
   ```
2. `radio(k,ce,who)` 加第三参：`me.push({text:k,secs:ce,who})`；`i.audio.speakRadio(k,who?VOICES[who]:null)`；渲染时 `whoEl.textContent = who?VOICES[who].who:"指挥部"`（当前 `comms-who` 是写死的"指挥部"，见 6455 行）。
3. 若要真正换 voice：给 `SpPick()` 加 `prefer` 名单参数（如 `pitch>1` 的角色优先 `xiaoyi/xiaoxiao`，低音优先 `kangkang/yunyang`），`speakRadio` 里 `SpPick(he)`；同一引擎里浏览器音色有限，**pitch+rate 已足够区分 3~4 个角色**。
4. `_l` 里每条台词带上 `who` 字段（改造时把字符串表升级为 `{text,who}`），mM 调用处不改。

### 6.5 `_l` 台词表全文（6562 行；实为 **20 条**，任务书估"24 条"不准确——已逐字核验）

```js
_l={intro:"渗透开始。三条上行链路，逐一切断。",
contact:"它发现你了。无人机上天，机器犬上街。把它们放倒。",
cut:["第一台熄火。它察觉了，机器正在过来。","第二台瘫痪。还剩最后一台，顶住。"],      // 2 条
all:"三台全灭。全网瘫痪，快艇在等你。跑！",
low:"你伤得很重，躲到钢板后面喘口气。",
done:"你已登艇，全网静默。干得漂亮。",
nearRelay:"中继站就在前面，找接口，按住别松。",
guardRelay:"它盯着这台中继，切之前先清场。",
alertGull:"无人机咬住你了，找掩体，别停。",
alertHound:"机器犬贴上来了，边退边打。",
killGull:"空中的哑了，干得不错。",
killHound:"机器犬趴窝了，继续推进。",
extractOpen:"安保网络下线。撤离窗口，现在开启。",
boatHint:"快艇停在码头南端，梯子那儿。快走。",
dead:"信号丢失……渗透员，请回话。",
idle:["你已进场，安保主脑还没发现你。","海边风大，正好盖住你的脚步。"],              // 2 条
waveGap:"度假岛的巡逻比平时密，小心。",
extractIdle:"潮涨了，快艇贴着梯口晃，别磨蹭。"}
```

另有两条**不在 `_l`** 的播报：`o.message("已把你拖回岸上")`（`player:rescued`，6562 行）与 `o.warn("发现敌人 — 方位…")`（`F()` 内，方位词表 `jC=["北面","东北","东面","东南","南面","西南","西面","西北"]`）。山谷版台词集中在 `_l` 重写即可（呼应"伐木场调度/河谷电台"）。

---

## 7. 游戏流程 `mM`（6562 行）

### 7.1 状态机

```js
_={state:"title",flow:Yi,run:c,menus:l,start(P){U({skipIntro,quick})},pause,resume,update:B,debugCut}
// M(P) 置状态并发事件：
function M(P){let V=_.state;P!==V&&(_.state=P,u=0,i.events.emit("game:state",{state:P,prev:V}))}
```

状态：`title`（Catmull-Rom 运镜 12 点 + 暗角）→ `intro`（3.5s，重试 1.3s；广播 intro）→ `playing` → `paused` / `dead` / `complete`。`B(P)` 是 switch 分派；`input:lock` 丢失 / `visibilitychange` / Esc → 自动暂停。

流程常量 `Yi`（6562 行）：

```js
Yi={introSeconds:3.5,retryIntroSeconds:1.3,interactRange:2.2,interactFacing:.45,cutSeconds:2.4,
patrol:{gull:2,hound:1},waves:[{gull:3,hound:1},{gull:3,hound:2},{gull:4,hound:3}],
maxAlive:9,spawnStagger:.85,spawnFar:18,pursuitEvery:7,pursuitMinAlive:4,pursuitExtra:5,
titleSpeed:1.15,titleFov:50}
```

### 7.2 中继目标流

- 开局 `H()` 把 `level.objectives` 转 `c.relays=[{o,id,short:"A",t:0,cut:false,cutting}]`，`object.userData.setState("live")`；`hud.setRelays(0,3)` + `setMarkers`。
- 按住 E（`r.down("interact")`，面向 `.45`、距离 2.2m 内）→ `L.t+=P/Yi.cutSeconds` → `objective:progress` → 满 1 调 `me(P)`：`cut++`、`setState("cut")`、**`F(cut-1)` 触发波次**、广播 `_l.cut[k]`；三台全断 → `allCut`，广播 extractOpen / 3.8s 后 all / 13s 后 boatHint，撤离点标记出现（`q()` 里 push `{kind:"extract"}`）。
- 松开 E 回退 `L.t-=P*1.6` 并 `setState("live")`。

### 7.3 波次与出生点选择

```js
// F(P)：按波次表混编队列（hound 插在 gull 序列里 stagger .85s），c.waveHot=30，o.warn("发现敌人 — 方位")
function F(P){let V=Yi.waves[Math.min(P,…)],Y=[];…c.queue.push({type,pos:le,at:c.time+1.6+fe*Yi.spawnStagger})…}
// X(P)：每帧出队，aliveCount≥maxAlive 则推迟；全断后进入"追猎"补兵（pursuitEvery 7s × pursuitExtra 5 次）
// Q(type)：在 enemySpawns 里按 打分选点：距离≥spawnFar 加分、preferHidden(无 LOS)+2.5、6s 内用过 -3
function ie(){…for(let Y=0;Y<Yi.patrol[V];Y++)K(V,Q(V,{minDist:32,…}),{state:"patrol"})}   // 开局巡逻 3 组
```

### 7.4 撤离触发

```js
// ue(P) 内：
let Z=L<(Y.radius||2.5)&&Math.abs(Y.pos.y-n.pos.y)<3.5;
Z&&c.allCut&&n.alive?ee()      // 撤离成立 → ee()
 :Z&&!c.allCut&&c.extractHint<=0&&o.message("中继站仍在工作 — 快艇不会在炮火里干等")
// ee()：player.invulnerable=true、emit("extraction:reached")、广播 done、setDebrief、M("complete")
```

### 7.5 结算与"毫发无伤"三档评价（现值与改法）

```js
// 6562 行 ee() 内，现评分：三项各 0~2 分相加 → 六档
let P=i.combat&&i.combat.stats||{shots:0,hits:0,kills:0},V=P.shots>0?Zn(P.hits/P.shots,0,1):null,
Y=(c.time<270?2:c.time<400?1:0)+(V>=.5?2:V>=.3?1:0)+(c.retries===0?1:0),
L=["狼狈","大动静","稳扎稳打","干净利落","精准狠辣","手术刀级"][Y];
l.setDebrief({time:c.time,accuracy:V,kills:P.kills||0,retries:c.retries,rating:L})
```

**加"毫发无伤"三档评价（推荐做法）**：
1. `c` 里加 `damageTaken:0`；现成的监听 `i.events.on("player:hit",()=>{c.alertT=…})`（6562 行）扩为 `(_,k)=>{c.damageTaken+=k&&k.amount||10}`（player:hit 事件带 `fromPos`，量值可在 player.damage 里随事件补发，或按掉血 delta 记：`c.damageTaken=Math.max(0,prevHealth-newHealth)` 更稳）。
2. `ee()` 里在 `Y` 之外独立算三档并**前置显示**：
   ```js
   let touch=c.damageTaken<=0?"毫发无伤":c.damageTaken<=40?"皮糙肉厚":"遍体鳞伤";
   l.setDebrief({…,rating:touch+" · "+L})   // 或 setDebrief 加独立字段 integrity:touch
   ```
   菜单面板 `pM`（6478 行）的 debrief 卡片加一行渲染该字段。
3. 想让"无伤"参与星级：`Y+=(c.damageTaken<=0?1:0)` 并把六档表补为七档（或直接封顶）。
4. 重开逻辑：`H()` 复位清单里补 `c.damageTaken=0`（6562 行 `H()` 已复位 contactSaid 等 20+ 旗标，照抄一行）。

---

## 8. 调试钩子

### 8.1 URL 参数（全量实测清单）

| 参数 | 处理处 | 作用 |
|---|---|---|
| `q=test/low/medium/high/ultra` | `zy(i.q||…)` 4186/6562 | 画质档（未知则 GPU 嗅探：Intel 非 Arc→medium，其余 high；移动端→low） |
| `seed` | 6562 `il(+(i.seed||4207))` | 关卡/生成随机种子 |
| `shot` | 6562 | `quality=test` + `game.start({skipIntro})` + 静态拍照模式（关闭动态分辨率） |
| `cam=x,y,z,lx,ly,lz` | 6562 `o(h)` → `window.__setShot` | 每帧硬覆写相机位姿（6 参数；`cam=` 清除；look 缺省 `[0,1,0]`） |
| `fov=` | 6562 `o(h)` | 覆写相机 fov |
| `exposure=` | 6562 `o(h)` | 覆写 `render.exposure` |
| `show=<key>` | 6562 `gM[i.show]` | 进 showcase 模式（见 8.3） |
| `autostart=1` | 6562 | 跳过标题直接开局 |
| `noaudio=1` | 6562 | 音频桩 |
| `bench` 或 `#bench` | 6562/6573 | bench 模式（隐含 noaudio+autostart，`eP` 6562 建 HUD 面板） |
| `dt=` | 6562 主循环 | 锁定帧步长（慢动作调试） |
| `noweapon=1` | 6562 | `weapon.setVisible(!1)` |
| `post=0 / ao=0 / vol=0 / bloom=0 / mb=1 / dynres=0` | 4739 | 后期开关（mb 默认关，`mb=1` 强开） |
| `tex=` / `wet=` | 5539 Gg | 纹理尺寸 / 全局湿度 |
| `bshow=crane/ships/gulls/hills` | 5816 MR | backdrop 单分支 |
| `eshow=both/gull/hound/fight/dead` + `epre=` + `efreeze=1` | 6455 VC | 敌人 showcase |
| `eseed=` | 6433 Em | 敌人 AI 随机种子 |
| `fxshow=` + `fxt/fxsoft/fxsize/fxhold` | 6307 JR | 特效 showcase |
| `wpose=` | 6433 | 武器姿态展示 |
| `only=` | 5539 wA / 5788 Eb | 材质/背景只渲染子集 |
| `names=a,b,…` | props showcase AA | 道具清单 |

### 8.2 window 全局钩子（6562/6569 行）

- `window.__G`（完整上下文）、`__setShot(o)`、`__stats()`（`{…render.stats, fps, state}`）、`__frames`、第 2 帧置 `__ready=!0`、`__fatal`、`__errors`。
- 错误捕获（6562 行）：`window.addEventListener("error",…)` push `__errors`；**console.error 被包裹**（保留原始输出同时入 `__errors`，截 400 字符）；模块装载失败时 `[boot] module "x" failed` 且有桩则降级（`dr` 表 4186 行：ground/backdrop/fx/audio/weapon/enemies/hud/mats 的 stub）。
- 致命错误：`bM`（6562 行）置 `__fatal` 并在 `#fatal` 显示 `《盐线》启动失败：…`。
- `t.game.debugCut()`：立即切掉下一个中继（测试通关链路用）。
- 设置持久化：localStorage `saltline.settings.v1`（quality/sens/invertY/volume/fov，6478 行 `YC/Wf`）。

### 8.3 showcase 注册表（6562 行 `gM`）

```js
var gM={mats:qg,level:cv,backdrop:mv,ground:vv,fx:Sv,weapon:Xv,enemies:ex,props:$g,render:Vg};
```

每个是 `br()` 导出包（如 5557 行 `var cv={};br(cv,{create:()=>C1,showcase:()=>mR})`；其余注册行实测：qg=4739、Vg=4186、$g=5539、mv=5705、vv=5816、Sv=6193、Xv=6307、ex=6433）。`?show=level` 会搭 stub 场景跑 `mR`（关卡尺寸统计）；`?show=enemies` 支持 `eshow=fight`（6455 行 VC：3 hound + 2 gull 互相开战预演）。**山谷版做新资产时，为每个模块保留/更新 showcase 是最便宜的 QA 手段。**

---

## 9. 山谷·伐木场改造落点速查（结论汇总）

| 改造项 | 主要落点（行号） |
|---|---|
| 主题文案（盐线→山谷） | 3、346–347、6562（boot 文案/loc-card）、6478（菜单标题卡） |
| 天空白天+雪山 | 4185 Mn、4186 en、4216–4290 shader 参数、5788 Eb 加 `mountains` 分支 |
| 光照 | 4739（太阳拟合盒 `-44…43` 按新布局改）、`Jy/Ky` 换行 |
| 关卡数据 | 5684–5703（C1 全量重写：objectives/ spawns/ zones/ interiorBoxes/ cinematicPath/ coverPoints/ extraction/ groundSurfaceAt） |
| 物理/导航 | 5539 d3（世界边界 oi 4184，nav 栅格 5539 `Ls/Ya/EA/ol/SA`，quayX→河界） |
| 材质/贴图 | 5380 c3+l1、4828 Tn 加 wood/dirt/gravel 集 |
| 敌人→+友军 | 6433（Ui/Em/Q_/iM/_activate/h.think/fireBolt 命中）+ 6307 zv（误伤）+ 6562 mM（aliveCount 口径） |
| 音频角色化 | 6455 radio/comms-who、6307 speakRadio(he) 传参、6562 _l 重写 |
| 三档评价 | 6562 ee() + c.damageTaken + 6478 setDebrief 渲染 |
| QA 机位 | 见 `docs/cams.md`（`?cam=` 六参数，6562 `__setShot`） |

> 未核验项声明：本文不涉及 three.js 引擎包内部（353–4159）逐行内容，仅引用其导出表与初始化行为；`Mt`（玩家移动调参）内部字段未全文展开，改造移动手感时需另读 6307 行 `x_` 主体。
