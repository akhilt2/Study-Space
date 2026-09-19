'use client'

import React from 'react'

type MathJaxApi = {
  typesetPromise: (elements?: HTMLElement[]) => Promise<void>
}

declare global {
  interface Window {
    MathJax?: MathJaxApi
  }
}

let mathJaxPromise: Promise<MathJaxApi> | null = null

function loadMathJax(): Promise<MathJaxApi> {
  if (typeof window === 'undefined') return Promise.reject(new Error('MathJax requires a browser'))
  if (window.MathJax?.typesetPromise) return Promise.resolve(window.MathJax)
  if (mathJaxPromise) return mathJaxPromise

  mathJaxPromise = new Promise((resolve, reject) => {
    const existing = document.querySelector<HTMLScriptElement>('script[data-study-space-mathjax]')
    if (existing) {
      existing.addEventListener('load', () => window.MathJax && resolve(window.MathJax))
      existing.addEventListener('error', () => reject(new Error('Unable to load MathJax')))
      return
    }

    const script = document.createElement('script')
    script.src = 'https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-svg.js'
    script.async = true
    script.dataset.studySpaceMathjax = 'true'
    script.onload = () => window.MathJax && resolve(window.MathJax)
    script.onerror = () => reject(new Error('Unable to load MathJax'))
    document.head.appendChild(script)
  })

  return mathJaxPromise
}

type MathJaxCodeProps = React.HTMLAttributes<HTMLElement> & {
  node?: unknown
}

export function MathJaxCode({ className, children, ...props }: MathJaxCodeProps) {
  const isMath = className?.includes('math-inline') || className?.includes('math-display')
  const ref = React.useRef<HTMLElement>(null)
  const source = String(children ?? '').replace(/\n$/, '')

  React.useEffect(() => {
    if (!isMath || !ref.current) return
    const element = ref.current
    element.textContent = className?.includes('math-display') ? `\\[${source}\\]` : `\\(${source}\\)`
    loadMathJax()
      .then((mathJax) => mathJax.typesetPromise([element]))
      .catch(() => {
        element.textContent = source
      })
  }, [className, isMath, source])

  if (!isMath) return <code className={className} {...props}>{children}</code>
  if (className?.includes('math-display')) {
    return <div ref={ref as React.RefObject<HTMLDivElement>} className="mathjax-display overflow-x-auto" {...props} />
  }
  return <span ref={ref} className="mathjax-inline" {...props} />
}
