import React from 'react';
import { Code2, Home, Play, RotateCcw } from 'lucide-react';
import { GamePhase, HudSnapshot } from '../game/types';

interface StatusModalsProps {
  phase: GamePhase;
  hud: HudSnapshot;
  onResume: () => void;
  onRestart: () => void;
  onTitle: () => void;
  onOpenGodot: () => void;
}

export const StatusModals: React.FC<StatusModalsProps> = ({
  phase,
  hud,
  onResume,
  onRestart,
  onTitle,
  onOpenGodot,
}) => {
  if (phase !== 'paused' && phase !== 'gameover') return null;

  const accuracy = hud.shotsFired > 0 ? Math.round((hud.shotsHit / hud.shotsFired) * 100) : 0;
  const hsRate = hud.kills > 0 ? Math.round((hud.headshots / hud.kills) * 100) : 0;

  return (
    <div
      className="fixed inset-0 z-30 flex items-center justify-center p-4"
      style={{ backgroundColor: 'rgba(10, 9, 8, 0.8)' }}
    >
      <div
        className="w-full max-w-md rounded-lg border border-amber-500/40 p-6 shadow-2xl"
        style={{ backgroundColor: 'rgba(20, 17, 14, 0.97)' }}
      >
        {phase === 'paused' ? (
          <>
            <div className="text-xs font-mono uppercase tracking-widest text-amber-400 mb-1">
              Tactical Pause
            </div>
            <h2 className="text-2xl font-black uppercase text-stone-100 mb-5">Match Paused</h2>

            <div className="grid grid-cols-3 gap-2 mb-6">
              <div className="p-2.5 rounded bg-stone-900 border border-stone-800">
                <div className="text-[10px] font-mono text-stone-400">SCORE</div>
                <div className="text-lg font-bold text-stone-100 tabular-nums">
                  {hud.playerScore} - {hud.botScore}
                </div>
              </div>
              <div className="p-2.5 rounded bg-stone-900 border border-stone-800">
                <div className="text-[10px] font-mono text-stone-400">KILLS</div>
                <div className="text-lg font-bold text-emerald-400 tabular-nums">{hud.kills}</div>
              </div>
              <div className="p-2.5 rounded bg-stone-900 border border-stone-800">
                <div className="text-[10px] font-mono text-stone-400">ACCURACY</div>
                <div className="text-lg font-bold text-amber-300 tabular-nums">{accuracy}%</div>
              </div>
            </div>

            <div className="space-y-2.5">
              <button
                type="button"
                onClick={onResume}
                className="w-full flex items-center justify-center gap-2 py-3 rounded bg-amber-600 hover:bg-amber-500 text-stone-950 font-black uppercase tracking-wide cursor-pointer"
              >
                <Play className="w-4 h-4 fill-current" />
                Resume Match
              </button>
              <button
                type="button"
                onClick={onRestart}
                className="w-full flex items-center justify-center gap-2 py-2.5 rounded bg-stone-900 hover:bg-stone-800 text-stone-200 border border-stone-700 font-semibold uppercase text-sm cursor-pointer"
              >
                <RotateCcw className="w-4 h-4" />
                Restart Match
              </button>
              <button
                type="button"
                onClick={onOpenGodot}
                className="w-full flex items-center justify-center gap-2 py-2.5 rounded bg-stone-900 hover:bg-stone-800 text-amber-200 border border-amber-500/35 font-semibold uppercase text-sm cursor-pointer"
              >
                <Code2 className="w-4 h-4 text-amber-400" />
                Godot 4 GDScript Source
              </button>
              <button
                type="button"
                onClick={onTitle}
                className="w-full flex items-center justify-center gap-2 py-2.5 rounded bg-stone-950 hover:bg-stone-900 text-stone-400 border border-stone-800 font-semibold uppercase text-sm cursor-pointer"
              >
                <Home className="w-4 h-4" />
                Main Menu
              </button>
            </div>
          </>
        ) : (
          <>
            <div
              className={`text-xs font-mono uppercase tracking-widest mb-1 ${
                hud.isVictory ? 'text-emerald-400' : 'text-rose-400'
              }`}
            >
              {hud.isVictory ? 'Mission Accomplished' : 'Squad Eliminated'}
            </div>
            <h2 className="text-3xl font-black uppercase text-stone-100 mb-2">
              {hud.isVictory ? 'Match Victory' : 'Defeat'}
            </h2>
            <p className="text-xs font-mono text-stone-400 mb-5">
              Final Score {hud.playerScore} – {hud.botScore} · Difficulty: {hud.difficulty.toUpperCase()}
            </p>

            <div className="grid grid-cols-2 gap-2.5 mb-6">
              <div className="p-3 rounded bg-stone-900 border border-stone-800">
                <div className="text-[10px] font-mono text-stone-400">ELIMINATIONS</div>
                <div className="text-2xl font-black text-stone-100 tabular-nums">{hud.kills}</div>
              </div>
              <div className="p-3 rounded bg-stone-900 border border-stone-800">
                <div className="text-[10px] font-mono text-stone-400">HEADSHOTS</div>
                <div className="text-2xl font-black text-amber-400 tabular-nums">{hsRate}%</div>
              </div>
              <div className="p-3 rounded bg-stone-900 border border-stone-800">
                <div className="text-[10px] font-mono text-stone-400">ACCURACY</div>
                <div className="text-2xl font-black text-sky-300 tabular-nums">{accuracy}%</div>
              </div>
              <div className="p-3 rounded bg-stone-900 border border-stone-800">
                <div className="text-[10px] font-mono text-stone-400">TOTAL DAMAGE</div>
                <div className="text-2xl font-black text-emerald-400 tabular-nums">
                  {hud.damageDealt}
                </div>
              </div>
            </div>

            <div className="space-y-2.5">
              <button
                type="button"
                data-start="true"
                onClick={onRestart}
                className="w-full flex items-center justify-center gap-2 py-3 rounded bg-amber-600 hover:bg-amber-500 text-stone-950 font-black uppercase tracking-wide cursor-pointer"
              >
                <RotateCcw className="w-4 h-4" />
                {hud.isVictory ? 'Play Again' : 'Try Again'}
              </button>
              <button
                type="button"
                onClick={onTitle}
                className="w-full flex items-center justify-center gap-2 py-2.5 rounded bg-stone-900 hover:bg-stone-800 text-stone-300 border border-stone-700 font-semibold uppercase text-sm cursor-pointer"
              >
                <Home className="w-4 h-4" />
                Main Menu
              </button>
            </div>
          </>
        )}
      </div>
    </div>
  );
};
