import * as THREE from 'three';
import { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';
import {
  BOT_SPAWNS,
  COVER_SPOTS,
  MAP_COLLIDERS,
  MAP_PROPS,
  PLAYER_SPAWN,
  PLAYER_SPAWN_YAW,
} from './mapData';
import { buildBotRig, buildViewModel, BotRig, ViewModelRig } from './models';
import {
  calculateBallisticDamage,
  computeDynamicSpread,
  createWeaponInstance,
  evaluateBotNextState,
  evaluatePurchase,
  getDifficultyTuning,
  getRecoilForShot,
  getSupportFloorY,
  HitRegion,
  intersectSegmentAABB,
  resolveHorizontalCollision,
} from './rules';
import { createTacticalTextures, TacticalTextureSet } from './textures';
import {
  BotAIState,
  BotArchetype,
  BotDifficulty,
  GamePhase,
  HudSnapshot,
  KillfeedEntry,
  RadarBlip,
  Vec3,
  WEAPONS,
  WeaponId,
  WeaponInstance,
  WeaponSlot,
} from './types';
import { tacticalAudio } from './audio';

interface ActiveBot {
  id: string;
  name: string;
  archetype: BotArchetype;
  rig: BotRig;
  pos: THREE.Vector3;
  vel: THREE.Vector3;
  yaw: number;
  hp: number;
  maxHp: number;
  armor: number;
  hasHelmet: boolean;
  ammoInMag: number;
  maxMag: number;
  reloadTimer: number;
  fireCooldown: number;
  reactionTimer: number;
  windupTimer: number;
  blindTimer: number;
  hitFlashTimer: number;
  koTimer: number;
  state: BotAIState;
  patrolRoute: Vec3[];
  patrolIdx: number;
  lastHeardPos: THREE.Vector3;
  timeSinceHeard: number;
  strafePhase: number;
  walkDist: number;
  weaponId: WeaponId;
  laserLine: THREE.Line;
}

interface ActiveGrenade {
  kind: 'he_grenade' | 'flashbang';
  mesh: THREE.Group;
  pos: THREE.Vector3;
  vel: THREE.Vector3;
  fuse: number;
  active: boolean;
}

interface TracerBeam {
  line: THREE.Line;
  mat: THREE.LineBasicMaterial;
  life: number;
  maxLife: number;
}

interface ParticleSlot {
  active: boolean;
  pos: THREE.Vector3;
  vel: THREE.Vector3;
  life: number;
  maxLife: number;
  scale: number;
}

const BOT_NAMES = ['BOT Viper', 'BOT Kestrel', 'BOT Rook', 'BOT Jaeger', 'BOT Nomad'];

// Pre-allocated scratch math objects (zero GC in render loop)
const _v1 = new THREE.Vector3();
const _v2 = new THREE.Vector3();
const _v3 = new THREE.Vector3();
const _v4 = new THREE.Vector3();
const _mat4 = new THREE.Matrix4();
const _quat = new THREE.Quaternion();
const _euler = new THREE.Euler(0, 0, 0, 'YXZ');
const _raycaster = new THREE.Raycaster();
const _color = new THREE.Color();

export class FpsEngine {
  private container: HTMLElement;
  private renderer: THREE.WebGLRenderer;
  private scene: THREE.Scene;
  private camera: THREE.PerspectiveCamera;
  private isSoftwareGl: boolean;
  private textures: TacticalTextureSet;

  private frameId = 0;
  private disposed = false;
  private lastTime = performance.now();
  private elapsed = 0;
  private hudSyncTimer = 0;

  private phase: GamePhase = 'title';
  private difficulty: BotDifficulty = 'tactical';
  private botCount = 4;

  // Player state
  private playerPos = new THREE.Vector3(PLAYER_SPAWN.x, 0, PLAYER_SPAWN.z);
  private playerVel = new THREE.Vector3();
  private playerYaw = PLAYER_SPAWN_YAW;
  private playerPitch = 0;
  private playerGrounded = true;
  private playerHp = 100;
  private playerArmor = 100;
  private playerHasHelmet = true;
  private playerCash = 3500;
  private walkBobPhase = 0;
  private stepDistAccum = 0;

  // Weapon & recoil state
  private slots: Record<WeaponSlot, WeaponInstance | null> = {
    1: createWeaponInstance('m4a1s'),
    2: createWeaponInstance('usps'),
    3: createWeaponInstance('karambit'),
    4: createWeaponInstance('he_grenade'),
    5: createWeaponInstance('flashbang'),
  };
  private activeSlot: WeaponSlot = 1;
  private heCount = 1;
  private flashCount = 1;
  private fireCooldown = 0;
  private reloadTimer = 0;
  private isReloading = false;
  private isScoped = false;
  private recoilPitch = 0;
  private recoilYaw = 0;
  private recoilBloom = 0;
  private sprayCount = 0;
  private sprayResetTimer = 0;
  private viewKickZ = 0;
  private viewKickRot = 0;
  private knifeSwingTimer = 0;

  // Juice & feedback
  private hitstopTimer = 0;
  private cameraTrauma = 0;
  private flashAlpha = 0;
  private damageFlashAlpha = 0;
  private hitmarkerType: 'none' | 'body' | 'head' | 'kill' = 'none';
  private hitmarkerTimer = 0;
  private roundBanner: string | null = null;
  private roundBannerTimer = 0;

  // Match stats
  private round = 1;
  private readonly maxRounds = 5;
  private playerScore = 0;
  private botScore = 0;
  private kills = 0;
  private headshots = 0;
  private shotsFired = 0;
  private shotsHit = 0;
  private damageDealt = 0;
  private roundEndDelay = 0;
  private roundPendingState: 'none' | 'won' | 'lost' = 'none';
  private killfeed: KillfeedEntry[] = [];
  private nextKillId = 1;

  // Input state
  private keys = new Set<string>();
  private justPressed = new Set<string>();
  private mouseDown = false;
  private mouseJustPressed = false;
  private rightMouseDown = false;
  private isDraggingLook = false;
  private lastPointerX = 0;
  private lastPointerY = 0;
  private pointerLocked = false;

  // Scene objects
  private viewModelMount = new THREE.Group();
  private viewModels = new Map<WeaponId, ViewModelRig>();
  private muzzleFlashMesh: THREE.Mesh;
  private muzzleFlashTimer = 0;
  private bots: ActiveBot[] = [];
  private grenades: ActiveGrenade[] = [];
  private tracerPool: TracerBeam[] = [];
  private tracerCursor = 0;
  private particleMesh: THREE.InstancedMesh;
  private particles: ParticleSlot[] = [];
  private particleCursor = 0;
  private hitMeshesList: THREE.Mesh[] = [];

  private onHudUpdate: (hud: HudSnapshot) => void;
  private onPhaseChange: (phase: GamePhase) => void;
  private resizeObserver: ResizeObserver;

  constructor(
    container: HTMLElement,
    onHudUpdate: (hud: HudSnapshot) => void,
    onPhaseChange: (phase: GamePhase) => void,
  ) {
    this.container = container;
    this.onHudUpdate = onHudUpdate;
    this.onPhaseChange = onPhaseChange;

    this.isSoftwareGl = (() => {
      const gl = document.createElement('canvas').getContext('webgl2');
      if (!gl) return true;
      const ext = gl.getExtension('WEBGL_debug_renderer_info');
      const param = ext ? ext.UNMASKED_RENDERER_WEBGL : gl.RENDERER;
      const gpu = String(gl.getParameter(param));
      gl.getExtension('WEBGL_lose_context')?.loseContext();
      return /SwiftShader|llvmpipe|softpipe|Software|Basic Render/i.test(gpu);
    })();

    this.renderer = new THREE.WebGLRenderer({
      antialias: !this.isSoftwareGl,
      powerPreference: 'high-performance',
    });
    this.renderer.outputColorSpace = THREE.SRGBColorSpace;
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
    this.renderer.toneMappingExposure = 1.12;
    this.renderer.setPixelRatio(this.isSoftwareGl ? 1 : Math.min(window.devicePixelRatio, 2));
    this.renderer.shadowMap.enabled = !this.isSoftwareGl;
    this.renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    this.renderer.setSize(container.clientWidth || window.innerWidth, container.clientHeight || window.innerHeight);
    container.appendChild(this.renderer.domElement);

    this.scene = new THREE.Scene();
    this.scene.background = new THREE.Color(0xd9c7ae);
    this.scene.fog = new THREE.FogExp2(0xd9c7ae, 0.0115);

    const aspect = (container.clientWidth || window.innerWidth) / Math.max(1, container.clientHeight || window.innerHeight);
    this.camera = new THREE.PerspectiveCamera(75, aspect, 0.08, 220);
    this.camera.rotation.order = 'YXZ';
    this.scene.add(this.camera);

    // Studio reflection map
    const pmrem = new THREE.PMREMGenerator(this.renderer);
    this.scene.environment = pmrem.fromScene(new RoomEnvironment(), 0.04).texture;
    pmrem.dispose();

    this.textures = createTacticalTextures(this.renderer);

    this.setupLighting();
    this.buildArena();
    this.setupViewModels();

    // Muzzle flash sprite mesh attached to camera viewmodel mount
    const flashGeo = new THREE.OctahedronGeometry(0.08, 0);
    const flashMat = new THREE.MeshBasicMaterial({
      color: 0xffd27a,
      transparent: true,
      opacity: 0.9,
      depthWrite: false,
    });
    this.muzzleFlashMesh = new THREE.Mesh(flashGeo, flashMat);
    this.muzzleFlashMesh.visible = false;
    this.viewModelMount.add(this.muzzleFlashMesh);

    // Zero-GC pooled tracers (16 lines)
    for (let i = 0; i < 16; i++) {
      const geo = new THREE.BufferGeometry().setFromPoints([new THREE.Vector3(), new THREE.Vector3()]);
      const mat = new THREE.LineBasicMaterial({ color: 0xffdf99, transparent: true, opacity: 0 });
      const line = new THREE.Line(geo, mat);
      line.frustumCulled = false;
      line.visible = false;
      this.scene.add(line);
      this.tracerPool.push({ line, mat, life: 0, maxLife: 0.12 });
    }

    // Zero-GC pooled spark/dust/blood particles (96 instances)
    const pGeo = new THREE.BoxGeometry(0.09, 0.09, 0.09);
    const pMat = new THREE.MeshBasicMaterial({ color: 0xffffff });
    this.particleMesh = new THREE.InstancedMesh(pGeo, pMat, 96);
    this.particleMesh.frustumCulled = false;
    for (let i = 0; i < 96; i++) {
      this.particles.push({
        active: false,
        pos: new THREE.Vector3(0, -50, 0),
        vel: new THREE.Vector3(),
        life: 0,
        maxLife: 0.4,
        scale: 0,
      });
      _mat4.makeScale(0, 0, 0);
      this.particleMesh.setMatrixAt(i, _mat4);
      this.particleMesh.setColorAt(i, _color.setHex(0xffc168));
    }
    this.particleMesh.instanceMatrix.needsUpdate = true;
    if (this.particleMesh.instanceColor) this.particleMesh.instanceColor.needsUpdate = true;
    this.scene.add(this.particleMesh);

    this.spawnRoundBots();
    this.bindEvents();

    this.resizeObserver = new ResizeObserver(() => this.handleResize());
    this.resizeObserver.observe(this.container);

    if (!this.isSoftwareGl) {
      this.renderer.compile(this.scene, this.camera);
    }

    this.pushHudSnapshot();
    this.tick();
  }

  private setupLighting(): void {
    const hemi = new THREE.HemisphereLight(0x9bc4e2, 0x8d6e4c, 0.8);
    this.scene.add(hemi);

    const sun = new THREE.DirectionalLight(0xffe7c2, 2.15);
    sun.position.set(28, 44, 22);
    if (!this.isSoftwareGl) {
      sun.castShadow = true;
      sun.shadow.mapSize.width = 1024;
      sun.shadow.mapSize.height = 1024;
      sun.shadow.camera.near = 5;
      sun.shadow.camera.far = 115;
      const d = 38;
      sun.shadow.camera.left = -d;
      sun.shadow.camera.right = d;
      sun.shadow.camera.top = d;
      sun.shadow.camera.bottom = -d;
      sun.shadow.bias = -0.0005;
      sun.shadow.normalBias = 0.02;
    }
    this.scene.add(sun);

    const rim = new THREE.DirectionalLight(0x88b4e6, 0.5);
    rim.position.set(-24, 18, -30);
    this.scene.add(rim);
  }

  private buildArena(): void {
    // Extended desert floor (220x220m) so perimeter never looks like a floating box
    const desertGeo = new THREE.PlaneGeometry(240, 240);
    desertGeo.rotateX(-Math.PI / 2);
    const desertMat = new THREE.MeshStandardMaterial({
      color: 0xc2a378,
      roughness: 0.94,
      metalness: 0.02,
    });
    const desertFloor = new THREE.Mesh(desertGeo, desertMat);
    desertFloor.position.y = -0.03;
    desertFloor.receiveShadow = true;
    this.scene.add(desertFloor);

    // Playable Sandstone Courtyard Floor (offset +0.03 above desert floor)
    const floorGeo = new THREE.PlaneGeometry(72, 72);
    floorGeo.rotateX(-Math.PI / 2);
    const floorMat = new THREE.MeshStandardMaterial({
      color: 0xffffff,
      map: this.textures.sandstoneColor,
      bumpMap: this.textures.sandstoneBump,
      bumpScale: 0.04,
      roughness: 0.86,
      metalness: 0.04,
    });
    const floor = new THREE.Mesh(floorGeo, floorMat);
    floor.position.y = 0;
    floor.receiveShadow = true;
    this.scene.add(floor);

    // Painted Tactical Site Markers (A-Site, B-Site, Mid Lane)
    const makeSiteDecal = (label: string, color: string, x: number, z: number) => {
      const c = document.createElement('canvas');
      c.width = 128;
      c.height = 128;
      const ctx = c.getContext('2d')!;
      ctx.strokeStyle = color;
      ctx.lineWidth = 8;
      ctx.strokeRect(10, 10, 108, 108);
      ctx.fillStyle = color;
      ctx.font = 'bold 68px sans-serif';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText(label, 64, 66);
      const tex = new THREE.CanvasTexture(c);
      tex.colorSpace = THREE.SRGBColorSpace;
      const mat = new THREE.MeshStandardMaterial({
        map: tex,
        transparent: true,
        opacity: 0.72,
        roughness: 0.9,
        polygonOffset: true,
        polygonOffsetFactor: -1,
        polygonOffsetUnits: -1,
      });
      const plane = new THREE.Mesh(new THREE.PlaneGeometry(3.2, 3.2), mat);
      plane.rotation.x = -Math.PI / 2;
      plane.position.set(x, 0.022, z);
      plane.receiveShadow = true;
      this.scene.add(plane);
    };
    makeSiteDecal('A', '#d9483b', -20, -10);
    makeSiteDecal('B', '#e08e26', 22, -4);

    // Shared materials
    const wallMat = new THREE.MeshStandardMaterial({
      color: 0xffffff,
      map: this.textures.concreteWallColor,
      bumpMap: this.textures.concreteWallBump,
      bumpScale: 0.05,
      roughness: 0.85,
      metalness: 0.04,
    });
    const trimMat = new THREE.MeshStandardMaterial({
      color: 0x6f5b46,
      roughness: 0.72,
      metalness: 0.12,
    });
    const woodMat = new THREE.MeshStandardMaterial({
      color: 0xffffff,
      map: this.textures.woodCrateColor,
      bumpMap: this.textures.woodCrateBump,
      bumpScale: 0.06,
      roughness: 0.78,
      metalness: 0.05,
    });
    const sandbagMat = new THREE.MeshStandardMaterial({
      color: 0x9b8663,
      roughness: 0.92,
      metalness: 0.02,
    });
    const barrelMat = new THREE.MeshStandardMaterial({
      color: 0x9f3327,
      roughness: 0.42,
      metalness: 0.62,
    });

    for (const p of MAP_PROPS) {
      const group = new THREE.Group();
      group.position.set(p.x, p.y, p.z);

      if (p.kind === 'wall' || p.kind === 'arch' || p.kind === 'ramp_block') {
        const body = new THREE.Mesh(new THREE.BoxGeometry(p.w, p.h, p.d), wallMat);
        body.position.y = p.h / 2;
        body.castShadow = !this.isSoftwareGl;
        body.receiveShadow = true;
        group.add(body);

        // Top stone coping lip for silhouette depth
        const cap = new THREE.Mesh(new THREE.BoxGeometry(p.w + 0.14, 0.14, p.d + 0.14), trimMat);
        cap.position.y = p.h - 0.05;
        cap.receiveShadow = true;
        group.add(cap);
      } else if (p.kind === 'crate') {
        const crate = new THREE.Mesh(new THREE.BoxGeometry(p.w, p.h, p.d), woodMat);
        crate.position.y = p.h / 2;
        crate.castShadow = !this.isSoftwareGl;
        crate.receiveShadow = true;
        group.add(crate);

        // Steel corner bands (roughness contrast)
        const strap = new THREE.Mesh(new THREE.BoxGeometry(p.w + 0.04, 0.1, p.d + 0.04), trimMat);
        strap.position.y = p.h * 0.5;
        group.add(strap);
      } else if (p.kind === 'container') {
        const cMat = new THREE.MeshStandardMaterial({
          color: p.tint ?? 0x334d5c,
          map: this.textures.metalContainerColor,
          bumpMap: this.textures.metalContainerBump,
          bumpScale: 0.06,
          roughness: 0.48,
          metalness: 0.58,
        });
        const hull = new THREE.Mesh(new THREE.BoxGeometry(p.w, p.h, p.d), cMat);
        hull.position.y = p.h / 2;
        hull.castShadow = !this.isSoftwareGl;
        hull.receiveShadow = true;
        group.add(hull);

        // Corner frame posts
        const postGeo = new THREE.BoxGeometry(0.16, p.h + 0.04, 0.16);
        const corners = [
          [-p.w / 2 + 0.08, -p.d / 2 + 0.08],
          [p.w / 2 - 0.08, -p.d / 2 + 0.08],
          [-p.w / 2 + 0.08, p.d / 2 - 0.08],
          [p.w / 2 - 0.08, p.d / 2 - 0.08],
        ];
        for (const [cx, cz] of corners) {
          const post = new THREE.Mesh(postGeo, trimMat);
          post.position.set(cx, p.h / 2, cz);
          group.add(post);
        }
      } else if (p.kind === 'sandbag') {
        // Multi-course stacked sandbag barricade
        const rows = 3;
        for (let r = 0; r < rows; r++) {
          const count = 4;
          for (let i = 0; i < count; i++) {
            const bagW = p.w / count;
            const bag = new THREE.Mesh(
              new THREE.BoxGeometry(bagW * 0.94, p.h / rows, p.d * 0.9),
              sandbagMat,
            );
            bag.position.set(
              -p.w / 2 + bagW * (i + 0.5) + (r % 2 === 0 ? 0.05 : -0.05),
              (r + 0.5) * (p.h / rows),
              0,
            );
            bag.castShadow = !this.isSoftwareGl;
            bag.receiveShadow = true;
            group.add(bag);
          }
        }
      } else if (p.kind === 'barrel') {
        const cyl = new THREE.Mesh(new THREE.CylinderGeometry(p.w * 0.5, p.w * 0.5, p.h, 16), barrelMat);
        cyl.position.y = p.h / 2;
        cyl.castShadow = !this.isSoftwareGl;
        cyl.receiveShadow = true;
        group.add(cyl);
        for (const ry of [0.35, 0.9]) {
          const rib = new THREE.Mesh(
            new THREE.CylinderGeometry(p.w * 0.53, p.w * 0.53, 0.08, 16),
            trimMat,
          );
          rib.position.y = ry;
          group.add(rib);
        }
      }

      this.scene.add(group);
    }

    // Perimeter Sandstone Compound Walls (with crenellations & watchtower landmark) + Canyon Cliffs outside
    const perimSpecs: Array<[number, number, number, number, number]> = [
      [0, -34.5, 70, 4.2, 1.5],
      [0, 34.5, 70, 4.2, 1.5],
      [-34.5, 0, 1.5, 4.2, 70],
      [34.5, 0, 1.5, 4.2, 70],
    ];
    for (const [px, pz, pw, ph, pd] of perimSpecs) {
      const m = new THREE.Mesh(new THREE.BoxGeometry(pw, ph, pd), wallMat);
      m.position.set(px, ph / 2, pz);
      m.receiveShadow = true;
      this.scene.add(m);
    }

    // Tall North Watchtower Landmark framed directly in spawn camera vista
    const tower = new THREE.Group();
    tower.position.set(-10, 0, -34.5);
    const tBase = new THREE.Mesh(new THREE.BoxGeometry(4.5, 11, 4.5), wallMat);
    tBase.position.y = 5.5;
    tower.add(tBase);
    const tTop = new THREE.Mesh(new THREE.BoxGeometry(5.2, 1.2, 5.2), trimMat);
    tTop.position.y = 11.4;
    tower.add(tTop);
    const tAntenna = new THREE.Mesh(new THREE.CylinderGeometry(0.08, 0.14, 4.5, 8), barrelMat);
    tAntenna.position.set(1.2, 13.8, 0);
    tower.add(tAntenna);
    this.scene.add(tower);

    // Distant Sandstone Canyon Ridges & Desert Buttes (InstancedMesh)
    const rockGeo = new THREE.DodecahedronGeometry(1, 0);
    const rockMat = new THREE.MeshStandardMaterial({ color: 0xb18e67, roughness: 0.94, metalness: 0.02 });
    const rockCount = 36;
    const rocks = new THREE.InstancedMesh(rockGeo, rockMat, rockCount);
    const dummy = new THREE.Object3D();
    for (let i = 0; i < rockCount; i++) {
      const angle = (i / rockCount) * Math.PI * 2;
      const dist = 52 + (i % 4) * 14;
      dummy.position.set(Math.cos(angle) * dist, 2 + (i % 3) * 1.5, Math.sin(angle) * dist);
      dummy.scale.set(6 + (i % 5) * 2.5, 5 + (i % 4) * 3.5, 6 + ((i + 2) % 5) * 2.2);
      dummy.rotation.set(0, angle * 1.7, 0);
      dummy.updateMatrix();
      rocks.setMatrixAt(i, dummy.matrix);
    }
    rocks.instanceMatrix.needsUpdate = true;
    rocks.computeBoundingSphere();
    this.scene.add(rocks);
  }

  private setupViewModels(): void {
    this.viewModelMount.position.set(0.24, -0.22, -0.35);
    this.camera.add(this.viewModelMount);

    const allIds: WeaponId[] = [
      'ak47',
      'm4a1s',
      'awp',
      'p90',
      'nova',
      'deagle',
      'usps',
      'karambit',
      'he_grenade',
      'flashbang',
    ];
    for (const id of allIds) {
      const vm = buildViewModel(id);
      vm.root.visible = false;
      this.viewModelMount.add(vm.root);
      this.viewModels.set(id, vm);
    }
    this.updateVisibleViewModel();
  }

  private getActiveWeaponId(): WeaponId {
    const inst = this.slots[this.activeSlot];
    return inst ? inst.id : 'karambit';
  }

  private updateVisibleViewModel(): void {
    const activeId = this.getActiveWeaponId();
    for (const [id, vm] of this.viewModels.entries()) {
      vm.root.visible = id === activeId && !this.isScoped && this.phase === 'playing';
    }
  }

  private spawnRoundBots(): void {
    for (const b of this.bots) {
      this.scene.remove(b.rig.root);
      this.scene.remove(b.laserLine);
    }
    this.bots = [];
    this.hitMeshesList = [];

    const tuning = getDifficultyTuning(this.difficulty);
    const count = Math.min(this.botCount, BOT_SPAWNS.length);

    for (let i = 0; i < count; i++) {
      const spec = BOT_SPAWNS[i];
      const rig = buildBotRig(spec.archetype, !this.isSoftwareGl);
      rig.root.position.set(spec.pos.x, spec.pos.y, spec.pos.z);
      this.scene.add(rig.root);

      const weaponId: WeaponId =
        spec.archetype === 'sniper' ? 'awp' : spec.archetype === 'entry' ? 'ak47' : 'm4a1s';

      const laserGeo = new THREE.BufferGeometry().setFromPoints([new THREE.Vector3(), new THREE.Vector3()]);
      const laserMat = new THREE.LineBasicMaterial({ color: 0xff3b30, transparent: true, opacity: 0.75 });
      const laserLine = new THREE.Line(laserGeo, laserMat);
      laserLine.visible = false;
      laserLine.frustumCulled = false;
      this.scene.add(laserLine);

      const bot: ActiveBot = {
        id: spec.id,
        name: BOT_NAMES[i % BOT_NAMES.length],
        archetype: spec.archetype,
        rig,
        pos: new THREE.Vector3(spec.pos.x, spec.pos.y, spec.pos.z),
        vel: new THREE.Vector3(),
        yaw: 0,
        hp: tuning.botHp,
        maxHp: tuning.botHp,
        armor: this.difficulty === 'recruit' ? 35 : 85,
        hasHelmet: this.difficulty === 'elite',
        ammoInMag: WEAPONS[weaponId].magazineSize,
        maxMag: WEAPONS[weaponId].magazineSize,
        reloadTimer: 0,
        fireCooldown: 0.5 + i * 0.2,
        reactionTimer: 0,
        windupTimer: 0,
        blindTimer: 0,
        hitFlashTimer: 0,
        koTimer: 0,
        state: 'PATROL',
        patrolRoute: spec.patrolRoute,
        patrolIdx: 0,
        lastHeardPos: new THREE.Vector3(spec.pos.x, spec.pos.y, spec.pos.z),
        timeSinceHeard: 99,
        strafePhase: i * 1.4,
        walkDist: 0,
        weaponId,
        laserLine,
      };

      for (const hm of rig.hitMeshes) {
        hm.userData.botRef = bot;
        this.hitMeshesList.push(hm);
      }

      this.bots.push(bot);
    }
  }

  public startNewMatch(difficulty?: BotDifficulty, botCount?: number): void {
    if (difficulty) this.difficulty = difficulty;
    if (botCount) this.botCount = botCount;

    this.round = 1;
    this.playerScore = 0;
    this.botScore = 0;
    this.kills = 0;
    this.headshots = 0;
    this.shotsFired = 0;
    this.shotsHit = 0;
    this.damageDealt = 0;
    this.playerCash = 3500;
    this.killfeed = [];

    this.slots = {
      1: createWeaponInstance('m4a1s'),
      2: createWeaponInstance('usps'),
      3: createWeaponInstance('karambit'),
      4: createWeaponInstance('he_grenade'),
      5: createWeaponInstance('flashbang'),
    };
    this.heCount = 1;
    this.flashCount = 1;
    this.activeSlot = 1;

    this.resetRoundState('ROUND 1 · ELIMINATE HOSTILES');
    this.setPhase('playing');
  }

  private resetRoundState(banner: string): void {
    this.playerPos.set(PLAYER_SPAWN.x, PLAYER_SPAWN.y, PLAYER_SPAWN.z);
    this.playerVel.set(0, 0, 0);
    this.playerYaw = PLAYER_SPAWN_YAW;
    this.playerPitch = 0;
    this.playerGrounded = true;
    this.playerHp = 100;
    this.playerArmor = 100;
    this.playerHasHelmet = true;
    this.isReloading = false;
    this.isScoped = false;
    this.camera.fov = 75;
    this.camera.updateProjectionMatrix();
    this.recoilPitch = 0;
    this.recoilYaw = 0;
    this.recoilBloom = 0;
    this.sprayCount = 0;
    this.flashAlpha = 0;
    this.damageFlashAlpha = 0;
    this.roundPendingState = 'none';
    this.roundEndDelay = 0;

    // Refill magazines for owned weapons
    for (const s of [1, 2] as WeaponSlot[]) {
      const w = this.slots[s];
      if (w) {
        w.ammoInMag = WEAPONS[w.id].magazineSize;
        w.reserveAmmo = WEAPONS[w.id].reserveMax;
      }
    }

    for (const g of this.grenades) {
      this.scene.remove(g.mesh);
    }
    this.grenades = [];

    this.spawnRoundBots();
    this.roundBanner = banner;
    this.roundBannerTimer = 2.4;
    this.updateVisibleViewModel();
    this.pushHudSnapshot();
  }

  public setPhase(next: GamePhase): void {
    this.phase = next;
    document.body.dataset.state = next;
    this.keys.clear();
    this.justPressed.clear();
    this.mouseDown = false;
    this.rightMouseDown = false;

    if (next !== 'playing') {
      this.isScoped = false;
      this.camera.fov = 75;
      this.camera.updateProjectionMatrix();
      if (document.pointerLockElement === this.renderer.domElement) {
        document.exitPointerLock?.();
      }
    }
    this.updateVisibleViewModel();
    this.onPhaseChange(next);
    this.pushHudSnapshot();
  }

  public requestPointerLock(): void {
    if (this.phase === 'playing' && !this.isSoftwareGl) {
      try {
        this.renderer.domElement.requestPointerLock?.();
      } catch {
        // Ignore in headless environments
      }
    }
  }

  public selectSlot(slot: WeaponSlot): void {
    if (!this.slots[slot]) return;
    if (slot === 4 && this.heCount <= 0) return;
    if (slot === 5 && this.flashCount <= 0) return;

    this.activeSlot = slot;
    this.isReloading = false;
    this.isScoped = false;
    this.camera.fov = 75;
    this.camera.updateProjectionMatrix();
    this.sprayCount = 0;
    this.viewKickZ = -0.07;
    tacticalAudio.playMetallicClick(0, 880);
    this.updateVisibleViewModel();
    this.pushHudSnapshot();
  }

  public buyItem(item: WeaponId | 'kevlar_helmet'): { ok: boolean; reason?: string } {
    const check = evaluatePurchase({
      item,
      cash: this.playerCash,
      currentArmor: this.playerArmor,
      hasHelmet: this.playerHasHelmet,
      heCount: this.heCount,
      flashCount: this.flashCount,
      currentPrimaryId: this.slots[1]?.id ?? null,
      currentPistolId: this.slots[2]?.id ?? 'usps',
    });

    if (!check.ok) {
      tacticalAudio.playMetallicClick(0, 320);
      return { ok: false, reason: check.reason };
    }

    this.playerCash -= check.cost;
    tacticalAudio.playMetallicClick(0, 1260);

    if (item === 'kevlar_helmet') {
      this.playerArmor = 100;
      this.playerHasHelmet = true;
    } else if (item === 'he_grenade') {
      this.heCount += 1;
      this.slots[4] = createWeaponInstance('he_grenade');
    } else if (item === 'flashbang') {
      this.flashCount += 1;
      this.slots[5] = createWeaponInstance('flashbang');
    } else {
      const spec = WEAPONS[item];
      this.slots[spec.slot] = createWeaponInstance(item);
      this.selectSlot(spec.slot);
    }

    this.pushHudSnapshot();
    return { ok: true };
  }

  private bindEvents(): void {
    window.addEventListener('keydown', this.handleKeyDown);
    window.addEventListener('keyup', this.handleKeyUp);
    window.addEventListener('blur', this.handleBlur);
    document.addEventListener('visibilitychange', this.handleBlur);
    document.addEventListener('pointerlockchange', this.handlePointerLockChange);

    const canvas = this.renderer.domElement;
    canvas.addEventListener('mousedown', this.handleMouseDown);
    window.addEventListener('mouseup', this.handleMouseUp);
    window.addEventListener('mousemove', this.handleMouseMove);
    canvas.addEventListener('contextmenu', this.handleContextMenu);
  }

  private handleContextMenu = (e: MouseEvent) => {
    e.preventDefault();
  };

  private handlePointerLockChange = () => {
    this.pointerLocked = document.pointerLockElement === this.renderer.domElement;
    this.pushHudSnapshot();
  };

  private handleBlur = () => {
    this.keys.clear();
    this.justPressed.clear();
    this.mouseDown = false;
    this.isDraggingLook = false;
  };

  private handleKeyDown = (e: KeyboardEvent) => {
    if (this.phase !== 'playing') return;
    if (!this.keys.has(e.code)) {
      this.justPressed.add(e.code);
    }
    this.keys.add(e.code);

    if (e.code === 'Digit1') this.selectSlot(1);
    else if (e.code === 'Digit2') this.selectSlot(2);
    else if (e.code === 'Digit3') this.selectSlot(3);
    else if (e.code === 'Digit4') this.selectSlot(4);
    else if (e.code === 'Digit5') this.selectSlot(5);
    else if (e.code === 'KeyG') {
      if (this.heCount > 0) {
        this.selectSlot(4);
        this.throwActiveGrenade('he_grenade');
      }
    } else if (e.code === 'KeyF') {
      if (this.flashCount > 0) {
        this.selectSlot(5);
        this.throwActiveGrenade('flashbang');
      }
    } else if (e.code === 'KeyR') {
      this.tryStartReload();
    }
  };

  private handleKeyUp = (e: KeyboardEvent) => {
    this.keys.delete(e.code);
  };

  private handleMouseDown = (e: MouseEvent) => {
    if (this.phase !== 'playing') return;
    if (e.button === 0) {
      this.mouseDown = true;
      this.mouseJustPressed = true;
      this.isDraggingLook = true;
      this.lastPointerX = e.clientX;
      this.lastPointerY = e.clientY;
      if (!this.pointerLocked) {
        this.requestPointerLock();
      }
    } else if (e.button === 2) {
      this.rightMouseDown = true;
      const spec = WEAPONS[this.getActiveWeaponId()];
      if (spec.canScope && !this.isReloading) {
        this.isScoped = !this.isScoped;
        this.camera.fov = this.isScoped ? 28 : 75;
        this.camera.updateProjectionMatrix();
        tacticalAudio.playMetallicClick(0, 1450);
        this.updateVisibleViewModel();
        this.pushHudSnapshot();
      }
    }
  };

  private handleMouseUp = (e: MouseEvent) => {
    if (e.button === 0) {
      this.mouseDown = false;
      this.isDraggingLook = false;
    } else if (e.button === 2) {
      this.rightMouseDown = false;
    }
  };

  private handleMouseMove = (e: MouseEvent) => {
    if (this.phase !== 'playing') return;
    const sens = this.isScoped ? 0.00095 : 0.0022;
    if (this.pointerLocked) {
      this.playerYaw -= e.movementX * sens;
      this.playerPitch = THREE.MathUtils.clamp(
        this.playerPitch - e.movementY * sens,
        -Math.PI * 0.46,
        Math.PI * 0.46,
      );
    } else if (this.isDraggingLook) {
      const dx = e.clientX - this.lastPointerX;
      const dy = e.clientY - this.lastPointerY;
      this.lastPointerX = e.clientX;
      this.lastPointerY = e.clientY;
      this.playerYaw -= dx * sens * 1.4;
      this.playerPitch = THREE.MathUtils.clamp(
        this.playerPitch - dy * sens * 1.4,
        -Math.PI * 0.46,
        Math.PI * 0.46,
      );
    }
  };

  private tryStartReload(): void {
    const inst = this.slots[this.activeSlot];
    if (!inst) return;
    const spec = WEAPONS[inst.id];
    if (spec.category === 'melee' || spec.category === 'grenade') return;
    if (this.isReloading || inst.ammoInMag >= spec.magazineSize || inst.reserveAmmo <= 0) return;

    this.isReloading = true;
    this.reloadTimer = spec.reloadTime;
    this.isScoped = false;
    this.camera.fov = 75;
    this.camera.updateProjectionMatrix();
    this.updateVisibleViewModel();
    tacticalAudio.playReload();
  }

  private finishReload(): void {
    this.isReloading = false;
    const inst = this.slots[this.activeSlot];
    if (!inst) return;
    const spec = WEAPONS[inst.id];
    const need = spec.magazineSize - inst.ammoInMag;
    const take = Math.min(need, inst.reserveAmmo);
    inst.ammoInMag += take;
    inst.reserveAmmo -= take;
  }

  private tryFireWeapon(): void {
    const inst = this.slots[this.activeSlot];
    if (!inst) return;
    const spec = WEAPONS[inst.id];

    if (spec.category === 'grenade') {
      this.throwActiveGrenade(inst.id as 'he_grenade' | 'flashbang');
      return;
    }

    if (spec.category !== 'melee') {
      if (inst.ammoInMag <= 0) {
        this.tryStartReload();
        return;
      }
      inst.ammoInMag -= 1;
    } else {
      this.knifeSwingTimer = 0.22;
    }

    this.fireCooldown = 60 / spec.fireRateRpm;
    this.sprayResetTimer = 0.4;

    const kick = getRecoilForShot(inst.id, this.sprayCount);
    this.recoilPitch += kick.pitch;
    this.recoilYaw += kick.yaw;
    this.sprayCount += 1;
    this.recoilBloom = Math.min(1.6, this.recoilBloom + (spec.category === 'pistol' ? 0.36 : 0.24));
    this.viewKickZ = 0.065;
    this.viewKickRot = 0.09;
    this.cameraTrauma = Math.min(0.65, this.cameraTrauma + (spec.id === 'awp' ? 0.45 : 0.14));

    if (spec.category !== 'melee') {
      this.shotsFired += 1;
      this.muzzleFlashTimer = 0.045;
      this.muzzleFlashMesh.visible = !spec.silenced;
      const vm = this.viewModels.get(inst.id);
      if (vm) {
        this.muzzleFlashMesh.position.copy(vm.muzzlePoint.position);
        this.muzzleFlashMesh.rotation.z = Math.random() * Math.PI;
      }
      // Alert bots to gunfire noise
      const hearRadius = spec.silenced ? 16 : 36;
      for (const b of this.bots) {
        if (b.pos.distanceTo(this.playerPos) <= hearRadius) {
          b.lastHeardPos.copy(this.playerPos);
          b.timeSinceHeard = 0;
        }
      }
    }

    tacticalAudio.playGunshot(inst.id, 1.0);

    const horizSpeed = Math.hypot(this.playerVel.x, this.playerVel.z);
    const spread = computeDynamicSpread({
      weaponId: inst.id,
      horizontalSpeed: horizSpeed,
      isGrounded: this.playerGrounded,
      isCrouching: this.keys.has('ControlLeft') || this.keys.has('KeyC'),
      isScoped: this.isScoped,
      recoilBloom: this.recoilBloom,
    });

    const eyeOrigin = _v1.set(
      this.playerPos.x,
      this.playerPos.y + (this.keys.has('ControlLeft') || this.keys.has('KeyC') ? 1.25 : 1.62),
      this.playerPos.z,
    );

    const camForward = _v2.set(0, 0, -1).applyEuler(this.camera.rotation).normalize();
    const camRight = _v3.set(1, 0, 0).applyEuler(this.camera.rotation).normalize();
    const camUp = _v4.crossVectors(camRight, camForward).normalize();

    let hitSomethingThisShot = false;
    let bestHitType: 'body' | 'head' | 'kill' = 'body';

    for (let p = 0; p < spec.pellets; p++) {
      const rx = (Math.random() - 0.5) * 2 * spread + THREE.MathUtils.degToRad(kick.yaw * 0.35);
      const ry = (Math.random() - 0.5) * 2 * spread + THREE.MathUtils.degToRad(kick.pitch * 0.35);

      const rayDir = new THREE.Vector3()
        .copy(camForward)
        .addScaledVector(camRight, rx)
        .addScaledVector(camUp, ry)
        .normalize();

      _raycaster.set(eyeOrigin, rayDir);
      _raycaster.far = spec.range;

      // Check closest wall occlusion & penetrable walls
      const wallHits: Array<{ t: number; penetrable: boolean }> = [];
      const rayEnd = new THREE.Vector3().copy(eyeOrigin).addScaledVector(rayDir, spec.range);
      for (const box of MAP_COLLIDERS) {
        const t = intersectSegmentAABB(eyeOrigin, rayEnd, box);
        if (t !== null) {
          wallHits.push({ t, penetrable: box.penetrable });
        }
      }
      wallHits.sort((a, b) => a.t - b.t);

      // Compute max unobstructed / wallbangable range
      let maxAllowedDist = spec.range;
      let penetratedWalls = 0;
      for (const wh of wallHits) {
        if (!wh.penetrable || spec.wallPenetration <= 0.1) {
          maxAllowedDist = wh.t * spec.range;
          break;
        }
        penetratedWalls += 1;
        if (penetratedWalls > 1) {
          maxAllowedDist = wh.t * spec.range;
          break;
        }
      }

      const intersects = _raycaster.intersectObjects(this.hitMeshesList, false);
      let endPoint = new THREE.Vector3().copy(eyeOrigin).addScaledVector(rayDir, Math.min(maxAllowedDist, 65));

      if (intersects.length > 0 && intersects[0].distance <= maxAllowedDist) {
        const hit = intersects[0];
        const bot = hit.object.userData.botRef as ActiveBot | undefined;
        endPoint.copy(hit.point);

        if (bot && bot.state !== 'KO') {
          const region = (hit.object.userData.hitRegion as HitRegion) || 'chest';
          let wallsThrough = 0;
          for (const wh of wallHits) {
            if (wh.t * spec.range < hit.distance && wh.penetrable) {
              wallsThrough += 1;
            }
          }

          const dmgRes = calculateBallisticDamage({
            weaponId: inst.id,
            region,
            distance: hit.distance,
            targetArmor: bot.armor,
            targetHasHelmet: bot.hasHelmet,
            penetratedWalls: wallsThrough,
          });

          bot.hp = Math.max(0, bot.hp - dmgRes.hpDamage);
          bot.armor = Math.max(0, bot.armor - dmgRes.armorDamage);
          bot.hitFlashTimer = 0.055;
          bot.lastHeardPos.copy(this.playerPos);
          bot.timeSinceHeard = 0;
          this.damageDealt += dmgRes.hpDamage;
          hitSomethingThisShot = true;

          // Knockback impulse & particles
          bot.vel.addScaledVector(rayDir, spec.id === 'nova' ? 3.5 : 1.4);
          this.spawnParticleBurst(hit.point, dmgRes.isHeadshot ? 0xff453a : 0xd9483b, 10);

          if (bot.hp <= 0) {
            this.handleBotEliminated(bot, spec.shortName, dmgRes.isHeadshot, spec.killReward);
            bestHitType = 'kill';
            this.hitstopTimer = 0.045;
          } else if (dmgRes.isHeadshot && bestHitType !== 'kill') {
            bestHitType = 'head';
            this.hitstopTimer = 0.03;
          }
        }
      } else if (wallHits.length > 0) {
        const firstHitDist = wallHits[0].t * spec.range;
        endPoint.copy(eyeOrigin).addScaledVector(rayDir, firstHitDist);
        if (spec.category !== 'melee') {
          this.spawnParticleBurst(endPoint, 0xe8d5b5, 5);
        }
      }

      if (spec.category !== 'melee') {
        const vm = this.viewModels.get(inst.id);
        const startPt = new THREE.Vector3();
        if (vm && !this.isScoped) {
          vm.muzzlePoint.getWorldPosition(startPt);
        } else {
          startPt.copy(eyeOrigin).addScaledVector(camRight, 0.12).addScaledVector(camUp, -0.08);
        }
        this.spawnTracer(startPt, endPoint);
      }
    }

    if (hitSomethingThisShot) {
      this.shotsHit += 1;
      this.hitmarkerType = bestHitType;
      this.hitmarkerTimer = 0.22;
      tacticalAudio.playHitmarker(bestHitType === 'head' || bestHitType === 'kill');
    }

    // Auto-unscope AWP briefly after shot
    if (inst.id === 'awp' && this.isScoped) {
      this.isScoped = false;
      this.camera.fov = 75;
      this.camera.updateProjectionMatrix();
      this.updateVisibleViewModel();
    }
  }

  private throwActiveGrenade(kind: 'he_grenade' | 'flashbang'): void {
    if (kind === 'he_grenade') {
      if (this.heCount <= 0) return;
      this.heCount -= 1;
      if (this.heCount === 0) this.slots[4] = null;
    } else {
      if (this.flashCount <= 0) return;
      this.flashCount -= 1;
      if (this.flashCount === 0) this.slots[5] = null;
    }

    tacticalAudio.playGunshot('karambit', 0.8);

    const mesh = new THREE.Group();
    const cyl = new THREE.Mesh(
      new THREE.CylinderGeometry(0.06, 0.06, 0.14, 10),
      new THREE.MeshStandardMaterial({
        color: kind === 'he_grenade' ? 0x45583a : 0xb0bac5,
        roughness: 0.45,
        metalness: 0.5,
      }),
    );
    mesh.add(cyl);
    const band = new THREE.Mesh(
      new THREE.CylinderGeometry(0.064, 0.064, 0.03, 10),
      new THREE.MeshBasicMaterial({ color: kind === 'he_grenade' ? 0xf59e0b : 0x38bdf8 }),
    );
    band.position.y = 0.02;
    mesh.add(band);

    const forward = new THREE.Vector3(0, 0, -1).applyEuler(this.camera.rotation).normalize();
    const startPos = new THREE.Vector3(this.playerPos.x, this.playerPos.y + 1.55, this.playerPos.z).addScaledVector(
      forward,
      0.6,
    );
    mesh.position.copy(startPos);
    this.scene.add(mesh);

    const throwVel = forward.multiplyScalar(17.5);
    throwVel.y += 4.2;

    this.grenades.push({
      kind,
      mesh,
      pos: startPos,
      vel: throwVel,
      fuse: kind === 'he_grenade' ? 1.55 : 1.25,
      active: true,
    });

    // Switch back to primary or pistol after throw
    if (this.slots[1]) this.selectSlot(1);
    else if (this.slots[2]) this.selectSlot(2);
    else this.selectSlot(3);
  }

  private detonateGrenade(g: ActiveGrenade): void {
    g.active = false;
    this.scene.remove(g.mesh);

    const isFlash = g.kind === 'flashbang';
    tacticalAudio.playExplosion(isFlash);
    this.spawnParticleBurst(g.pos, isFlash ? 0xffffff : 0xff7b29, 24);
    this.cameraTrauma = Math.min(1.0, this.cameraTrauma + (isFlash ? 0.25 : 0.65));

    // Alert all bots to explosion
    for (const b of this.bots) {
      if (b.state !== 'KO' && b.pos.distanceTo(g.pos) < 35) {
        b.lastHeardPos.copy(g.pos);
        b.timeSinceHeard = 0;
      }
    }

    if (isFlash) {
      // Check flash line-of-sight on player
      const playerEye = new THREE.Vector3(this.playerPos.x, this.playerPos.y + 1.6, this.playerPos.z);
      const distP = playerEye.distanceTo(g.pos);
      if (distP < 18 && this.hasLineOfSight(g.pos, playerEye)) {
        const toFlash = _v1.subVectors(g.pos, playerEye).normalize();
        const lookDir = _v2.set(0, 0, -1).applyEuler(this.camera.rotation).normalize();
        const facing = toFlash.dot(lookDir);
        if (facing > 0.15) {
          this.flashAlpha = Math.min(1, 0.85 * (1 - distP / 20));
        }
      }
      // Blind bots within line-of-sight
      for (const b of this.bots) {
        if (b.state === 'KO') continue;
        const botEye = _v1.set(b.pos.x, b.pos.y + 1.65, b.pos.z);
        const distB = botEye.distanceTo(g.pos);
        if (distB < 18 && this.hasLineOfSight(g.pos, botEye)) {
          b.blindTimer = Math.max(b.blindTimer, 3.2 * (1 - distB / 22));
        }
      }
      return;
    }

    // HE Frag damage & physics blast impulse
    const blastRadius = WEAPONS.he_grenade.range;
    for (const b of this.bots) {
      if (b.state === 'KO') continue;
      const dist = b.pos.distanceTo(g.pos);
      if (dist <= blastRadius) {
        const falloff = Math.max(0.15, 1 - dist / blastRadius);
        const dmg = Math.round(WEAPONS.he_grenade.damage * falloff);
        b.hp = Math.max(0, b.hp - dmg);
        b.hitFlashTimer = 0.08;
        this.damageDealt += dmg;
        const push = _v1.subVectors(b.pos, g.pos).normalize().multiplyScalar(8 * falloff);
        b.vel.add(push);
        if (b.hp <= 0) {
          this.handleBotEliminated(b, 'HE FRAG', false, 300);
        }
      }
    }

    const pDist = this.playerPos.distanceTo(g.pos);
    if (pDist <= blastRadius) {
      const falloff = Math.max(0.1, 1 - pDist / blastRadius);
      this.applyPlayerDamage(Math.round(58 * falloff));
    }
  }

  private handleBotEliminated(
    bot: ActiveBot,
    weaponShort: string,
    headshot: boolean,
    reward: number,
  ): void {
    bot.state = 'KO';
    bot.koTimer = 0.38;
    bot.laserLine.visible = false;
    this.kills += 1;
    if (headshot) this.headshots += 1;
    this.playerCash += reward;
    this.killfeed = [
      {
        id: this.nextKillId++,
        killer: 'YOU',
        victim: bot.name,
        weapon: weaponShort,
        headshot,
        timestamp: this.elapsed,
      },
      ...this.killfeed,
    ].slice(0, 4);

    // Check if all bots eliminated
    const alive = this.bots.filter((b) => b.state !== 'KO').length;
    if (alive === 0 && this.roundPendingState === 'none') {
      this.roundPendingState = 'won';
      this.roundEndDelay = 1.6;
      this.playerScore += 1;
      this.playerCash += 3250;
      this.roundBanner = 'ROUND WON · ALL HOSTILES ELIMINATED';
      this.roundBannerTimer = 2.5;
      tacticalAudio.playRoundSting(true);
    }
  }

  private applyPlayerDamage(rawDmg: number): void {
    if (this.phase !== 'playing' || this.playerHp <= 0) return;
    let hpDmg = rawDmg;
    if (this.playerArmor > 0) {
      const absorbed = Math.min(this.playerArmor, Math.round(rawDmg * 0.35));
      this.playerArmor -= absorbed;
      hpDmg = Math.max(1, rawDmg - absorbed);
    }
    this.playerHp = Math.max(0, this.playerHp - hpDmg);
    this.damageFlashAlpha = Math.min(0.85, this.damageFlashAlpha + 0.55);
    this.cameraTrauma = Math.min(0.85, this.cameraTrauma + 0.32);
    tacticalAudio.playPlayerHurt();

    if (this.playerHp <= 0 && this.roundPendingState === 'none') {
      this.roundPendingState = 'lost';
      this.roundEndDelay = 0.85;
      this.botScore += 1;
      this.playerCash += 1900;
      this.killfeed = [
        {
          id: this.nextKillId++,
          killer: 'BOT SQUAD',
          victim: 'YOU',
          weapon: 'RIFLE',
          headshot: false,
          timestamp: this.elapsed,
        },
        ...this.killfeed,
      ].slice(0, 4);
      tacticalAudio.playRoundSting(false);
    }
  }

  private hasLineOfSight(from: Vec3, to: Vec3): boolean {
    for (const box of MAP_COLLIDERS) {
      if (intersectSegmentAABB(from, to, box) !== null) {
        return false;
      }
    }
    return true;
  }

  private spawnTracer(start: THREE.Vector3, end: THREE.Vector3): void {
    const t = this.tracerPool[this.tracerCursor];
    this.tracerCursor = (this.tracerCursor + 1) % this.tracerPool.length;
    const posAttr = t.line.geometry.attributes.position as THREE.BufferAttribute;
    posAttr.setXYZ(0, start.x, start.y, start.z);
    posAttr.setXYZ(1, end.x, end.y, end.z);
    posAttr.needsUpdate = true;
    t.life = t.maxLife;
    t.mat.opacity = 0.9;
    t.line.visible = true;
  }

  private spawnParticleBurst(origin: THREE.Vector3, hexColor: number, count: number): void {
    _color.setHex(hexColor);
    for (let i = 0; i < count; i++) {
      const slot = this.particles[this.particleCursor];
      this.particleCursor = (this.particleCursor + 1) % this.particles.length;
      slot.active = true;
      slot.pos.copy(origin);
      slot.vel.set(
        (Math.random() - 0.5) * 7,
        1.5 + Math.random() * 4.5,
        (Math.random() - 0.5) * 7,
      );
      slot.maxLife = 0.25 + Math.random() * 0.25;
      slot.life = slot.maxLife;
      slot.scale = 0.7 + Math.random() * 0.8;
      this.particleMesh.setColorAt(this.particleCursor, _color);
    }
    if (this.particleMesh.instanceColor) {
      this.particleMesh.instanceColor.needsUpdate = true;
    }
  }

  private updatePlayer(dt: number): void {
    // Keyboard look fallback (Arrow keys) for accessibility & automated testing
    const keyTurnSpeed = 2.0;
    if (this.keys.has('ArrowLeft')) this.playerYaw += keyTurnSpeed * dt;
    if (this.keys.has('ArrowRight')) this.playerYaw -= keyTurnSpeed * dt;
    if (this.keys.has('ArrowUp')) {
      this.playerPitch = THREE.MathUtils.clamp(this.playerPitch + 1.5 * dt, -1.4, 1.4);
    }
    if (this.keys.has('ArrowDown')) {
      this.playerPitch = THREE.MathUtils.clamp(this.playerPitch - 1.5 * dt, -1.4, 1.4);
    }

    const forwardInput = (this.keys.has('KeyW') ? 1 : 0) - (this.keys.has('KeyS') ? 1 : 0);
    const strafeInput = (this.keys.has('KeyD') ? 1 : 0) - (this.keys.has('KeyA') ? 1 : 0);
    const crouching = this.keys.has('ControlLeft') || this.keys.has('KeyC');
    const walking = this.keys.has('ShiftLeft');

    const fwdX = -Math.sin(this.playerYaw);
    const fwdZ = -Math.cos(this.playerYaw);
    const rightX = Math.cos(this.playerYaw);
    const rightZ = -Math.sin(this.playerYaw);

    let wishX = fwdX * forwardInput + rightX * strafeInput;
    let wishZ = fwdZ * forwardInput + rightZ * strafeInput;
    const wishLen = Math.hypot(wishX, wishZ);
    if (wishLen > 0.001) {
      wishX /= wishLen;
      wishZ /= wishLen;
    }

    const spec = WEAPONS[this.getActiveWeaponId()];
    const baseSpeed = crouching ? 3.2 : walking ? 3.8 : 6.4;
    const maxSpeed = baseSpeed * spec.moveSpeedMultiplier * (this.isScoped ? 0.55 : 1);

    if (this.playerGrounded) {
      const hSpeed = Math.hypot(this.playerVel.x, this.playerVel.z);
      if (hSpeed > 0.01) {
        const drop = hSpeed * 11.5 * dt;
        const factor = Math.max(0, hSpeed - drop) / hSpeed;
        this.playerVel.x *= factor;
        this.playerVel.z *= factor;
      }
      // Crisp CS ground acceleration
      const currentProj = this.playerVel.x * wishX + this.playerVel.z * wishZ;
      const addSpeed = maxSpeed - currentProj;
      if (addSpeed > 0 && wishLen > 0.001) {
        const accel = Math.min(48 * dt, addSpeed);
        this.playerVel.x += wishX * accel;
        this.playerVel.z += wishZ * accel;
      }
    } else {
      // Air strafe acceleration
      const currentProj = this.playerVel.x * wishX + this.playerVel.z * wishZ;
      const addSpeed = maxSpeed - currentProj;
      if (addSpeed > 0 && wishLen > 0.001) {
        const accel = Math.min(12 * dt, addSpeed);
        this.playerVel.x += wishX * accel;
        this.playerVel.z += wishZ * accel;
      }
    }

    if ((this.justPressed.has('Space') || this.keys.has('Space')) && this.playerGrounded) {
      this.playerVel.y = 5.6;
      this.playerGrounded = false;
    }

    this.playerVel.y -= 17.5 * dt;

    // Integrate & resolve horizontal AABB sliding
    const nextPos: Vec3 = {
      x: this.playerPos.x + this.playerVel.x * dt,
      y: this.playerPos.y,
      z: this.playerPos.z + this.playerVel.z * dt,
    };
    const resolved = resolveHorizontalCollision(nextPos, 0.45, crouching ? 1.3 : 1.8, MAP_COLLIDERS);
    this.playerPos.x = resolved.x;
    this.playerPos.z = resolved.z;

    this.playerPos.y += this.playerVel.y * dt;
    const supportY = getSupportFloorY(this.playerPos.x, this.playerPos.z, this.playerPos.y, 0.45, MAP_COLLIDERS);
    if (this.playerPos.y <= supportY) {
      this.playerPos.y = supportY;
      this.playerVel.y = 0;
      this.playerGrounded = true;
    } else {
      this.playerGrounded = false;
    }

    // Distance-synced walk cycle bob & footstep audio
    const hSpeed = Math.hypot(this.playerVel.x, this.playerVel.z);
    if (this.playerGrounded && hSpeed > 0.4) {
      this.walkBobPhase += hSpeed * dt * 2.2;
      this.stepDistAccum += hSpeed * dt;
      if (this.stepDistAccum >= 2.2 && !walking && !crouching) {
        this.stepDistAccum = 0;
        tacticalAudio.playFootstep();
        // Bots can hear loud sprinting footsteps within 12m
        for (const b of this.bots) {
          if (b.pos.distanceTo(this.playerPos) <= 12) {
            b.lastHeardPos.copy(this.playerPos);
            b.timeSinceHeard = 0;
          }
        }
      }
    }

    // Weapon firing & reload updates
    this.fireCooldown = Math.max(0, this.fireCooldown - dt);
    this.recoilBloom = Math.max(0, this.recoilBloom - dt * 3.8);
    if (this.sprayResetTimer > 0) {
      this.sprayResetTimer -= dt;
      if (this.sprayResetTimer <= 0) this.sprayCount = 0;
    }

    if (this.isReloading) {
      this.reloadTimer -= dt;
      if (this.reloadTimer <= 0) {
        this.finishReload();
      }
    } else {
      const wantFire = spec.automatic ? this.mouseDown : this.mouseJustPressed;
      if (wantFire && this.fireCooldown <= 0) {
        this.tryFireWeapon();
      }
    }

    // Recoil & viewmodel recovery
    this.recoilPitch = THREE.MathUtils.damp(this.recoilPitch, 0, 10, dt);
    this.recoilYaw = THREE.MathUtils.damp(this.recoilYaw, 0, 10, dt);
    this.viewKickZ = THREE.MathUtils.damp(this.viewKickZ, 0, 14, dt);
    this.viewKickRot = THREE.MathUtils.damp(this.viewKickRot, 0, 14, dt);
    this.knifeSwingTimer = Math.max(0, this.knifeSwingTimer - dt);

    const eyeH = crouching ? 1.25 : 1.62;
    const bobY = this.playerGrounded ? Math.sin(this.walkBobPhase) * 0.035 * Math.min(1, hSpeed / 5) : 0;
    const shake = this.cameraTrauma * this.cameraTrauma;
    const shakeX = (Math.random() - 0.5) * 0.06 * shake;
    const shakeY = (Math.random() - 0.5) * 0.06 * shake;

    this.camera.position.set(this.playerPos.x, this.playerPos.y + eyeH + bobY, this.playerPos.z);
    _euler.set(
      this.playerPitch + THREE.MathUtils.degToRad(this.recoilPitch) + shakeX,
      this.playerYaw + THREE.MathUtils.degToRad(this.recoilYaw) + shakeY,
      0,
      'YXZ',
    );
    this.camera.quaternion.setFromEuler(_euler);

    // Animate viewmodel
    const reloadDip = this.isReloading ? Math.sin((this.reloadTimer / Math.max(0.1, spec.reloadTime)) * Math.PI) * 0.14 : 0;
    const knifeSlash = this.knifeSwingTimer > 0 ? Math.sin((this.knifeSwingTimer / 0.22) * Math.PI) * 0.55 : 0;
    this.viewModelMount.position.set(
      0.24 + Math.cos(this.walkBobPhase * 0.5) * 0.012 * Math.min(1, hSpeed / 5) - knifeSlash * 0.25,
      -0.22 + Math.abs(Math.sin(this.walkBobPhase * 0.5)) * 0.012 * Math.min(1, hSpeed / 5) - reloadDip,
      -0.35 + this.viewKickZ - knifeSlash * 0.2,
    );
    this.viewModelMount.rotation.set(this.viewKickRot - reloadDip * 1.4, knifeSlash * 0.9, knifeSlash * 0.4);
  }

  private updateBots(dt: number, simMode: 'combat' | 'patrol_only'): void {
    const tuning = getDifficultyTuning(this.difficulty);
    const playerEye = _v1.set(this.playerPos.x, this.playerPos.y + 1.5, this.playerPos.z);

    for (const bot of this.bots) {
      // Visual hit flash decay
      if (bot.hitFlashTimer > 0) {
        bot.hitFlashTimer -= dt;
        bot.rig.armorMat.emissive.setHex(0xffffff);
        bot.rig.armorMat.emissiveIntensity = 0.7;
      } else {
        bot.rig.armorMat.emissive.setHex(0x000000);
        bot.rig.armorMat.emissiveIntensity = 0;
      }

      if (bot.state === 'KO') {
        bot.koTimer = Math.max(0, bot.koTimer - dt);
        bot.rig.bodyPivot.rotation.x = THREE.MathUtils.damp(bot.rig.bodyPivot.rotation.x, -Math.PI * 0.48, 12, dt);
        bot.rig.bodyPivot.position.y = THREE.MathUtils.damp(bot.rig.bodyPivot.position.y, 0.2, 12, dt);
        bot.rig.contactShadow.visible = false;
        bot.laserLine.visible = false;
        continue;
      }

      bot.timeSinceHeard += dt;
      bot.fireCooldown = Math.max(0, bot.fireCooldown - dt);
      bot.blindTimer = Math.max(0, bot.blindTimer - dt);

      if (bot.state === 'RELOAD') {
        bot.reloadTimer -= dt;
        if (bot.reloadTimer <= 0) {
          bot.ammoInMag = bot.maxMag;
        }
      }

      const botEye = _v2.set(bot.pos.x, bot.pos.y + 1.62, bot.pos.z);
      const distToPlayer = botEye.distanceTo(playerEye);
      const canSeePlayer =
        simMode === 'combat' &&
        this.playerHp > 0 &&
        distToPlayer < 56 &&
        this.hasLineOfSight(botEye, playerEye);

      if (canSeePlayer) {
        bot.lastHeardPos.copy(this.playerPos);
        bot.timeSinceHeard = 0;
      }

      const prevState = bot.state;
      bot.state = evaluateBotNextState({
        hp: bot.hp,
        maxHp: bot.maxHp,
        ammoInMag: bot.ammoInMag,
        blindTimer: bot.blindTimer,
        canSeePlayer,
        distanceToPlayer: distToPlayer,
        timeSinceHeardPlayer: bot.timeSinceHeard,
        hasCoverNearby: COVER_SPOTS.length > 0,
        archetype: bot.archetype,
        difficulty: this.difficulty,
        currentState: bot.state,
      });

      if (bot.state === 'RELOAD' && prevState !== 'RELOAD') {
        bot.reloadTimer = 2.0;
      }

      // Visor color cue matching AI state
      if (bot.state === 'BLINDED') {
        bot.rig.visorMat.color.setHex(0xffffff);
        bot.rig.visorMat.emissive.setHex(0xe2e8f0);
      } else if (bot.state === 'ENGAGE') {
        bot.rig.visorMat.color.setHex(0xff3b30);
        bot.rig.visorMat.emissive.setHex(0xdc2626);
      } else if (bot.state === 'TAKE_COVER' || bot.state === 'RELOAD') {
        bot.rig.visorMat.color.setHex(0x38bdf8);
        bot.rig.visorMat.emissive.setHex(0x0284c7);
      } else {
        bot.rig.visorMat.color.setHex(0xf59e0b);
        bot.rig.visorMat.emissive.setHex(0xd97706);
      }

      // Steering & Behavior
      let moveTarget: THREE.Vector3 | null = null;
      let moveSpeed = tuning.moveSpeed;
      bot.laserLine.visible = false;

      if (bot.state === 'BLINDED') {
        bot.vel.x *= 0.85;
        bot.vel.z *= 0.85;
        bot.rig.headGroup.rotation.y = Math.sin(this.elapsed * 9) * 0.45;
      } else if (bot.state === 'ENGAGE') {
        bot.rig.headGroup.rotation.y = 0;
        const toP = _v3.subVectors(this.playerPos, bot.pos);
        const targetYaw = Math.atan2(toP.x, toP.z);
        bot.yaw = this.lerpAngle(bot.yaw, targetYaw, 1 - Math.exp(-10 * dt));

        // Counter-strafe sideways while maintaining preferred combat range
        bot.strafePhase += dt * tuning.strafeFrequency;
        const rightX = Math.cos(bot.yaw);
        const rightZ = -Math.sin(bot.yaw);
        const strafe = Math.sin(bot.strafePhase);
        bot.vel.x = rightX * strafe * moveSpeed * 0.65;
        bot.vel.z = rightZ * strafe * moveSpeed * 0.65;

        bot.reactionTimer += dt;
        // Sniper / heavy windup telegraph laser before shot
        if (bot.archetype === 'sniper' && bot.fireCooldown < 0.45 && bot.reactionTimer >= tuning.reactionDelay * 0.5) {
          bot.laserLine.visible = true;
          const mPos = new THREE.Vector3();
          bot.rig.muzzlePoint.getWorldPosition(mPos);
          const posAttr = bot.laserLine.geometry.attributes.position as THREE.BufferAttribute;
          posAttr.setXYZ(0, mPos.x, mPos.y, mPos.z);
          posAttr.setXYZ(1, playerEye.x, playerEye.y, playerEye.z);
          posAttr.needsUpdate = true;
        }

        if (bot.reactionTimer >= tuning.reactionDelay && bot.fireCooldown <= 0) {
          this.fireBotWeapon(bot, tuning.aimErrorRad, tuning.headshotChance);
        }
      } else if (bot.state === 'TAKE_COVER' || bot.state === 'RELOAD') {
        // Find cover spot farthest from player or shielded from player sightline
        let bestSpot = COVER_SPOTS[0];
        let bestScore = -Infinity;
        for (const c of COVER_SPOTS) {
          const dBot = Math.hypot(c.x - bot.pos.x, c.z - bot.pos.z);
          const blocked = !this.hasLineOfSight({ x: c.x, y: c.y + 1.4, z: c.z }, playerEye);
          const score = (blocked ? 30 : 0) - dBot;
          if (score > bestScore) {
            bestScore = score;
            bestSpot = c;
          }
        }
        moveTarget = _v3.set(bestSpot.x, bestSpot.y, bestSpot.z);
        moveSpeed *= 1.1;
      } else if (bot.state === 'INVESTIGATE' || bot.state === 'FLANK') {
        bot.reactionTimer = 0;
        moveTarget = _v3.copy(bot.lastHeardPos);
        if (bot.state === 'FLANK') {
          // Offset perpendicular to direct line to flank around Mid/Sites
          moveTarget.x += bot.archetype === 'entry' ? (bot.pos.x > 0 ? 7 : -7) : 0;
        }
      } else {
        // PATROL
        bot.reactionTimer = 0;
        const wp = bot.patrolRoute[bot.patrolIdx];
        if (Math.hypot(wp.x - bot.pos.x, wp.z - bot.pos.z) < 1.6) {
          bot.patrolIdx = (bot.patrolIdx + 1) % bot.patrolRoute.length;
        }
        const nextWp = bot.patrolRoute[bot.patrolIdx];
        moveTarget = _v3.set(nextWp.x, nextWp.y, nextWp.z);
        moveSpeed *= 0.78;
      }

      if (moveTarget) {
        const dx = moveTarget.x - bot.pos.x;
        const dz = moveTarget.z - bot.pos.z;
        const dist = Math.hypot(dx, dz);
        if (dist > 0.4) {
          let dirX = dx / dist;
          let dirZ = dz / dist;

          // Simple obstacle-avoidance whisker steering so bots navigate smoothly around boxes
          const probe = { x: bot.pos.x + dirX * 1.3, y: bot.pos.y + 0.9, z: bot.pos.z + dirZ * 1.3 };
          for (const box of MAP_COLLIDERS) {
            if (intersectSegmentAABB({ x: bot.pos.x, y: bot.pos.y + 0.9, z: bot.pos.z }, probe, box) !== null) {
              const side = bot.strafePhase >= 0 ? 1 : -1;
              const rx = -dirZ * side;
              const rz = dirX * side;
              dirX = dirX * 0.35 + rx * 0.85;
              dirZ = dirZ * 0.35 + rz * 0.85;
              const n = Math.hypot(dirX, dirZ) || 1;
              dirX /= n;
              dirZ /= n;
              break;
            }
          }

          bot.vel.x = THREE.MathUtils.damp(bot.vel.x, dirX * moveSpeed, 8, dt);
          bot.vel.z = THREE.MathUtils.damp(bot.vel.z, dirZ * moveSpeed, 8, dt);
          const targetYaw = Math.atan2(dirX, dirZ);
          bot.yaw = this.lerpAngle(bot.yaw, targetYaw, 1 - Math.exp(-8 * dt));
        } else {
          bot.vel.x *= 0.8;
          bot.vel.z *= 0.8;
        }
      }

      // Integrate bot physics & collision
      bot.vel.y -= 17.5 * dt;
      const nextBotPos = resolveHorizontalCollision(
        { x: bot.pos.x + bot.vel.x * dt, y: bot.pos.y, z: bot.pos.z + bot.vel.z * dt },
        0.45,
        1.8,
        MAP_COLLIDERS,
      );
      bot.pos.x = nextBotPos.x;
      bot.pos.z = nextBotPos.z;
      bot.pos.y += bot.vel.y * dt;
      const floorY = getSupportFloorY(bot.pos.x, bot.pos.z, bot.pos.y, 0.45, MAP_COLLIDERS);
      if (bot.pos.y <= floorY) {
        bot.pos.y = floorY;
        bot.vel.y = 0;
      }

      // Sync articulated rig + distance-based gait animation
      bot.rig.root.position.copy(bot.pos);
      bot.rig.root.rotation.y = bot.yaw;
      const speed = Math.hypot(bot.vel.x, bot.vel.z);
      bot.walkDist += speed * dt * 3.2;
      const swing = Math.sin(bot.walkDist) * Math.min(0.6, speed * 0.14);
      bot.rig.legL.rotation.x = swing;
      bot.rig.legR.rotation.x = -swing;
    }
  }

  private fireBotWeapon(bot: ActiveBot, aimErrorRad: number, headshotChance: number): void {
    const spec = WEAPONS[bot.weaponId];
    bot.ammoInMag = Math.max(0, bot.ammoInMag - 1);
    bot.fireCooldown = bot.archetype === 'sniper' ? 1.55 : 60 / spec.fireRateRpm + Math.random() * 0.08;

    const muzzlePos = new THREE.Vector3();
    bot.rig.muzzlePoint.getWorldPosition(muzzlePos);

    const dist = muzzlePos.distanceTo(this.playerPos);
    const atten = Math.max(0.15, 1 - dist / 45);
    tacticalAudio.playGunshot(bot.weaponId, atten * 0.65);

    const targetCenter = new THREE.Vector3(this.playerPos.x, this.playerPos.y + 1.4, this.playerPos.z);
    const dir = targetCenter.sub(muzzlePos).normalize();
    dir.x += (Math.random() - 0.5) * aimErrorRad * 2;
    dir.y += (Math.random() - 0.5) * aimErrorRad * 2;
    dir.z += (Math.random() - 0.5) * aimErrorRad * 2;
    dir.normalize();

    const endPt = new THREE.Vector3().copy(muzzlePos).addScaledVector(dir, 50);

    // Distance from ray to player capsule center
    const playerEye = new THREE.Vector3(this.playerPos.x, this.playerPos.y + 1.35, this.playerPos.z);
    const toPlayer = new THREE.Vector3().subVectors(playerEye, muzzlePos);
    const proj = toPlayer.dot(dir);

    let hitPlayer = false;
    if (proj > 0 && proj < 55) {
      const closest = new THREE.Vector3().copy(muzzlePos).addScaledVector(dir, proj);
      const perpDist = closest.distanceTo(playerEye);
      if (perpDist < 0.48 && this.hasLineOfSight(muzzlePos, closest)) {
        hitPlayer = true;
        endPt.copy(closest);
        const isHead = Math.random() < headshotChance;
        const baseDmg = bot.archetype === 'sniper' ? 48 : 16;
        this.applyPlayerDamage(isHead ? Math.round(baseDmg * 1.65) : baseDmg);
      }
    }

    if (!hitPlayer) {
      for (const box of MAP_COLLIDERS) {
        const t = intersectSegmentAABB(muzzlePos, endPt, box);
        if (t !== null) {
          endPt.copy(muzzlePos).lerp(endPt, t);
          break;
        }
      }
    }

    this.spawnTracer(muzzlePos, endPt);
  }

  private updateGrenades(dt: number): void {
    for (const g of this.grenades) {
      if (!g.active) continue;
      g.fuse -= dt;
      g.vel.y -= 16.5 * dt;

      const nextX = g.pos.x + g.vel.x * dt;
      const nextZ = g.pos.z + g.vel.z * dt;
      const hitWall = resolveHorizontalCollision(
        { x: nextX, y: g.pos.y, z: nextZ },
        0.12,
        0.24,
        MAP_COLLIDERS,
      );
      if (Math.abs(hitWall.x - nextX) > 0.001) {
        g.vel.x *= -0.52;
        tacticalAudio.playGrenadeBounce();
      }
      if (Math.abs(hitWall.z - nextZ) > 0.001) {
        g.vel.z *= -0.52;
        tacticalAudio.playGrenadeBounce();
      }
      g.pos.x = hitWall.x;
      g.pos.z = hitWall.z;

      g.pos.y += g.vel.y * dt;
      const floorY = getSupportFloorY(g.pos.x, g.pos.z, g.pos.y, 0.12, MAP_COLLIDERS, 0.1) + 0.08;
      if (g.pos.y <= floorY) {
        g.pos.y = floorY;
        if (Math.abs(g.vel.y) > 1.2) {
          g.vel.y = -g.vel.y * 0.45;
          g.vel.x *= 0.72;
          g.vel.z *= 0.72;
          tacticalAudio.playGrenadeBounce();
        } else {
          g.vel.y = 0;
          g.vel.x *= 0.85;
          g.vel.z *= 0.85;
        }
      }

      g.mesh.position.copy(g.pos);
      g.mesh.rotation.x += dt * 7;
      g.mesh.rotation.z += dt * 5;

      if (g.fuse <= 0) {
        this.detonateGrenade(g);
      }
    }
    this.grenades = this.grenades.filter((g) => g.active);
  }

  private updateEffects(dt: number): void {
    if (this.muzzleFlashTimer > 0) {
      this.muzzleFlashTimer -= dt;
      if (this.muzzleFlashTimer <= 0) this.muzzleFlashMesh.visible = false;
    }

    for (const t of this.tracerPool) {
      if (t.life > 0) {
        t.life -= dt;
        t.mat.opacity = Math.max(0, t.life / t.maxLife);
        if (t.life <= 0) t.line.visible = false;
      }
    }

    let anyParticleUpdated = false;
    for (let i = 0; i < this.particles.length; i++) {
      const p = this.particles[i];
      if (!p.active) continue;
      anyParticleUpdated = true;
      p.life -= dt;
      if (p.life <= 0) {
        p.active = false;
        _mat4.makeScale(0, 0, 0);
        this.particleMesh.setMatrixAt(i, _mat4);
        continue;
      }
      p.vel.y -= 11 * dt;
      p.pos.addScaledVector(p.vel, dt);
      const s = p.scale * (p.life / p.maxLife);
      _quat.identity();
      _v4.set(s, s, s);
      _mat4.compose(p.pos, _quat, _v4);
      this.particleMesh.setMatrixAt(i, _mat4);
    }
    if (anyParticleUpdated) {
      this.particleMesh.instanceMatrix.needsUpdate = true;
    }

    this.cameraTrauma = Math.max(0, this.cameraTrauma - dt * 1.8);
    this.flashAlpha = Math.max(0, this.flashAlpha - dt * 0.55);
    this.damageFlashAlpha = Math.max(0, this.damageFlashAlpha - dt * 1.9);
    if (this.hitmarkerTimer > 0) {
      this.hitmarkerTimer -= dt;
      if (this.hitmarkerTimer <= 0) this.hitmarkerType = 'none';
    }
    if (this.roundBannerTimer > 0) {
      this.roundBannerTimer -= dt;
      if (this.roundBannerTimer <= 0) this.roundBanner = null;
    }
  }

  private lerpAngle(a: number, b: number, t: number): number {
    let diff = b - a;
    while (diff < -Math.PI) diff += Math.PI * 2;
    while (diff > Math.PI) diff -= Math.PI * 2;
    return a + diff * t;
  }

  private tick = () => {
    if (this.disposed) return;

    const now = performance.now();
    const rawDt = (now - this.lastTime) / 1000;
    this.lastTime = now;
    const dt = Math.min(rawDt, 0.05);
    this.elapsed += dt;

    if (this.phase === 'title') {
      // Live atmospheric spline flyover of the Dust compound
      const t = this.elapsed * 0.22 + 0.55;
      this.camera.position.set(Math.sin(t) * 24, 9.5 + Math.sin(t * 1.4) * 1.6, Math.cos(t) * 26);
      this.camera.lookAt(0, 1.8, -4);
      this.updateBots(dt, 'patrol_only');
      this.updateEffects(dt);
    } else if (this.phase === 'playing') {
      if (this.hitstopTimer > 0) {
        this.hitstopTimer -= dt;
        this.updateEffects(dt);
      } else {
        this.updatePlayer(dt);
        this.updateBots(dt, 'combat');
        this.updateGrenades(dt);
        this.updateEffects(dt);
      }

      if (this.roundPendingState !== 'none') {
        this.roundEndDelay -= dt;
        if (this.roundEndDelay <= 0) {
          const matchOver =
            this.playerScore >= 3 || this.botScore >= 3 || this.round >= this.maxRounds;
          if (matchOver) {
            this.setPhase('gameover');
          } else {
            this.round += 1;
            this.resetRoundState(`ROUND ${this.round} · DEPLOY`);
          }
        }
      }

      this.justPressed.clear();
      this.mouseJustPressed = false;

      this.hudSyncTimer += dt;
      if (this.hudSyncTimer >= 0.065) {
        this.hudSyncTimer = 0;
        this.pushHudSnapshot();
      }
    }

    this.renderer.render(this.scene, this.camera);

    if (this.isSoftwareGl) {
      this.afterDraw(() => {
        if (!this.disposed) {
          this.frameId = requestAnimationFrame(this.tick);
        }
      });
    } else {
      this.frameId = requestAnimationFrame(this.tick);
    }
  };

  private afterDraw(cb: () => void): void {
    const gl = this.renderer.getContext() as WebGL2RenderingContext;
    const sync = gl.fenceSync(gl.SYNC_GPU_COMMANDS_COMPLETE, 0);
    gl.flush();
    const poll = () => {
      if (this.disposed) {
        if (sync) gl.deleteSync(sync);
        return;
      }
      const state = sync && gl.getSyncParameter(sync, gl.SYNC_STATUS);
      if (state === gl.UNSIGNALED) {
        this.frameId = window.setTimeout(poll, 5);
      } else {
        if (sync) gl.deleteSync(sync);
        this.frameId = window.setTimeout(cb, 80);
      }
    };
    this.frameId = window.setTimeout(poll, 5);
  }

  public pushHudSnapshot(): void {
    const activeInst = this.slots[this.activeSlot];
    const activeId = activeInst ? activeInst.id : 'karambit';
    const spec = WEAPONS[activeId];
    const hSpeed = Math.hypot(this.playerVel.x, this.playerVel.z);
    const spread = computeDynamicSpread({
      weaponId: activeId,
      horizontalSpeed: hSpeed,
      isGrounded: this.playerGrounded,
      isCrouching: this.keys.has('ControlLeft') || this.keys.has('KeyC'),
      isScoped: this.isScoped,
      recoilBloom: this.recoilBloom,
    });

    const radarBlips: RadarBlip[] = this.bots
      .filter((b) => b.state !== 'KO')
      .map((b) => ({
        id: b.id,
        x: b.pos.x,
        z: b.pos.z,
        type: 'bot',
        state: b.state,
      }));

    const slotSummary: HudSnapshot['slots'] = {
      1: this.slots[1]
        ? { id: this.slots[1].id, name: WEAPONS[this.slots[1].id].shortName, ammo: this.slots[1].ammoInMag, reserve: this.slots[1].reserveAmmo }
        : null,
      2: this.slots[2]
        ? { id: this.slots[2].id, name: WEAPONS[this.slots[2].id].shortName, ammo: this.slots[2].ammoInMag, reserve: this.slots[2].reserveAmmo }
        : null,
      3: { id: 'karambit', name: 'KNIFE', ammo: 0, reserve: 0 },
      4: this.heCount > 0 ? { id: 'he_grenade', name: 'HE', ammo: this.heCount, reserve: 0 } : null,
      5: this.flashCount > 0 ? { id: 'flashbang', name: 'FLASH', ammo: this.flashCount, reserve: 0 } : null,
    };

    this.onHudUpdate({
      hp: Math.round(this.playerHp),
      armor: Math.round(this.playerArmor),
      hasHelmet: this.playerHasHelmet,
      cash: Math.round(this.playerCash),
      round: this.round,
      maxRounds: this.maxRounds,
      playerScore: this.playerScore,
      botScore: this.botScore,
      botsAlive: this.bots.filter((b) => b.state !== 'KO').length,
      totalBots: this.bots.length,
      activeSlot: this.activeSlot,
      activeWeaponId: activeId,
      activeWeaponName: spec.name,
      ammoInMag: activeInst ? activeInst.ammoInMag : 0,
      reserveAmmo: activeInst ? activeInst.reserveAmmo : 0,
      isReloading: this.isReloading,
      reloadProgress: this.isReloading ? 1 - this.reloadTimer / Math.max(0.1, spec.reloadTime) : 0,
      isScoped: this.isScoped,
      crosshairSpread: spread,
      flashAlpha: this.flashAlpha,
      damageFlashAlpha: this.damageFlashAlpha,
      hitmarkerType: this.hitmarkerType,
      heCount: this.heCount,
      flashCount: this.flashCount,
      slots: slotSummary,
      kills: this.kills,
      headshots: this.headshots,
      shotsFired: this.shotsFired,
      shotsHit: this.shotsHit,
      damageDealt: this.damageDealt,
      roundBanner: this.roundBanner,
      killfeed: this.killfeed,
      radarBlips,
      playerX: this.playerPos.x,
      playerZ: this.playerPos.z,
      playerYaw: this.playerYaw,
      pointerLocked: this.pointerLocked,
      isVictory: this.playerScore >= this.botScore,
      difficulty: this.difficulty,
    });
  }

  private handleResize(): void {
    const w = this.container.clientWidth || window.innerWidth;
    const h = this.container.clientHeight || window.innerHeight;
    this.camera.aspect = w / Math.max(1, h);
    this.camera.updateProjectionMatrix();
    this.renderer.setSize(w, h);
    this.renderer.render(this.scene, this.camera);
  }

  public dispose(): void {
    this.disposed = true;
    cancelAnimationFrame(this.frameId);
    clearTimeout(this.frameId);
    this.resizeObserver.disconnect();
    window.removeEventListener('keydown', this.handleKeyDown);
    window.removeEventListener('keyup', this.handleKeyUp);
    window.removeEventListener('blur', this.handleBlur);
    document.removeEventListener('visibilitychange', this.handleBlur);
    document.removeEventListener('pointerlockchange', this.handlePointerLockChange);
    const canvas = this.renderer.domElement;
    canvas.removeEventListener('mousedown', this.handleMouseDown);
    window.removeEventListener('mouseup', this.handleMouseUp);
    window.removeEventListener('mousemove', this.handleMouseMove);
    canvas.removeEventListener('contextmenu', this.handleContextMenu);
    this.textures.dispose();
    this.renderer.dispose();
    if (canvas.parentElement === this.container) {
      this.container.removeChild(canvas);
    }
  }
}
