import { useCallback, useEffect, useRef, useState } from 'react';
import { BuyMenuModal } from './components/BuyMenuModal';
import { GodotExportModal } from './components/GodotExportModal';
import { HudOverlay } from './components/HudOverlay';
import { StatusModals } from './components/StatusModals';
import { TitleScreen } from './components/TitleScreen';
import { tacticalAudio } from './game/audio';
import { FpsEngine } from './game/engine';
import { BotDifficulty, GamePhase, HudSnapshot, WeaponId, WeaponSlot } from './game/types';

const INITIAL_HUD: HudSnapshot = {
  hp: 100,
  armor: 100,
  hasHelmet: true,
  cash: 3500,
  round: 1,
  maxRounds: 5,
  playerScore: 0,
  botScore: 0,
  botsAlive: 4,
  totalBots: 4,
  activeSlot: 1,
  activeWeaponId: 'm4a1s',
  activeWeaponName: 'M4A1-S',
  ammoInMag: 20,
  reserveAmmo: 80,
  isReloading: false,
  reloadProgress: 0,
  isScoped: false,
  crosshairSpread: 0.003,
  flashAlpha: 0,
  damageFlashAlpha: 0,
  hitmarkerType: 'none',
  heCount: 1,
  flashCount: 1,
  slots: {
    1: { id: 'm4a1s', name: 'M4A1-S', ammo: 20, reserve: 80 },
    2: { id: 'usps', name: 'USP-S', ammo: 12, reserve: 24 },
    3: { id: 'karambit', name: 'KNIFE', ammo: 0, reserve: 0 },
    4: { id: 'he_grenade', name: 'HE', ammo: 1, reserve: 0 },
    5: { id: 'flashbang', name: 'FLASH', ammo: 1, reserve: 0 },
  },
  kills: 0,
  headshots: 0,
  shotsFired: 0,
  shotsHit: 0,
  damageDealt: 0,
  roundBanner: null,
  killfeed: [],
  radarBlips: [],
  playerX: 0,
  playerZ: 24,
  playerYaw: 0,
  pointerLocked: false,
  isVictory: false,
  difficulty: 'tactical',
};

export default function App() {
  const mountRef = useRef<HTMLDivElement | null>(null);
  const engineRef = useRef<FpsEngine | null>(null);

  const [phase, setPhase] = useState<GamePhase>('title');
  const [hud, setHud] = useState<HudSnapshot>(INITIAL_HUD);
  const [difficulty, setDifficulty] = useState<BotDifficulty>('tactical');
  const [botCount, setBotCount] = useState<number>(4);
  const [buyOpen, setBuyOpen] = useState(false);
  const [godotOpen, setGodotOpen] = useState(false);
  const [muted, setMuted] = useState(false);

  const phaseRef = useRef(phase);
  const buyOpenRef = useRef(buyOpen);
  const godotOpenRef = useRef(godotOpen);
  const difficultyRef = useRef(difficulty);
  const botCountRef = useRef(botCount);

  phaseRef.current = phase;
  buyOpenRef.current = buyOpen;
  godotOpenRef.current = godotOpen;
  difficultyRef.current = difficulty;
  botCountRef.current = botCount;

  const handleStartMatch = useCallback(() => {
    (document.activeElement as HTMLElement | null)?.blur();
    setBuyOpen(false);
    setGodotOpen(false);
    engineRef.current?.startNewMatch(difficultyRef.current, botCountRef.current);
  }, []);

  const handleToggleMute = useCallback(() => {
    setMuted((prev) => {
      const next = !prev;
      tacticalAudio.setMuted(next);
      return next;
    });
  }, []);

  useEffect(() => {
    document.body.dataset.state = 'title';
    const container = mountRef.current;
    if (!container) return;

    const engine = new FpsEngine(
      container,
      (snapshot) => setHud(snapshot),
      (nextPhase) => {
        setPhase(nextPhase);
        if (nextPhase !== 'playing') {
          setBuyOpen(false);
        }
      },
    );
    engineRef.current = engine;

    const params = new URLSearchParams(window.location.search);
    if (params.get('autostart') === '1') {
      engine.startNewMatch(difficultyRef.current, botCountRef.current);
    }

    return () => {
      engine.dispose();
      engineRef.current = null;
    };
  }, []);

  useEffect(() => {
    const onKeyDown = (e: KeyboardEvent) => {
      if (godotOpenRef.current) {
        if (e.code === 'Escape') {
          setGodotOpen(false);
        }
        return;
      }

      if (phaseRef.current === 'title') {
        if (e.code === 'Enter' || e.code === 'Space') {
          e.preventDefault();
          handleStartMatch();
        }
        return;
      }

      if (e.code === 'KeyM') {
        handleToggleMute();
        return;
      }

      if (phaseRef.current === 'playing') {
        if (e.code === 'KeyB') {
          e.preventDefault();
          setBuyOpen((prev) => {
            const next = !prev;
            if (next && document.pointerLockElement) {
              document.exitPointerLock?.();
            }
            return next;
          });
          return;
        }
        if (e.code === 'Escape' || e.code === 'KeyP') {
          if (buyOpenRef.current) {
            setBuyOpen(false);
          } else {
            engineRef.current?.setPhase('paused');
          }
          return;
        }
      } else if (phaseRef.current === 'paused') {
        if (e.code === 'Escape' || e.code === 'KeyP') {
          engineRef.current?.setPhase('playing');
        }
      }
    };

    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [handleStartMatch, handleToggleMute]);

  const handleBuy = (item: WeaponId | 'kevlar_helmet') => {
    engineRef.current?.buyItem(item);
  };

  const handleSelectSlot = (slot: WeaponSlot) => {
    engineRef.current?.selectSlot(slot);
  };

  return (
    <div className="relative w-full h-full overflow-hidden bg-stone-950">
      {/* Isolated WebGL Canvas Container */}
      <div
        ref={mountRef}
        data-testid="fps-canvas-mount"
        className="fixed inset-0 w-full h-full"
      />

      {phase === 'title' && (
        <TitleScreen
          difficulty={difficulty}
          botCount={botCount}
          onDifficultyChange={setDifficulty}
          onBotCountChange={setBotCount}
          onStart={handleStartMatch}
          onOpenGodot={() => setGodotOpen(true)}
        />
      )}

      {phase === 'playing' && (
        <HudOverlay
          hud={hud}
          muted={muted}
          onToggleMute={handleToggleMute}
          onOpenBuy={() => {
            if (document.pointerLockElement) document.exitPointerLock?.();
            setBuyOpen(true);
          }}
          onOpenGodot={() => {
            if (document.pointerLockElement) document.exitPointerLock?.();
            engineRef.current?.setPhase('paused');
            setGodotOpen(true);
          }}
          onPause={() => engineRef.current?.setPhase('paused')}
          onSelectSlot={handleSelectSlot}
        />
      )}

      {phase === 'playing' && buyOpen && (
        <BuyMenuModal
          hud={hud}
          onBuy={handleBuy}
          onClose={() => {
            setBuyOpen(false);
            engineRef.current?.requestPointerLock();
          }}
        />
      )}

      <StatusModals
        phase={phase}
        hud={hud}
        onResume={() => engineRef.current?.setPhase('playing')}
        onRestart={handleStartMatch}
        onTitle={() => engineRef.current?.setPhase('title')}
        onOpenGodot={() => setGodotOpen(true)}
      />

      {godotOpen && <GodotExportModal onClose={() => setGodotOpen(false)} />}
    </div>
  );
}
