import { WeaponId } from './types';

class TacticalAudio {
  private ctx: AudioContext | null = null;
  private noiseBuffer: AudioBuffer | null = null;
  public muted = false;

  private ensureContext(): AudioContext | null {
    if (this.muted) return null;
    if (!this.ctx && typeof window !== 'undefined') {
      const AudioCtx = window.AudioContext || (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
      if (AudioCtx) {
        this.ctx = new AudioCtx();
      }
    }
    if (this.ctx && this.ctx.state === 'suspended') {
      this.ctx.resume().catch(() => {});
    }
    if (this.ctx && !this.noiseBuffer) {
      const sampleRate = this.ctx.sampleRate;
      const length = Math.floor(sampleRate * 1.2);
      const buf = this.ctx.createBuffer(1, length, sampleRate);
      const data = buf.getChannelData(0);
      for (let i = 0; i < length; i++) {
        data[i] = Math.random() * 2 - 1;
      }
      this.noiseBuffer = buf;
    }
    return this.ctx;
  }

  public setMuted(muted: boolean): void {
    this.muted = muted;
  }

  public playGunshot(weaponId: WeaponId, distanceAttenuation = 1.0): void {
    const ctx = this.ensureContext();
    if (!ctx || !this.noiseBuffer) return;

    const now = ctx.currentTime;
    const pitchVar = 0.92 + Math.random() * 0.16;
    const gainScale = Math.max(0.05, Math.min(1, distanceAttenuation));

    if (weaponId === 'karambit') {
      const noise = ctx.createBufferSource();
      noise.buffer = this.noiseBuffer;
      const filter = ctx.createBiquadFilter();
      filter.type = 'bandpass';
      filter.frequency.setValueAtTime(1600 * pitchVar, now);
      filter.frequency.exponentialRampToValueAtTime(420, now + 0.12);
      const gain = ctx.createGain();
      gain.gain.setValueAtTime(0.22 * gainScale, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.13);
      noise.connect(filter).connect(gain).connect(ctx.destination);
      noise.start(now);
      noise.stop(now + 0.14);
      return;
    }

    const isSilenced = weaponId === 'm4a1s' || weaponId === 'usps';
    const isSniper = weaponId === 'awp';
    const isShotgun = weaponId === 'nova';
    const isDeagle = weaponId === 'deagle';

    // Transient punch oscillator
    const osc = ctx.createOscillator();
    osc.type = isSniper || isDeagle ? 'sawtooth' : 'triangle';
    const startFreq = isSilenced ? 260 : isSniper ? 190 : isShotgun ? 140 : isDeagle ? 240 : 210;
    osc.frequency.setValueAtTime(startFreq * pitchVar, now);
    osc.frequency.exponentialRampToValueAtTime(38, now + (isSniper ? 0.22 : 0.09));

    const oscGain = ctx.createGain();
    oscGain.gain.setValueAtTime((isSilenced ? 0.18 : isSniper ? 0.42 : 0.3) * gainScale, now);
    oscGain.gain.exponentialRampToValueAtTime(0.001, now + (isSniper ? 0.25 : 0.11));
    osc.connect(oscGain).connect(ctx.destination);
    osc.start(now);
    osc.stop(now + (isSniper ? 0.26 : 0.12));

    // Gunpowder crack noise burst
    const noise = ctx.createBufferSource();
    noise.buffer = this.noiseBuffer;
    const filter = ctx.createBiquadFilter();
    filter.type = isSilenced ? 'bandpass' : 'lowpass';
    filter.frequency.setValueAtTime(
      isSilenced ? 1800 * pitchVar : isSniper ? 4200 : isShotgun ? 2400 : 3400 * pitchVar,
      now,
    );
    if (!isSilenced) {
      filter.frequency.exponentialRampToValueAtTime(280, now + (isSniper ? 0.35 : 0.16));
    }

    const noiseGain = ctx.createGain();
    const peak = isSilenced ? 0.14 : isSniper ? 0.48 : isShotgun ? 0.42 : isDeagle ? 0.36 : 0.28;
    const dur = isSilenced ? 0.075 : isSniper ? 0.42 : isShotgun ? 0.26 : 0.16;
    noiseGain.gain.setValueAtTime(peak * gainScale, now);
    noiseGain.gain.exponentialRampToValueAtTime(0.001, now + dur);

    noise.connect(filter).connect(noiseGain).connect(ctx.destination);
    noise.start(now);
    noise.stop(now + dur + 0.02);

    // AWP bolt cycle clack
    if (isSniper && distanceAttenuation > 0.7) {
      this.playMetallicClick(0.32, 920);
      this.playMetallicClick(0.46, 1180);
    }
  }

  public playMetallicClick(delay = 0, freq = 1100): void {
    const ctx = this.ensureContext();
    if (!ctx) return;
    const now = ctx.currentTime + delay;
    const osc = ctx.createOscillator();
    osc.type = 'square';
    osc.frequency.setValueAtTime(freq, now);
    osc.frequency.exponentialRampToValueAtTime(freq * 0.45, now + 0.035);
    const gain = ctx.createGain();
    gain.gain.setValueAtTime(0.08, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + 0.04);
    osc.connect(gain).connect(ctx.destination);
    osc.start(now);
    osc.stop(now + 0.045);
  }

  public playReload(): void {
    this.playMetallicClick(0.05, 760);
    this.playMetallicClick(0.55, 1020);
    this.playMetallicClick(1.15, 1340);
  }

  public playHitmarker(headshot: boolean): void {
    const ctx = this.ensureContext();
    if (!ctx) return;
    const now = ctx.currentTime;
    const osc = ctx.createOscillator();
    osc.type = headshot ? 'triangle' : 'sine';
    osc.frequency.setValueAtTime(headshot ? 1950 : 920, now);
    osc.frequency.exponentialRampToValueAtTime(headshot ? 2900 : 480, now + 0.065);
    const gain = ctx.createGain();
    gain.gain.setValueAtTime(headshot ? 0.24 : 0.14, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + 0.075);
    osc.connect(gain).connect(ctx.destination);
    osc.start(now);
    osc.stop(now + 0.08);
  }

  public playPlayerHurt(): void {
    const ctx = this.ensureContext();
    if (!ctx) return;
    const now = ctx.currentTime;
    const osc = ctx.createOscillator();
    osc.type = 'sawtooth';
    osc.frequency.setValueAtTime(140, now);
    osc.frequency.exponentialRampToValueAtTime(48, now + 0.14);
    const gain = ctx.createGain();
    gain.gain.setValueAtTime(0.24, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + 0.15);
    osc.connect(gain).connect(ctx.destination);
    osc.start(now);
    osc.stop(now + 0.16);
  }

  public playFootstep(): void {
    const ctx = this.ensureContext();
    if (!ctx || !this.noiseBuffer) return;
    const now = ctx.currentTime;
    const noise = ctx.createBufferSource();
    noise.buffer = this.noiseBuffer;
    const filter = ctx.createBiquadFilter();
    filter.type = 'lowpass';
    filter.frequency.setValueAtTime(340 + Math.random() * 120, now);
    const gain = ctx.createGain();
    gain.gain.setValueAtTime(0.065, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + 0.065);
    noise.connect(filter).connect(gain).connect(ctx.destination);
    noise.start(now);
    noise.stop(now + 0.07);
  }

  public playGrenadeBounce(): void {
    this.playMetallicClick(0, 620 + Math.random() * 140);
  }

  public playExplosion(isFlash: boolean): void {
    const ctx = this.ensureContext();
    if (!ctx || !this.noiseBuffer) return;
    const now = ctx.currentTime;

    if (isFlash) {
      // Sharp crack + high tinnitus ring
      const noise = ctx.createBufferSource();
      noise.buffer = this.noiseBuffer;
      const filter = ctx.createBiquadFilter();
      filter.type = 'highpass';
      filter.frequency.setValueAtTime(1800, now);
      const gain = ctx.createGain();
      gain.gain.setValueAtTime(0.35, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.25);
      noise.connect(filter).connect(gain).connect(ctx.destination);
      noise.start(now);
      noise.stop(now + 0.26);

      const ring = ctx.createOscillator();
      ring.type = 'sine';
      ring.frequency.setValueAtTime(3400, now);
      const ringGain = ctx.createGain();
      ringGain.gain.setValueAtTime(0.09, now);
      ringGain.gain.exponentialRampToValueAtTime(0.001, now + 1.1);
      ring.connect(ringGain).connect(ctx.destination);
      ring.start(now);
      ring.stop(now + 1.15);
      return;
    }

    // HE Frag deep bass boom
    const osc = ctx.createOscillator();
    osc.type = 'sine';
    osc.frequency.setValueAtTime(115, now);
    osc.frequency.exponentialRampToValueAtTime(24, now + 0.55);
    const oscGain = ctx.createGain();
    oscGain.gain.setValueAtTime(0.55, now);
    oscGain.gain.exponentialRampToValueAtTime(0.001, now + 0.6);
    osc.connect(oscGain).connect(ctx.destination);
    osc.start(now);
    osc.stop(now + 0.62);

    const noise = ctx.createBufferSource();
    noise.buffer = this.noiseBuffer;
    const filter = ctx.createBiquadFilter();
    filter.type = 'lowpass';
    filter.frequency.setValueAtTime(1600, now);
    filter.frequency.exponentialRampToValueAtTime(160, now + 0.7);
    const noiseGain = ctx.createGain();
    noiseGain.gain.setValueAtTime(0.45, now);
    noiseGain.gain.exponentialRampToValueAtTime(0.001, now + 0.72);
    noise.connect(filter).connect(noiseGain).connect(ctx.destination);
    noise.start(now);
    noise.stop(now + 0.75);
  }

  public playRoundSting(victory: boolean): void {
    const ctx = this.ensureContext();
    if (!ctx) return;
    const now = ctx.currentTime;
    const notes = victory ? [440, 554.37, 659.25] : [330, 293.66, 220];
    notes.forEach((freq, idx) => {
      const osc = ctx.createOscillator();
      osc.type = 'triangle';
      osc.frequency.setValueAtTime(freq, now + idx * 0.11);
      const gain = ctx.createGain();
      gain.gain.setValueAtTime(0.14, now + idx * 0.11);
      gain.gain.exponentialRampToValueAtTime(0.001, now + idx * 0.11 + 0.28);
      osc.connect(gain).connect(ctx.destination);
      osc.start(now + idx * 0.11);
      osc.stop(now + idx * 0.11 + 0.3);
    });
  }
}

export const tacticalAudio = new TacticalAudio();
