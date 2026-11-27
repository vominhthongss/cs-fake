export type GamePhase = 'title' | 'playing' | 'paused' | 'gameover';

export type WeaponId =
  | 'ak47'
  | 'm4a1s'
  | 'awp'
  | 'p90'
  | 'nova'
  | 'deagle'
  | 'usps'
  | 'karambit'
  | 'he_grenade'
  | 'flashbang';

export type WeaponSlot = 1 | 2 | 3 | 4 | 5;

export type WeaponCategory = 'rifle' | 'sniper' | 'smg' | 'shotgun' | 'pistol' | 'melee' | 'grenade';

export interface RecoilPoint {
  pitch: number; // upward kick in degrees
  yaw: number;   // horizontal kick in degrees (+right, -left)
}

export interface WeaponSpec {
  id: WeaponId;
  name: string;
  shortName: string;
  category: WeaponCategory;
  slot: WeaponSlot;
  price: number;
  killReward: number;
  damage: number;
  headshotMultiplier: number;
  armorPenetration: number; // 0..1 (portion ignoring Kevlar)
  wallPenetration: number;  // 0..1 (damage retained through thin cover)
  fireRateRpm: number;
  automatic: boolean;
  magazineSize: number;
  reserveMax: number;
  reloadTime: number; // seconds
  moveSpeedMultiplier: number;
  baseSpread: number;      // radians
  moveSpreadFactor: number; // added spread per m/s
  pellets: number;
  range: number;
  canScope: boolean;
  silenced: boolean;
  recoilPattern: RecoilPoint[];
  roleHint: string;
}

export interface WeaponInstance {
  id: WeaponId;
  ammoInMag: number;
  reserveAmmo: number;
}

export type BotDifficulty = 'recruit' | 'tactical' | 'elite';

export type BotArchetype = 'entry' | 'anchor' | 'sniper';

export type BotAIState =
  | 'PATROL'
  | 'INVESTIGATE'
  | 'ENGAGE'
  | 'TAKE_COVER'
  | 'FLANK'
  | 'RELOAD'
  | 'BLINDED'
  | 'KO';

export interface Vec3 {
  x: number;
  y: number;
  z: number;
}

export interface AABB {
  id: string;
  minX: number;
  maxX: number;
  minY: number;
  maxY: number;
  minZ: number;
  maxZ: number;
  materialType: 'concrete' | 'wood' | 'metal' | 'sandbag' | 'cliff';
  penetrable: boolean;
}

export interface KillfeedEntry {
  id: number;
  killer: string;
  victim: string;
  weapon: string;
  headshot: boolean;
  timestamp: number;
}

export interface RadarBlip {
  id: string;
  x: number;
  z: number;
  type: 'bot' | 'sound' | 'grenade';
  state: BotAIState;
}

export interface HudSnapshot {
  hp: number;
  armor: number;
  hasHelmet: boolean;
  cash: number;
  round: number;
  maxRounds: number;
  playerScore: number;
  botScore: number;
  botsAlive: number;
  totalBots: number;
  activeSlot: WeaponSlot;
  activeWeaponId: WeaponId;
  activeWeaponName: string;
  ammoInMag: number;
  reserveAmmo: number;
  isReloading: boolean;
  reloadProgress: number;
  isScoped: boolean;
  crosshairSpread: number;
  flashAlpha: number;
  damageFlashAlpha: number;
  hitmarkerType: 'none' | 'body' | 'head' | 'kill';
  heCount: number;
  flashCount: number;
  slots: Record<WeaponSlot, { id: WeaponId; name: string; ammo: number; reserve: number } | null>;
  kills: number;
  headshots: number;
  shotsFired: number;
  shotsHit: number;
  damageDealt: number;
  roundBanner: string | null;
  killfeed: KillfeedEntry[];
  radarBlips: RadarBlip[];
  playerX: number;
  playerZ: number;
  playerYaw: number;
  pointerLocked: boolean;
  isVictory: boolean;
  difficulty: BotDifficulty;
}

export const WEAPONS: Record<WeaponId, WeaponSpec> = {
  ak47: {
    id: 'ak47',
    name: 'AK-47',
    shortName: 'AK-47',
    category: 'rifle',
    slot: 1,
    price: 2700,
    killReward: 300,
    damage: 36,
    headshotMultiplier: 3.9,
    armorPenetration: 0.775,
    wallPenetration: 0.6,
    fireRateRpm: 600,
    automatic: true,
    magazineSize: 30,
    reserveMax: 90,
    reloadTime: 2.4,
    moveSpeedMultiplier: 0.88,
    baseSpread: 0.004,
    moveSpreadFactor: 0.011,
    pellets: 1,
    range: 120,
    canScope: false,
    silenced: false,
    roleHint: '1-Tap Headshot · Heavy 7-Pattern',
    recoilPattern: [
      { pitch: 0.6, yaw: 0.0 },
      { pitch: 1.1, yaw: 0.1 },
      { pitch: 1.5, yaw: -0.2 },
      { pitch: 1.8, yaw: 0.3 },
      { pitch: 1.9, yaw: -0.4 },
      { pitch: 1.7, yaw: 0.7 },
      { pitch: 1.4, yaw: 1.3 },
      { pitch: 1.1, yaw: 1.5 },
      { pitch: 0.8, yaw: -1.2 },
      { pitch: 0.6, yaw: -1.8 },
      { pitch: 0.5, yaw: -1.6 },
      { pitch: 0.5, yaw: 1.4 },
    ],
  },
  m4a1s: {
    id: 'm4a1s',
    name: 'M4A1-S',
    shortName: 'M4A1-S',
    category: 'rifle',
    slot: 1,
    price: 2900,
    killReward: 300,
    damage: 33,
    headshotMultiplier: 3.2,
    armorPenetration: 0.7,
    wallPenetration: 0.5,
    fireRateRpm: 600,
    automatic: true,
    magazineSize: 20,
    reserveMax: 80,
    reloadTime: 2.2,
    moveSpeedMultiplier: 0.9,
    baseSpread: 0.0025,
    moveSpreadFactor: 0.0085,
    pellets: 1,
    range: 120,
    canScope: false,
    silenced: true,
    roleHint: 'Suppressed Precision · Tight Spray',
    recoilPattern: [
      { pitch: 0.45, yaw: 0.0 },
      { pitch: 0.75, yaw: -0.1 },
      { pitch: 0.95, yaw: 0.15 },
      { pitch: 1.1, yaw: -0.2 },
      { pitch: 1.15, yaw: 0.35 },
      { pitch: 1.0, yaw: 0.6 },
      { pitch: 0.8, yaw: -0.7 },
      { pitch: 0.6, yaw: -0.8 },
      { pitch: 0.4, yaw: 0.7 },
    ],
  },
  awp: {
    id: 'awp',
    name: 'AWP',
    shortName: 'AWP',
    category: 'sniper',
    slot: 1,
    price: 4750,
    killReward: 100,
    damage: 115,
    headshotMultiplier: 4.0,
    armorPenetration: 0.975,
    wallPenetration: 0.82,
    fireRateRpm: 41,
    automatic: false,
    magazineSize: 5,
    reserveMax: 30,
    reloadTime: 3.2,
    moveSpeedMultiplier: 0.8,
    baseSpread: 0.0006,
    moveSpreadFactor: 0.025,
    pellets: 1,
    range: 180,
    canScope: true,
    silenced: false,
    roleHint: 'RMB Scope · 1-Shot Torso/Head',
    recoilPattern: [{ pitch: 3.6, yaw: 0.3 }],
  },
  p90: {
    id: 'p90',
    name: 'P90',
    shortName: 'P90',
    category: 'smg',
    slot: 1,
    price: 2350,
    killReward: 300,
    damage: 25,
    headshotMultiplier: 3.0,
    armorPenetration: 0.69,
    wallPenetration: 0.35,
    fireRateRpm: 857,
    automatic: true,
    magazineSize: 50,
    reserveMax: 100,
    reloadTime: 2.6,
    moveSpeedMultiplier: 0.96,
    baseSpread: 0.011,
    moveSpreadFactor: 0.0045,
    pellets: 1,
    range: 85,
    canScope: false,
    silenced: false,
    roleHint: '50-Rd Rush SMG · High Mobility',
    recoilPattern: [
      { pitch: 0.35, yaw: 0.1 },
      { pitch: 0.55, yaw: -0.2 },
      { pitch: 0.7, yaw: 0.3 },
      { pitch: 0.85, yaw: -0.4 },
      { pitch: 0.9, yaw: 0.5 },
      { pitch: 0.7, yaw: 0.8 },
      { pitch: 0.6, yaw: -0.9 },
    ],
  },
  nova: {
    id: 'nova',
    name: 'Nova',
    shortName: 'NOVA',
    category: 'shotgun',
    slot: 1,
    price: 1050,
    killReward: 900,
    damage: 22,
    headshotMultiplier: 2.2,
    armorPenetration: 0.5,
    wallPenetration: 0.2,
    fireRateRpm: 68,
    automatic: false,
    magazineSize: 8,
    reserveMax: 32,
    reloadTime: 2.2,
    moveSpeedMultiplier: 0.91,
    baseSpread: 0.048,
    moveSpreadFactor: 0.005,
    pellets: 8,
    range: 42,
    canScope: false,
    silenced: false,
    roleHint: '8-Pellet Buckshot · $900 Kill Bonus',
    recoilPattern: [{ pitch: 2.8, yaw: 0.2 }],
  },
  deagle: {
    id: 'deagle',
    name: 'Desert Eagle',
    shortName: 'DEAGLE',
    category: 'pistol',
    slot: 2,
    price: 700,
    killReward: 300,
    damage: 58,
    headshotMultiplier: 3.8,
    armorPenetration: 0.93,
    wallPenetration: 0.65,
    fireRateRpm: 240,
    automatic: false,
    magazineSize: 7,
    reserveMax: 35,
    reloadTime: 2.0,
    moveSpeedMultiplier: 0.95,
    baseSpread: 0.003,
    moveSpreadFactor: 0.012,
    pellets: 1,
    range: 100,
    canScope: false,
    silenced: false,
    roleHint: '.50 AE Hand Cannon · 1-Tap Head',
    recoilPattern: [
      { pitch: 2.2, yaw: 0.2 },
      { pitch: 2.6, yaw: -0.4 },
      { pitch: 2.8, yaw: 0.5 },
    ],
  },
  usps: {
    id: 'usps',
    name: 'USP-S',
    shortName: 'USP-S',
    category: 'pistol',
    slot: 2,
    price: 200,
    killReward: 300,
    damage: 32,
    headshotMultiplier: 3.8,
    armorPenetration: 0.505,
    wallPenetration: 0.25,
    fireRateRpm: 350,
    automatic: false,
    magazineSize: 12,
    reserveMax: 24,
    reloadTime: 1.9,
    moveSpeedMultiplier: 0.98,
    baseSpread: 0.0025,
    moveSpreadFactor: 0.006,
    pellets: 1,
    range: 90,
    canScope: false,
    silenced: true,
    roleHint: 'Silenced Sidearm · Crisp Accuracy',
    recoilPattern: [
      { pitch: 0.8, yaw: 0.05 },
      { pitch: 1.0, yaw: -0.1 },
    ],
  },
  karambit: {
    id: 'karambit',
    name: 'Karambit',
    shortName: 'KNIFE',
    category: 'melee',
    slot: 3,
    price: 0,
    killReward: 1500,
    damage: 55,
    headshotMultiplier: 1.5,
    armorPenetration: 0.85,
    wallPenetration: 0,
    fireRateRpm: 120,
    automatic: false,
    magazineSize: 0,
    reserveMax: 0,
    reloadTime: 0,
    moveSpeedMultiplier: 1.15,
    baseSpread: 0,
    moveSpreadFactor: 0,
    pellets: 1,
    range: 2.6,
    canScope: false,
    silenced: true,
    roleHint: '+15% Sprint Speed · $1500 Bonus',
    recoilPattern: [{ pitch: 0.2, yaw: -0.3 }],
  },
  he_grenade: {
    id: 'he_grenade',
    name: 'HE Grenade',
    shortName: 'HE FRAG',
    category: 'grenade',
    slot: 4,
    price: 300,
    killReward: 300,
    damage: 98,
    headshotMultiplier: 1.0,
    armorPenetration: 0.65,
    wallPenetration: 0,
    fireRateRpm: 60,
    automatic: false,
    magazineSize: 1,
    reserveMax: 0,
    reloadTime: 0,
    moveSpeedMultiplier: 1.0,
    baseSpread: 0,
    moveSpreadFactor: 0,
    pellets: 1,
    range: 8.5,
    canScope: false,
    silenced: false,
    roleHint: 'Bouncing Frag · Radial Blast',
    recoilPattern: [],
  },
  flashbang: {
    id: 'flashbang',
    name: 'Flashbang',
    shortName: 'FLASH',
    category: 'grenade',
    slot: 5,
    price: 200,
    killReward: 0,
    damage: 0,
    headshotMultiplier: 1.0,
    armorPenetration: 0,
    wallPenetration: 0,
    fireRateRpm: 60,
    automatic: false,
    magazineSize: 1,
    reserveMax: 0,
    reloadTime: 0,
    moveSpeedMultiplier: 1.0,
    baseSpread: 0,
    moveSpreadFactor: 0,
    pellets: 1,
    range: 16,
    canScope: false,
    silenced: false,
    roleHint: 'Tactical Blind · Stuns Bots',
    recoilPattern: [],
  },
};

export const BUYABLE_WEAPON_IDS: WeaponId[] = [
  'ak47',
  'm4a1s',
  'awp',
  'p90',
  'nova',
  'deagle',
  'he_grenade',
  'flashbang',
];
