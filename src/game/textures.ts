import * as THREE from 'three';

export interface TacticalTextureSet {
  sandstoneColor: THREE.CanvasTexture;
  sandstoneBump: THREE.CanvasTexture;
  concreteWallColor: THREE.CanvasTexture;
  concreteWallBump: THREE.CanvasTexture;
  woodCrateColor: THREE.CanvasTexture;
  woodCrateBump: THREE.CanvasTexture;
  metalContainerColor: THREE.CanvasTexture;
  metalContainerBump: THREE.CanvasTexture;
  dispose: () => void;
}

function makeCanvas(size = 256): [HTMLCanvasElement, CanvasRenderingContext2D] {
  const canvas = document.createElement('canvas');
  canvas.width = size;
  canvas.height = size;
  const ctx = canvas.getContext('2d')!;
  return [canvas, ctx];
}

function finalizeTexture(
  canvas: HTMLCanvasElement,
  isColor: boolean,
  repeatX: number,
  repeatY: number,
  maxAniso: number,
): THREE.CanvasTexture {
  const tex = new THREE.CanvasTexture(canvas);
  tex.wrapS = THREE.RepeatWrapping;
  tex.wrapT = THREE.RepeatWrapping;
  tex.repeat.set(repeatX, repeatY);
  tex.anisotropy = maxAniso;
  if (isColor) {
    tex.colorSpace = THREE.SRGBColorSpace;
  }
  return tex;
}

export function createTacticalTextures(renderer: THREE.WebGLRenderer): TacticalTextureSet {
  const maxAniso = renderer.capabilities.getMaxAnisotropy();

  // 1. Sandstone Dust Courtyard Floor (Albedo + Bump)
  const [sandC, sandCtx] = makeCanvas(256);
  const [sandB, sandBCtx] = makeCanvas(256);
  sandCtx.fillStyle = '#c8aa7e';
  sandCtx.fillRect(0, 0, 256, 256);
  sandBCtx.fillStyle = '#808080';
  sandBCtx.fillRect(0, 0, 256, 256);

  // Tile seams & grit
  for (let i = 0; i < 1800; i++) {
    const x = Math.random() * 256;
    const y = Math.random() * 256;
    const r = 1 + Math.random() * 2.5;
    const shade = Math.random() > 0.5 ? 'rgba(255,240,210,0.16)' : 'rgba(110,85,55,0.15)';
    sandCtx.fillStyle = shade;
    sandCtx.fillRect(x, y, r, r);

    const bVal = Math.floor(110 + Math.random() * 45);
    sandBCtx.fillStyle = `rgb(${bVal},${bVal},${bVal})`;
    sandBCtx.fillRect(x, y, r, r);
  }
  sandCtx.strokeStyle = 'rgba(92, 72, 48, 0.28)';
  sandCtx.lineWidth = 2;
  sandBCtx.strokeStyle = '#383838';
  sandBCtx.lineWidth = 3;
  for (let g = 0; g <= 256; g += 64) {
    sandCtx.beginPath();
    sandCtx.moveTo(g, 0);
    sandCtx.lineTo(g, 256);
    sandCtx.stroke();
    sandCtx.beginPath();
    sandCtx.moveTo(0, g);
    sandCtx.lineTo(256, g);
    sandCtx.stroke();

    sandBCtx.beginPath();
    sandBCtx.moveTo(g, 0);
    sandBCtx.lineTo(g, 256);
    sandBCtx.stroke();
    sandBCtx.beginPath();
    sandBCtx.moveTo(0, g);
    sandBCtx.lineTo(256, g);
    sandBCtx.stroke();
  }

  // 2. Weathered Concrete / Sandstone Wall
  const [wallC, wallCtx] = makeCanvas(256);
  const [wallB, wallBCtx] = makeCanvas(256);
  wallCtx.fillStyle = '#b99f7c';
  wallCtx.fillRect(0, 0, 256, 256);
  wallBCtx.fillStyle = '#848484';
  wallBCtx.fillRect(0, 0, 256, 256);

  // Horizontal plaster bands & masonry blocks
  for (let y = 0; y < 256; y += 32) {
    wallCtx.fillStyle = y % 64 === 0 ? 'rgba(130, 108, 78, 0.12)' : 'rgba(240, 224, 195, 0.08)';
    wallCtx.fillRect(0, y, 256, 30);
    wallCtx.fillStyle = 'rgba(72, 58, 42, 0.25)';
    wallCtx.fillRect(0, y + 30, 256, 2);
    wallBCtx.fillStyle = '#484848';
    wallBCtx.fillRect(0, y + 30, 256, 2);
  }
  for (let i = 0; i < 900; i++) {
    const x = Math.random() * 256;
    const y = Math.random() * 256;
    wallCtx.fillStyle = Math.random() > 0.5 ? 'rgba(85,68,48,0.12)' : 'rgba(255,245,225,0.1)';
    wallCtx.fillRect(x, y, 2, 2);
  }

  // 3. Tactical Wooden Supply Crate
  const [woodC, woodCtx] = makeCanvas(256);
  const [woodB, woodBCtx] = makeCanvas(256);
  woodCtx.fillStyle = '#9c7144';
  woodCtx.fillRect(0, 0, 256, 256);
  woodBCtx.fillStyle = '#808080';
  woodBCtx.fillRect(0, 0, 256, 256);

  for (let y = 0; y < 256; y += 32) {
    woodCtx.fillStyle = y % 64 === 0 ? '#a97b4c' : '#91673c';
    woodCtx.fillRect(16, y, 224, 30);
    woodCtx.fillStyle = '#52381e';
    woodCtx.fillRect(16, y + 30, 224, 2);
    woodBCtx.fillStyle = '#303030';
    woodBCtx.fillRect(16, y + 30, 224, 2);
  }
  // Crate frame & diagonal brace
  woodCtx.strokeStyle = '#75512d';
  woodCtx.lineWidth = 22;
  woodCtx.strokeRect(11, 11, 234, 234);
  woodCtx.beginPath();
  woodCtx.moveTo(18, 18);
  woodCtx.lineTo(238, 238);
  woodCtx.stroke();

  woodBCtx.strokeStyle = '#c8c8c8';
  woodBCtx.lineWidth = 22;
  woodBCtx.strokeRect(11, 11, 234, 234);
  woodBCtx.beginPath();
  woodBCtx.moveTo(18, 18);
  woodBCtx.lineTo(238, 238);
  woodBCtx.stroke();

  // 4. Corrugated Shipping Container Steel
  const [metC, metCtx] = makeCanvas(256);
  const [metB, metBCtx] = makeCanvas(256);
  metCtx.fillStyle = '#334d5c';
  metCtx.fillRect(0, 0, 256, 256);
  metBCtx.fillStyle = '#808080';
  metBCtx.fillRect(0, 0, 256, 256);

  for (let x = 0; x < 256; x += 16) {
    metCtx.fillStyle = 'rgba(255,255,255,0.09)';
    metCtx.fillRect(x, 0, 6, 256);
    metCtx.fillStyle = 'rgba(0,0,0,0.22)';
    metCtx.fillRect(x + 8, 0, 6, 256);

    metBCtx.fillStyle = '#cfcfcf';
    metBCtx.fillRect(x, 0, 7, 256);
    metBCtx.fillStyle = '#3a3a3a';
    metBCtx.fillRect(x + 8, 0, 7, 256);
  }

  const sandstoneColor = finalizeTexture(sandC, true, 24, 24, maxAniso);
  const sandstoneBump = finalizeTexture(sandB, false, 24, 24, maxAniso);
  const concreteWallColor = finalizeTexture(wallC, true, 2, 1, maxAniso);
  const concreteWallBump = finalizeTexture(wallB, false, 2, 1, maxAniso);
  const woodCrateColor = finalizeTexture(woodC, true, 1, 1, maxAniso);
  const woodCrateBump = finalizeTexture(woodB, false, 1, 1, maxAniso);
  const metalContainerColor = finalizeTexture(metC, true, 2, 1, maxAniso);
  const metalContainerBump = finalizeTexture(metB, false, 2, 1, maxAniso);

  return {
    sandstoneColor,
    sandstoneBump,
    concreteWallColor,
    concreteWallBump,
    woodCrateColor,
    woodCrateBump,
    metalContainerColor,
    metalContainerBump,
    dispose: () => {
      sandstoneColor.dispose();
      sandstoneBump.dispose();
      concreteWallColor.dispose();
      concreteWallBump.dispose();
      woodCrateColor.dispose();
      woodCrateBump.dispose();
      metalContainerColor.dispose();
      metalContainerBump.dispose();
    },
  };
}
