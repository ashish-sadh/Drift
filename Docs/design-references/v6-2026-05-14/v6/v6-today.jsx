// v6-today.jsx — Today tab. The "natural flow" hero.
// Anatomy (top → bottom):
//   1. TopBar: avatar · "Today" · streak chip · AI button
//   2. Big rings hero (calories / protein / fiber) with under-legend
//   3. Quick log row: 4 chips → Snap · Voice · Search · Recent
//   4. Meals timeline (vertical, today's meals + add-meal placeholders)
//   5. Today's body: weight tile + sleep tile + readiness tile (row of 3)
//   6. Coaching nudge card (single, friendly)
//   7. Spacer for FAB

function V6TodayTab({ data, onOpenSub, onOpenAI, onLog, onLogWeight, latestWeight, accent }) {
  const f = data.food;
  const currentWeight = latestWeight ?? data.weight.current;
  const rings = [
    { label: 'kcal',  unit: '',  value: f.consumed, target: f.target,
      color: V6.ringMove,  bg: V6.ringMoveBg },
    { label: 'protein', unit: 'g', value: f.macros.protein.eaten, target: f.macros.protein.target,
      color: V6.ringEx,    bg: V6.ringExBg },
    { label: 'fiber',  unit: 'g', value: f.macros.fiber.eaten,   target: f.macros.fiber.target,
      color: V6.ringStand, bg: V6.ringStandBg },
  ];
  const pctKcal = Math.round(f.consumed / f.target * 100);

  return (
    <div style={{ padding: '0 0 130px', background: V6.bg2, minHeight: '100%' }}>

      {/* ── Hero rings card ────────────────────────────── */}
      <div style={{ padding: '4px 16px 0' }}>
        <V6Card padded={false} raised style={{ padding: '20px 18px 18px', borderRadius: V6.r.xl }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 8 }}>
            <div>
              <div style={{
                fontFamily: V6.sans, fontSize: 11.5, fontWeight: 700, color: V6.ink3,
                letterSpacing: '0.08em', textTransform: 'uppercase',
              }}>Today’s intake</div>
              <div style={{
                fontFamily: V6.display, fontSize: 16, fontWeight: 600, color: V6.ink,
                letterSpacing: '-0.018em', marginTop: 4,
              }}>{f.target - f.consumed > 0 ? `${(f.target - f.consumed).toLocaleString()} kcal left` : 'On target'}</div>
            </div>
            <div style={{
              fontFamily: V6.sans, fontSize: 11, fontWeight: 700, color: V6.accent,
              background: V6.accentSoft, padding: '5px 9px', borderRadius: 999,
              letterSpacing: '-0.005em',
            }}>{pctKcal}% of goal</div>
          </div>
          <div style={{ display: 'flex', justifyContent: 'center', padding: '12px 0 14px' }}>
            <V6Rings size={210} stroke={20} gap={4} rings={rings} center={
              <div style={{ textAlign: 'center' }}>
                <V6Num value={f.consumed.toLocaleString()} size={36}/>
                <div style={{
                  fontFamily: V6.sans, fontSize: 11.5, fontWeight: 700,
                  color: V6.ink3, marginTop: 4, letterSpacing: '0.06em', textTransform: 'uppercase',
                }}>kcal</div>
              </div>
            }/>
          </div>
          <V6RingLegend rings={rings}/>
          {/* Carb + fat — same legend style, aligned with the 3 rings above */}
          <div style={{
            marginTop: 14, paddingTop: 12,
            borderTop: `0.5px solid ${V6.hairline}`,
            display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 12,
          }}>
            <V6LegendItem label="carbs" unit="g"
              value={f.macros.carbs.eaten} target={f.macros.carbs.target} color={V6.ringCarbs}/>
            <div/>
            <V6LegendItem label="fat" unit="g"
              value={f.macros.fat.eaten} target={f.macros.fat.target} color={V6.ringFat}/>
          </div>
        </V6Card>
      </div>

      {/* ── Quick log strip ────────────────────────────── */}
      <div style={{ padding: '20px 16px 0' }}>
        <V6SectionHead title="Log" aside="0 entries left for today"/>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4,1fr)', gap: 8 }}>
          {[
            { k: 'snap',   label: 'Snap',   icon: 'camera' },
            { k: 'voice',  label: 'Voice',  icon: 'mic' },
            { k: 'search', label: 'Search', icon: 'search' },
            { k: 'recent', label: 'Recent', icon: 'clock' },
          ].map(it => (
            <button key={it.k} onClick={onLog} style={{
              background: V6.surface, borderRadius: V6.r.lg, border: 'none',
              boxShadow: V6.shadow.soft, padding: '14px 8px 12px',
              cursor: 'pointer', display: 'flex', flexDirection: 'column',
              alignItems: 'center', gap: 6,
            }}>
              <V6QuickIcon kind={it.icon} accent={accent}/>
              <span style={{
                fontFamily: V6.sans, fontSize: 11.5, fontWeight: 600, color: V6.ink,
                letterSpacing: '-0.005em',
              }}>{it.label}</span>
            </button>
          ))}
        </div>
      </div>

      {/* ── Today's meals ──────────────────────────────── */}
      <div style={{ padding: '20px 16px 0' }}>
        <V6SectionHead title="Today’s meals" action={
          <div style={{ display: 'flex', gap: 6 }}>
            <V6Pill onClick={onLog} tone="ghost" size="sm">Copy yesterday</V6Pill>
            <V6Pill onClick={() => onOpenSub('food')} tone="ghost" size="sm">View all</V6Pill>
          </div>
        }/>
        <V6MealTimeline diary={f.diary} onLog={onLog}/>
      </div>

      {/* ── Today's body strip ─────────────────────────── */}
      <div style={{ padding: '22px 16px 0' }}>
        <V6SectionHead title="Body"/>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3,1fr)', gap: 8 }}>
          <V6BodyTile label="Weight" value={currentWeight} unit="lbs"
            delta={data.weight.weeklyChange > 0 ? `+${data.weight.weeklyChange}` : data.weight.weeklyChange}
            deltaLabel="this wk" tone={V6.ringMove}
            onClick={() => onOpenSub('weight')} onAdd={onLogWeight}/>
          <V6BodyTile label="Sleep" value={data.bodyRhythm.sleep.slept} unit="h"
            delta={`${Math.round(data.bodyRhythm.sleep.score)}`} deltaLabel="score"
            tone={V6.ringStand} onClick={() => onOpenSub('rhythm')}/>
          <V6BodyTile label="Readiness" value={data.bodyRhythm.recovery} unit=""
            delta={`avg ${data.bodyRhythm.recoveryAvg}`} deltaLabel="14d"
            tone={V6.ringEx} onClick={() => onOpenSub('rhythm')}/>
        </div>
      </div>

      {/* ── Nudge card ─────────────────────────────────── */}
      <div style={{ padding: '22px 16px 0' }}>
        <V6Card style={{
          padding: '16px 16px 16px 18px', display: 'flex', gap: 12, alignItems: 'flex-start',
          background: V6.surface, position: 'relative', overflow: 'hidden',
        }}>
          <div style={{
            width: 36, height: 36, borderRadius: '50%', flexShrink: 0,
            background: V6.accentSoft, display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke={V6.accent}
                 strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
              <path d="M12 2v3M12 19v3M4 12H1M23 12h-3M5.6 5.6l2.1 2.1M16.3 16.3l2.1 2.1M5.6 18.4l2.1-2.1M16.3 7.7l2.1-2.1"/>
              <circle cx="12" cy="12" r="3.5"/>
            </svg>
          </div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{
              fontFamily: V6.display, fontSize: 15, fontWeight: 700, color: V6.ink,
              letterSpacing: '-0.018em', marginBottom: 3,
            }}>You're {f.target - f.consumed} kcal under today</div>
            <div style={{
              fontFamily: V6.sans, fontSize: 13, color: V6.ink2, lineHeight: 1.42,
            }}>You're trying to gain. A protein-forward snack now will help you hit your kcal and protein targets together.</div>
            <div style={{ display: 'flex', gap: 6, marginTop: 10 }}>
              <V6Pill tone="accent" size="sm" onClick={onOpenAI}>Suggest a snack</V6Pill>
              <V6Pill tone="ghost" size="sm" onClick={onOpenAI}>Ask AI</V6Pill>
            </div>
          </div>
        </V6Card>
      </div>

    </div>
  );
}

// ─── Quick-log icon ────────────────────────────────────────
function V6QuickIcon({ kind, accent }) {
  const c = V6.ink;
  const sw = 2;
  switch (kind) {
    case 'camera': return (
      <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round">
        <path d="M3 8a2 2 0 0 1 2-2h2.5l1.5-2h6l1.5 2H19a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>
        <circle cx="12" cy="13" r="3.5"/>
      </svg>
    );
    case 'mic': return (
      <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round">
        <rect x="9" y="3" width="6" height="11" rx="3"/>
        <path d="M6 11a6 6 0 0 0 12 0M12 17v4M8 21h8"/>
      </svg>
    );
    case 'search': return (
      <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round">
        <circle cx="11" cy="11" r="7"/><path d="M20 20l-3.5-3.5"/>
      </svg>
    );
    case 'clock': return (
      <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round">
        <circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>
      </svg>
    );
  }
}

// ─── Meal timeline (vertical with dot+line) ───────────────
function V6MealTimeline({ diary, onLog }) {
  // Build a fixed 4-slot day: Breakfast, Lunch, Dinner, Snacks (placeholders if empty)
  const slots = ['Breakfast', 'Lunch', 'Dinner', 'Snacks'];
  const ts = { Breakfast: '7:00 AM', Lunch: '12:30 PM', Dinner: '7:00 PM', Snacks: 'Anytime' };
  const byMeal = Object.fromEntries(diary.map(m => [m.meal, m]));

  return (
    <div style={{ position: 'relative', paddingLeft: 22 }}>
      {/* vertical line */}
      <div style={{
        position: 'absolute', left: 7, top: 8, bottom: 8, width: 2,
        background: V6.hairline,
      }}/>
      {slots.map((name, i) => {
        const m = byMeal[name];
        const filled = !!m;
        return (
          <div key={name} style={{ position: 'relative', marginBottom: i === slots.length - 1 ? 0 : 10 }}>
            {/* dot */}
            <div style={{
              position: 'absolute', left: -22, top: 18,
              width: 16, height: 16, borderRadius: '50%',
              background: filled ? V6.ink : V6.surface,
              border: filled ? `none` : `2px dashed ${V6.hairline}`,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
            }}>
              {filled && <div style={{ width: 6, height: 6, borderRadius: '50%', background: V6.bg }}/>}
            </div>
            {filled ? (
              <V6Card padded={false} style={{ padding: '12px 14px' }}>
                <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', marginBottom: 6 }}>
                  <div>
                    <span style={{
                      fontFamily: V6.display, fontSize: 15, fontWeight: 700, color: V6.ink,
                      letterSpacing: '-0.015em',
                    }}>{name}</span>
                    <span style={{
                      fontFamily: V6.sans, fontSize: 11.5, color: V6.ink3, marginLeft: 8,
                    }}>{m.range}</span>
                  </div>
                  <V6Num value={`${m.calories}`} size={16}/>
                </div>
                <div style={{
                  fontFamily: V6.sans, fontSize: 12.5, color: V6.ink2, lineHeight: 1.42,
                  whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
                }}>{m.items.slice(0, 3).map(i => i.name.split(' ').slice(0, 3).join(' ')).join(' · ')}{m.items.length > 3 ? ` · +${m.items.length - 3}` : ''}</div>
              </V6Card>
            ) : (
              <button onClick={onLog} style={{
                width: '100%', border: 'none', background: 'transparent', cursor: 'pointer',
                textAlign: 'left', padding: '12px 14px',
                display: 'flex', alignItems: 'center', gap: 10,
              }}>
                <span style={{
                  fontFamily: V6.display, fontSize: 14, fontWeight: 600, color: V6.ink3,
                  letterSpacing: '-0.012em',
                }}>{name}</span>
                <span style={{
                  fontFamily: V6.sans, fontSize: 11.5, color: V6.ink4,
                }}>~{ts[name]}</span>
                <span style={{ flex: 1 }}/>
                <span style={{
                  fontFamily: V6.sans, fontSize: 12, color: V6.accent, fontWeight: 600,
                }}>Log</span>
              </button>
            )}
          </div>
        );
      })}
    </div>
  );
}

// ─── Body tile (small KPI) ────────────────────────────────
function V6BodyTile({ label, value, unit, delta, deltaLabel, tone, onClick, onAdd }) {
  const handleKey = (e) => {
    if (onClick && (e.key === 'Enter' || e.key === ' ')) { e.preventDefault(); onClick(); }
  };
  return (
    <div
      role={onClick ? 'button' : undefined}
      tabIndex={onClick ? 0 : undefined}
      onClick={onClick}
      onKeyDown={handleKey}
      style={{
        position: 'relative', cursor: onClick ? 'pointer' : 'default',
        background: V6.surface, borderRadius: V6.r.lg,
        boxShadow: V6.shadow.soft,
        padding: '14px 14px 12px',
      }}
    >
      <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 8 }}>
        <span style={{ width: 7, height: 7, borderRadius: '50%', background: tone }}/>
        <span style={{
          fontFamily: V6.sans, fontSize: 11, fontWeight: 700, color: V6.ink2,
          letterSpacing: '0.04em', textTransform: 'uppercase',
        }}>{label}</span>
        {onAdd && (
          <button onClick={(e) => { e.stopPropagation(); onAdd(); }} aria-label={`Log ${label}`} style={{
            marginLeft: 'auto', width: 22, height: 22, borderRadius: '50%',
            background: V6.ink, border: 'none', cursor: 'pointer', padding: 0,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            boxShadow: V6.shadow.soft,
          }}>
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke={V6.bg}
                 strokeWidth="3" strokeLinecap="round" strokeLinejoin="round">
              <path d="M12 5v14M5 12h14"/>
            </svg>
          </button>
        )}
      </div>
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 3 }}>
        <V6Num value={value} size={22}/>
        {unit && <span style={{
          fontFamily: V6.sans, fontSize: 11, color: V6.ink3, fontWeight: 600,
        }}>{unit}</span>}
      </div>
      <div style={{
        fontFamily: V6.sans, fontSize: 11, color: V6.ink3, marginTop: 4,
        fontVariantNumeric: 'tabular-nums',
      }}>{delta} <span style={{ color: V6.ink4 }}>{deltaLabel}</span></div>
    </div>
  );
}

// ─── Macro bar (carbs / fat under the rings) ─────────────
function V6MacroBar({ label, eaten, target, tone }) {
  const pct = Math.min(100, Math.round((eaten / target) * 100));
  return (
    <div>
      <div style={{
        display: 'flex', alignItems: 'baseline', justifyContent: 'space-between',
        marginBottom: 6,
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
          <span style={{ width: 7, height: 7, borderRadius: '50%', background: tone }}/>
          <span style={{
            fontFamily: V6.sans, fontSize: 11, fontWeight: 700, color: V6.ink2,
            letterSpacing: '0.04em', textTransform: 'uppercase',
          }}>{label}</span>
        </div>
        <div style={{
          fontFamily: V6.display, fontSize: 13, fontWeight: 700, color: V6.ink,
          letterSpacing: '-0.015em', fontVariantNumeric: 'tabular-nums',
        }}>{eaten}<span style={{ color: V6.ink3, fontWeight: 500 }}>/{target}g</span></div>
      </div>
      <div style={{
        height: 6, background: V6.surface2, borderRadius: 999, overflow: 'hidden',
      }}>
        <div style={{
          width: `${pct}%`, height: '100%', background: tone, borderRadius: 999,
        }}/>
      </div>
    </div>
  );
}

Object.assign(window, { V6TodayTab, V6MealTimeline, V6BodyTile, V6QuickIcon, V6MacroBar });
