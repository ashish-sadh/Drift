// v6-theme.jsx — Drift v6. Light-only, Apple Fitness DNA.
// Soft white surfaces, glassy depth, vivid ring palette. One display family,
// one body family, mono only for tabular numerics.

const V6 = {
  // Surfaces (warm, near-white)
  bg:        'oklch(0.985 0.002 250)',   // paper
  bg2:       'oklch(0.965 0.003 250)',   // grouped scroll bg
  surface:   '#ffffff',                  // card
  surface2:  'oklch(0.965 0.003 250)',   // inset/sub
  surface3:  'oklch(0.945 0.004 250)',   // pill / chip
  hairline:  'oklch(0.92 0.003 250)',
  hairline2: 'oklch(0.95 0.003 250)',

  // Ink (cool near-black)
  ink:   'oklch(0.18 0.012 260)',
  ink2:  'oklch(0.40 0.010 260)',
  ink3:  'oklch(0.58 0.008 260)',
  ink4:  'oklch(0.74 0.006 260)',

  // Vivid Apple-Fitness ring palette
  ringMove:    'oklch(0.66 0.22 25)',   // red — move/kcal
  ringMoveBg:  'oklch(0.94 0.06 25)',
  ringEx:      'oklch(0.78 0.20 145)',  // green — protein / exercise
  ringExBg:    'oklch(0.94 0.07 145)',
  ringStand:   'oklch(0.78 0.18 220)',  // blue — fiber / hydration / stand
  ringStandBg: 'oklch(0.94 0.05 220)',
  ringCarbs:   'oklch(0.83 0.16 90)',   // amber — carbs
  ringCarbsBg: 'oklch(0.95 0.07 90)',
  ringFat:     'oklch(0.78 0.16 60)',   // orange — fat
  ringFatBg:   'oklch(0.95 0.07 60)',

  // Semantic
  good:   'oklch(0.66 0.16 145)',
  goodSoft:'oklch(0.95 0.05 145)',
  warn:   'oklch(0.74 0.16 70)',
  warnSoft:'oklch(0.95 0.06 70)',
  bad:    'oklch(0.62 0.21 25)',
  badSoft: 'oklch(0.95 0.05 25)',

  // Accent (picks one of the ring hues)
  accent: 'oklch(0.66 0.22 25)',
  accentSoft: 'oklch(0.94 0.06 25)',

  // Typography
  display: '"Geist","SF Pro Display",-apple-system,system-ui,sans-serif',
  sans:    '"Inter","SF Pro Text",-apple-system,system-ui,sans-serif',
  mono:    '"JetBrains Mono","SF Mono",ui-monospace,Menlo,monospace',

  r: { sm: 8, md: 14, lg: 20, xl: 28, pill: 999 },
  shadow: {
    soft: '0 1px 2px oklch(0.18 0.012 260 / 0.04), 0 0 0 0.5px oklch(0.18 0.012 260 / 0.04)',
    pop:  '0 10px 30px oklch(0.18 0.012 260 / 0.10), 0 2px 8px oklch(0.18 0.012 260 / 0.06)',
    raise:'0 4px 14px oklch(0.18 0.012 260 / 0.07), 0 0 0 0.5px oklch(0.18 0.012 260 / 0.05)',
  },
};

// ─── Big stat number (display, tabular) ────────────────────
function V6Num({ value, size = 48, color, weight = 700, style = {} }) {
  return (
    <span style={{
      fontFamily: V6.display,
      fontVariantNumeric: 'tabular-nums lining-nums',
      fontSize: size, fontWeight: weight,
      letterSpacing: '-0.03em',
      lineHeight: 0.95,
      color: color || V6.ink,
      ...style,
    }}>{value}</span>
  );
}

// ─── Section label (Apple-style: small, semibold, sentence case) ──
function V6SectionHead({ title, aside, action, style = {} }) {
  return (
    <div style={{
      display: 'flex', alignItems: 'baseline', justifyContent: 'space-between',
      padding: '0 4px 10px', ...style,
    }}>
      <span style={{
        fontFamily: V6.display, fontSize: 20, fontWeight: 700, color: V6.ink,
        letterSpacing: '-0.022em',
      }}>{title}</span>
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 8 }}>
        {aside && (
          <span style={{
            fontFamily: V6.sans, fontSize: 12, color: V6.ink3, fontWeight: 500,
          }}>{aside}</span>
        )}
        {action}
      </div>
    </div>
  );
}

// ─── Card surface ──────────────────────────────────────────
function V6Card({ children, style = {}, padded = true, inset = false, raised = false, onClick }) {
  const isButton = !!onClick;
  const Comp = isButton ? 'button' : 'div';
  return (
    <Comp onClick={onClick} style={{
      background: inset ? V6.surface2 : V6.surface,
      borderRadius: V6.r.lg,
      boxShadow: raised ? V6.shadow.raise : V6.shadow.soft,
      padding: padded ? '16px 18px' : 0,
      border: 'none', textAlign: 'left',
      width: isButton ? '100%' : undefined,
      cursor: isButton ? 'pointer' : undefined,
      ...style,
    }}>{children}</Comp>
  );
}

// ─── Pill (tap target, supports leading icon) ──────────────
function V6Pill({ children, onClick, tone = 'neutral', size = 'md', style = {} }) {
  const tones = {
    neutral: { bg: V6.surface3, fg: V6.ink },
    accent:  { bg: V6.ink, fg: V6.bg },
    soft:    { bg: V6.accentSoft, fg: V6.accent },
    ghost:   { bg: 'transparent', fg: V6.ink2 },
  };
  const sizes = {
    sm: { pad: '6px 10px', fs: 11 },
    md: { pad: '8px 14px', fs: 12.5 },
    lg: { pad: '12px 18px', fs: 14 },
  };
  const t = tones[tone], s = sizes[size];
  return (
    <button onClick={onClick} style={{
      background: t.bg, color: t.fg, border: 'none',
      borderRadius: V6.r.pill, padding: s.pad, cursor: 'pointer',
      fontFamily: V6.sans, fontSize: s.fs, fontWeight: 600,
      display: 'inline-flex', alignItems: 'center', gap: 6,
      letterSpacing: '-0.005em',
      ...style,
    }}>{children}</button>
  );
}

// ─── Chevron ───────────────────────────────────────────────
function V6Chev({ color, size = 14 }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none"
         stroke={color || V6.ink3} strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round">
      <path d="M9 6l6 6-6 6"/>
    </svg>
  );
}

Object.assign(window, { V6, V6Num, V6SectionHead, V6Card, V6Pill, V6Chev });
