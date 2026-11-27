import {
  AABB,
  BotAIState,
  BotArchetype,
  BotDifficulty,
  RecoilPoint,
  Vec3,
  WEAPONS,
  WeaponId,
  WeaponInstance,
} from './types';

export type HitRegion = 'head' | 'chest' | 'limb';

export interface DamageResult {
  hpDamage: number;
  armorDamage: number;
  isHeadshot: boolean;
}

/**
 * Computes CS:GO-inspired ballistic damage with hit region, armor absorption,
 * distance falloff, and wall penetration scaling.
 */
export function calculateBallisticDamage(params: {
  weaponId: WeaponId;
  region: HitRegion;
  distance: number;
  targetArmor: number;
  targetHasHelmet: boolean;
  penetratedWalls: number;
}): DamageResult {
  const spec = WEAPONS[params.weaponId];
  let base = spec.damage;

  if (params.region === 'head') {
    base *= spec.headshotMultiplier;
  } else if (params.region === 'limb') {
    base *= 0.75;
  }

  // Distance falloff (slight for rifles, sharp for shotguns/SMGs)
  const falloffRate =
    spec.category === 'shotgun'
      ? 0.032
      : spec.category === 'smg'
        ? 0.011
        : spec.category === 'sniper'
          ? 0.001
          : 0.0035;
  const distFactor = Math.max(0.25, 1 - Math.max(0, params.distance - 8) * falloffRate);
  base *= distFactor;

  // Wallbang penetration reduction
  for (let i = 0; i < params.penetratedWalls; i++) {
    base *= spec.wallPenetration;
  }

  const isHeadshot = params.region === 'head';
  const protectedByArmor =
    params.targetArmor > 0 && (isHeadshot ? params.targetHasHelmet : params.region === 'chest');

  if (!protectedByArmor) {
    return {
      hpDamage: Math.max(1, Math.round(base)),
      armorDamage: 0,
      isHeadshot,
    };
  }

  const hpDamage = Math.max(1, Math.round(base * spec.armorPenetration));
  const absorbed = Math.max(0, base - hpDamage);
  const armorDamage = Math.min(params.targetArmor, Math.max(1, Math.round(absorbed * 0.55)));

  return {
    hpDamage,
    armorDamage,
    isHeadshot,
  };
}

/**
 * Returns cumulative spray/recoil offset for the nth consecutive shot in a burst.
 */
export function getRecoilForShot(weaponId: WeaponId, shotIndex: number): RecoilPoint {
  const pattern = WEAPONS[weaponId].recoilPattern;
  if (pattern.length === 0) return { pitch: 0, yaw: 0 };
  const idx = Math.min(shotIndex, pattern.length - 1);
  return pattern[idx];
}

/**
 * Computes effective spread in radians given movement speed, crouch, air state, and scope.
 */
export function computeDynamicSpread(params: {
  weaponId: WeaponId;
  horizontalSpeed: number;
  isGrounded: boolean;
  isCrouching: boolean;
  isScoped: boolean;
  recoilBloom: number;
}): number {
  const spec = WEAPONS[params.weaponId];
  let spread = spec.baseSpread;

  if (spec.canScope && !params.isScoped) {
    // Unscoped AWP hip-fire inaccuracy
    spread += 0.042;
  }

  spread += params.horizontalSpeed * spec.moveSpreadFactor;
  if (!params.isGrounded) {
    spread += 0.055;
  }
  if (params.isCrouching) {
    spread *= 0.72;
  }
  spread += params.recoilBloom * 0.015;
  return spread;
}

/**
 * Evaluates a buy request for weapons or armor.
 */
export function evaluatePurchase(params: {
  item: WeaponId | 'kevlar_helmet';
  cash: number;
  currentArmor: number;
  hasHelmet: boolean;
  heCount: number;
  flashCount: number;
  currentPrimaryId: WeaponId | null;
  currentPistolId: WeaponId;
}): {
  ok: boolean;
  cost: number;
  reason?: string;
} {
  if (params.item === 'kevlar_helmet') {
    const cost = params.currentArmor >= 100 && params.hasHelmet ? 0 : params.currentArmor > 0 ? 350 : 1000;
    if (cost === 0) return { ok: false, cost: 0, reason: 'Armor full' };
    if (params.cash < cost) return { ok: false, cost, reason: 'Insufficient funds' };
    return { ok: true, cost };
  }

  const spec = WEAPONS[params.item];
  if (params.item === 'he_grenade' && params.heCount >= 2) {
    return { ok: false, cost: spec.price, reason: 'Max HE grenades' };
  }
  if (params.item === 'flashbang' && params.flashCount >= 2) {
    return { ok: false, cost: spec.price, reason: 'Max flashbangs' };
  }
  if (spec.slot === 1 && params.currentPrimaryId === params.item) {
    return { ok: false, cost: spec.price, reason: 'Already equipped' };
  }
  if (spec.slot === 2 && params.currentPistolId === params.item) {
    return { ok: false, cost: spec.price, reason: 'Already equipped' };
  }
  if (params.cash < spec.price) {
    return { ok: false, cost: spec.price, reason: 'Insufficient funds' };
  }
  return { ok: true, cost: spec.price };
}

export function createWeaponInstance(id: WeaponId): WeaponInstance {
  const spec = WEAPONS[id];
  return {
    id,
    ammoInMag: spec.magazineSize,
    reserveAmmo: spec.reserveMax,
  };
}

/**
 * Resolves circle-vs-AABB collision on the XZ plane for smooth wall sliding.
 */
export function resolveHorizontalCollision(
  pos: Vec3,
  radius: number,
  playerHeight: number,
  colliders: AABB[],
): Vec3 {
  let x = pos.x;
  let z = pos.z;

  for (const box of colliders) {
    // Check vertical overlap
    if (pos.y + playerHeight <= box.minY + 0.05 || pos.y >= box.maxY - 0.05) {
      continue;
    }

    const closestX = Math.max(box.minX, Math.min(x, box.maxX));
    const closestZ = Math.max(box.minZ, Math.min(z, box.maxZ));

    const dx = x - closestX;
    const dz = z - closestZ;
    const distSq = dx * dx + dz * dz;

    if (distSq < radius * radius) {
      const dist = Math.sqrt(distSq);
      if (dist > 0.0001) {
        const push = radius - dist;
        x += (dx / dist) * push;
        z += (dz / dist) * push;
      } else {
        // Center is inside box: push out along shallowest axis
        const penLeft = Math.abs(x - box.minX);
        const penRight = Math.abs(box.maxX - x);
        const penFront = Math.abs(z - box.minZ);
        const penBack = Math.abs(box.maxZ - z);
        const minPen = Math.min(penLeft, penRight, penFront, penBack);
        if (minPen === penLeft) x = box.minX - radius;
        else if (minPen === penRight) x = box.maxX + radius;
        else if (minPen === penFront) z = box.minZ - radius;
        else z = box.maxZ + radius;
      }
    }
  }

  return { x, y: pos.y, z };
}

/**
 * Finds the highest walkable floor Y under (x, z) at current feetY + stepUpHeight.
 */
export function getSupportFloorY(
  x: number,
  z: number,
  feetY: number,
  radius: number,
  colliders: AABB[],
  stepHeight = 0.55,
): number {
  let floorY = 0;
  for (const box of colliders) {
    if (
      x + radius * 0.7 > box.minX &&
      x - radius * 0.7 < box.maxX &&
      z + radius * 0.7 > box.minZ &&
      z - radius * 0.7 < box.maxZ
    ) {
      if (box.maxY <= feetY + stepHeight && box.maxY > floorY) {
        floorY = box.maxY;
      }
    }
  }
  return floorY;
}

export interface BotDecisionInput {
  hp: number;
  maxHp: number;
  ammoInMag: number;
  blindTimer: number;
  canSeePlayer: boolean;
  distanceToPlayer: number;
  timeSinceHeardPlayer: number;
  hasCoverNearby: boolean;
  archetype: BotArchetype;
  difficulty: BotDifficulty;
  currentState: BotAIState;
}

/**
 * Pure Tactical Utility AI state selector used by both the live 3D bots and unit tests.
 */
export function evaluateBotNextState(input: BotDecisionInput): BotAIState {
  if (input.hp <= 0) return 'KO';
  if (input.blindTimer > 0) return 'BLINDED';
  if (input.ammoInMag <= 0) return 'RELOAD';

  const lowHpThreshold =
    input.difficulty === 'elite' ? 0.35 : input.difficulty === 'tactical' ? 0.28 : 0.2;

  // Smart retreat behind cover when wounded and exposed
  if (
    input.hp / input.maxHp <= lowHpThreshold &&
    input.hasCoverNearby &&
    input.canSeePlayer &&
    input.archetype !== 'entry'
  ) {
    return 'TAKE_COVER';
  }

  if (input.canSeePlayer) {
    // Sniper repositions to cover after firing or if player gets too close
    if (input.archetype === 'sniper' && input.distanceToPlayer < 9 && input.hasCoverNearby) {
      return 'FLANK';
    }
    return 'ENGAGE';
  }

  // React to recent player gunfire / footsteps / grenade noise
  const memoryWindow =
    input.difficulty === 'elite' ? 6.0 : input.difficulty === 'tactical' ? 4.2 : 2.5;
  if (input.timeSinceHeardPlayer <= memoryWindow) {
    if (input.archetype === 'entry' && input.distanceToPlayer > 14) {
      return 'FLANK';
    }
    return 'INVESTIGATE';
  }

  return 'PATROL';
}

export interface DifficultyTuning {
  reactionDelay: number;     // seconds before opening fire after spotting player
  aimErrorRad: number;       // angular inaccuracy in radians
  burstLength: number;       // shots per burst
  strafeFrequency: number;   // counter-strafe cadence
  moveSpeed: number;
  botHp: number;
  headshotChance: number;
}

export function getDifficultyTuning(difficulty: BotDifficulty): DifficultyTuning {
  switch (difficulty) {
    case 'recruit':
      return {
        reactionDelay: 0.58,
        aimErrorRad: 0.085,
        burstLength: 3,
        strafeFrequency: 0.7,
        moveSpeed: 3.9,
        botHp: 90,
        headshotChance: 0.08,
      };
    case 'tactical':
      return {
        reactionDelay: 0.34,
        aimErrorRad: 0.045,
        burstLength: 4,
        strafeFrequency: 1.4,
        moveSpeed: 4.5,
        botHp: 100,
        headshotChance: 0.18,
      };
    case 'elite':
      return {
        reactionDelay: 0.19,
        aimErrorRad: 0.022,
        burstLength: 5,
        strafeFrequency: 2.1,
        moveSpeed: 5.0,
        botHp: 110,
        headshotChance: 0.34,
      };
  }
}

/**
 * Checks if a segment (p1 -> p2) intersects an AABB (slab method).
 * Returns normalized t in [0, 1] or null.
 */
export function intersectSegmentAABB(p1: Vec3, p2: Vec3, box: AABB): number | null {
  const dx = p2.x - p1.x;
  const dy = p2.y - p1.y;
  const dz = p2.z - p1.z;

  let tmin = 0;
  let tmax = 1;

  const axes: Array<[number, number, number, number]> = [
    [p1.x, dx, box.minX, box.maxX],
    [p1.y, dy, box.minY, box.maxY],
    [p1.z, dz, box.minZ, box.maxZ],
  ];

  for (const [origin, dir, bmin, bmax] of axes) {
    if (Math.abs(dir) < 1e-8) {
      if (origin < bmin || origin > bmax) return null;
    } else {
      let t1 = (bmin - origin) / dir;
      let t2 = (bmax - origin) / dir;
      if (t1 > t2) {
        const tmp = t1;
        t1 = t2;
        t2 = tmp;
      }
      tmin = Math.max(tmin, t1);
      tmax = Math.min(tmax, t2);
      if (tmin > tmax) return null;
    }
  }

  return tmin;
}
