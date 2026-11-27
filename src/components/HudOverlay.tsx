import React from 'react';
import { Code2, Pause, ShoppingCart, Volume2, VolumeX } from 'lucide-react';
import { MAP_HALF_SIZE, MAP_PROPS } from '../game/mapData';
import { HudSnapshot, WeaponSlot } from '../game/types';

interface HudOverlayProps {
  hud: HudSnapshot;
  muted: boolean;
  onToggleMute: () => void;
  onOpenBuy: () => void;
  onOpenGodot: () => void;
  onPause: () => void;
  onSelectSlot: (slot: WeaponSlot) => void;
}

export const HudOverlay: React.FC<HudOverlayProps> = ({
  hud,
  muted,
  onToggleMute,
  onOpenBuy,
  onOpenGodot,
  onPause,
  onSelectSlot,
}) => {
  const spreadPx = Math.min(34, Math.max(4, Math.round(hud.crosshairSpread * 420)));
  const radarSize = 132;
  const toRadar = (wx: number, wz: number) => ({
    x: ((wx + MAP_HALF_SIZE) / (MAP_HALF_SIZE * 2)) * radarSize,
    y: ((wz + MAP_HALF_SIZE) / (MAP_HALF_SIZE * 2)) * radarSize,
  });
  const playerRadar = toRadar(hud.playerX, hud.playerZ);

  return (
    <div className="fixed inset-0 z-10 pointer-events-none select-none overflow-hidden">
      {/* Flashbang & Damage Vignettes */}
      {hud.flashAlpha > 0.01 && (
        <div
          className="fixed inset-0"
          style={{ backgroundColor: `rgba(255, 255, 255, ${hud.flashAlpha.toFixed(2)})` }}
        />
      )}
      {(hud.damageFlashAlpha > 0.01 || hud.hp <= 25) && (
        <div
          className="fixed inset-0"
          style={{
            boxShadow: `inset 0 0 90px rgba(220, 38, 38, ${Math.max(
              hud.damageFlashAlpha,
              hud.hp <= 25 ? 0.35 : 0,
            ).toFixed(2)})`,
          }}
        />
      )}

      {/* AWP Optical Scope Overlay */}
      {hud.isScoped && (
        <div className="fixed inset-0 flex items-center justify-center">
          <div
            className="w-full h-full"
            style={{
              background:
                'radial-gradient(circle at center, transparent 28%, rgba(8, 9, 10, 0.96) 29.5%)',
            }}
          />
          <div className="fixed left-0 right-0 top-1/2 h-[1.5px] bg-stone-950/90" />
          <div className="fixed top-0 bottom-0 left-1/2 w-[1.5px] bg-stone-950/90" />
          <div className="fixed left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 w-2 h-2 rounded-full bg-red-500" />
        </div>
      )}

      {/* Dynamic Center Crosshair + Hitmarker */}
      {!hud.isScoped && (
        <div className="fixed left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2">
          <div
            className="absolute left-1/2 -translate-x-1/2 w-[2px] h-2.5 bg-emerald-300 shadow-[0_0_2px_#000]"
            style={{ bottom: `${spreadPx}px` }}
          />
          <div
            className="absolute left-1/2 -translate-x-1/2 w-[2px] h-2.5 bg-emerald-300 shadow-[0_0_2px_#000]"
            style={{ top: `${spreadPx}px` }}
          />
          <div
            className="absolute top-1/2 -translate-y-1/2 h-[2px] w-2.5 bg-emerald-300 shadow-[0_0_2px_#000]"
            style={{ right: `${spreadPx}px` }}
          />
          <div
            className="absolute top-1/2 -translate-y-1/2 h-[2px] w-2.5 bg-emerald-300 shadow-[0_0_2px_#000]"
            style={{ left: `${spreadPx}px` }}
          />
          <div className="w-[2px] h-[2px] bg-emerald-300" />
        </div>
      )}

      {hud.hitmarkerType !== 'none' && (
        <svg
          viewBox="0 0 32 32"
          className="fixed left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 w-8 h-8"
        >
          <path
            d="M7 7 L12 12 M25 7 L20 12 M7 25 L12 20 M25 25 L20 20"
            stroke={
              hud.hitmarkerType === 'kill'
                ? '#ef4444'
                : hud.hitmarkerType === 'head'
                  ? '#f59e0b'
                  : '#ffffff'
            }
            strokeWidth="2.5"
            strokeLinecap="round"
          />
        </svg>
      )}

      {/* TOP-LEFT: Tactical Compound Radar Minimap */}
      <div
        className="fixed top-4 left-4 rounded border border-amber-500/35 p-1.5"
        style={{ backgroundColor: 'rgba(18, 16, 13, 0.84)' }}
      >
        <svg width={radarSize} height={radarSize} viewBox={`0 0 ${radarSize} ${radarSize}`}>
          <rect width={radarSize} height={radarSize} fill="#181511" />
          {MAP_PROPS.map((p) => {
            const tl = toRadar(p.x - p.w / 2, p.z - p.d / 2);
            const rw = Math.max(2, (p.w / (MAP_HALF_SIZE * 2)) * radarSize);
            const rh = Math.max(2, (p.d / (MAP_HALF_SIZE * 2)) * radarSize);
            return (
              <rect
                key={p.id}
                x={tl.x}
                y={tl.y}
                width={rw}
                height={rh}
                fill={p.kind === 'crate' ? '#7c5a37' : '#574c3f'}
              />
            );
          })}
          {/* Bot Blips */}
          {hud.radarBlips.map((b) => {
            const pt = toRadar(b.x, b.z);
            const color =
              b.state === 'BLINDED'
                ? '#ffffff'
                : b.state === 'ENGAGE'
                  ? '#ef4444'
                  : '#f59e0b';
            return <circle key={b.id} cx={pt.x} cy={pt.y} r="3.4" fill={color} stroke="#000" strokeWidth="1" />;
          })}
          {/* Player Arrow */}
          <g
            transform={`translate(${playerRadar.x}, ${playerRadar.y}) rotate(${
              (-hud.playerYaw * 180) / Math.PI
            })`}
          >
            <polygon points="0,-6 4.5,5 0,2.5 -4.5,5" fill="#34d399" stroke="#000" strokeWidth="1" />
          </g>
        </svg>
        <div className="mt-1 flex justify-between text-[10px] font-mono text-amber-200/80 px-0.5 tabular-nums">
          <span>RADAR</span>
          <span>{hud.botsAlive}/{hud.totalBots} BOTS</span>
        </div>
      </div>

      {/* TOP-CENTER: Match Score & Round Strip */}
      <div className="fixed top-4 left-1/2 -translate-x-1/2 flex flex-col items-center gap-2">
        <div
          className="flex items-center gap-4 px-4 py-1.5 rounded border border-amber-500/35 font-mono"
          style={{ backgroundColor: 'rgba(18, 16, 13, 0.86)' }}
        >
          <div className="flex items-center gap-2">
            <span className="text-[11px] text-emerald-400 font-bold">YOU</span>
            <span className="text-xl font-black text-stone-100 tabular-nums">{hud.playerScore}</span>
          </div>
          <div className="text-xs text-amber-400 font-bold tracking-wider tabular-nums">
            R{hud.round}/{hud.maxRounds}
          </div>
          <div className="flex items-center gap-2">
            <span className="text-xl font-black text-stone-100 tabular-nums">{hud.botScore}</span>
            <span className="text-[11px] text-rose-400 font-bold">BOT</span>
          </div>
          <div className="h-4 w-px bg-stone-700" />
          <button
            type="button"
            tabIndex={-1}
            onClick={(e) => {
              e.currentTarget.blur();
              onOpenBuy();
            }}
            className="pointer-events-auto flex items-center gap-1.5 text-sm font-bold text-emerald-400 hover:text-emerald-300 tabular-nums cursor-pointer"
            aria-label="Open Buy Menu"
          >
            <span>${hud.cash}</span>
            <span className="text-[10px] px-1 py-0.5 rounded bg-stone-800 text-stone-300">[B]</span>
          </button>
        </div>

        {hud.roundBanner && (
          <div
            className="px-5 py-1.5 rounded border border-amber-400/60 text-amber-200 font-mono text-xs md:text-sm font-bold tracking-widest uppercase"
            style={{ backgroundColor: 'rgba(20, 16, 11, 0.92)' }}
          >
            {hud.roundBanner}
          </div>
        )}
      </div>

      {/* TOP-RIGHT: Compact Utility Controls + Killfeed */}
      <div className="fixed top-4 right-4 flex flex-col items-end gap-2">
        <div className="flex items-center gap-1.5 pointer-events-auto">
          <button
            type="button"
            tabIndex={-1}
            aria-label="Buy Armory"
            onClick={(e) => {
              e.currentTarget.blur();
              onOpenBuy();
            }}
            className="w-9 h-9 flex items-center justify-center rounded border border-amber-500/35 text-amber-200 hover:bg-stone-800 cursor-pointer"
            style={{ backgroundColor: 'rgba(18, 16, 13, 0.86)' }}
          >
            <ShoppingCart className="w-4 h-4" />
          </button>
          <button
            type="button"
            tabIndex={-1}
            aria-label="Godot 4 GDScript"
            onClick={(e) => {
              e.currentTarget.blur();
              onOpenGodot();
            }}
            className="w-9 h-9 flex items-center justify-center rounded border border-amber-500/35 text-amber-200 hover:bg-stone-800 cursor-pointer"
            style={{ backgroundColor: 'rgba(18, 16, 13, 0.86)' }}
          >
            <Code2 className="w-4 h-4" />
          </button>
          <button
            type="button"
            tabIndex={-1}
            aria-label={muted ? 'Unmute Audio' : 'Mute Audio'}
            onClick={(e) => {
              e.currentTarget.blur();
              onToggleMute();
            }}
            className="w-9 h-9 flex items-center justify-center rounded border border-amber-500/35 text-amber-200 hover:bg-stone-800 cursor-pointer"
            style={{ backgroundColor: 'rgba(18, 16, 13, 0.86)' }}
          >
            {muted ? <VolumeX className="w-4 h-4 text-rose-400" /> : <Volume2 className="w-4 h-4" />}
          </button>
          <button
            type="button"
            tabIndex={-1}
            aria-label="Pause Match"
            onClick={(e) => {
              e.currentTarget.blur();
              onPause();
            }}
            className="w-9 h-9 flex items-center justify-center rounded border border-amber-500/35 text-amber-200 hover:bg-stone-800 cursor-pointer"
            style={{ backgroundColor: 'rgba(18, 16, 13, 0.86)' }}
          >
            <Pause className="w-4 h-4" />
          </button>
        </div>

        {/* Killfeed */}
        <div className="flex flex-col items-end gap-1">
          {hud.killfeed.map((k) => (
            <div
              key={k.id}
              className="px-2.5 py-1 rounded border border-stone-700/80 text-xs font-mono flex items-center gap-1.5"
              style={{ backgroundColor: 'rgba(18, 16, 13, 0.86)' }}
            >
              <span className={k.killer === 'YOU' ? 'text-emerald-400 font-bold' : 'text-rose-400 font-bold'}>
                {k.killer}
              </span>
              <span className="text-stone-400">[{k.weapon}]</span>
              {k.headshot && <span className="text-amber-400 font-bold">HS</span>}
              <span className={k.victim === 'YOU' ? 'text-rose-400 font-bold' : 'text-stone-200'}>
                {k.victim}
              </span>
            </div>
          ))}
        </div>
      </div>

      {/* BOTTOM-LEFT: HP & Armor Vitality Cluster */}
      <div
        className="fixed bottom-4 left-4 flex items-center gap-5 px-4 py-2.5 rounded border border-amber-500/35"
        style={{ backgroundColor: 'rgba(18, 16, 13, 0.86)' }}
      >
        <div className="flex items-baseline gap-2">
          <svg viewBox="0 0 24 24" className="w-5 h-5 self-center">
            <path d="M9 3h6v6h6v6h-6v6H9v-6H3V9h6V3z" fill={hud.hp <= 25 ? '#ef4444' : '#e5e7eb'} />
          </svg>
          <span
            className={`text-3xl font-black tabular-nums leading-none ${
              hud.hp <= 25 ? 'text-rose-400' : 'text-stone-100'
            }`}
          >
            {hud.hp}
          </span>
          <span className="text-[11px] font-mono text-stone-400">HP</span>
        </div>

        <div className="h-7 w-px bg-stone-700" />

        <div className="flex items-baseline gap-2">
          <svg viewBox="0 0 24 24" className="w-5 h-5 self-center">
            <path
              d="M12 2L4 5v6.5c0 5.2 3.4 9.9 8 11.5 4.6-1.6 8-6.3 8-11.5V5l-8-3z"
              fill={hud.armor > 0 ? '#60a5fa' : '#4b5563'}
            />
          </svg>
          <span className="text-2xl font-extrabold text-sky-300 tabular-nums leading-none">
            {hud.armor}
          </span>
          <span className="text-[11px] font-mono text-stone-400">
            {hud.hasHelmet ? 'KEVLAR+' : 'ARMOR'}
          </span>
        </div>
      </div>

      {/* BOTTOM-RIGHT: Weapon Slots & Ammo Cluster */}
      <div className="fixed bottom-4 right-4 flex flex-col items-end gap-2">
        {/* Quick Weapon Slots 1-5 */}
        <div className="flex items-center gap-1.5 pointer-events-auto">
          {([1, 2, 3, 4, 5] as WeaponSlot[]).map((slot) => {
            const item = hud.slots[slot];
            const active = hud.activeSlot === slot;
            return (
              <button
                key={slot}
                type="button"
                tabIndex={-1}
                disabled={!item}
                onClick={(e) => {
                  e.currentTarget.blur();
                  onSelectSlot(slot);
                }}
                className={`px-2.5 py-1 rounded border text-[11px] font-mono transition-colors cursor-pointer ${
                  active
                    ? 'bg-amber-600 text-stone-950 border-amber-300 font-bold'
                    : item
                      ? 'text-stone-200 border-stone-700 hover:border-amber-500/50'
                      : 'text-stone-600 border-stone-800 opacity-50 cursor-default'
                }`}
                style={active ? undefined : { backgroundColor: 'rgba(18, 16, 13, 0.85)' }}
              >
                <span className="mr-1 opacity-75">[{slot}]</span>
                <span>{item ? item.name : '—'}</span>
              </button>
            );
          })}
        </div>

        {/* Ammo Readout */}
        <div
          className="px-4 py-2.5 rounded border border-amber-500/35 flex items-center gap-4"
          style={{ backgroundColor: 'rgba(18, 16, 13, 0.86)' }}
        >
          <div className="text-right">
            <div className="text-xs font-mono uppercase tracking-wider text-amber-300">
              {hud.activeWeaponName}
            </div>
            {hud.isReloading && (
              <div className="mt-1 w-28 h-1.5 bg-stone-800 rounded overflow-hidden">
                <div
                  className="h-full bg-amber-400"
                  style={{ width: `${Math.round(hud.reloadProgress * 100)}%` }}
                />
              </div>
            )}
          </div>
          {hud.activeSlot <= 2 ? (
            <div className="flex items-baseline gap-1 font-mono tabular-nums">
              <span className="text-3xl font-black text-stone-100 leading-none">
                {hud.ammoInMag}
              </span>
              <span className="text-base text-stone-400 font-bold">/ {hud.reserveAmmo}</span>
            </div>
          ) : (
            <div className="text-lg font-mono font-bold text-stone-300 tabular-nums">
              {hud.activeSlot === 3 ? 'MELEE' : hud.activeSlot === 4 ? `x${hud.heCount}` : `x${hud.flashCount}`}
            </div>
          )}
        </div>
      </div>

      {/* Subtle Pointer-Lock / Aim Hint when unlocked during gameplay */}
      {!hud.pointerLocked && (
        <div
          className="fixed bottom-4 left-1/2 -translate-x-1/2 px-3 py-1 rounded text-[11px] font-mono text-stone-300 border border-stone-700/70"
          style={{ backgroundColor: 'rgba(18, 16, 13, 0.8)' }}
        >
          Click Arena to Lock Mouse · Drag or Arrow Keys to Look · B to Buy
        </div>
      )}
    </div>
  );
};
