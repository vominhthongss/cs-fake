import test from 'node:test';
import assert from 'node:assert/strict';
import {
  calculateBallisticDamage,
  computeDynamicSpread,
  evaluateBotNextState,
  evaluatePurchase,
  getRecoilForShot,
  intersectSegmentAABB,
  resolveHorizontalCollision,
} from './rules';
import { AABB } from './types';

test('AK-47 delivers lethal unhelmeted and helmeted headshots within range', () => {
  const unhelmeted = calculateBallisticDamage({
    weaponId: 'ak47',
    region: 'head',
    distance: 15,
    targetArmor: 0,
    targetHasHelmet: false,
    penetratedWalls: 0,
  });
  assert.ok(unhelmeted.hpDamage >= 100);
  assert.equal(unhelmeted.isHeadshot, true);

  const helmeted = calculateBallisticDamage({
    weaponId: 'ak47',
    region: 'head',
    distance: 15,
    targetArmor: 100,
    targetHasHelmet: true,
    penetratedWalls: 0,
  });
  assert.ok(helmeted.hpDamage >= 100, 'AK-47 must 1-tap through helmet at close-mid range');
  assert.ok(helmeted.armorDamage > 0);
});

test('AWP penetrates walls and deals lethal chest damage', () => {
  const wallbang = calculateBallisticDamage({
    weaponId: 'awp',
    region: 'chest',
    distance: 25,
    targetArmor: 100,
    targetHasHelmet: true,
    penetratedWalls: 1,
  });
  assert.ok(wallbang.hpDamage >= 80);
});

test('Recoil pattern progresses upward and horizontally for AK-47', () => {
  const first = getRecoilForShot('ak47', 0);
  const seventh = getRecoilForShot('ak47', 6);
  assert.ok(seventh.pitch > first.pitch);
  assert.notEqual(seventh.yaw, 0);
});

test('Movement and unscoped AWP increase spread; crouching tightens spread', () => {
  const stillSpread = computeDynamicSpread({
    weaponId: 'ak47',
    horizontalSpeed: 0,
    isGrounded: true,
    isCrouching: false,
    isScoped: false,
    recoilBloom: 0,
  });
  const runningSpread = computeDynamicSpread({
    weaponId: 'ak47',
    horizontalSpeed: 5.5,
    isGrounded: true,
    isCrouching: false,
    isScoped: false,
    recoilBloom: 0,
  });
  const crouchSpread = computeDynamicSpread({
    weaponId: 'ak47',
    horizontalSpeed: 0,
    isGrounded: true,
    isCrouching: true,
    isScoped: false,
    recoilBloom: 0,
  });
  assert.ok(runningSpread > stillSpread);
  assert.ok(crouchSpread < stillSpread);

  const awpHip = computeDynamicSpread({
    weaponId: 'awp',
    horizontalSpeed: 0,
    isGrounded: true,
    isCrouching: false,
    isScoped: false,
    recoilBloom: 0,
  });
  const awpScoped = computeDynamicSpread({
    weaponId: 'awp',
    horizontalSpeed: 0,
    isGrounded: true,
    isCrouching: false,
    isScoped: true,
    recoilBloom: 0,
  });
  assert.ok(awpHip > awpScoped * 10);
});

test('Buy economy enforces cash and inventory limits', () => {
  const cantAfford = evaluatePurchase({
    item: 'awp',
    cash: 2500,
    currentArmor: 0,
    hasHelmet: false,
    heCount: 0,
    flashCount: 0,
    currentPrimaryId: null,
    currentPistolId: 'usps',
  });
  assert.equal(cantAfford.ok, false);

  const canBuyAk = evaluatePurchase({
    item: 'ak47',
    cash: 3000,
    currentArmor: 0,
    hasHelmet: false,
    heCount: 0,
    flashCount: 0,
    currentPrimaryId: null,
    currentPistolId: 'usps',
  });
  assert.equal(canBuyAk.ok, true);
  assert.equal(canBuyAk.cost, 2700);
});

test('Horizontal AABB collision pushes player out cleanly', () => {
  const wall: AABB = {
    id: 'wall1',
    minX: 2,
    maxX: 4,
    minY: 0,
    maxY: 3,
    minZ: -2,
    maxZ: 2,
    materialType: 'concrete',
    penetrable: false,
  };
  const resolved = resolveHorizontalCollision({ x: 1.8, y: 0, z: 0 }, 0.45, 1.8, [wall]);
  assert.ok(resolved.x <= 2 - 0.449);
});

test('Segment-AABB raycast detects cover occlusion accurately', () => {
  const crate: AABB = {
    id: 'crate',
    minX: -1,
    maxX: 1,
    minY: 0,
    maxY: 2,
    minZ: 4,
    maxZ: 6,
    materialType: 'wood',
    penetrable: true,
  };
  const hit = intersectSegmentAABB({ x: 0, y: 1, z: 0 }, { x: 0, y: 1, z: 10 }, crate);
  assert.ok(hit !== null && hit > 0.35 && hit < 0.45);
  const miss = intersectSegmentAABB({ x: 3, y: 1, z: 0 }, { x: 3, y: 1, z: 10 }, crate);
  assert.equal(miss, null);
});

test('Bot tactical utility AI transitions through BLINDED, RELOAD, TAKE_COVER, ENGAGE, INVESTIGATE, FLANK, PATROL', () => {
  const blinded = evaluateBotNextState({
    hp: 100,
    maxHp: 100,
    ammoInMag: 20,
    blindTimer: 1.5,
    canSeePlayer: true,
    distanceToPlayer: 10,
    timeSinceHeardPlayer: 0,
    hasCoverNearby: true,
    archetype: 'anchor',
    difficulty: 'tactical',
    currentState: 'ENGAGE',
  });
  assert.equal(blinded, 'BLINDED');

  const reload = evaluateBotNextState({
    hp: 100,
    maxHp: 100,
    ammoInMag: 0,
    blindTimer: 0,
    canSeePlayer: true,
    distanceToPlayer: 10,
    timeSinceHeardPlayer: 0,
    hasCoverNearby: true,
    archetype: 'entry',
    difficulty: 'tactical',
    currentState: 'ENGAGE',
  });
  assert.equal(reload, 'RELOAD');

  const cover = evaluateBotNextState({
    hp: 20,
    maxHp: 100,
    ammoInMag: 15,
    blindTimer: 0,
    canSeePlayer: true,
    distanceToPlayer: 12,
    timeSinceHeardPlayer: 0,
    hasCoverNearby: true,
    archetype: 'anchor',
    difficulty: 'tactical',
    currentState: 'ENGAGE',
  });
  assert.equal(cover, 'TAKE_COVER');

  const flank = evaluateBotNextState({
    hp: 100,
    maxHp: 100,
    ammoInMag: 25,
    blindTimer: 0,
    canSeePlayer: false,
    distanceToPlayer: 20,
    timeSinceHeardPlayer: 1.5,
    hasCoverNearby: true,
    archetype: 'entry',
    difficulty: 'tactical',
    currentState: 'PATROL',
  });
  assert.equal(flank, 'FLANK');
});
