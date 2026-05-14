// v6-rings.jsx — Apple Fitness-style concentric rings.
// 3 rings: Calories (red), Protein (green), Fiber (blue).
// Each ring fills toward target, can overshoot (shown with a glow cap).

function V6Rings({ size = 200, stroke = 18, gap = 4, rings, showCenter = true, center }) {
  // rings: [{ value, target, color, bg, label }]
  const cx = size / 2, cy = size / 2;
  const radii = rings.map((_, i) => (size - stroke) / 2 - i * (stroke + gap));

  return (
    <div style={{ position: 'relative', width: size, height: size }}>
      <svg width={size} height={size} style={{ transform: 'rotate(-90deg)' }}>
        <defs>
          {rings.map((r, i) => (
            <linearGradient key={i} id={`v6-rg-${i}-${r.color}`} x1="0" y1="0" x2="1" y2="1">
              <stop offset="0%" stopColor={r.color} stopOpacity="1"/>
              <stop offset="100%" stopColor={r.color} stopOpacity="0.78"/>
            </linearGradient>
          ))}
        </defs>
        {rings.map((r, i) => {
          const radius = radii[i];
          const C = 2 * Math.PI * radius;
          const pct = Math.min(r.value / r.target, 1);
          const over = r.value > r.target ? (r.value / r.target - 1) : 0;
          const fill = C * pct;
          return (
            <g key={i}>
              {/* track */}
              <circle cx={cx} cy={cy} r={radius} fill="none"
                      stroke={r.bg} strokeWidth={stroke}/>
              {/* progress */}
              <circle cx={cx} cy={cy} r={radius} fill="none"
                      stroke={`url(#v6-rg-${i}-${r.color})`} strokeWidth={stroke}
                      strokeLinecap="round"
                      strokeDasharray={`${fill} ${C}`}
                      style={{ transition: 'stroke-dasharray .6s cubic-bezier(.2,.7,.3,1)' }}/>
              {/* overshoot — second arc on top, slightly inset for halo effect */}
              {over > 0 && (
                <circle cx={cx} cy={cy} r={radius} fill="none"
                        stroke={r.color} strokeWidth={stroke * 0.6}
                        strokeLinecap="round"
                        strokeDasharray={`${C * Math.min(over, 1)} ${C}`}
                        opacity="0.35"/>
              )}
            </g>
          );
        })}
      </svg>
      {showCenter && (
        <div style={{
          position: 'absolute', inset: 0,
          display: 'flex', flexDirection: 'column',
          alignItems: 'center', justifyContent: 'center',
          pointerEvents: 'none',
        }}>{center}</div>
      )}
    </div>
  );
}

// ─── Tiny pill ring (for compact stat tiles) ──────────────
function V6MiniRing({ size = 36, stroke = 5, value, target, color, bg }) {
  const r = (size - stroke) / 2;
  const C = 2 * Math.PI * r;
  const pct = Math.min(value / target, 1);
  return (
    <svg width={size} height={size} style={{ transform: 'rotate(-90deg)' }}>
      <circle cx={size/2} cy={size/2} r={r} fill="none" stroke={bg} strokeWidth={stroke}/>
      <circle cx={size/2} cy={size/2} r={r} fill="none"
              stroke={color} strokeWidth={stroke} strokeLinecap="round"
              strokeDasharray={`${C * pct} ${C}`}/>
    </svg>
  );
}

// ─── Legend dot (small color square + label) ───────────────
function V6RingLegend({ rings }) {
  return (
    <div style={{ display: 'flex', justifyContent: 'space-around', gap: 12, width: '100%' }}>
      {rings.map((r, i) => (
        <div key={i} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4, flex: 1 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 5 }}>
            <span style={{ width: 7, height: 7, borderRadius: '50%', background: r.color }}/>
            <span style={{
              fontFamily: V6.sans, fontSize: 11, fontWeight: 600, color: V6.ink2,
              letterSpacing: '-0.005em',
            }}>{r.label}</span>
          </div>
          <div style={{ fontFamily: V6.display, fontSize: 15, fontWeight: 700, color: V6.ink,
                        fontVariantNumeric: 'tabular-nums', letterSpacing: '-0.02em' }}>
            {r.value}<span style={{ color: V6.ink3, fontWeight: 500 }}>/{r.target}{r.unit || ''}</span>
          </div>
        </div>
      ))}
    </div>
  );
}

Object.assign(window, { V6Rings, V6MiniRing, V6RingLegend, V6LegendItem });

// ─── Standalone legend item (matches V6RingLegend item style) ──
function V6LegendItem({ label, value, target, unit, color }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 5 }}>
        <span style={{ width: 7, height: 7, borderRadius: '50%', background: color }}/>
        <span style={{
          fontFamily: V6.sans, fontSize: 11, fontWeight: 600, color: V6.ink2,
          letterSpacing: '-0.005em',
        }}>{label}</span>
      </div>
      <div style={{
        fontFamily: V6.display, fontSize: 15, fontWeight: 700, color: V6.ink,
        fontVariantNumeric: 'tabular-nums', letterSpacing: '-0.02em',
      }}>
        {value}<span style={{ color: V6.ink3, fontWeight: 500 }}>/{target}{unit || ''}</span>
      </div>
    </div>
  );
}
