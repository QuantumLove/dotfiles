import { useMemo, useRef } from 'react'
import * as THREE from 'three'
import { Keycap } from './Keycap'
import { Case } from './Case'
import {
  KEYS,
  CODE_TO_IDS,
  CODES_BY_MOD,
  LAYER_ID_TO_NAME,
  legendFor,
  prettyLegend,
  activatorIndex,
  SPECIAL_KEYS,
} from './glove80Layout'
import { LAYER_BY_ID } from './layers'
import { useStore } from './store'
import { GUIDED } from './guided'

export function Keyboard() {
  const group = useRef<THREE.Group>(null)
  const pressed = useStore((s) => s.pressed)
  const mods = useStore((s) => s.mods)
  const layer = useStore((s) => s.layer)
  const pulseAt = useStore((s) => s.layerPulseAt)
  const workflowIndex = useStore((s) => s.workflowIndex)
  const stepIndex = useStore((s) => s.stepIndex)
  const tutorialOn = useStore((s) => s.tutorialOn)

  const accent = LAYER_BY_ID[layer].color
  const layerName = LAYER_ID_TO_NAME[layer] ?? 'default'

  // Resolve every cap's tap/hold legend for the active layer.
  const legends = useMemo(
    () =>
      KEYS.map((k) => {
        // Special default-layer keys (Raycast/Wispr) render their app name +
        // an icon rather than a raw modifier chord.
        const special = layerName === 'default' ? SPECIAL_KEYS[k.legendIndex] : undefined
        if (special) return { tap: special.label, hold: '', icon: special.icon }
        const l = legendFor(k.legendIndex, layerName)
        return { tap: prettyLegend(l.tap), hold: prettyLegend(l.hold), icon: undefined }
      }),
    [layerName],
  )

  // The thumb you hold to reach the active layer — glow it so the user sees
  // which key activates the layer they're looking at.
  const activator = activatorIndex(layerName)

  // Home-row mods: while a modifier is held, light its TWO home-row caps (the
  // event.codes that ARE that modifier on hold) in the distinct mod color.
  const modLitCodes = useMemo(() => {
    const s = new Set<string>()
    for (const m of mods) for (const code of CODES_BY_MOD[m]) s.add(code)
    return s
  }, [mods])

  // Which key ids are highlighted by the active guided-workflow step.
  const highlightedIds = useMemo(() => {
    if (!tutorialOn) return new Set<string>()
    const stepDef = GUIDED[workflowIndex]?.steps[stepIndex]
    if (!stepDef) return new Set<string>()
    const ids = new Set<string>()
    for (const code of stepDef.codes) {
      for (const id of CODE_TO_IDS[code] ?? []) ids.add(id)
    }
    return ids
  }, [workflowIndex, stepIndex, tutorialOn])

  return (
    <group ref={group}>
      {KEYS.map((def, i) => {
        const isPressed = def.code ? pressed.has(def.code) : false
        // Ripple delay keyed off x so the pulse sweeps left -> right.
        const rippleDelay = def.pos[0] + 8
        return (
          <Keycap
            key={def.id}
            def={def}
            tap={legends[i].tap}
            hold={legends[i].hold || undefined}
            icon={legends[i].icon}
            isActivator={def.legendIndex === activator}
            modHeld={def.code ? modLitCodes.has(def.code) : false}
            pressed={isPressed}
            highlighted={highlightedIds.has(def.id)}
            accent={accent}
            rippleDelay={rippleDelay}
            pulseAt={pulseAt}
          />
        )
      })}
      {/* Contoured per-half Cherry Blossom case under the key field. */}
      <Case />
    </group>
  )
}
