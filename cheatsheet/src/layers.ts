export type LayerId = 'BASE' | 'CURSOR' | 'NUMBER' | 'SYMBOL' | 'MOUSE' | 'TMUX'

export interface LayerDef {
  id: LayerId
  name: string
  /** Hue accent for emissive / rim / UI accent. */
  color: string
  /** A darker companion for the background gradient. */
  bg: string
  blurb: string
}

export const LAYERS: LayerDef[] = [
  { id: 'BASE', name: 'Base', color: '#7cc7ff', bg: '#0a1622', blurb: 'Letters and the daily drivers.' },
  { id: 'CURSOR', name: 'Cursor', color: '#b388ff', bg: '#160e22', blurb: 'Arrows, home/end, word jumps.' },
  { id: 'NUMBER', name: 'Number', color: '#ffc24b', bg: '#221a08', blurb: 'Numpad and quick math.' },
  { id: 'SYMBOL', name: 'Symbol', color: '#52e08a', bg: '#0a2014', blurb: 'Brackets, operators, glyphs.' },
  { id: 'MOUSE', name: 'Mouse', color: '#ff4fcb', bg: '#220a1a', blurb: 'Pointer control without the rodent.' },
  { id: 'TMUX', name: 'Tmux', color: '#34e0e0', bg: '#08201f', blurb: 'Panes, windows, sessions.' },
]

export const LAYER_BY_ID: Record<LayerId, LayerDef> = LAYERS.reduce(
  (acc, l) => {
    acc[l.id] = l
    return acc
  },
  {} as Record<LayerId, LayerDef>,
)
