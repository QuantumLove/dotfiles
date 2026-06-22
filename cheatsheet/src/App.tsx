import { useEffect } from 'react'
import { Scene } from './Scene'
import { SidePanel } from './SidePanel'
import { useStore } from './store'
import { LIT_CODES, type ModName } from './glove80Layout'
import './App.css'

export default function App() {
  const pressKey = useStore((s) => s.pressKey)
  const releaseKey = useStore((s) => s.releaseKey)
  const setMods = useStore((s) => s.setMods)
  const nextStep = useStore((s) => s.nextStep)
  const prevStep = useStore((s) => s.prevStep)
  const cycleLayerByDigit = useStore((s) => s.cycleLayerByDigit)
  const setLayer = useStore((s) => s.setLayer)
  const nextService = useStore((s) => s.nextService)
  const prevService = useStore((s) => s.prevService)

  useEffect(() => {
    // Derive the held-modifier set from an event's modifier flags. On a
    // modifier keyDOWN the event flag is already set; on keyUP it's already
    // cleared — so reading the flags after both events tracks state correctly.
    const modsFromEvent = (e: KeyboardEvent): Set<ModName> => {
      const m = new Set<ModName>()
      if (e.ctrlKey) m.add('ctrl')
      if (e.altKey) m.add('alt')
      if (e.metaKey) m.add('meta')
      if (e.shiftKey) m.add('shift')
      return m
    }

    const onDown = (e: KeyboardEvent) => {
      // Keep the HRM glow in sync with the OS modifier state on every event.
      setMods(modsFromEvent(e))
      // Ignore shortcuts while typing in the workflow search box.
      const target = e.target as HTMLElement | null
      if (target && (target.tagName === 'INPUT' || target.tagName === 'TEXTAREA')) {
        return
      }

      // Real tmux prefix (Ctrl+Space) flips the app to the tmux layer, reusing
      // the existing layer-switch recolor/pulse.
      if (e.ctrlKey && e.code === 'Space') {
        e.preventDefault()
        setLayer('TMUX')
      }

      // Cycle the per-service bindings view with [ and ] (unmodified).
      if (!e.metaKey && !e.ctrlKey && !e.altKey) {
        if (e.code === 'BracketRight') {
          nextService()
          return
        }
        if (e.code === 'BracketLeft') {
          prevService()
          return
        }
      }

      // Tutorial stepping with the arrow keys.
      if (e.code === 'ArrowRight' && !e.metaKey && !e.ctrlKey) {
        nextStep()
      } else if (e.code === 'ArrowLeft' && !e.metaKey && !e.ctrlKey) {
        prevStep()
      }

      // Layer switch via top-row digits 1-6 (only when unmodified).
      if (!e.metaKey && !e.ctrlKey && !e.altKey) {
        const m = /^Digit([1-6])$/.exec(e.code)
        if (m) cycleLayerByDigit(parseInt(m[1], 10))
      }

      // Light the matching cap. Gate to codes we render; the store ignores
      // repeats so holding a key doesn't re-trigger.
      if (LIT_CODES.has(e.code)) {
        pressKey(e.code)
      }
    }

    const onUp = (e: KeyboardEvent) => {
      if (LIT_CODES.has(e.code)) releaseKey(e.code)
      // Re-read modifier flags on every keyup (the released modifier's flag is
      // already cleared in the event), so the HRM glow decays on release.
      setMods(modsFromEvent(e))
    }

    const onBlur = () => {
      // Release everything if the window loses focus mid-press.
      for (const code of LIT_CODES) releaseKey(code)
      setMods(new Set<ModName>())
    }

    window.addEventListener('keydown', onDown)
    window.addEventListener('keyup', onUp)
    window.addEventListener('blur', onBlur)
    return () => {
      window.removeEventListener('keydown', onDown)
      window.removeEventListener('keyup', onUp)
      window.removeEventListener('blur', onBlur)
    }
  }, [pressKey, releaseKey, setMods, nextStep, prevStep, cycleLayerByDigit, setLayer, nextService, prevService])

  return (
    <div className="app">
      <div className="stage">
        <Scene />
      </div>
      <SidePanel />
    </div>
  )
}
