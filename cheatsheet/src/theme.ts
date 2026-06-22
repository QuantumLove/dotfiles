import * as THREE from 'three'

/**
 * "Graphite Sakura" colorway. A dark matte graphite case (so the pink caps and
 * the underglow bloom pop) with sakura-pink keycaps, a deeper-rose fn accent,
 * plum thumb/mod caps, and a soft pink RGB underglow. Caps stay matte
 * (roughness ~0.5, metalness 0); the case is darker and a touch glossier so it
 * reads as anodized graphite rather than washed cream.
 */
export const THEME = {
  case: '#26262d', // dark graphite body (matte anodized)
  caseFoot: '#17171b', // near-black feet
  keycap: '#F6C6D0', // sakura pink alphas
  keycapAccent: '#ECA6BC', // deeper rose accent (fn row)
  modAccent: '#C98AA8', // plum-rose thumb / modifier caps
  underglow: '#FF7BA8', // soft pink RGB underglow (emissive)
  legendDim: '#5b3a47', // muted plum legend at rest — dark for contrast on pink
  legendLit: '#ffffff',
  underglowColor: new THREE.Color('#FF7BA8'),
}
