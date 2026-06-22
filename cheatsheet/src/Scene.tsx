import { useEffect, useMemo, useRef } from 'react'
import { Canvas, useFrame, useThree } from '@react-three/fiber'
import { OrbitControls, Environment, ContactShadows } from '@react-three/drei'
import { EffectComposer, Bloom, Vignette } from '@react-three/postprocessing'
import * as THREE from 'three'
import type { OrbitControls as OrbitControlsImpl } from 'three-stdlib'
import { Keyboard } from './Keyboard'
import { LAYER_BY_ID } from './layers'
import { useStore } from './store'

/** A slow-orbiting rim light that rakes across the glossy caps. */
function RimLight() {
  const ref = useRef<THREE.PointLight>(null)
  const layer = useStore((s) => s.layer)
  const color = useMemo(() => new THREE.Color(LAYER_BY_ID[layer].color), [layer])
  useFrame((state) => {
    const l = ref.current
    if (!l) return
    const t = state.clock.elapsedTime * 0.35
    l.position.set(Math.cos(t) * 9, 5.5 + Math.sin(t * 0.7) * 1.2, Math.sin(t) * 7 - 2)
    l.color.lerp(color, 0.05)
  })
  return <pointLight ref={ref} intensity={55} distance={30} decay={1.6} />
}

/** Big gradient backdrop that shifts accent per layer. */
function Backdrop() {
  const mesh = useRef<THREE.Mesh>(null)
  const layer = useStore((s) => s.layer)
  const target = useMemo(() => new THREE.Color(LAYER_BY_ID[layer].bg), [layer])
  const uniforms = useMemo(
    () => ({
      uTop: { value: new THREE.Color('#0a070b') },
      uBottom: { value: new THREE.Color('#1a0f16') },
      uAccent: { value: new THREE.Color('#1a0f16') },
    }),
    [],
  )
  useFrame(() => {
    uniforms.uAccent.value.lerp(target, 0.04)
    uniforms.uBottom.value.copy(uniforms.uTop.value).lerp(uniforms.uAccent.value, 0.85)
  })
  return (
    <mesh ref={mesh} position={[0, 0, -16]} scale={[60, 36, 1]}>
      <planeGeometry args={[1, 1]} />
      <shaderMaterial
        depthWrite={false}
        uniforms={uniforms}
        vertexShader={`
          varying vec2 vUv;
          void main() {
            vUv = uv;
            gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
          }
        `}
        fragmentShader={`
          varying vec2 vUv;
          uniform vec3 uTop;
          uniform vec3 uBottom;
          uniform vec3 uAccent;
          void main() {
            float g = smoothstep(0.0, 1.0, vUv.y);
            vec3 col = mix(uBottom, uTop, g);
            // soft radial glow behind the hero, low so it pools under the board
            float d = distance(vUv, vec2(0.5, 0.30));
            float glow = smoothstep(0.5, 0.0, d) * 0.28;
            col += uAccent * glow;
            gl_FragColor = vec4(col, 1.0);
          }
        `}
      />
    </mesh>
  )
}

// ---- camera rubber-band ---------------------------------------------------
// Default: a high, near-top-down view looking at the board from above-and-front
// so the keys read clearly. azimuth 0 puts the camera on +Z — the board's near
// (thumb/bottom-row) edge faces the camera and the function row sits at the back.
// The user can drag anywhere (no hard polar/azimuth clamp); on release the
// camera smoothly rubber-bands back into the acceptable zone.
const HOME_TARGET = new THREE.Vector3(0, 0.4, 1.0)
// Spherical: polarAngle is measured from +Y (vertical). ~12deg from top =
// almost straight overhead with just a slight tilt so the near/thumb edge faces
// the camera and every key reads.
const HOME_POLAR = THREE.MathUtils.degToRad(12)
const HOME_AZIMUTH = 0 // front — near edge (thumbs) faces the camera
const HOME_RADIUS = 13
// Acceptable resting zone — generous: polar ~8-60deg from vertical, azimuth
// within ±55deg of front. The widened lower bound keeps the new near-top-down
// default comfortably inside the band. On release, if the camera is already
// inside this band it stays where the user left it; outside it, the rubber-band
// eases back toward the high top-down default.
const ZONE_POLAR_MIN = THREE.MathUtils.degToRad(8)
const ZONE_POLAR_MAX = THREE.MathUtils.degToRad(60)
const ZONE_AZIMUTH = THREE.MathUtils.degToRad(55) // allowed swing off front

function inZone(polar: number, az: number): boolean {
  return polar >= ZONE_POLAR_MIN && polar <= ZONE_POLAR_MAX && Math.abs(az) <= ZONE_AZIMUTH
}

function defaultCameraPosition(): [number, number, number] {
  const s = new THREE.Spherical(HOME_RADIUS, HOME_POLAR, HOME_AZIMUTH)
  const v = new THREE.Vector3().setFromSpherical(s).add(HOME_TARGET)
  return [v.x, v.y, v.z]
}

function CameraRig() {
  const controls = useRef<OrbitControlsImpl>(null)
  const camera = useThree((s) => s.camera)
  const dragging = useRef(false)
  // Where the rubber-band is pulling toward this release (chosen at 'end').
  const goalPolar = useRef(HOME_POLAR)
  const goalAzimuth = useRef(HOME_AZIMUTH)

  useEffect(() => {
    const c = controls.current
    if (!c) return
    const onStart = () => {
      dragging.current = true
    }
    const onEnd = () => {
      dragging.current = false
      const polar = c.getPolarAngle()
      const az = c.getAzimuthalAngle()
      if (inZone(polar, az)) {
        // Already a comfortable top-tilted near-front pose — leave it.
        goalPolar.current = polar
        goalAzimuth.current = az
      } else {
        // Outside the zone — rubber-band back to the top-tilted default.
        goalPolar.current = HOME_POLAR
        goalAzimuth.current = HOME_AZIMUTH
      }
    }
    c.addEventListener('start', onStart)
    c.addEventListener('end', onEnd)
    return () => {
      c.removeEventListener('start', onStart)
      c.removeEventListener('end', onEnd)
    }
  }, [])

  // Run AFTER drei's own OrbitControls damping update (priority -1 sorts last)
  // so the rubber-band gets the final say on the resting pose.
  useFrame((_, dt) => {
    const c = controls.current
    if (!c || dragging.current) return

    const curPolar = c.getPolarAngle()
    const curAz = c.getAzimuthalAngle()
    const dPolar = goalPolar.current - curPolar
    const dAz = goalAzimuth.current - curAz
    if (Math.abs(dPolar) < 1e-4 && Math.abs(dAz) < 1e-4) return

    // Critically-damped-ish ease: ~0.6-1s to home. lerp factor from dt.
    const k = 1 - Math.exp(-dt * 4.2)
    const sph = new THREE.Spherical().setFromVector3(
      camera.position.clone().sub(c.target),
    )
    sph.phi = curPolar + dPolar * k
    sph.theta = curAz + dAz * k
    sph.makeSafe()
    camera.position.copy(new THREE.Vector3().setFromSpherical(sph).add(c.target))
    camera.lookAt(c.target)
  }, -1)

  return (
    <OrbitControls
      ref={controls}
      makeDefault
      enableDamping
      dampingFactor={0.08}
      autoRotate={false}
      enablePan={false}
      minDistance={7}
      maxDistance={20}
      target={HOME_TARGET.toArray()}
    />
  )
}

export function Scene() {
  return (
    <Canvas
      shadows
      dpr={[1, 2]}
      camera={{ position: defaultCameraPosition(), fov: 38 }}
      gl={{ antialias: true, toneMapping: THREE.ACESFilmicToneMapping }}
    >
      <color attach="background" args={['#0a070b']} />
      <fog attach="fog" args={['#0a070b', 18, 38]} />

      <Backdrop />

      <ambientLight intensity={0.42} />
      <directionalLight position={[4, 10, 6]} intensity={0.4} castShadow shadow-mapSize={[1024, 1024]} />
      <RimLight />

      {/* Hero: tilt the whole board back ~25deg and center it. */}
      <group rotation={[-0.44, 0, 0]} position={[0, 0.2, 0]}>
        <Keyboard />
      </group>

      <ContactShadows position={[0, -1.0, 1.8]} opacity={0.55} scale={26} blur={2.6} far={9} color="#000000" />

      <Environment preset="night" />

      <CameraRig />

      <EffectComposer>
        <Bloom luminanceThreshold={1.25} luminanceSmoothing={0.2} intensity={1.05} mipmapBlur />
        <Vignette eskil={false} offset={0.3} darkness={0.85} />
      </EffectComposer>
    </Canvas>
  )
}
