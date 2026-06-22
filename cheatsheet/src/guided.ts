import type { LayerId } from './layers'
import content from './data/app-content.json'

export interface GuidedStep {
  key: string
  action: string
  detail: string
  /** event.codes to light on the board for this step (may be empty). */
  codes: string[]
  /** Layer to switch the board to while this step is active. */
  layer: LayerId
}

export interface GuidedWorkflow {
  id: string
  name: string
  app: string
  blurb: string
  steps: GuidedStep[]
}

export const GUIDED: GuidedWorkflow[] = content.guided as GuidedWorkflow[]
