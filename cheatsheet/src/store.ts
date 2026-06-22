import { create } from 'zustand'
import type { LayerId } from './layers'
import { LAYERS } from './layers'
import { GUIDED } from './guided'
import type { ModName } from './glove80Layout'
import content from './data/app-content.json'

const SERVICE_COUNT = content.services.length
const WORKFLOW_COUNT = GUIDED.length

interface AppState {
  /** Currently-held event.codes (physical keys). */
  pressed: Set<string>
  /** Currently-held home-row modifiers (CAGS) — lights their two HRM caps. */
  mods: Set<ModName>
  /** Active layer id. */
  layer: LayerId
  /** Timestamp (performance.now) of the last layer switch — drives the pulse. */
  layerPulseAt: number
  /** Active guided workflow index. */
  workflowIndex: number
  /** Active step within the current guided workflow. */
  stepIndex: number
  /** Whether the guided highlight drives the board. */
  tutorialOn: boolean
  /** Index into content.services for the per-service bindings view. */
  serviceIndex: number

  pressKey: (code: string) => void
  releaseKey: (code: string) => void
  /** Replace the held-modifier set (driven from event modifier state). */
  setMods: (mods: Set<ModName>) => void
  setLayer: (layer: LayerId) => void
  cycleLayerByDigit: (digit: number) => void
  /** Step forward within the current workflow, wrapping to the next workflow. */
  nextStep: () => void
  /** Step backward, wrapping to the previous workflow's last step. */
  prevStep: () => void
  /** Jump to a specific step within the current workflow. */
  goStep: (i: number) => void
  /** Select a guided workflow (resets to its first step). */
  setWorkflow: (i: number) => void
  toggleTutorial: () => void
  /** Sync the board layer to the active guided step. */
  syncLayerToStep: () => void
  nextService: () => void
  prevService: () => void
  setService: (i: number) => void
}

export const useStore = create<AppState>((set, get) => ({
  pressed: new Set<string>(),
  mods: new Set<ModName>(),
  layer: 'BASE',
  layerPulseAt: 0,
  workflowIndex: 0,
  stepIndex: 0,
  tutorialOn: true,
  serviceIndex: 0,

  pressKey: (code) => {
    const { pressed } = get()
    if (pressed.has(code)) return
    const next = new Set(pressed)
    next.add(code)
    set({ pressed: next })
  },

  releaseKey: (code) => {
    const { pressed } = get()
    if (!pressed.has(code)) return
    const next = new Set(pressed)
    next.delete(code)
    set({ pressed: next })
  },

  setMods: (mods) => {
    const cur = get().mods
    if (cur.size === mods.size && [...mods].every((m) => cur.has(m))) return
    set({ mods })
  },

  setLayer: (layer) => {
    if (get().layer === layer) return
    set({ layer, layerPulseAt: performance.now() })
  },

  cycleLayerByDigit: (digit) => {
    const idx = digit - 1
    if (idx >= 0 && idx < LAYERS.length) {
      get().setLayer(LAYERS[idx].id)
    }
  },

  nextStep: () => {
    const { workflowIndex, stepIndex } = get()
    const steps = GUIDED[workflowIndex].steps.length
    if (stepIndex + 1 < steps) {
      set({ stepIndex: stepIndex + 1, tutorialOn: true })
    } else {
      set({ workflowIndex: (workflowIndex + 1) % WORKFLOW_COUNT, stepIndex: 0, tutorialOn: true })
    }
    get().syncLayerToStep()
  },
  prevStep: () => {
    const { workflowIndex, stepIndex } = get()
    if (stepIndex > 0) {
      set({ stepIndex: stepIndex - 1, tutorialOn: true })
    } else {
      const w = (workflowIndex - 1 + WORKFLOW_COUNT) % WORKFLOW_COUNT
      set({ workflowIndex: w, stepIndex: GUIDED[w].steps.length - 1, tutorialOn: true })
    }
    get().syncLayerToStep()
  },
  goStep: (i) => {
    const steps = GUIDED[get().workflowIndex].steps.length
    if (i >= 0 && i < steps) {
      set({ stepIndex: i, tutorialOn: true })
      get().syncLayerToStep()
    }
  },
  setWorkflow: (i) => {
    if (i >= 0 && i < WORKFLOW_COUNT) {
      set({ workflowIndex: i, stepIndex: 0, tutorialOn: true })
      get().syncLayerToStep()
    }
  },
  toggleTutorial: () => set({ tutorialOn: !get().tutorialOn }),

  syncLayerToStep: () => {
    const { workflowIndex, stepIndex } = get()
    const step = GUIDED[workflowIndex]?.steps[stepIndex]
    if (step) get().setLayer(step.layer)
  },

  nextService: () => set({ serviceIndex: (get().serviceIndex + 1) % SERVICE_COUNT }),
  prevService: () =>
    set({ serviceIndex: (get().serviceIndex - 1 + SERVICE_COUNT) % SERVICE_COUNT }),
  setService: (i) => {
    if (i >= 0 && i < SERVICE_COUNT) set({ serviceIndex: i })
  },
}))
