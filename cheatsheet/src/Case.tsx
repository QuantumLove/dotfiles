import { useMemo, useRef } from 'react'
import { useFrame } from '@react-three/fiber'
import * as THREE from 'three'
import { CASE_HALVES, CASE_FEET, type CaseHalf } from './glove80Layout'
import { THEME } from './theme'

/**
 * One contoured Glove80 half-shell. Built as a beveled ExtrudeGeometry from a
 * rounded "bean" outline (THREE.Shape + bezier), extruded upward and capped
 * with a soft edge, plus a swelling palm pad and four short feet. The shape is
 * authored in the X-Y plane and the whole geometry is rotated -90deg about X so
 * the extrusion runs vertically (world Y = up) and the bean lies in the ground.
 */
function beanGeometry(h: CaseHalf): THREE.ExtrudeGeometry {
  const { x0, x1, z0, z1 } = h
  const w = x1 - x0
  const d = z1 - z0
  const cx = (x0 + x1) / 2
  const cz = (z0 + z1) / 2
  // Outboard side is the pinky edge (away from centerline); inboard is the
  // thumb/centerline side. h.dir = +1 means the half is on the +x side.
  const out = h.dir // sign of the outboard direction in local x

  // Author in a (u = sideways, v = front<->back) plane. v grows toward the
  // user (matches world z). We sweep a rounded bean: wider at the wrist (front)
  // for the palm swell, tapered at the top (fingers), bulged on the outboard
  // pinky edge.
  const hw = w / 2 + 0.4 // half width incl. margin
  const back = -d / 2 - 0.45 // top (finger) edge, away from user
  const front = d / 2 + 0.35 // wrist edge

  const inb = -out // inboard sign
  const s = new THREE.Shape()
  // Organic "wing/bean": widest at the top (index/top rows), curving inward on
  // the pinky side, with a convex lobe at the inner-lower corner for the THUMB
  // POD and a palm-rest shelf sweeping off the bottom-inner corner. Traced
  // clockwise from the back-inboard (top-thumb-side) corner.
  s.moveTo(inb * (hw * 0.72), back + 0.3)
  // TOP / BACK edge — widest here; gently domed across the index/top columns,
  // bulging out toward the index side and the outboard top corner.
  s.bezierCurveTo(
    inb * (hw * 0.25), back - 0.5,
    out * (hw * 0.6), back - 0.45,
    out * (hw * 1.02), back + 0.55,
  )
  // OUTBOARD (pinky) edge — curves gently INWARD as it drops toward the wrist
  // (the pinky side is narrower than the top), keeping a soft convex belly.
  s.bezierCurveTo(
    out * (hw * 1.06), back + d * 0.42,
    out * (hw * 0.86), front - d * 0.28,
    out * (hw * 0.66), front - 0.05,
  )
  // FRONT / WRIST edge — sweep across toward the inner side.
  s.bezierCurveTo(
    out * (hw * 0.32), front + 0.28,
    inb * (hw * 0.05), front + 0.3,
    inb * (hw * 0.4), front + 0.18,
  )
  // PALM-REST shelf — a modest lobe sweeping off the bottom-inner corner toward
  // the user (kept inside the half so the two halves never merge at center).
  s.bezierCurveTo(
    inb * (hw * 0.66), front + 0.34,
    inb * (hw * 0.86), front + 0.06,
    inb * (hw * 0.9), front - d * 0.2,
  )
  // THUMB-POD lobe — a convex bulge on the inner-lower corner for the thumb
  // cluster, protruding gently past the main key field (compact, not splayed).
  s.bezierCurveTo(
    inb * (hw * 0.94), front - d * 0.44,
    inb * (hw * 0.86), front - d * 0.62,
    inb * (hw * 0.74), front - d * 0.76,
  )
  // INNER edge back up toward the centerline and the top corner.
  s.bezierCurveTo(
    inb * (hw * 0.64), back + d * 0.66,
    inb * (hw * 0.72), back + d * 0.3,
    inb * (hw * 0.72), back + 0.3,
  )

  const depth = h.height
  const geo = new THREE.ExtrudeGeometry(s, {
    depth,
    bevelEnabled: true,
    bevelThickness: 0.13,
    bevelSize: 0.13,
    bevelSegments: 4,
    curveSegments: 24,
    steps: 1,
  })
  // Rotate so extrusion (+z) becomes world up (+y); bean (u,v) -> world (x,z).
  geo.rotateX(-Math.PI / 2)
  // After rotateX(-90): local +y(=v, front) -> world -z. We want front (wrist,
  // +v) to map to +z (toward user). Flip z.
  geo.scale(1, 1, -1)
  // Move so the top surface sits just under the key field and re-center on the
  // half. Extrusion now spans world y in [-depth-bevel, 0]; lift so the top is
  // a touch below the caps.
  geo.translate(cx, h.topY, cz)
  geo.computeVertexNormals()
  return geo
}

function CaseShellHalf({ half }: { half: CaseHalf }) {
  const geo = useMemo(() => beanGeometry(half), [half])
  return (
    // Outer group: tent each half about the centerline (z-rot at x=0), matching
    // the caps. Inner group: a gentle forward tilt about world x.
    <group rotation={[0, 0, half.tent]} position={[0, half.groupLift, 0]}>
      <group rotation={[half.tiltX, 0, 0]}>
      <mesh geometry={geo} castShadow receiveShadow>
        <meshStandardMaterial
          color={THEME.case}
          roughness={0.58}
          metalness={0.18}
          flatShading={false}
        />
      </mesh>

      {/* Pink RGB underglow: a soft emissive plate tucked UNDER the shell
          bottom so the case occludes it from above (no top-down blowout) — it
          bleeds the signature glow onto the desk and out the perimeter. Sized a
          touch inside the footprint and faced DOWNWARD. */}
      <mesh
        position={[(half.x0 + half.x1) / 2, half.topY - half.height - 0.08, (half.z0 + half.z1) / 2]}
        rotation={[Math.PI, 0, 0]}
      >
        <boxGeometry args={[(half.x1 - half.x0) + 0.4, 0.05, (half.z1 - half.z0) + 0.5]} />
        <meshStandardMaterial
          color={THEME.underglow}
          emissive={THEME.underglow}
          emissiveIntensity={0.34}
          roughness={1}
          metalness={0}
          toneMapped={false}
        />
      </mesh>

      {/* Four short feet. */}
      {CASE_FEET.map(([fx, fz], i) => (
        <mesh
          key={i}
          position={[(half.x0 + half.x1) / 2 + fx * (half.x1 - half.x0) * 0.42,
                     half.topY - half.height - 0.22,
                     (half.z0 + half.z1) / 2 + fz * (half.z1 - half.z0) * 0.42]}
          castShadow
        >
          <cylinderGeometry args={[0.16, 0.18, 0.4, 16]} />
          <meshStandardMaterial color={THEME.caseFoot} roughness={0.85} metalness={0.05} />
        </mesh>
      ))}
      </group>
    </group>
  )
}

export function Case() {
  const glow = useRef<THREE.Group>(null)
  // Gentle breathing on the underglow so the RGB feels alive (still subtle).
  useFrame((state) => {
    if (!glow.current) return
    const t = state.clock.elapsedTime
    glow.current.children.forEach((c) => {
      c.traverse((o) => {
        const m = (o as THREE.Mesh).material as THREE.MeshStandardMaterial | undefined
        if (m && (m as THREE.MeshStandardMaterial).emissive?.equals(THEME.underglowColor)) {
          m.emissiveIntensity = 0.34 + 0.12 * (0.5 + 0.5 * Math.sin(t * 1.4))
        }
      })
    })
  })
  return (
    <group ref={glow}>
      {CASE_HALVES.map((h) => (
        <CaseShellHalf key={h.id} half={h} />
      ))}
    </group>
  )
}
