import * as THREE from 'three';
import { BotArchetype, WeaponId } from './types';

export interface BotRig {
  root: THREE.Group;
  bodyPivot: THREE.Group;
  legL: THREE.Group;
  legR: THREE.Group;
  armR: THREE.Group;
  headGroup: THREE.Group;
  visorMesh: THREE.Mesh;
  visorMat: THREE.MeshStandardMaterial;
  armorMat: THREE.MeshStandardMaterial;
  muzzlePoint: THREE.Object3D;
  contactShadow: THREE.Mesh;
  hitMeshes: THREE.Mesh[];
}

export interface ViewModelRig {
  root: THREE.Group;
  muzzlePoint: THREE.Object3D;
  slideOrBolt?: THREE.Object3D;
}

const sharedMats = {
  gunmetalDark: new THREE.MeshStandardMaterial({ color: 0x22262b, roughness: 0.35, metalness: 0.85 }),
  gunmetalSteel: new THREE.MeshStandardMaterial({ color: 0x5c646d, roughness: 0.25, metalness: 0.9 }),
  chromeSlide: new THREE.MeshStandardMaterial({ color: 0xbec7d0, roughness: 0.16, metalness: 0.96 }),
  polymerBlack: new THREE.MeshStandardMaterial({ color: 0x1a1c20, roughness: 0.78, metalness: 0.1 }),
  woodWalnut: new THREE.MeshStandardMaterial({ color: 0x7c4624, roughness: 0.65, metalness: 0.05 }),
  awpOlive: new THREE.MeshStandardMaterial({ color: 0x455a36, roughness: 0.68, metalness: 0.12 }),
  bladeTitanium: new THREE.MeshStandardMaterial({ color: 0xd4dde6, roughness: 0.14, metalness: 0.98 }),
  karambitAccent: new THREE.MeshStandardMaterial({ color: 0xd97706, roughness: 0.3, metalness: 0.75 }),
  scopeGlass: new THREE.MeshStandardMaterial({
    color: 0x2299cc,
    roughness: 0.08,
    metalness: 0.9,
    emissive: 0x0a384c,
    emissiveIntensity: 0.6,
  }),
  gloveMat: new THREE.MeshStandardMaterial({ color: 0x2a2d34, roughness: 0.85, metalness: 0.05 }),
  sleeveMat: new THREE.MeshStandardMaterial({ color: 0x3b443b, roughness: 0.88, metalness: 0.02 }),
  heBody: new THREE.MeshStandardMaterial({ color: 0x3f4e37, roughness: 0.58, metalness: 0.3 }),
  flashBody: new THREE.MeshStandardMaterial({ color: 0x9aa3ad, roughness: 0.35, metalness: 0.75 }),
  grenadeBand: new THREE.MeshStandardMaterial({ color: 0xd97706, roughness: 0.4, metalness: 0.4 }),
};

function addBox(
  parent: THREE.Object3D,
  w: number,
  h: number,
  d: number,
  x: number,
  y: number,
  z: number,
  mat: THREE.Material,
  rx = 0,
  ry = 0,
  rz = 0,
): THREE.Mesh {
  const mesh = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), mat);
  mesh.position.set(x, y, z);
  mesh.rotation.set(rx, ry, rz);
  parent.add(mesh);
  return mesh;
}

function addCyl(
  parent: THREE.Object3D,
  rt: number,
  rb: number,
  h: number,
  x: number,
  y: number,
  z: number,
  mat: THREE.Material,
  rx = Math.PI / 2,
  seg = 12,
): THREE.Mesh {
  const mesh = new THREE.Mesh(new THREE.CylinderGeometry(rt, rb, h, seg), mat);
  mesh.position.set(x, y, z);
  mesh.rotation.x = rx;
  parent.add(mesh);
  return mesh;
}

/**
 * Builds a composite 6-10 part first-person weapon viewmodel oriented down -Z.
 */
export function buildViewModel(weaponId: WeaponId): ViewModelRig {
  const root = new THREE.Group();
  const muzzlePoint = new THREE.Object3D();
  muzzlePoint.position.set(0, 0.04, -0.78);
  root.add(muzzlePoint);

  // Supporting tactical forearm/gloves
  addBox(root, 0.075, 0.075, 0.28, 0.03, -0.1, 0.24, sharedMats.sleeveMat, 0.18, -0.12, 0);
  addBox(root, 0.068, 0.065, 0.1, 0.01, -0.055, 0.09, sharedMats.gloveMat, 0.05, 0, 0);

  let slideOrBolt: THREE.Object3D | undefined;

  if (weaponId === 'ak47') {
    // Receiver, dust cover, wooden stock, wooden handguard, barrel, gas tube, front sight, curved banana mag
    addBox(root, 0.052, 0.072, 0.34, 0, 0, -0.04, sharedMats.gunmetalDark);
    addBox(root, 0.046, 0.024, 0.26, 0, 0.042, -0.02, sharedMats.gunmetalSteel);
    addBox(root, 0.044, 0.085, 0.24, 0, -0.02, 0.24, sharedMats.woodWalnut, 0.14);
    addBox(root, 0.05, 0.062, 0.22, 0, -0.005, -0.31, sharedMats.woodWalnut);
    addBox(root, 0.034, 0.095, 0.048, 0, -0.08, 0.05, sharedMats.woodWalnut, -0.35); // grip
    addCyl(root, 0.011, 0.012, 0.38, 0, 0.014, -0.52, sharedMats.gunmetalSteel); // barrel
    addCyl(root, 0.009, 0.009, 0.22, 0, 0.034, -0.35, sharedMats.gunmetalDark); // gas tube
    addBox(root, 0.012, 0.038, 0.02, 0, 0.036, -0.66, sharedMats.gunmetalDark); // front sight post
    // Curved banana magazine (2 angled segments)
    addBox(root, 0.032, 0.13, 0.065, 0, -0.09, -0.11, sharedMats.gunmetalSteel, 0.22);
    addBox(root, 0.031, 0.11, 0.062, 0, -0.19, -0.15, sharedMats.gunmetalDark, 0.45);
    // Support left hand tucked beneath handguard
    addBox(root, 0.056, 0.044, 0.1, -0.015, -0.044, -0.28, sharedMats.gloveMat, 0.08, 0.16, 0);
    muzzlePoint.position.set(0, 0.014, -0.72);
  } else if (weaponId === 'm4a1s') {
    addBox(root, 0.05, 0.068, 0.32, 0, 0, -0.04, sharedMats.gunmetalDark);
    addBox(root, 0.048, 0.022, 0.36, 0, 0.044, -0.14, sharedMats.polymerBlack); // picatinny rail
    addBox(root, 0.046, 0.07, 0.22, 0, -0.01, 0.22, sharedMats.polymerBlack); // crane stock
    addBox(root, 0.052, 0.058, 0.23, 0, 0.002, -0.3, sharedMats.polymerBlack); // quad rail
    addBox(root, 0.032, 0.095, 0.045, 0, -0.08, 0.05, sharedMats.polymerBlack, -0.32);
    addBox(root, 0.03, 0.16, 0.058, 0, -0.11, -0.1, sharedMats.gunmetalSteel, 0.08); // STANAG mag
    // Optic holo sight + suppressor
    addBox(root, 0.038, 0.042, 0.075, 0, 0.07, -0.06, sharedMats.gunmetalDark);
    addBox(root, 0.028, 0.026, 0.01, 0, 0.07, -0.09, sharedMats.scopeGlass);
    addCyl(root, 0.018, 0.018, 0.26, 0, 0.01, -0.56, sharedMats.gunmetalSteel); // suppressor
    addBox(root, 0.056, 0.044, 0.1, -0.015, -0.044, -0.27, sharedMats.gloveMat, 0.08, 0.16, 0);
    muzzlePoint.position.set(0, 0.01, -0.7);
  } else if (weaponId === 'awp') {
    // Iconic Arctic Warfare Police silhouette
    addBox(root, 0.056, 0.078, 0.46, 0, -0.008, -0.06, sharedMats.awpOlive);
    addBox(root, 0.052, 0.095, 0.26, 0, -0.02, 0.24, sharedMats.awpOlive); // thumbhole stock
    addBox(root, 0.048, 0.042, 0.22, 0, 0.038, -0.04, sharedMats.gunmetalDark); // receiver
    addCyl(root, 0.013, 0.015, 0.56, 0, 0.03, -0.52, sharedMats.gunmetalSteel); // fluted barrel
    addBox(root, 0.028, 0.026, 0.05, 0, 0.03, -0.8, sharedMats.gunmetalDark); // muzzle brake
    // Scope mounts + long tube + lenses
    addBox(root, 0.024, 0.034, 0.024, 0, 0.065, -0.12, sharedMats.gunmetalDark);
    addBox(root, 0.024, 0.034, 0.024, 0, 0.065, 0.02, sharedMats.gunmetalDark);
    addCyl(root, 0.024, 0.02, 0.34, 0, 0.092, -0.07, sharedMats.gunmetalDark);
    addCyl(root, 0.021, 0.021, 0.012, 0, 0.092, 0.1, sharedMats.scopeGlass);
    // Bolt handle
    const bolt = addBox(root, 0.045, 0.012, 0.012, 0.036, 0.042, 0.04, sharedMats.chromeSlide);
    slideOrBolt = bolt;
    muzzlePoint.position.set(0, 0.03, -0.82);
  } else if (weaponId === 'p90') {
    addBox(root, 0.054, 0.09, 0.42, 0, -0.01, -0.06, sharedMats.polymerBlack);
    addBox(root, 0.048, 0.035, 0.28, 0, 0.045, -0.04, sharedMats.gunmetalSteel); // top horizontal mag
    addBox(root, 0.042, 0.04, 0.08, 0, 0.08, -0.12, sharedMats.gunmetalDark); // rail
    addCyl(root, 0.012, 0.012, 0.14, 0, 0.008, -0.32, sharedMats.gunmetalSteel);
    addBox(root, 0.065, 0.055, 0.1, -0.03, -0.05, -0.22, sharedMats.gloveMat);
    muzzlePoint.position.set(0, 0.008, -0.4);
  } else if (weaponId === 'nova') {
    addBox(root, 0.052, 0.068, 0.28, 0, 0, -0.02, sharedMats.gunmetalDark);
    addBox(root, 0.044, 0.082, 0.26, 0, -0.025, 0.23, sharedMats.polymerBlack, 0.18);
    addCyl(root, 0.015, 0.015, 0.48, 0, 0.022, -0.38, sharedMats.gunmetalSteel); // barrel
    addCyl(root, 0.013, 0.013, 0.42, 0, -0.008, -0.35, sharedMats.gunmetalDark); // mag tube
    const pump = addBox(root, 0.056, 0.052, 0.17, 0, -0.016, -0.32, sharedMats.polymerBlack);
    slideOrBolt = pump;
    addBox(root, 0.065, 0.055, 0.11, -0.03, -0.045, -0.32, sharedMats.gloveMat);
    muzzlePoint.position.set(0, 0.022, -0.63);
  } else if (weaponId === 'deagle') {
    addBox(root, 0.044, 0.042, 0.24, 0, 0.01, -0.1, sharedMats.gunmetalDark); // frame
    const slide = addBox(root, 0.046, 0.044, 0.27, 0, 0.038, -0.11, sharedMats.chromeSlide); // heavy chrome slide
    slideOrBolt = slide;
    addBox(root, 0.038, 0.105, 0.058, 0, -0.055, -0.01, sharedMats.polymerBlack, -0.28);
    addBox(root, 0.014, 0.016, 0.018, 0, 0.065, -0.22, sharedMats.gunmetalDark); // front sight
    muzzlePoint.position.set(0, 0.038, -0.26);
  } else if (weaponId === 'usps') {
    addBox(root, 0.038, 0.034, 0.19, 0, 0.008, -0.08, sharedMats.polymerBlack);
    const slide = addBox(root, 0.04, 0.034, 0.21, 0, 0.032, -0.09, sharedMats.gunmetalDark);
    slideOrBolt = slide;
    addCyl(root, 0.015, 0.015, 0.18, 0, 0.025, -0.28, sharedMats.gunmetalSteel); // suppressor
    addBox(root, 0.034, 0.095, 0.05, 0, -0.048, -0.01, sharedMats.polymerBlack, -0.25);
    muzzlePoint.position.set(0, 0.025, -0.38);
  } else if (weaponId === 'karambit') {
    // Curved Karambit claw + finger ring
    addBox(root, 0.024, 0.095, 0.032, 0, -0.01, -0.05, sharedMats.polymerBlack, 0.45);
    addCyl(root, 0.018, 0.018, 0.022, 0, -0.05, -0.02, sharedMats.karambitAccent, 0, 14);
    const bladeShape = new THREE.Shape();
    bladeShape.moveTo(0, 0);
    bladeShape.quadraticCurveTo(0.06, 0.06, 0.02, 0.16);
    bladeShape.quadraticCurveTo(-0.01, 0.08, -0.022, 0.01);
    bladeShape.closePath();
    const bladeGeo = new THREE.ExtrudeGeometry(bladeShape, { depth: 0.006, bevelEnabled: true, bevelSize: 0.002, bevelThickness: 0.002 });
    const blade = new THREE.Mesh(bladeGeo, sharedMats.bladeTitanium);
    blade.position.set(-0.003, 0.02, -0.08);
    blade.rotation.set(-0.9, Math.PI / 2, 0);
    root.add(blade);
    muzzlePoint.position.set(0, 0.02, -0.25);
  } else {
    // HE Grenade or Flashbang
    const bodyMat = weaponId === 'he_grenade' ? sharedMats.heBody : sharedMats.flashBody;
    addCyl(root, 0.042, 0.042, 0.11, 0, 0.01, -0.1, bodyMat, 0, 14);
    addCyl(root, 0.044, 0.044, 0.02, 0, 0.02, -0.1, sharedMats.grenadeBand, 0, 14);
    addBox(root, 0.022, 0.04, 0.028, 0, 0.075, -0.1, sharedMats.gunmetalSteel);
    muzzlePoint.position.set(0, 0.02, -0.22);
  }

  return { root, muzzlePoint, slideOrBolt };
}

/**
 * Builds an articulated 10-part tactical Bot rig pivoted at bottom-center (y=0).
 */
export function buildBotRig(archetype: BotArchetype, castShadow: boolean): BotRig {
  const root = new THREE.Group();
  const bodyPivot = new THREE.Group();
  root.add(bodyPivot);

  const primaryColor =
    archetype === 'entry' ? 0x8a3d2b : archetype === 'sniper' ? 0x2f4338 : 0x3b4859;
  const armorMat = new THREE.MeshStandardMaterial({
    color: primaryColor,
    roughness: 0.72,
    metalness: 0.15,
  });
  const pantsMat = new THREE.MeshStandardMaterial({
    color: 0x2c3036,
    roughness: 0.85,
    metalness: 0.05,
  });
  const bootMat = new THREE.MeshStandardMaterial({
    color: 0x181a1d,
    roughness: 0.9,
    metalness: 0.08,
  });
  const helmetMat = new THREE.MeshStandardMaterial({
    color: 0x22262b,
    roughness: 0.45,
    metalness: 0.45,
  });
  const visorMat = new THREE.MeshStandardMaterial({
    color: 0xf59e0b,
    emissive: 0xd97706,
    emissiveIntensity: 0.9,
    roughness: 0.2,
    metalness: 0.8,
  });

  const hitMeshes: THREE.Mesh[] = [];

  // Legs (pivoted at hip y = 0.85)
  const legL = new THREE.Group();
  legL.position.set(-0.15, 0.85, 0);
  const thighL = addBox(legL, 0.19, 0.68, 0.21, 0, -0.34, 0, pantsMat);
  const bootL = addBox(legL, 0.21, 0.18, 0.28, 0, -0.76, 0.03, bootMat);
  thighL.userData.hitRegion = 'limb';
  bootL.userData.hitRegion = 'limb';
  hitMeshes.push(thighL, bootL);
  bodyPivot.add(legL);

  const legR = new THREE.Group();
  legR.position.set(0.15, 0.85, 0);
  const thighR = addBox(legR, 0.19, 0.68, 0.21, 0, -0.34, 0, pantsMat);
  const bootR = addBox(legR, 0.21, 0.18, 0.28, 0, -0.76, 0.03, bootMat);
  thighR.userData.hitRegion = 'limb';
  bootR.userData.hitRegion = 'limb';
  hitMeshes.push(thighR, bootR);
  bodyPivot.add(legR);

  // Armored Torso + Tactical Vest + Backpack
  const torso = addBox(bodyPivot, 0.48, 0.64, 0.28, 0, 1.18, 0, armorMat);
  const vestPlate = addBox(bodyPivot, 0.42, 0.46, 0.33, 0, 1.2, 0.01, helmetMat);
  const backpack = addBox(bodyPivot, 0.32, 0.42, 0.16, 0, 1.21, -0.2, pantsMat);
  torso.userData.hitRegion = 'chest';
  vestPlate.userData.hitRegion = 'chest';
  backpack.userData.hitRegion = 'chest';
  hitMeshes.push(torso, vestPlate, backpack);

  // Head + Helmet + Glowing Tactical Visor
  const headGroup = new THREE.Group();
  headGroup.position.set(0, 1.66, 0);
  const cranium = new THREE.Mesh(new THREE.SphereGeometry(0.155, 14, 12), helmetMat);
  cranium.userData.hitRegion = 'head';
  headGroup.add(cranium);
  const helmetRim = addBox(headGroup, 0.34, 0.14, 0.34, 0, 0.05, 0, helmetMat);
  helmetRim.userData.hitRegion = 'head';
  const visorMesh = addBox(headGroup, 0.24, 0.065, 0.06, 0, 0.01, 0.145, visorMat);
  visorMesh.userData.hitRegion = 'head';
  hitMeshes.push(cranium, helmetRim, visorMesh);
  bodyPivot.add(headGroup);

  // Left Shoulder/Arm
  const armL = addBox(bodyPivot, 0.14, 0.48, 0.14, -0.32, 1.22, 0.1, armorMat, -0.55);
  armL.userData.hitRegion = 'limb';
  hitMeshes.push(armL);

  // Right Aiming Arm + Bot Weapon
  const armR = new THREE.Group();
  armR.position.set(0.3, 1.38, 0.05);
  const armMesh = addBox(armR, 0.14, 0.14, 0.44, 0, -0.06, 0.2, armorMat);
  armMesh.userData.hitRegion = 'limb';
  hitMeshes.push(armMesh);

  // Bot Weapon silhouette (faces +Z in bot local space so lookAt works naturally!)
  const gunBody = addBox(armR, 0.06, 0.09, 0.56, -0.05, -0.02, 0.45, sharedMats.gunmetalDark);
  const gunBarrel = addCyl(
    armR,
    0.016,
    0.016,
    archetype === 'sniper' ? 0.55 : 0.35,
    -0.05,
    0.0,
    archetype === 'sniper' ? 0.92 : 0.82,
    sharedMats.gunmetalSteel,
  );
  gunBody.userData.hitRegion = 'limb';
  gunBarrel.userData.hitRegion = 'limb';
  if (archetype === 'sniper') {
    addCyl(armR, 0.022, 0.02, 0.26, -0.05, 0.06, 0.48, sharedMats.gunmetalDark);
  }

  const muzzlePoint = new THREE.Object3D();
  muzzlePoint.position.set(-0.05, 0.0, archetype === 'sniper' ? 1.2 : 1.0);
  armR.add(muzzlePoint);
  bodyPivot.add(armR);

  // Contact shadow disc grounded at y = 0.015
  const shadowGeo = new THREE.CircleGeometry(0.55, 20);
  shadowGeo.rotateX(-Math.PI / 2);
  const shadowMat = new THREE.MeshBasicMaterial({
    color: 0x0b0a08,
    transparent: true,
    opacity: 0.42,
    depthWrite: false,
  });
  const contactShadow = new THREE.Mesh(shadowGeo, shadowMat);
  contactShadow.position.y = 0.015;
  root.add(contactShadow);

  root.traverse((obj) => {
    if ((obj as THREE.Mesh).isMesh && obj !== contactShadow) {
      obj.castShadow = castShadow;
      obj.receiveShadow = true;
    }
  });

  return {
    root,
    bodyPivot,
    legL,
    legR,
    armR,
    headGroup,
    visorMesh,
    visorMat,
    armorMat,
    muzzlePoint,
    contactShadow,
    hitMeshes,
  };
}
