// v6-body.jsx — Body tab. Consolidated: Weight, Sleep/Rhythm, Glucose, Body Comp.
// Each section opens a deeper sub-screen via a card-button.

function V6BodyTab({ data, onOpenSub, onOpenAI, accent }) {
  const w = data.weight, r = data.bodyRhythm, g = data.glucose, b = data.bodyComp;

  return (
    <div style={{ padding: '0 0 130px', background: V6.bg2, minHeight: '100%' }}>

      {/* ── Weight card with sparkline ─────────────────── */}
      <div style={{ padding: '4px 16px 0' }}>
        <V6Card onClick={() => onOpenSub('weight')} padded={false} raised
          style={{ padding: 0, borderRadius: V6.r.xl, overflow: 'hidden' }}>
          <div style={{ padding: '18px 18px 12px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
              <div>
                <div style={{
                  fontFamily: V6.sans, fontSize: 11.5, fontWeight: 700, color: V6.ink3,
                  letterSpacing: '0.08em', textTransform: 'uppercase',
                }}>Weight</div>
                <div style={{ display: 'flex', alignItems: 'baseline', gap: 6, marginTop: 6 }}>
                  <V6Num value={w.current} size={42}/>
                  <span style={{
                    fontFamily: V6.sans, fontSize: 13, color: V6.ink3, fontWeight: 600,
                  }}>lbs</span>
                </div>
                <div style={{
                  fontFamily: V6.sans, fontSize: 12.5, color: V6.ink2, marginTop: 6,
                  fontVariantNumeric: 'tabular-nums',
                }}>
                  <span style={{ color: w.weeklyChange < 0 ? V6.bad : V6.good, fontWeight: 700 }}>
                    {w.weeklyChange > 0 ? '+' : ''}{w.weeklyChange} lbs
                  </span>
                  <span style={{ color: V6.ink3 }}> this week · trend {w.trendWeight}</span>
                </div>
              </div>
              <V6Chev/>
            </div>
          </div>
          <V6Spark series={w.series} color={V6.ringMove} height={80} range={w.range}/>
          <div style={{
            display: 'grid', gridTemplateColumns: 'repeat(5,1fr)', borderTop: `0.5px solid ${V6.hairline}`,
          }}>
            {[['3d', w.deltas['3d']], ['7d', w.deltas['7d']], ['14d', w.deltas['14d']],
              ['30d', w.deltas['30d']], ['90d', w.deltas['90d']]].map(([k, v]) => (
              <div key={k} style={{ padding: '10px 4px 11px', textAlign: 'center',
                borderRight: k === '90d' ? 'none' : `0.5px solid ${V6.hairline}` }}>
                <div style={{
                  fontFamily: V6.sans, fontSize: 10, fontWeight: 700, color: V6.ink3,
                  letterSpacing: '0.06em',
                }}>{k.toUpperCase()}</div>
                <div style={{
                  fontFamily: V6.display, fontSize: 14, fontWeight: 700,
                  color: v > 0 ? V6.good : v < 0 ? V6.bad : V6.ink3, marginTop: 2,
                  fontVariantNumeric: 'tabular-nums', letterSpacing: '-0.02em',
                }}>{v > 0 ? '+' : ''}{v}</div>
              </div>
            ))}
          </div>
        </V6Card>
      </div>

      {/* ── Goal mini ─────────────────────────────────── */}
      <div style={{ padding: '10px 16px 0' }}>
        <V6Card onClick={() => onOpenSub('weight-goal')} padded={false}
          style={{ padding: '12px 14px', display: 'flex', alignItems: 'center', gap: 12 }}>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{
              fontFamily: V6.sans, fontSize: 11, fontWeight: 700, color: V6.ink3,
              letterSpacing: '0.06em', textTransform: 'uppercase',
            }}>Goal · {data.goal.direction}</div>
            <div style={{
              fontFamily: V6.display, fontSize: 14, fontWeight: 600, color: V6.ink,
              letterSpacing: '-0.012em', marginTop: 4,
            }}>{w.current} → {data.goal.target} lbs · {data.goal.toGo} to go</div>
            <V6Progress pct={data.goal.pctDone} color={V6.accent}/>
          </div>
          <V6Chev/>
        </V6Card>
      </div>

      {/* ── Sleep & rhythm row ─────────────────────────── */}
      <div style={{ padding: '22px 16px 0' }}>
        <V6SectionHead title="Rhythm" aside={`Recovery ${r.recovery}`} action={
          <V6Pill tone="ghost" size="sm" onClick={() => onOpenSub('rhythm')}>Open</V6Pill>
        }/>
        <V6Card padded={false} style={{ padding: '16px 16px 14px' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 16 }}>
            <V6MiniRing size={64} stroke={9} value={r.sleep.slept} target={r.sleep.needed}
              color={V6.ringStand} bg={V6.ringStandBg}/>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{
                fontFamily: V6.sans, fontSize: 11, fontWeight: 700, color: V6.ink3,
                letterSpacing: '0.06em', textTransform: 'uppercase',
              }}>Last night</div>
              <div style={{ display: 'flex', alignItems: 'baseline', gap: 4, marginTop: 4 }}>
                <V6Num value={r.sleep.slept} size={26}/>
                <span style={{ fontFamily: V6.sans, fontSize: 13, color: V6.ink3 }}>h</span>
                <span style={{
                  fontFamily: V6.sans, fontSize: 12, color: V6.ink2, marginLeft: 6,
                  fontVariantNumeric: 'tabular-nums',
                }}>· {r.sleep.balance} balance</span>
              </div>
              <div style={{
                fontFamily: V6.sans, fontSize: 12, color: V6.ink2, marginTop: 4,
                lineHeight: 1.4,
              }}>{r.sleep.bed}</div>
            </div>
          </div>
          <div style={{
            display: 'grid', gridTemplateColumns: 'repeat(3,1fr)', gap: 8,
            marginTop: 14, paddingTop: 14, borderTop: `0.5px solid ${V6.hairline}`,
          }}>
            <V6KPI label="Resting HR" value={r.rhr} unit="bpm" delta={`${r.rhrChange > 0 ? '+' : ''}${r.rhrChange}`}/>
            <V6KPI label="Resp" value={r.respiratory} unit="br/m"/>
            <V6KPI label="Readiness" value={r.recovery} unit="" delta={`avg ${r.recoveryAvg}`}/>
          </div>
        </V6Card>
      </div>

      {/* ── Glucose ──────────────────────────────────── */}
      <div style={{ padding: '22px 16px 0' }}>
        <V6SectionHead title="Glucose" aside={`${g.timeInRange}% in range`} action={
          <V6Pill tone="ghost" size="sm" onClick={() => onOpenSub('glucose')}>Open</V6Pill>
        }/>
        <V6Card onClick={() => onOpenSub('glucose')} padded={false} style={{ padding: '14px 16px' }}>
          <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', marginBottom: 10 }}>
            <div>
              <V6Num value={g.current} size={28}/>
              <span style={{ fontFamily: V6.sans, fontSize: 12, color: V6.ink3, marginLeft: 4 }}>mg/dL now</span>
            </div>
            <div style={{
              fontFamily: V6.sans, fontSize: 11, color: V6.ink3, fontVariantNumeric: 'tabular-nums',
            }}>24h avg <b style={{ color: V6.ink, fontWeight: 700 }}>{g.mean24h}</b></div>
          </div>
          <V6GlucoseSpark series={g.series} low={g.low} high={g.high}/>
        </V6Card>
      </div>

      {/* ── Body composition ─────────────────────────── */}
      <div style={{ padding: '22px 16px 0' }}>
        <V6SectionHead title="Composition" aside={`Last scan · ${b.date}`} action={
          <V6Pill tone="ghost" size="sm" onClick={() => onOpenSub('bodycomp')}>Open</V6Pill>
        }/>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3,1fr)', gap: 8 }}>
          <V6CompTile label="Body fat" value={b.bodyFat} unit="%" delta={b.bodyFatChange}
            tone={V6.ringFat}/>
          <V6CompTile label="Lean mass" value={b.leanMass} unit="lb" delta={b.leanChange}
            tone={V6.ringEx}/>
          <V6CompTile label="Fat mass" value={b.fatMass} unit="lb" delta={b.fatChange}
            tone={V6.ringMove}/>
        </div>
      </div>

      {/* ── Biomarkers shortcut ───────────────────────── */}
      <div style={{ padding: '22px 16px 0' }}>
        <V6Card onClick={() => onOpenSub('biomarkers')} padded={false}
          style={{ padding: '14px 16px', display: 'flex', alignItems: 'center', gap: 12 }}>
          <div style={{
            width: 38, height: 38, borderRadius: 12, background: V6.ringStandBg,
            display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
          }}>
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke={V6.ringStand}
                 strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
              <path d="M9 2v6L4 19a2 2 0 0 0 2 3h12a2 2 0 0 0 2-3L15 8V2"/>
              <path d="M8 2h8M7 14h10"/>
            </svg>
          </div>
          <div style={{ flex: 1 }}>
            <div style={{
              fontFamily: V6.display, fontSize: 14, fontWeight: 700, color: V6.ink,
              letterSpacing: '-0.015em',
            }}>Biomarkers</div>
            <div style={{
              fontFamily: V6.sans, fontSize: 12, color: V6.ink2, marginTop: 2,
            }}>3 panels · last Feb 10 · 1 out of range</div>
          </div>
          <V6Chev/>
        </V6Card>
      </div>
    </div>
  );
}

// ─── Sparkline (weight) ────────────────────────────────────
function V6Spark({ series, color, height = 80, range }) {
  const min = range?.min ?? Math.min(...series);
  const max = range?.max ?? Math.max(...series);
  const w = 350, h = height;
  const pad = 6;
  const pts = series.map((v, i) => {
    const x = (i / (series.length - 1)) * (w - pad * 2) + pad;
    const y = h - pad - ((v - min) / (max - min)) * (h - pad * 2);
    return [x, y];
  });
  const d = pts.map((p, i) => `${i === 0 ? 'M' : 'L'} ${p[0].toFixed(1)} ${p[1].toFixed(1)}`).join(' ');
  const fill = `${d} L ${pts[pts.length-1][0]} ${h} L ${pts[0][0]} ${h} Z`;
  return (
    <svg viewBox={`0 0 ${w} ${h}`} width="100%" height={h} preserveAspectRatio="none"
         style={{ display: 'block' }}>
      <defs>
        <linearGradient id={`v6-spark-${color.replace(/[^a-z0-9]/gi, '')}`} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%"  stopColor={color} stopOpacity="0.20"/>
          <stop offset="100%" stopColor={color} stopOpacity="0"/>
        </linearGradient>
      </defs>
      <path d={fill} fill={`url(#v6-spark-${color.replace(/[^a-z0-9]/gi, '')})`}/>
      <path d={d} stroke={color} strokeWidth="2.2" fill="none" strokeLinejoin="round" strokeLinecap="round"/>
      <circle cx={pts[pts.length-1][0]} cy={pts[pts.length-1][1]} r="3" fill={color}/>
    </svg>
  );
}

// ─── Glucose sparkline w/ range band ───────────────────────
function V6GlucoseSpark({ series, low, high }) {
  const min = Math.min(...series, low) - 8;
  const max = Math.max(...series, high) + 8;
  const w = 350, h = 56, pad = 4;
  const y = v => h - pad - ((v - min) / (max - min)) * (h - pad * 2);
  const pts = series.map((v, i) => [(i / (series.length - 1)) * (w - pad * 2) + pad, y(v)]);
  const d = pts.map((p, i) => `${i === 0 ? 'M' : 'L'} ${p[0].toFixed(1)} ${p[1].toFixed(1)}`).join(' ');
  return (
    <svg viewBox={`0 0 ${w} ${h}`} width="100%" height={h} preserveAspectRatio="none"
         style={{ display: 'block' }}>
      <rect x="0" y={y(high)} width={w} height={y(low) - y(high)} fill={V6.goodSoft} opacity="0.6"/>
      <path d={d} stroke={V6.ringStand} strokeWidth="1.8" fill="none" strokeLinejoin="round" strokeLinecap="round"/>
    </svg>
  );
}

function V6KPI({ label, value, unit, delta }) {
  return (
    <div>
      <div style={{
        fontFamily: V6.sans, fontSize: 10, fontWeight: 700, color: V6.ink3,
        letterSpacing: '0.06em', textTransform: 'uppercase',
      }}>{label}</div>
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 3, marginTop: 4 }}>
        <V6Num value={value} size={18}/>
        {unit && <span style={{ fontFamily: V6.sans, fontSize: 10, color: V6.ink3, fontWeight: 600 }}>{unit}</span>}
      </div>
      {delta && <div style={{
        fontFamily: V6.sans, fontSize: 10.5, color: V6.ink3, marginTop: 3,
        fontVariantNumeric: 'tabular-nums',
      }}>{delta}</div>}
    </div>
  );
}

function V6CompTile({ label, value, unit, delta, tone }) {
  return (
    <V6Card padded={false} style={{ padding: '12px 12px 11px' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 6 }}>
        <span style={{ width: 7, height: 7, borderRadius: '50%', background: tone }}/>
        <span style={{
          fontFamily: V6.sans, fontSize: 10, fontWeight: 700, color: V6.ink2,
          letterSpacing: '0.05em', textTransform: 'uppercase',
        }}>{label}</span>
      </div>
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 2 }}>
        <V6Num value={value} size={20}/>
        <span style={{ fontFamily: V6.sans, fontSize: 10, color: V6.ink3, fontWeight: 600 }}>{unit}</span>
      </div>
      <div style={{
        fontFamily: V6.sans, fontSize: 10.5, marginTop: 3,
        color: delta < 0 ? V6.good : delta > 0 ? V6.warn : V6.ink3,
        fontVariantNumeric: 'tabular-nums', fontWeight: 600,
      }}>{delta > 0 ? '+' : ''}{delta} <span style={{ color: V6.ink3, fontWeight: 500 }}>since</span></div>
    </V6Card>
  );
}

function V6Progress({ pct, color }) {
  return (
    <div style={{
      height: 6, borderRadius: 3, background: V6.surface3, marginTop: 8, overflow: 'hidden',
    }}>
      <div style={{
        height: '100%', width: `${pct}%`, background: color, borderRadius: 3,
      }}/>
    </div>
  );
}

Object.assign(window, { V6BodyTab, V6Spark, V6GlucoseSpark, V6KPI, V6CompTile, V6Progress });
