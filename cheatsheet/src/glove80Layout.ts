import POSITIONS from './data/glove80-positions.json'
import CODES from './data/glove80-codes.json'
import LAYERS_DATA from './data/keymap-layers.json'

/**
 * Authoritative Glove80 geometry, derived from MoErgo's official footprint
 * (keymap-drawer SVG → glove80-positions.json) plus the published 3D-contour
 * approximations (per-column dish, per-row tilt, tented halves, arced thumb
 * cluster). The x/y/rotZ values are exact; the z-drop / rotX / rotY / thumb
 * tilt are calibrated against the 20mm home-row height, 60mm case, 6x6 layout
 * and the flattened-Dactyl family.
 */

export type Half = 'L' | 'R'
export type Section = 'fn' | 'main' | 'thumb'

export interface KeyDef {
  id: string
  /** event.code that lights this cap, e.g. "KeyA", "Space". null = no live code. */
  code: string | null
  /** World position [x, y, z] (y is up). */
  pos: [number, number, number]
  /** Tilt about local X (row pitch), radians. */
  rotX: number
  /** Tilt about local Y (tenting + thumb inward lean), radians. */
  rotY: number
  /** Rotation about local Z (column / thumb splay), radians. */
  rotZ: number
  /** Cap footprint [w, depth-in-y(thickness), h]. */
  size: [number, number, number]
  half: Half
  section: Section
  /** Index into the per-layer legend arrays (0..79). */
  legendIndex: number
}

interface RawKey {
  i: number
  x: number
  y: number
  rot: number
  w: number
  h: number
}

const RAW = POSITIONS as RawKey[]
const CODE_LIST = CODES as (string | null)[]

const DEG = Math.PI / 180

// ---- SVG → world ----------------------------------------------------------
// keymap-drawer SVG uses 56px = 1 key pitch, caps are 52px. The board spans
// x∈[0,952] (≈17 key-units). The previous flat layout read ~14 world-units
// wide, so scale the footprint to keep the same on-screen size and re-center.
const PX_PER_U = 56
const TARGET_WIDTH = 14.0
const minX = Math.min(...RAW.map((k) => k.x))
const maxX = Math.max(...RAW.map((k) => k.x))
const minY = Math.min(...RAW.map((k) => k.y))
const maxY = Math.max(...RAW.map((k) => k.y))
const SCALE = TARGET_WIDTH / (maxX - minX) // world-units per SVG px
const CENTER_X = (minX + maxX) / 2
const CENTER_Y = (minY + maxY) / 2
// Bias depth so the board centers near the old camera/orbit target (~z=1.8).
const DEPTH_BIAS = 1.6

// Cap footprint in world units (52px square → ~0.76u; thickness kept low to
// read as Choc low-profile, matching the old 0.55 cap height).
const CAP = 52 * SCALE
const CAP_THICK = 0.55

// SVG y grows downward (toward the user). World depth axis is z, also growing
// toward the user, so z = svgY * SCALE. Up axis is world y.

// ---- 3D contour parameters ------------------------------------------------
// The finger field is a single concave bowl per half (MoErgo's "dish"). Two
// curls combine: a deep front-to-back row curl (the dominant one) and a per-
// column finger-length offset so the columns sit at different heights.
//
// Pitch: column ≈ 21.8mm / row ≈ 18mm (ratio ~1.21). The SVG already encodes
// the x/y footprint; we only set the z-rise/tilt here. Row curl uses the 18mm
// row pitch as its mm reference so the bowl depth tracks the real geometry.
//
// Per-row z-rise (mm above the home-row valley) and per-row pitch (deg).
// R1=top(fn) … R6=near. Higher rise = the row climbs further up the bowl wall.
const ROW_Z_DROP_MM: Record<number, number> = { 1: 12, 2: 5.5, 3: 1, 4: 0, 5: 3.5, 6: 9 }
const ROW_PITCH_DEG: Record<number, number> = { 1: 22, 2: 13, 3: 5, 4: 0, 5: -8, 6: -17 }

// Per-column finger-length offset (mm the column's home key rises out of the
// bowl). Middle (C3) highest, index/ring a touch lower, pinky lowest — keyed by
// SVG x bucket (left + mirrored right). The offset tapers toward the lower rows
// (pinky curl converges), applied via COL_OFFSET_LOWER_FALLOFF below.
const COL_FINGER_RISE_MM: Record<number, number> = {
  // left: x=0 outer-pinky … x=280 inner-index. Peak at the middle columns.
  0: 0, 56: 1.5, 112: 5, 168: 6.5, 224: 4.5, 280: 1.5,
  // right: mirror — x=952 outer-pinky … x=672 inner-index.
  672: 1.5, 728: 4.5, 784: 6.5, 840: 5, 896: 1.5, 952: 0,
}
// Finger-length stagger fades out toward the near rows (R5/R6) so the columns
// converge as the fingers curl down — fraction of the rise kept per row.
const COL_RISE_BY_ROW: Record<number, number> = { 1: 1, 2: 1, 3: 1, 4: 0.85, 5: 0.55, 6: 0.3 }

// mm → world units. 1 key-unit ≈ 19mm horizontally; 1u = SCALE*PX_PER_U world.
const MM_TO_U = (SCALE * PX_PER_U) / 19.0

// Tenting: rotate each half about the centerline so the pinky side lifts.
const TENT_DEG = 18

// Thumb cluster 3D tilt (left hand; mirror Y-sign for right).
// Upright, compact 3+3 block in the palm plane: high pitch (rotX), gentle fan.
const THUMB_INNER_ROTX_DEG = 25 // inner row pitched up toward the palm
const THUMB_OUTER_ROTX_DEG = 32 // outer row a touch more upright (+7)
const THUMB_ROTY_DEG = 4 // gentle palm lean, kept low so the cluster stays coplanar
// Flatten the raw SVG cap fan (±60..±20) almost entirely so the six caps read
// as a compact, near-coplanar thumb pad rather than a splayed outward arc. A
// trace of the fan direction is kept, not a wide spread.
const THUMB_FAN_SCALE = 0.1
const THUMB_RAISE_U = 8 * MM_TO_U // ~8mm above home as a unit
const THUMB_OUTER_LIFT_U = 5 * MM_TO_U // outer thumb row raised vs inner

// ---- classification -------------------------------------------------------
const FN_IDX = new Set([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
const THUMB_IDX = new Set([52, 53, 54, 55, 56, 57, 69, 70, 71, 72, 73, 74])
const THUMB_OUTER_IDX = new Set([52, 53, 54, 55, 56, 57])

function halfOf(k: RawKey): Half {
  return k.x < CENTER_X ? 'L' : 'R'
}

function sectionOf(k: RawKey): Section {
  if (THUMB_IDX.has(k.i)) return 'thumb'
  if (FN_IDX.has(k.i)) return 'fn'
  return 'main'
}

// Home-row y per column (keyed by half + raw x bucket). Home = A/S/D/F/G (L),
// H/J/K/L/;/' (R), plus the Esc/quote outer-pinky pair.
const HOME_INDICES = new Set([34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45])
const homeYByCol = new Map<string, number>()
for (const k of RAW) {
  if (HOME_INDICES.has(k.i)) homeYByCol.set(`${halfOf(k)}:${k.x}`, k.y)
}

/** Row index R1(top)…R6(near) for a finger/main key (fn keys are R1). */
function rowOf(k: RawKey): number {
  if (FN_IDX.has(k.i)) return 1
  const homeY = homeYByCol.get(`${halfOf(k)}:${k.x}`)
  if (homeY === undefined) return 4
  const step = Math.round((k.y - homeY) / PX_PER_U) // 56px = one row; home = R4
  return Math.min(6, Math.max(2, 4 + step))
}

// Rotate a point about the centerline (x=0) in the X–Y plane so the outer side
// lifts up with the tent angle.
function tentPoint(x: number, y: number, angle: number): [number, number] {
  const cos = Math.cos(angle)
  const sin = Math.sin(angle)
  return [x * cos - y * sin, x * sin + y * cos]
}

function build(): KeyDef[] {
  const keys: KeyDef[] = []

  for (const k of RAW) {
    const half = halfOf(k)
    const section = sectionOf(k)
    const dir = half === 'L' ? -1 : 1

    // (1) Base footprint in world space (top-down), centered.
    let x = (k.x - CENTER_X) * SCALE
    let z = (k.y - CENTER_Y) * SCALE + DEPTH_BIAS
    let y = 0

    let rotX = 0
    let rotY = 0
    // SVG cap rotation is the real cap splay; thumbs carry it, finger cols = 0.
    // SVG rot is CW in screen space — negate for world right-handed Z.
    let rotZ = -k.rot * DEG

    if (section === 'thumb') {
      // (5) Thumb cluster: a compact, near-flat 3+3 block tilted UP toward the
      // palm. Pitched upright (rotX ~25/32) rather than fanned flat; the cap
      // fan from the SVG is scaled down so each row spans ~16deg, not ~120.
      const outer = THUMB_OUTER_IDX.has(k.i)
      y += THUMB_RAISE_U
      if (outer) y += THUMB_OUTER_LIFT_U
      rotX = (outer ? THUMB_OUTER_ROTX_DEG : THUMB_INNER_ROTX_DEG) * DEG
      rotY = dir * THUMB_ROTY_DEG * DEG // lean inward toward the palm
      rotZ *= THUMB_FAN_SCALE // gentle fan, same direction as the data
    } else {
      // (2) Concave dish: rows rise out of the home-row valley (front-to-back
      // curl) AND each column sits at its own finger-length height. The column
      // stagger tapers toward the near rows so the fingers converge on the curl.
      const row = rowOf(k)
      const fingerRise = (COL_FINGER_RISE_MM[k.x] ?? 0) * (COL_RISE_BY_ROW[row] ?? 1)
      y += (ROW_Z_DROP_MM[row] ?? 0) * MM_TO_U + fingerRise * MM_TO_U
      // (3) Per-row pitch about the cap's own X axis (the bowl wall tilt).
      rotX = (ROW_PITCH_DEG[row] ?? 0) * DEG
    }

    // (4) Tenting: rotate the whole half about the centerline; the cap face
    // pitches with the tent plane too (rotY).
    const tent = dir * TENT_DEG * DEG
    const [tx, ty] = tentPoint(x, y, tent)
    x = tx
    y = ty
    rotY += tent

    keys.push({
      id: `${half}-${section}-${k.i}`,
      code: CODE_LIST[k.i] ?? null,
      pos: [x, y, z],
      rotX,
      rotY,
      rotZ,
      size: [CAP, CAP_THICK, CAP],
      half,
      section,
      legendIndex: k.i,
    })
  }

  return keys
}

export const KEYS: KeyDef[] = build()

// ---- case shell geometry --------------------------------------------------
// Per-half contoured shell that sits UNDER the floating key field. Extents are
// taken from the un-tented key footprint; the Case component tents each half
// about the centerline (z-rotation) to match how the caps are tented.
export interface CaseHalf {
  id: Half
  /** un-tented world bounds of the key field for this half */
  x0: number
  x1: number
  z0: number
  z1: number
  /** outboard sign (+1 = +x side) */
  dir: number
  /** world y of the shell top (just under the home caps) */
  topY: number
  /** extruded shell height (world units) */
  height: number
  /** tent rotation about the centerline (radians), applied as group rot-z */
  tent: number
  /** slight forward tilt about world x (radians) */
  tiltX: number
  /** group lift so the tented half clears the desk */
  groupLift: number
}

const CASE_HEIGHT = 12 * MM_TO_U // ~12mm low-profile shell
// Top of the shell sits right under the home-row caps so the switches read as
// mounted on the case (no floating gap). Home cap bottoms ≈ -0.275; the shell
// top is just below that, letting the dished rows rise out of the case body.
const CASE_TOP_Y = -0.16
const CASE_TILT_X = -4 * DEG // gentle forward tilt (neutral wrist)

function buildCaseHalves(): CaseHalf[] {
  const out: CaseHalf[] = []
  for (const half of ['L', 'R'] as Half[]) {
    const ks = RAW.filter((k) => halfOf(k) === half)
    const xs = ks.map((k) => (k.x - CENTER_X) * SCALE)
    const zs = ks.map((k) => (k.y - CENTER_Y) * SCALE + DEPTH_BIAS)
    const x0 = Math.min(...xs)
    const x1 = Math.max(...xs)
    const z0 = Math.min(...zs)
    const z1 = Math.max(...zs)
    const dir = half === 'L' ? -1 : 1
    out.push({
      id: half,
      x0,
      x1,
      z0,
      z1,
      dir,
      topY: CASE_TOP_Y,
      height: CASE_HEIGHT,
      tent: dir * TENT_DEG * DEG,
      tiltX: CASE_TILT_X,
      groupLift: 0,
    })
  }
  return out
}

export const CASE_HALVES: CaseHalf[] = buildCaseHalves()

/** Four foot offsets as fractions of the half footprint [fx, fz] (corners). */
export const CASE_FEET: [number, number][] = [
  [-0.78, -0.7],
  [0.78, -0.7],
  [-0.78, 0.78],
  [0.78, 0.78],
]

// ---- per-layer legends ----------------------------------------------------
export interface Legend {
  tap: string
  hold?: string
}

export const LAYER_LEGENDS = LAYERS_DATA as Record<string, Legend[]>

/** keymap-drawer layer-name → app LayerId. */
export const LAYER_NAME_TO_ID: Record<string, string> = {
  default: 'BASE',
  cursor: 'CURSOR',
  number: 'NUMBER',
  symbol: 'SYMBOL',
  mouse: 'MOUSE',
  tmux: 'TMUX',
}
export const LAYER_ID_TO_NAME: Record<string, string> = Object.fromEntries(
  Object.entries(LAYER_NAME_TO_ID).map(([k, v]) => [v, k]),
)

const TOKEN_MAP: Record<string, string> = {
  LSHFT: '⇧',
  RSHFT: '⇧',
  LSFT: '⇧',
  LCTRL: '⌃',
  RCTRL: '⌃',
  LCTL: '⌃',
  LALT: '⌥',
  RALT: '⌥',
  LGUI: '⌘',
  RGUI: '⌘',
  BSPC: '⌫',
  DEL: 'Del',
  RET: '⏎',
  SPACE: '␣',
  TAB: '⇥',
  ESC: 'Esc',
  HOME: 'Home',
  END: 'End',
  'PG UP': 'PgUp',
  'PG DN': 'PgDn',
  PG_UP: 'PgUp',
  PG_DN: 'PgDn',
  PSCRN: 'PrtSc',
  SLCK: 'ScrLk',
  CMENU: 'Menu',
  'PAUSE BREAK': 'Pause',
  PAUSE: 'Pause',
  INS: 'Ins',
  LEFT: '←',
  RIGHT: '→',
  UP: '↑',
  DOWN: '↓',
  CAPS: '⇪',
  'BRI DN': 'Bri-',
  'BRI UP': 'Bri+',
  'VOL DN': 'Vol-',
  'VOL UP': 'Vol+',
  MUTE: 'Mute',
  PREV: '⏮',
  NEXT: '⏭',
  PP: '⏯',
  // Keypad (lower layer numpad).
  'KP NUM': 'Num',
  'KP EQUAL': 'KP=',
  'KP DIVIDE': 'KP/',
  'KP MULTIPLY': 'KP*',
  'KP MINUS': 'KP-',
  'KP PLUS': 'KP+',
  'KP ENTER': 'KP⏎',
  'KP DOT': 'KP.',
  'KP 0': '0',
  'KP 1': '1',
  'KP 2': '2',
  'KP 3': '3',
  'KP 4': '4',
  'KP 5': '5',
  'KP 6': '6',
  'KP 7': '7',
  'KP 8': '8',
  'KP 9': '9',
  // Layer names (appear as layer-tap hold legends, and as &tog targets).
  default: 'Base',
  cursor: 'Cursor',
  number: 'Number',
  symbol: 'Symbol',
  mouse: 'Mouse',
  tmux: 'Tmux',
  lower: 'Lower',
  magic: 'Magic',
  sticky: 'Sticky',
  toggle: 'Lock',
  mouse_fast: 'Fast',
  mouse_warp: 'Warp',
  mouse_slow: 'Slow',
}

// Shifted-number / shifted-punct tokens render as the symbol they produce, so
// the number/symbol layers read as the actual glyphs the user types.
const SHIFTED_SYMBOL: Record<string, string> = {
  '1': '!',
  '2': '@',
  '3': '#',
  '4': '$',
  '5': '%',
  '6': '^',
  '7': '&',
  '8': '*',
  '9': '(',
  '0': ')',
  '-': '_',
  '=': '+',
  '[': '{',
  ']': '}',
  '\\': '|',
  '/': '?',
  ',': '<',
  '.': '>',
  ';': ':',
  "'": '"',
  '`': '~',
}

// Cmd-chord editing shortcuts → the action they perform (cursor/number layers).
const GUI_ACTION: Record<string, string> = {
  X: 'Cut',
  C: 'Copy',
  V: 'Paste',
  Z: 'Undo',
  F: 'Find',
  G: 'FindNxt',
  A: 'SelAll',
  L: 'GoLine',
  K: 'DelLine',
  H: 'Hide',
  LEFT: 'WordL',
  RIGHT: 'WordR',
}

// ZMK behavior refs (&foo ARG) → short, readable cap legends.
const BEHAVIOR_MAP: Record<string, string> = {
  '&triple_backtick': '```',
  '&dot_dot': '..',
  '&select_all': 'SelAll',
  '&select_line': 'SelLine',
  '&select_word': 'SelWord',
  '&layer_td': 'Lower',
  '&rgb_ug_status_macro': 'RGB',
  '&bootloader': 'Boot',
  '&sys_reset': 'Reset',
  // Mouse keys — clicks read as actions, scroll/move keep their direction.
  '&mkp LCLK': 'LClk',
  '&mkp RCLK': 'RClk',
  '&mkp MCLK': 'MClk',
  '&mkp MB4': 'MB4',
  '&mkp MB5': 'MB5',
  '&mmv MOVE_UP': '↑',
  '&mmv MOVE_DOWN': '↓',
  '&mmv MOVE_LEFT': '←',
  '&mmv MOVE_RIGHT': '→',
  '&msc SCRL_UP': 'ScrUp',
  '&msc SCRL_DOWN': 'ScrDn',
  '&msc SCRL_LEFT': 'ScrL',
  '&msc SCRL_RIGHT': 'ScrR',
}

// tmux_key ARG → the tmux action it triggers (sends the Ctrl+Space prefix then
// the key). Keyed by the bare arg as it appears after "&tmux_key ".
const TMUX_ACTION: Record<string, string> = {
  S: 'Tree',
  D: 'Detach',
  Z: 'Zoom',
  C: 'NewWin',
  H: 'Pane←',
  J: 'Pane↓',
  K: 'Pane↑',
  L: 'Pane→',
  N: 'NextWin',
  P: 'PrevWin',
  M: 'PrevWin',
  O: 'CopyCwd',
  'LS(BSLH)': 'Split|',
  'LS(MINUS)': 'Split_',
}

/** Special default-layer keys that render an app icon + name instead of a raw
 *  modifier chord. Keyed by legendIndex (position on the default layer). */
export type SpecialIcon = 'raycast' | 'wispr'
export const SPECIAL_KEYS: Record<number, { icon: SpecialIcon; label: string }> = {
  55: { icon: 'raycast', label: 'Raycast' }, // &kp LG(SPACE) = Cmd+Space
  57: { icon: 'wispr', label: 'Wispr' }, // &wispr LG(F18)/LG(F19) = dictation
}

/** Per-layer activator: legendIndex of the thumb you HOLD to reach that layer.
 *  Glowing this cap tells the user which key activates the active layer. */
export const LAYER_ACTIVATOR: Record<string, number> = {
  cursor: 69, // Bksp thumb  (&lt_thumb CURSOR BSPC)
  number: 70, // Del thumb   (&lt_thumb NUMBER DEL)
  tmux: 72, // Ctl+Spc thumb (&lt_thumb TMUX LC(SPACE))
  mouse: 73, // Enter thumb  (&lt_thumb MOUSE RET)
  symbol: 74, // Space thumb  (&lt_space SYMBOL SPACE)
  lower: 54, // Lower thumb  (&layer_td)
}

/** legendIndex of the thumb that activates the given layer, if any. */
export function activatorIndex(layerName: string): number | undefined {
  return LAYER_ACTIVATOR[layerName]
}

/** Tidy a raw ZMK/keymap-drawer legend token for display on a cap. */
export function prettyLegend(token: string | undefined): string {
  if (!token) return ''
  let t = token.trim()
  if (t === '▽' || t === '') return '' // keymap-drawer "transparent"/empty

  // ZMK behavior refs.
  if (t.startsWith('&')) {
    if (BEHAVIOR_MAP[t]) return BEHAVIOR_MAP[t]
    // &tmux_key X / &tmux_key LS(MINUS) → the tmux action it performs.
    const tm = /^&tmux_key\s+(.+)$/.exec(t)
    if (tm) return TMUX_ACTION[tm[1].trim()] ?? prettyLegend(stripMods(tm[1]))
    // Generic "&beh ARG" → humanize the argument.
    const m = /^&\w+\s+(.+)$/.exec(t)
    if (m) return prettyLegend(stripMods(m[1]))
    return '' // unknown bare behavior — drop rather than show "&foo"
  }

  if (TOKEN_MAP[t]) return TOKEN_MAP[t]

  // Modifier chords like "Gui+SPACE", "Sft+4", "Gui+Sft+Z".
  if (t.includes('+')) {
    const parts = t.split('+').map((p) => p.trim())
    const mods = parts.slice(0, -1)
    const core = parts[parts.length - 1]
    const onlyShift = mods.length === 1 && /^sft$/i.test(mods[0])
    const hasGui = mods.some((m) => /^gui$/i.test(m))

    // Shift + symbol/number → the produced glyph (e.g. Sft+4 → $, Sft+9 → ().
    if (onlyShift) {
      const glyph = stripMods(core)
      if (SHIFTED_SYMBOL[glyph]) return SHIFTED_SYMBOL[glyph]
      return glyph
    }
    // Cmd-chord editing shortcuts → the action they perform. Match on the raw
    // core token (LEFT/RIGHT/Z/…) BEFORE stripMods turns it into a glyph.
    if (hasGui) {
      const shifted = mods.some((m) => /^sft$/i.test(m))
      const c = core.toUpperCase()
      if (c === 'Z') return shifted ? 'Redo' : 'Undo'
      if (c === 'G') return shifted ? 'FindPrv' : 'FindNxt'
      if (GUI_ACTION[c]) return GUI_ACTION[c]
    }
    return TOKEN_MAP[core] ?? stripMods(core)
  }

  // Strip ZMK modifier wrappers like LS(MINUS), LC(LA(...)) down to the core.
  t = stripMods(t)
  if (TOKEN_MAP[t]) return TOKEN_MAP[t]
  return t
}

/** Unwrap ZMK modifier-function notation, e.g. LS(MINUS) → MINUS, and map a
 *  few key names to glyphs. Recurses through nested wrappers. */
function stripMods(token: string): string {
  let t = token.trim()
  let m: RegExpExecArray | null
  while ((m = /^[LR][SCAG]\((.+)\)$/.exec(t))) t = m[1].trim()
  const NAME_GLYPH: Record<string, string> = {
    MINUS: '-',
    BSLH: '\\',
    EQUAL: '=',
    GRAVE: '`',
    SEMI: ';',
    COMMA: ',',
    DOT: '.',
    FSLH: '/',
    LBKT: '[',
    RBKT: ']',
    SQT: "'",
  }
  return NAME_GLYPH[t] ?? TOKEN_MAP[t] ?? t
}

/** Legend (tap/hold) for a legend index in a given layer name. */
export function legendFor(legendIndex: number, layerName: string): Legend {
  const layer = LAYER_LEGENDS[layerName] ?? LAYER_LEGENDS.default
  return layer?.[legendIndex] ?? { tap: '' }
}

// ---- live-typing / tutorial highlight maps --------------------------------
/** event.code → key ids that should light. One code may map to >1 cap. */
export const CODE_TO_IDS: Record<string, string[]> = KEYS.reduce(
  (acc, k) => {
    if (k.code) (acc[k.code] ||= []).push(k.id)
    return acc
  },
  {} as Record<string, string[]>,
)

/** Codes we actively light — gates which keydowns we handle. */
export const LIT_CODES = new Set(Object.keys(CODE_TO_IDS))

// ---- home-row mods (CAGS) -------------------------------------------------
/** The four held modifiers, each lighting its TWO home-row keys (one per hand).
 *  Glove80 home-row mods: L A=Ctrl S=Alt D=Cmd F=Shift / R J=Shift K=Cmd
 *  L=Alt ;=Ctrl. Keyed by a stable modifier name. */
export type ModName = 'ctrl' | 'alt' | 'meta' | 'shift'

/** modifier → the two event.codes (its home-row mod keys, left + right). */
export const CODES_BY_MOD: Record<ModName, string[]> = {
  ctrl: ['KeyA', 'Semicolon'],
  alt: ['KeyS', 'KeyL'],
  meta: ['KeyD', 'KeyK'],
  shift: ['KeyF', 'KeyJ'],
}
