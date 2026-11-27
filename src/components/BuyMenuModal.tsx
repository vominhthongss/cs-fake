import React from 'react';
import { Shield, X } from 'lucide-react';
import { BUYABLE_WEAPON_IDS, HudSnapshot, WEAPONS, WeaponId } from '../game/types';

interface BuyMenuModalProps {
  hud: HudSnapshot;
  onBuy: (item: WeaponId | 'kevlar_helmet') => void;
  onClose: () => void;
}

export const BuyMenuModal: React.FC<BuyMenuModalProps> = ({ hud, onBuy, onClose }) => {
  const armorCost = hud.armor >= 100 && hud.hasHelmet ? 0 : hud.armor > 0 ? 350 : 1000;

  return (
    <div
      className="fixed inset-0 z-30 flex items-center justify-center p-4"
      style={{ backgroundColor: 'rgba(10, 9, 8, 0.78)' }}
    >
      <div
        className="w-full max-w-3xl rounded-lg border border-amber-500/40 p-6 shadow-2xl"
        style={{ backgroundColor: 'rgba(22, 19, 15, 0.97)' }}
      >
        <div className="flex items-center justify-between border-b border-stone-700 pb-3 mb-4">
          <div>
            <h2 className="text-xl font-black tracking-wide uppercase text-stone-100">
              Tactical Armory
            </h2>
            <p className="text-xs font-mono text-stone-400">
              Purchase Rifles, SMGs, Sniper, Sidearms & Utility
            </p>
          </div>
          <div className="flex items-center gap-4">
            <span className="text-2xl font-black font-mono text-emerald-400 tabular-nums">
              ${hud.cash}
            </span>
            <button
              type="button"
              onClick={onClose}
              aria-label="Close Buy Menu"
              className="p-1.5 rounded border border-stone-700 text-stone-300 hover:bg-stone-800 cursor-pointer"
            >
              <X className="w-5 h-5" />
            </button>
          </div>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-2.5">
          {BUYABLE_WEAPON_IDS.map((id) => {
            const spec = WEAPONS[id];
            const owned =
              (spec.slot === 1 && hud.slots[1]?.id === id) ||
              (spec.slot === 2 && hud.slots[2]?.id === id);
            const canAfford = hud.cash >= spec.price;
            return (
              <button
                key={id}
                type="button"
                disabled={owned || !canAfford}
                onClick={() => onBuy(id)}
                className={`p-3 rounded border text-left transition-colors cursor-pointer ${
                  owned
                    ? 'border-emerald-500/50 bg-emerald-950/30 text-stone-200'
                    : canAfford
                      ? 'border-stone-700 bg-stone-900/90 hover:border-amber-400 text-stone-100'
                      : 'border-stone-800 bg-stone-950/60 text-stone-500 opacity-60 cursor-not-allowed'
                }`}
              >
                <div className="flex items-center justify-between mb-1">
                  <span className="font-bold text-sm uppercase">{spec.name}</span>
                  <span className="font-mono text-sm font-bold text-amber-400 tabular-nums">
                    {owned ? 'EQUIPPED' : `$${spec.price}`}
                  </span>
                </div>
                <div className="text-[11px] font-mono text-stone-400 mb-1.5">{spec.roleHint}</div>
                <div className="flex justify-between text-[10px] font-mono text-stone-500 tabular-nums">
                  <span>DMG {spec.damage}</span>
                  <span>MAG {spec.magazineSize || 1}</span>
                </div>
              </button>
            );
          })}

          {/* Kevlar + Helmet */}
          <button
            type="button"
            disabled={armorCost === 0 || hud.cash < armorCost}
            onClick={() => onBuy('kevlar_helmet')}
            className={`p-3 rounded border text-left transition-colors cursor-pointer ${
              armorCost === 0
                ? 'border-sky-500/50 bg-sky-950/30 text-stone-200'
                : hud.cash >= armorCost
                  ? 'border-stone-700 bg-stone-900/90 hover:border-sky-400 text-stone-100'
                  : 'border-stone-800 bg-stone-950/60 text-stone-500 opacity-60 cursor-not-allowed'
            }`}
          >
            <div className="flex items-center justify-between mb-1">
              <span className="font-bold text-sm uppercase flex items-center gap-1.5">
                <Shield className="w-4 h-4 text-sky-400" />
                Kevlar + Helmet
              </span>
              <span className="font-mono text-sm font-bold text-sky-400 tabular-nums">
                {armorCost === 0 ? 'FULL' : `$${armorCost}`}
              </span>
            </div>
            <div className="text-[11px] font-mono text-stone-400">
              Reduces torso & helmet headshot damage
            </div>
          </button>
        </div>

        <div className="mt-4 pt-3 border-t border-stone-800 flex justify-between items-center text-xs font-mono text-stone-400">
          <span>Press [B] or [Esc] to return to combat</span>
          <button
            type="button"
            onClick={onClose}
            className="px-4 py-1.5 rounded bg-amber-600 hover:bg-amber-500 text-stone-950 font-bold uppercase cursor-pointer"
          >
            Done
          </button>
        </div>
      </div>
    </div>
  );
};
