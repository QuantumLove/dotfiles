import { useEffect, useMemo, useRef, useState } from 'react'
import { LAYERS, LAYER_BY_ID } from './layers'
import { useStore } from './store'
import { GUIDED } from './guided'
import content from './data/app-content.json'

/** Subsequence fuzzy match: every char of `q` appears in order in `text`. */
function fuzzyMatch(text: string, q: string): boolean {
  if (!q) return true
  const t = text.toLowerCase()
  let i = 0
  for (const ch of q.toLowerCase()) {
    i = t.indexOf(ch, i)
    if (i === -1) return false
    i += 1
  }
  return true
}

/**
 * A scrollable region that responds to BOTH the mouse wheel (native overflow)
 * AND the keyboard (arrows / j-k / PageUp-PageDown / Home-End) when the region
 * is hovered or holds focus. tabIndex={0} makes it focusable; the keydown is
 * scoped to the element so it never hijacks global app shortcuts elsewhere.
 */
function ScrollBox({
  className,
  children,
}: {
  className?: string
  children: React.ReactNode
}) {
  const ref = useRef<HTMLDivElement>(null)
  const hovered = useRef(false)

  useEffect(() => {
    const el = ref.current
    if (!el) return
    const onKey = (e: KeyboardEvent) => {
      // Only act when this region is hovered or focused.
      const active = hovered.current || el.contains(document.activeElement)
      if (!active) return
      // Don't fight typing in an input within the region.
      const t = e.target as HTMLElement | null
      if (t && (t.tagName === 'INPUT' || t.tagName === 'TEXTAREA')) return
      const line = 48
      const page = el.clientHeight - 40
      let dy = 0
      switch (e.key) {
        case 'ArrowDown':
        case 'j':
          dy = line
          break
        case 'ArrowUp':
        case 'k':
          dy = -line
          break
        case 'PageDown':
          dy = page
          break
        case 'PageUp':
          dy = -page
          break
        case 'Home':
          el.scrollTo({ top: 0, behavior: 'smooth' })
          e.preventDefault()
          return
        case 'End':
          el.scrollTo({ top: el.scrollHeight, behavior: 'smooth' })
          e.preventDefault()
          return
        default:
          return
      }
      el.scrollBy({ top: dy, behavior: 'smooth' })
      e.preventDefault()
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [])

  return (
    <div
      ref={ref}
      className={`scrollbox${className ? ' ' + className : ''}`}
      tabIndex={0}
      onMouseEnter={() => (hovered.current = true)}
      onMouseLeave={() => (hovered.current = false)}
    >
      {children}
    </div>
  )
}

export function SidePanel() {
  const layer = useStore((s) => s.layer)
  const setLayer = useStore((s) => s.setLayer)
  const workflowIndex = useStore((s) => s.workflowIndex)
  const stepIndex = useStore((s) => s.stepIndex)
  const nextStep = useStore((s) => s.nextStep)
  const prevStep = useStore((s) => s.prevStep)
  const goStep = useStore((s) => s.goStep)
  const setWorkflow = useStore((s) => s.setWorkflow)
  const tutorialOn = useStore((s) => s.tutorialOn)
  const toggleTutorial = useStore((s) => s.toggleTutorial)
  const serviceIndex = useStore((s) => s.serviceIndex)
  const nextService = useStore((s) => s.nextService)
  const prevService = useStore((s) => s.prevService)
  const setService = useStore((s) => s.setService)

  const [query, setQuery] = useState('')

  const accent = LAYER_BY_ID[layer].color
  const workflow = GUIDED[workflowIndex]
  const service = content.services[serviceIndex]

  const groups = useMemo(() => {
    const q = query.trim()
    return content.workflows
      .map((g) => ({
        ...g,
        items: g.items.filter(
          (it) => fuzzyMatch(it.name, q) || fuzzyMatch(it.does, q),
        ),
      }))
      .filter((g) => g.items.length > 0)
  }, [query])

  return (
    <aside className="panel" style={{ ['--accent' as string]: accent }}>
      <header className="brand">
        <div className="brand-mark" />
        <div>
          <div className="brand-title">LIVING GLOVE80</div>
          <div className="brand-sub">the keyboard is the hero</div>
        </div>
      </header>

      <section className="layers">
        <div className="section-label">Layer</div>
        <div className="layer-grid">
          {LAYERS.map((l, i) => {
            const active = l.id === layer
            return (
              <button
                key={l.id}
                className={`layer-chip${active ? ' active' : ''}`}
                style={{ ['--chip' as string]: l.color }}
                onClick={() => setLayer(l.id)}
                title={l.blurb}
              >
                <span className="chip-num">{i + 1}</span>
                <span className="chip-name">{l.name}</span>
              </button>
            )
          })}
        </div>
        <div className="layer-blurb">{LAYER_BY_ID[layer].blurb}</div>
      </section>

      {/* ---- Guided workflows (multi-step) — FIRST, above per-service bindings ---- */}
      <section className="card guided">
        <div className="card-top">
          <div className="section-label">Guided workflows</div>
          <button className="ghost" onClick={toggleTutorial}>
            {tutorialOn ? 'board follows: on' : 'board follows: off'}
          </button>
        </div>

        <div className="wf-rail">
          {GUIDED.map((w, i) => (
            <button
              key={w.id}
              className={`wf-tab${i === workflowIndex ? ' on' : ''}`}
              onClick={() => setWorkflow(i)}
              title={w.blurb}
            >
              {w.name}
            </button>
          ))}
        </div>

        <div className="card-app">{workflow.app}</div>
        <div className="card-name">{workflow.name}</div>
        <div className="wf-blurb">{workflow.blurb}</div>

        <ScrollBox className="wf-steps">
          {workflow.steps.map((s, i) => {
            const on = i === stepIndex
            return (
              <button
                key={i}
                className={`wf-step${on ? ' on' : ''}`}
                onClick={() => goStep(i)}
              >
                <span className="wf-num">{i + 1}</span>
                <span className="wf-body">
                  <span className="wf-step-head">
                    <span className="kbd wf-key">{s.key}</span>
                    <span className="wf-action">{s.action}</span>
                  </span>
                  <span className="wf-detail">{s.detail}</span>
                </span>
              </button>
            )
          })}
        </ScrollBox>

        <div className="card-nav">
          <button className="nav-btn" onClick={prevStep} aria-label="Previous step">
            ‹ Prev
          </button>
          <div className="dots">
            {workflow.steps.map((_, i) => (
              <button
                key={i}
                className={`dot${i === stepIndex ? ' on' : ''}`}
                onClick={() => goStep(i)}
                aria-label={`Step ${i + 1}`}
              />
            ))}
          </div>
          <button className="nav-btn" onClick={nextStep} aria-label="Next step">
            Next ›
          </button>
        </div>
        <div className="card-hint">
          ← / → step the workflow · click a step to follow it on the board · scroll with wheel or ↑↓/j-k
        </div>
      </section>

      <section className="svc">
        <div className="svc-top">
          <div className="section-label">Bindings · {service.name}</div>
          <div className="svc-cycle">
            <button className="cyc-btn" onClick={prevService} aria-label="Previous service">
              [
            </button>
            <span className="cyc-count">
              {serviceIndex + 1}/{content.services.length}
            </span>
            <button className="cyc-btn" onClick={nextService} aria-label="Next service">
              ]
            </button>
          </div>
        </div>

        <div className="svc-rail">
          {content.services.map((s, i) => (
            <button
              key={s.id}
              className={`svc-tab${i === serviceIndex ? ' on' : ''}`}
              onClick={() => setService(i)}
              title={s.tag}
            >
              {s.name}
            </button>
          ))}
        </div>

        <div className="svc-head">
          <span className="svc-name">{service.name}</span>
          <span className="svc-tag">{service.tag}</span>
        </div>

        <ScrollBox className="svc-scroll">
          <ul className="svc-list">
            {service.bindings.map((b, i) => (
              <li key={i} className={`svc-row${b.learn ? ' learn' : ''}`}>
                <span className="svc-task">{b.task}</span>
                <span className="svc-keys">{b.keys}</span>
              </li>
            ))}
          </ul>
          {service.note && <div className="svc-note">{service.note}</div>}
        </ScrollBox>
        <div className="svc-hint">[ / ] to cycle services · scroll with wheel or ↑↓/j-k · ★ = learn first</div>
      </section>

      <section className="flows">
        <div className="flows-top">
          <div className="section-label">Workflows &amp; commands</div>
        </div>
        <input
          className="flows-search"
          type="text"
          value={query}
          placeholder="filter functions, ops, /skills…"
          onChange={(e) => setQuery(e.target.value)}
        />
        <ScrollBox className="flows-scroll">
          {groups.length === 0 && <div className="flows-empty">no matches</div>}
          {groups.map((g) => (
            <div key={g.id} className="flow-group">
              <div className="flow-group-name">{g.name}</div>
              <ul className="flow-list">
                {g.items.map((it, i) => (
                  <li key={i} className="flow-row">
                    <code className="flow-cmd">{it.name}</code>
                    <span className="flow-does">{it.does}</span>
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </ScrollBox>
      </section>

      <section className="repos">
        <div className="section-label">Repos</div>
        <div className="repo-links">
          {content.repos.map((r) => (
            <a
              key={r.url}
              className="repo-link"
              href={r.url}
              target="_blank"
              rel="noreferrer noopener"
            >
              <span className="repo-dot" />
              {r.name}
            </a>
          ))}
        </div>
      </section>
    </aside>
  )
}
