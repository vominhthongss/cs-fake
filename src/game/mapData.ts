import { AABB, BotArchetype, Vec3 } from './types';

export interface MapPropSpec {
  id: string;
  kind: 'wall' | 'crate' | 'container' | 'sandbag' | 'barrel' | 'arch' | 'ramp_block';
  x: number;
  y: number; // bottom Y
  z: number;
  w: number;
  h: number;
  d: number;
  penetrable: boolean;
  tint?: number;
}

export interface BotSpawnSpec {
  id: string;
  pos: Vec3;
  archetype: BotArchetype;
  patrolRoute: Vec3[];
}

export const MAP_HALF_SIZE = 34;

export const PLAYER_SPAWN: Vec3 = { x: 0, y: 0, z: 24 };
export const PLAYER_SPAWN_YAW = 0; // Facing -Z (north toward Mid archway & Bombsite vista)

/**
 * Tactical multi-lane Dust/Mirage-inspired compound:
 * - South (Z = +24): Player CT/Spawn Courtyard with clear sightline down Mid
 * - Center (Z = +6 .. -10): Mid Archway, Mid Window/Boxes, Connector lanes
 * - West (X = -16 .. -26): A-Site Shipping Yard & Elevated Catwalk
 * - East (X = +16 .. +26): B-Site Crate Compound & Ramp
 * - North (Z = -24): T/Bot Staging Plaza
 */
export const MAP_PROPS: MapPropSpec[] = [
  // Central Mid Archway Pillars & Overhead Beam (never blocks spawn line of sight!)
  { id: 'mid_pillar_w', kind: 'wall', x: -5.5, y: 0, z: 4, w: 3, h: 4.5, d: 3, penetrable: false },
  { id: 'mid_pillar_e', kind: 'wall', x: 5.5, y: 0, z: 4, w: 3, h: 4.5, d: 3, penetrable: false },
  { id: 'mid_arch_lintel', kind: 'arch', x: 0, y: 3.6, z: 4, w: 14, h: 1.4, d: 3, penetrable: false },

  // Mid Tactical Cover (Xbox & Double-Stack Crate)
  { id: 'mid_xbox', kind: 'crate', x: -2.2, y: 0, z: -2.5, w: 2.2, h: 1.7, d: 2.2, penetrable: true },
  { id: 'mid_crate_low', kind: 'crate', x: 3.2, y: 0, z: -6.5, w: 1.8, h: 1.35, d: 1.8, penetrable: true },

  // Courtyard flanking walls separating Mid from West/East sites with wide 5m+ passages
  { id: 'div_wall_sw', kind: 'wall', x: -12, y: 0, z: 10, w: 2, h: 3.8, d: 9, penetrable: false },
  { id: 'div_wall_se', kind: 'wall', x: 12, y: 0, z: 10, w: 2, h: 3.8, d: 9, penetrable: false },
  { id: 'div_wall_nw', kind: 'wall', x: -12, y: 0, z: -12, w: 2, h: 3.8, d: 9, penetrable: false },
  { id: 'div_wall_ne', kind: 'wall', x: 12, y: 0, z: -12, w: 2, h: 3.8, d: 9, penetrable: false },

  // West A-Site: Industrial Shipping Containers & Tactical Crates
  { id: 'a_container_blue', kind: 'container', x: -22, y: 0, z: -4, w: 3.2, h: 2.8, d: 7.5, penetrable: false, tint: 0x2c4b66 },
  { id: 'a_container_rust', kind: 'container', x: -25, y: 0, z: 11, w: 7.0, h: 2.8, d: 3.2, penetrable: false, tint: 0x7c3e2b },
  { id: 'a_crate_site_1', kind: 'crate', x: -18, y: 0, z: -14, w: 2.2, h: 2.0, d: 2.2, penetrable: true },
  { id: 'a_crate_site_2', kind: 'crate', x: -20.5, y: 0, z: -14, w: 1.8, h: 1.4, d: 1.8, penetrable: true },
  { id: 'a_sandbag_1', kind: 'sandbag', x: -16, y: 0, z: 2, w: 3.0, h: 1.05, d: 1.0, penetrable: true },
  { id: 'a_barrel_1', kind: 'barrel', x: -19.8, y: 0, z: -11.8, w: 0.9, h: 1.25, d: 0.9, penetrable: true },

  // East B-Site: Elevated Platform, Steps & Double Crates
  { id: 'b_platform', kind: 'ramp_block', x: 22, y: 0, z: -4, w: 8, h: 1.2, d: 8, penetrable: false },
  { id: 'b_step_1', kind: 'ramp_block', x: 22, y: 0, z: 1.0, w: 4, h: 0.45, d: 2.0, penetrable: false },
  { id: 'b_step_2', kind: 'ramp_block', x: 22, y: 0, z: -0.2, w: 4, h: 0.85, d: 1.2, penetrable: false },
  { id: 'b_crate_top', kind: 'crate', x: 23.5, y: 1.2, z: -5.5, w: 1.8, h: 1.5, d: 1.8, penetrable: true },
  { id: 'b_container_olive', kind: 'container', x: 25, y: 0, z: 12, w: 6.8, h: 2.8, d: 3.1, penetrable: false, tint: 0x45583a },
  { id: 'b_crate_mid_e', kind: 'crate', x: 18, y: 0, z: -15, w: 2.0, h: 1.8, d: 2.0, penetrable: true },
  { id: 'b_sandbag_e', kind: 'sandbag', x: 16, y: 0, z: 3, w: 3.0, h: 1.05, d: 1.0, penetrable: true },
  { id: 'b_barrel_e', kind: 'barrel', x: 19.6, y: 0, z: -13.2, w: 0.9, h: 1.25, d: 0.9, penetrable: true },

  // North Plaza Headglitch & Back Cover
  { id: 'north_sandbag_c', kind: 'sandbag', x: 0, y: 0, z: -19, w: 4.5, h: 1.1, d: 1.1, penetrable: true },
  { id: 'north_crate_w', kind: 'crate', x: -7, y: 0, z: -23, w: 2.1, h: 1.8, d: 2.1, penetrable: true },
  { id: 'north_crate_e', kind: 'crate', x: 7, y: 0, z: -23, w: 2.1, h: 1.8, d: 2.1, penetrable: true },

  // South Spawn Flank Cover
  { id: 'south_crate_w', kind: 'crate', x: -7.5, y: 0, z: 19, w: 1.8, h: 1.4, d: 1.8, penetrable: true },
  { id: 'south_crate_e', kind: 'crate', x: 7.5, y: 0, z: 19, w: 1.8, h: 1.4, d: 1.8, penetrable: true },
  { id: 'south_barrel', kind: 'barrel', x: -5.4, y: 0, z: 19.2, w: 0.9, h: 1.25, d: 0.9, penetrable: true },
];

export const MAP_COLLIDERS: AABB[] = [
  ...MAP_PROPS.map((p): AABB => ({
    id: p.id,
    minX: p.x - p.w / 2,
    maxX: p.x + p.w / 2,
    minY: p.y,
    maxY: p.y + p.h,
    minZ: p.z - p.d / 2,
    maxZ: p.z + p.d / 2,
    materialType:
      p.kind === 'crate'
        ? 'wood'
        : p.kind === 'container' || p.kind === 'barrel'
          ? 'metal'
          : p.kind === 'sandbag'
            ? 'sandbag'
            : 'concrete',
    penetrable: p.penetrable,
  })),
  // Invisible perimeter bounds at outer canyon / fence edge so player stays inside playable compound
  { id: 'bound_n', minX: -36, maxX: 36, minY: 0, maxY: 6, minZ: -35, maxZ: -33.5, materialType: 'cliff', penetrable: false },
  { id: 'bound_s', minX: -36, maxX: 36, minY: 0, maxY: 6, minZ: 33.5, maxZ: 35, materialType: 'cliff', penetrable: false },
  { id: 'bound_w', minX: -35, maxX: -33.5, minY: 0, maxY: 6, minZ: -36, maxZ: 36, materialType: 'cliff', penetrable: false },
  { id: 'bound_e', minX: 33.5, maxX: 35, minY: 0, maxY: 6, minZ: -36, maxZ: 36, materialType: 'cliff', penetrable: false },
];

export const COVER_SPOTS: Vec3[] = [
  { x: -2.2, y: 0, z: -5.2 },
  { x: 3.2, y: 0, z: -9.0 },
  { x: -18, y: 0, z: -17 },
  { x: -19, y: 0, z: -4 },
  { x: 18, y: 0, z: -18 },
  { x: 22, y: 1.2, z: -7.5 },
  { x: 0, y: 0, z: -21.5 },
  { x: -7, y: 0, z: -26 },
  { x: 7, y: 0, z: -26 },
  { x: -16, y: 0, z: 0 },
  { x: 16, y: 0, z: 1 },
];

export const BOT_SPAWNS: BotSpawnSpec[] = [
  {
    id: 'bot_mid_entry',
    pos: { x: 0, y: 0, z: -17 },
    archetype: 'entry',
    patrolRoute: [
      { x: 0, y: 0, z: -14 },
      { x: 2.5, y: 0, z: -4 },
      { x: -2.2, y: 0, z: -1 },
      { x: 0, y: 0, z: 9 },
    ],
  },
  {
    id: 'bot_a_anchor',
    pos: { x: -21, y: 0, z: -18 },
    archetype: 'anchor',
    patrolRoute: [
      { x: -17, y: 0, z: -10 },
      { x: -17, y: 0, z: 0 },
      { x: -22, y: 0, z: 6 },
      { x: -16, y: 0, z: -12 },
    ],
  },
  {
    id: 'bot_b_anchor',
    pos: { x: 21, y: 0, z: -18 },
    archetype: 'anchor',
    patrolRoute: [
      { x: 17, y: 0, z: -10 },
      { x: 22, y: 1.2, z: -4 },
      { x: 17, y: 0, z: 5 },
      { x: 19, y: 0, z: -14 },
    ],
  },
  {
    id: 'bot_overwatch',
    pos: { x: -4, y: 0, z: -26 },
    archetype: 'sniper',
    patrolRoute: [
      { x: -2, y: 0, z: -21 },
      { x: 3.5, y: 0, z: -20 },
      { x: 0, y: 0, z: -15 },
    ],
  },
  {
    id: 'bot_flanker',
    pos: { x: 15, y: 0, z: -24 },
    archetype: 'entry',
    patrolRoute: [
      { x: 18, y: 0, z: -6 },
      { x: 18, y: 0, z: 8 },
      { x: 8, y: 0, z: 14 },
      { x: 16, y: 0, z: -4 },
    ],
  },
];
