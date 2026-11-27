import React from 'react';
import { Code2, Crosshair, Play } from 'lucide-react';
import { BotDifficulty } from '../game/types';

interface TitleScreenProps {
  difficulty: BotDifficulty;
  botCount: number;
  onDifficultyChange: (d: BotDifficulty) => void;
  onBotCountChange: (c: number) => void;
  onStart: () => void;
  onOpenGodot: () => void;
}

export const TitleScreen: React.FC<TitleScreenProps> = ({
  difficulty,
  botCount,
  onDifficultyChange,
  onBotCountChange,
  onStart,
  onOpenGodot,
}) => {
  return (
    <div
      className="fixed inset-0 z-20 flex flex-col justify-between p-6 md:p-12 pointer-events-none select-none"
      style={{
        background:
          'linear-gradient(90deg, rgba(16,14,12,0.88) 0%, rgba(16,14,12,0.52) 44%, rgba(16,14,12,0.08) 100%)',
      }}
    >
      {/* Top-Left Bespoke SVG Title Lockup over calm negative space */}
      <div className="max-w-lg pt-4 md:pt-8 pointer-events-auto">
        <svg
          viewBox="0 0 460 128"
          className="w-full max-w-[440px] mb-6"
          aria-label="CS-PROTOCOL Tactical Bot FPS"
        >
          {/* Tactical Crest Icon */}
          <g transform="translate(8, 12)">
            <polygon
              points="44,4 82,22 76,68 44,94 12,68 6,22"
              fill="#1c1917"
              stroke="#d97706"
              strokeWidth="3"
            />
            <polygon
              points="44,14 70,28 65,62 44,82 23,62 18,28"
              fill="none"
              stroke="#f59e0b"
              strokeOpacity="0.45"
              strokeWidth="1.5"
            />
            <circle cx="44" cy="46" r="13" fill="none" stroke="#fef3c7" strokeWidth="2.5" />
            <line x1="44" y1="24" x2="44" y2="36" stroke="#f59e0b" strokeWidth="3" />
            <line x1="44" y1="56" x2="44" y2="68" stroke="#f59e0b" strokeWidth="3" />
            <line x1="22" y1="46" x2="34" y2="46" stroke="#f59e0b" strokeWidth="3" />
            <line x1="54" y1="46" x2="66" y2="46" stroke="#f59e0b" strokeWidth="3" />
          </g>

          {/* Display Title Typography */}
          <text
            x="108"
            y="62"
            fill="#faf5eb"
            fontFamily="system-ui, -apple-system, sans-serif"
            fontWeight="900"
            fontSize="44"
            letterSpacing="2"
          >
            CS-PROTOCOL
          </text>
          <rect x="108" y="74" width="210" height="3" fill="#d97706" />
          <text
            x="108"
            y="98"
            fill="#d6c7b2"
            fontFamily="ui-monospace, SFMono-Regular, monospace"
            fontWeight="700"
            fontSize="14"
            letterSpacing="3.5"
          >
            DUST SECTOR // BOT OPS
          </text>
        </svg>

        {/* Match Setup Controls */}
        <div
          className="p-4 rounded border border-amber-500/25 mb-5 space-y-3"
          style={{ backgroundColor: 'rgba(20, 18, 15, 0.88)' }}
        >
          <div className="flex items-center justify-between gap-4">
            <span className="text-xs font-mono uppercase tracking-wider text-amber-200/80">
              Bot AI Tier
            </span>
            <div className="flex gap-1.5">
              {(['recruit', 'tactical', 'elite'] as BotDifficulty[]).map((d) => (
                <button
                  key={d}
                  type="button"
                  onClick={() => onDifficultyChange(d)}
                  className={`px-3 py-1.5 text-xs font-mono uppercase tracking-wider rounded border transition-colors cursor-pointer ${
                    difficulty === d
                      ? 'bg-amber-600 text-stone-950 border-amber-400 font-bold'
                      : 'bg-stone-900 text-stone-300 border-stone-700 hover:border-amber-500/50'
                  }`}
                >
                  {d}
                </button>
              ))}
            </div>
          </div>

          <div className="flex items-center justify-between gap-4">
            <span className="text-xs font-mono uppercase tracking-wider text-amber-200/80">
              Hostile Squad
            </span>
            <div className="flex gap-1.5">
              {[3, 4, 5].map((cnt) => (
                <button
                  key={cnt}
                  type="button"
                  onClick={() => onBotCountChange(cnt)}
                  className={`px-3 py-1.5 text-xs font-mono rounded border transition-colors cursor-pointer tabular-nums ${
                    botCount === cnt
                      ? 'bg-amber-600 text-stone-950 border-amber-400 font-bold'
                      : 'bg-stone-900 text-stone-300 border-stone-700 hover:border-amber-500/50'
                  }`}
                >
                  {cnt} BOTS
                </button>
              ))}
            </div>
          </div>
        </div>

        {/* Primary & Secondary CTAs (<= 3 menu actions) */}
        <div className="flex flex-wrap items-center gap-3">
          <button
            type="button"
            data-start="true"
            onClick={onStart}
            className="flex items-center gap-2.5 px-7 py-3.5 rounded bg-amber-600 hover:bg-amber-500 text-stone-950 font-extrabold text-base tracking-wide uppercase shadow-lg transition-colors cursor-pointer"
          >
            <Play className="w-5 h-5 fill-current" />
            Deploy Match
          </button>

          <button
            type="button"
            onClick={onOpenGodot}
            className="flex items-center gap-2 px-5 py-3.5 rounded bg-stone-900/95 hover:bg-stone-800 text-amber-200 border border-amber-500/35 font-semibold text-sm tracking-wide uppercase transition-colors cursor-pointer"
          >
            <Code2 className="w-4 h-4 text-amber-400" />
            Godot 4 GDScript
          </button>
        </div>

        <div className="mt-4 flex items-center gap-2 text-xs text-stone-300/80 font-mono">
          <Crosshair className="w-3.5 h-3.5 text-amber-400" />
          <span>8 CS-Class Weapons · Ballistic Penetration · Utility AI Bots</span>
        </div>
      </div>

      {/* Single Flat Control-Hint Line */}
      <div className="text-xs md:text-sm font-mono text-stone-300/90 tracking-wide">
        WASD Move · Mouse / Arrows Aim · LMB Fire · RMB Scope · 1-5 Weapons · G/F Grenades · B Buy · Esc Pause
      </div>
    </div>
  );
};
