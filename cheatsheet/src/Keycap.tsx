import { useMemo, useRef } from 'react'
import { useFrame } from '@react-three/fiber'
import { RoundedBox, Text } from '@react-three/drei'
import { useSpring, animated } from '@react-spring/three'
import * as THREE from 'three'
import { SVGLoader } from 'three/examples/jsm/loaders/SVGLoader.js'
import type { KeyDef } from './glove80Layout'
import type { SpecialIcon } from './glove80Layout'
import { THEME } from './theme'

const AnimatedGroup = animated('group')

// A clearly different accent than the per-layer recolor: a hot mint glow on the
// thumb you HOLD to reach the active layer.
const ACTIVATOR_COLOR = new THREE.Color('#aaff6a')
// Home-row-mod glow: a distinct electric azure, separate from the mint
// activator and the warm-pink keypress bloom.
const MOD_COLOR = new THREE.Color('#3fd2ff')

interface KeycapProps {
  def: KeyDef
  /** Primary (tap) legend for the current layer. */
  tap: string
  /** Secondary (hold) legend for the current layer, if any. */
  hold?: string
  /** App-icon to draw on the cap instead of a plain text glyph. */
  icon?: SpecialIcon
  /** This cap is the thumb that activates the current layer. */
  isActivator?: boolean
  /** A home-row modifier is currently held — light this cap in the mod color. */
  modHeld?: boolean
  pressed: boolean
  /** Highlighted by the tutorial right now. */
  highlighted: boolean
  /** Layer accent color (hex). */
  accent: string
  /** Distance used to stagger the layer-switch ripple. */
  rippleDelay: number
  /** performance.now of the last layer switch. */
  pulseAt: number
}

// Cherry Blossom cap colorway: plum thumb/mod caps, deeper-rose fn accents,
// sakura-pink alphas everywhere else.
function capColor(def: KeyDef): string {
  if (def.section === 'thumb') return THEME.modAccent
  if (def.section === 'fn') return THEME.keycapAccent
  return THEME.keycap
}

const UNDERGLOW = new THREE.Color(THEME.underglow)

// ---- inline app-icon SVGs -------------------------------------------------
// Small, clean glyphs (not exact brand logos): a magnifier for Raycast, a mic
// for Wispr. Parsed once into flat shape geometry centered on the cap.
const ICON_SVG: Record<SpecialIcon, string> = {
  raycast: `<svg viewBox="0 0 24 24"><path d="M10.5 3a7.5 7.5 0 1 0 4.55 13.46l4.74 4.75 1.96-1.96-4.75-4.74A7.5 7.5 0 0 0 10.5 3Zm0 2.6a4.9 4.9 0 1 1 0 9.8 4.9 4.9 0 0 1 0-9.8Z"/></svg>`,
  wispr: `<svg viewBox="0 0 24 24"><path d="M12 2.4a3.3 3.3 0 0 0-3.3 3.3v6.2a3.3 3.3 0 0 0 6.6 0V5.7A3.3 3.3 0 0 0 12 2.4Zm6.2 9.5a6.2 6.2 0 0 1-12.4 0H3.6a8.4 8.4 0 0 0 7.3 8.3v1.4H8.7v2.2h6.6v-2.2h-2.2v-1.4a8.4 8.4 0 0 0 7.3-8.3h-2.2Z"/></svg>`,
}

const iconGeomCache = new Map<SpecialIcon, THREE.BufferGeometry>()
function iconGeometry(name: SpecialIcon): THREE.BufferGeometry {
  const cached = iconGeomCache.get(name)
  if (cached) return cached
  const loader = new SVGLoader()
  const { paths } = loader.parse(ICON_SVG[name])
  const geoms: THREE.BufferGeometry[] = []
  for (const p of paths) {
    for (const shape of SVGLoader.createShapes(p)) {
      geoms.push(new THREE.ShapeGeometry(shape))
    }
  }
  const merged = mergeGeometries(geoms)
  // SVG y grows down; flip so the glyph is upright, then center + normalize to a
  // unit box so we can scale it to the cap.
  merged.scale(1, -1, 1)
  merged.computeBoundingBox()
  const bb = merged.boundingBox!
  const cx = (bb.min.x + bb.max.x) / 2
  const cy = (bb.min.y + bb.max.y) / 2
  const span = Math.max(bb.max.x - bb.min.x, bb.max.y - bb.min.y) || 1
  merged.translate(-cx, -cy, 0)
  merged.scale(1 / span, 1 / span, 1)
  iconGeomCache.set(name, merged)
  return merged
}

// Minimal position-only geometry merge (avoids pulling in BufferGeometryUtils).
function mergeGeometries(geoms: THREE.BufferGeometry[]): THREE.BufferGeometry {
  const positions: number[] = []
  for (const g of geoms) {
    const nonIndexed = g.index ? g.toNonIndexed() : g
    const arr = nonIndexed.getAttribute('position').array
    for (let i = 0; i < arr.length; i++) positions.push(arr[i])
  }
  const out = new THREE.BufferGeometry()
  out.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3))
  return out
}

// ---- text fit -------------------------------------------------------------
// Auto-shrink the legend so multi-glyph labels ("SelWord", "PrevWin") never
// overflow the cap. Approximate glyph advance ≈ 0.58·fontSize; pick the largest
// font where label width ≤ usable cap width, clamped to a readable floor.
function fitFontSize(label: string, base: number, capWidth: number): number {
  const usable = capWidth * 0.86
  const len = Math.max(label.length, 1)
  const ADVANCE = 0.6 // mean glyph advance as a fraction of font size
  const widthLimited = usable / (len * ADVANCE)
  return Math.max(0.1, Math.min(base, widthLimited))
}

export function Keycap({
  def,
  tap,
  hold,
  icon,
  isActivator,
  modHeld,
  pressed,
  highlighted,
  accent,
  rippleDelay,
  pulseAt,
}: KeycapProps) {
  const matRef = useRef<THREE.MeshStandardMaterial>(null)
  const accentColor = useMemo(() => new THREE.Color(accent), [accent])
  const restColor = useMemo(() => new THREE.Color(capColor(def)), [def])
  const targetEmissive = useMemo(() => new THREE.Color(), [])
  const iconGeom = useMemo(() => (icon ? iconGeometry(icon) : null), [icon])

  // Spring the cap down (along its local up axis) on press.
  const { press } = useSpring({
    press: pressed ? 1 : 0,
    config: { tension: 520, friction: 18 },
  })

  useFrame(() => {
    const mat = matRef.current
    if (!mat) return

    const now = performance.now()
    // Layer-switch ripple: a brightness pulse that sweeps across columns.
    const since = now - pulseAt - rippleDelay * 26
    let ripple = 0
    if (since > 0 && since < 320) {
      ripple = Math.sin((since / 320) * Math.PI) // 0 -> 1 -> 0
    }

    // Rest: a soft warm-pink RGB underglow bleeding from the caps (blooms
    // subtly). Activity (ripple / highlight / press) ramps the LAYER accent so
    // the live recolor stays intact.
    const REST_GLOW = 0.09
    let intensity = REST_GLOW + ripple * 1.9
    const active = ripple > 0.001
    targetEmissive.copy(active ? accentColor : UNDERGLOW)

    if (highlighted) {
      const breathe = 0.5 + 0.5 * Math.sin(now * 0.006)
      intensity = Math.max(intensity, 1.6 + breathe * 1.1)
      targetEmissive.copy(accentColor)
    }

    // Layer-activator highlight: a steady, breathing mint glow on the thumb
    // that activates the current layer — a distinct accent from the recolor.
    if (isActivator) {
      const breathe = 0.5 + 0.5 * Math.sin(now * 0.005)
      intensity = Math.max(intensity, 1.9 + breathe * 1.0)
      targetEmissive.copy(ACTIVATOR_COLOR)
    }

    // Home-row-mod glow: while its modifier is held, this home-row cap glows in
    // the electric-azure mod color — distinct from the mint activator and the
    // warm-pink keypress bloom.
    if (modHeld) {
      const breathe = 0.5 + 0.5 * Math.sin(now * 0.007)
      intensity = Math.max(intensity, 2.2 + breathe * 0.9)
      targetEmissive.copy(MOD_COLOR)
    }

    if (pressed) {
      intensity = Math.max(intensity, 2.6)
      targetEmissive.copy(accentColor).lerp(new THREE.Color('#ffffff'), 0.35)
    }

    mat.emissive.lerp(targetEmissive, 0.25)
    mat.emissiveIntensity += (intensity - mat.emissiveIntensity) * 0.25

    // Tint the matte pink cap toward the active accent only while it's lit.
    // Pressed wins (white-ish bloom via accent), then mod, then activator.
    const accentTint = pressed
      ? accentColor
      : modHeld
        ? MOD_COLOR
        : isActivator
          ? ACTIVATOR_COLOR
          : accentColor
    const bodyMix = Math.min(0.4, (mat.emissiveIntensity - REST_GLOW) * 0.14)
    mat.color.copy(restColor).lerp(accentTint, Math.max(0, bodyMix))
  })

  // Press travel along the cap's local up (after its tilt) reads as a real
  // keypress; drive it via a tiny y-offset inside the rotated frame.
  const posY = press.to((p) => def.pos[1] - p * 0.16)

  const litText = highlighted || pressed || isActivator || modHeld
  const base = def.section === 'thumb' ? 0.2 : 0.26
  const tapSize = fitFontSize(tap, base, def.size[0])

  return (
    <AnimatedGroup
      position-x={def.pos[0]}
      position-y={posY}
      position-z={def.pos[2]}
      rotation-x={def.rotX}
      rotation-y={def.rotY}
      rotation-z={def.rotZ}
    >
      <RoundedBox args={def.size} radius={0.09} smoothness={4} castShadow receiveShadow>
        <meshStandardMaterial
          ref={matRef}
          color={restColor}
          emissive={UNDERGLOW}
          emissiveIntensity={0.09}
          metalness={0}
          roughness={0.62}
          toneMapped={false}
        />
      </RoundedBox>

      {iconGeom ? (
        <>
          {/* App icon (Raycast magnifier / Wispr mic) drawn on the cap top. */}
          <mesh
            geometry={iconGeom}
            position={[0, def.size[1] / 2 + 0.012, -0.12]}
            rotation={[-Math.PI / 2, 0, 0]}
            scale={[0.24, 0.24, 0.24]}
          >
            <meshStandardMaterial
              color={litText ? THEME.legendLit : THEME.legendDim}
              emissive={litText ? THEME.legendLit : '#000000'}
              emissiveIntensity={litText ? 0.6 : 0}
              metalness={0}
              roughness={0.5}
              toneMapped={false}
            />
          </mesh>
          {/* App name under the icon. */}
          <Text
            position={[0, def.size[1] / 2 + 0.012, def.size[2] * 0.22]}
            rotation={[-Math.PI / 2, 0, 0]}
            fontSize={fitFontSize(tap, base * 0.82, def.size[0])}
            color={litText ? THEME.legendLit : THEME.legendDim}
            anchorX="center"
            anchorY="middle"
            outlineWidth={0}
          >
            {tap}
          </Text>
        </>
      ) : (
        <>
          {/* Tap legend — prominent, centered (nudged up if a hold exists). */}
          <Text
            position={[0, def.size[1] / 2 + 0.012, hold ? -0.06 : 0.02]}
            rotation={[-Math.PI / 2, 0, 0]}
            fontSize={tapSize}
            color={litText ? THEME.legendLit : THEME.legendDim}
            anchorX="center"
            anchorY="middle"
            outlineWidth={0}
          >
            {tap}
          </Text>

          {/* Hold legend — small, toward the front edge. */}
          {hold ? (
            <Text
              position={[0, def.size[1] / 2 + 0.012, def.size[2] * 0.26]}
              rotation={[-Math.PI / 2, 0, 0]}
              fontSize={fitFontSize(hold, base * 0.6, def.size[0])}
              color={litText ? '#ffe7ef' : '#6a4350'}
              anchorX="center"
              anchorY="middle"
              outlineWidth={0}
            >
              {hold}
            </Text>
          ) : null}
        </>
      )}
    </AnimatedGroup>
  )
}
