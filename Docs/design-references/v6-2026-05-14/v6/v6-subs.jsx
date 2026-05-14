// v6-subs.jsx — Sub-screens pushed via "More" or links from Today/Body.
// Each export is window.<Name>Screen and consumes { data, onOpenAI }.

// ─── Food (full diary) ─────────────────────────────────────
function FoodScreen({ data, onOpenAI, onLog }) {
  const f = data.food;
  const macros = [
    { k: 'protein', label: 'Protein', color: V6.ringEx,    bg: V6.ringExBg,    eaten: f.macros.protein.eaten, target: f.macros.protein.target, unit: 'g' },
    { k: 'carbs',   label: 'Carbs',   color: V6.ringCarbs, bg: V6.ringCarbsBg, eaten: f.macros.carbs.eaten,   target: f.macros.carbs.target,   unit: 'g' },
    { k: 'fat',     label: 'Fat',     color: V6.ringFat,   bg: V6.ringFatBg,   eaten: f.macros.fat.eaten,     target: f.macros.fat.target,     unit: 'g' },
    { k: 'fiber',   label: 'Fiber',   color: V6.ringStand, bg: V6.ringStandBg, eaten: f.macros.fiber.eaten,   target: f.macros.fiber.target,   unit: 'g' },
  ];
  return (
    <div style={{ padding: '12px 0 130px', background: V6.bg2 }}>
      {/* Date strip (simple, today centered) */}
      <V6DayStrip/>

      {/* Summary card */}
      <div style={{ padding: '14px 16px 0' }}>
        <V6Card padded={false} raised style={{ padding: '18px', borderRadius: V6.r.xl }}>
          <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between' }}>
            <div>
              <div style={{
                fontFamily: V6.sans, fontSize: 11, fontWeight: 700, color: V6.ink3,
                letterSpacing: '0.06em', textTransform: 'uppercase',
              }}>Eaten today</div>
              <div style={{ display: 'flex', alignItems: 'baseline', gap: 4, marginTop: 4 }}>
                <V6Num value={f.consumed.toLocaleString()} size={40}/>
                <span style={{ fontFamily: V6.sans, fontSize: 13, color: V6.ink3 }}>/ {f.target.toLocaleString()} kcal</span>
              </div>
            </div>
            <div style={{ textAlign: 'right' }}>
              <V6Num value={f.left} size={20} color={V6.accent}/>
              <div style={{ fontFamily: V6.sans, fontSize: 10.5, color: V6.ink3, marginTop: 2 }}>left</div>
            </div>
          </div>
          <V6Progress pct={f.consumed / f.target * 100} color={V6.ringMove}/>
          <div style={{
            display: 'grid', gridTemplateColumns: 'repeat(4,1fr)', gap: 12,
            marginTop: 14, paddingTop: 14, borderTop: `0.5px solid ${V6.hairline}`,
          }}>
            {macros.map(m => (
              <div key={m.k}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 5, marginBottom: 4 }}>
                  <span style={{ width: 6, height: 6, borderRadius: '50%', background: m.color }}/>
                  <span style={{
                    fontFamily: V6.sans, fontSize: 10, fontWeight: 700, color: V6.ink2,
                    letterSpacing: '0.04em', textTransform: 'uppercase',
                  }}>{m.label}</span>
                </div>
                <V6Num value={m.eaten} size={17}/>
                <span style={{ fontFamily: V6.sans, fontSize: 10, color: V6.ink3, marginLeft: 2 }}>/{m.target}{m.unit}</span>
                <V6Progress pct={Math.min(m.eaten / m.target * 100, 100)} color={m.color}/>
              </div>
            ))}
          </div>
        </V6Card>
      </div>

      {/* Quick add: copy yesterday · combos · AI suggestion */}
      <div style={{ padding: '20px 16px 0' }}>
        <V6SectionHead title="Quick add"/>
        <V6Card padded={false}>
          <V6QuickAddRow
            kind="copy"
            title="Copy yesterday"
            sub="3 meals · 2,154 kcal · 82g protein"
            onClick={onLog}
          />
          <V6QuickAddRow
            kind="combo"
            title="Greek yogurt + berries + granola"
            sub="Saved combo · 280 kcal · used 9×"
            onClick={onLog}
          />
          <V6QuickAddRow
            kind="combo"
            title="Whey + banana + almond butter"
            sub="Saved combo · 340 kcal · used 6×"
            onClick={onLog}
          />
          <V6QuickAddRow
            kind="suggest"
            title="Try a high-protein snack"
            sub="892 kcal left · protein-leaning · ask Drift"
            onClick={onOpenAI}
            last
          />
        </V6Card>
      </div>

      {/* Diary */}
      <div style={{ padding: '22px 16px 0' }}>
        <V6SectionHead title="Diary" aside={`${f.diary.reduce((s, m) => s + m.items.length, 0)} entries`}/>
        {f.diary.map((meal, mi) => (
          <V6Card key={mi} padded={false} style={{ marginBottom: 10 }}>
            <div style={{
              padding: '12px 16px 8px', display: 'flex', alignItems: 'baseline',
              justifyContent: 'space-between', borderBottom: `0.5px solid ${V6.hairline2}`,
            }}>
              <div>
                <span style={{
                  fontFamily: V6.display, fontSize: 15, fontWeight: 700, color: V6.ink,
                  letterSpacing: '-0.018em',
                }}>{meal.meal}</span>
                <span style={{
                  fontFamily: V6.sans, fontSize: 11.5, color: V6.ink3, marginLeft: 8,
                }}>{meal.range}</span>
              </div>
              <V6Num value={meal.calories} size={15}/>
            </div>
            {meal.items.map((it, ii) => (
              <div key={ii} style={{
                padding: '10px 16px', display: 'flex', alignItems: 'center', gap: 10,
                borderTop: ii === 0 ? 'none' : `0.5px solid ${V6.hairline2}`,
              }}>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{
                    fontFamily: V6.sans, fontSize: 13.5, fontWeight: 600, color: V6.ink,
                    overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
                  }}>{it.name}</div>
                  <div style={{
                    fontFamily: V6.sans, fontSize: 11, color: V6.ink3, marginTop: 2,
                    fontVariantNumeric: 'tabular-nums',
                  }}>{it.t} · P{it.p} C{it.c} F{it.f} · Fb{it.fb}</div>
                </div>
                <V6Num value={it.kcal} size={14}/>
              </div>
            ))}
          </V6Card>
        ))}
      </div>

      {/* Plant points */}
      <div style={{ padding: '16px 16px 0' }}>
        <V6Card padded={false} style={{ padding: '14px 16px', display: 'flex', alignItems: 'center', gap: 14 }}>
          <V6MiniRing size={48} stroke={7} value={f.plantPoints.count} target={f.plantPoints.target}
            color={V6.ringEx} bg={V6.ringExBg}/>
          <div style={{ flex: 1 }}>
            <div style={{
              fontFamily: V6.sans, fontSize: 11, fontWeight: 700, color: V6.ink3,
              letterSpacing: '0.06em', textTransform: 'uppercase',
            }}>Plant diversity</div>
            <div style={{
              fontFamily: V6.display, fontSize: 16, fontWeight: 700, color: V6.ink,
              letterSpacing: '-0.02em', marginTop: 3,
            }}>{f.plantPoints.count}<span style={{ color: V6.ink3, fontWeight: 500, fontSize: 13 }}>/{f.plantPoints.target} this week</span></div>
            <div style={{ fontFamily: V6.sans, fontSize: 11.5, color: V6.ink2, marginTop: 2 }}>{f.plantPoints.plants} plants · {f.plantPoints.herbs} herbs</div>
          </div>
        </V6Card>
      </div>
    </div>
  );
}

function V6DayStrip() {
  // Show 21 days, centered on "today" (Tue the 23rd in this mock)
  const DOW = ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'];
  const todayIdx = 10;            // 11th item is today
  const todayDow = 2;             // Tuesday
  const todayDate = 23;
  const range = Array.from({ length: 21 }, (_, i) => {
    const offset = i - todayIdx;
    return {
      key: i,
      dow: DOW[(todayDow + offset + 7 * 10) % 7],
      date: todayDate + offset,   // simple linear; fine for the mock
      isToday: i === todayIdx,
      isFuture: offset > 0,
    };
  });
  const [selected, setSelected] = React.useState(todayIdx);
  const scrollerRef = React.useRef(null);
  const itemRefs = React.useRef([]);

  // Center today on first mount
  React.useEffect(() => {
    const scroller = scrollerRef.current;
    const el = itemRefs.current[todayIdx];
    if (!scroller || !el) return;
    scroller.scrollLeft = el.offsetLeft - (scroller.clientWidth / 2) + (el.clientWidth / 2);
  }, []);

  return (
    <div
      ref={scrollerRef}
      style={{
        display: 'flex', gap: 6,
        padding: '2px 16px 8px',
        overflowX: 'auto',
        scrollSnapType: 'x mandatory',
        WebkitOverflowScrolling: 'touch',
        scrollbarWidth: 'none',
      }}
    >
      <style>{`.v6-daystrip::-webkit-scrollbar{display:none}`}</style>
      {range.map((d, i) => {
        const isSel = i === selected;
        const isToday = d.isToday;
        return (
          <button
            key={d.key}
            ref={(el) => (itemRefs.current[i] = el)}
            onClick={() => setSelected(i)}
            disabled={d.isFuture}
            style={{
              flex: '0 0 auto',
              width: 44,
              scrollSnapAlign: 'center',
              border: 'none',
              cursor: d.isFuture ? 'default' : 'pointer',
              background: isSel ? V6.ink : V6.surface,
              color: isSel ? V6.bg : V6.ink,
              opacity: d.isFuture ? 0.4 : 1,
              borderRadius: V6.r.md,
              padding: '8px 0',
              display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 2,
              boxShadow: isSel ? 'none' : V6.shadow.soft,
              position: 'relative',
            }}
          >
            <span style={{
              fontFamily: V6.sans, fontSize: 9.5, fontWeight: 700,
              color: isSel ? V6.bg : V6.ink3, letterSpacing: '0.05em',
            }}>{d.dow.toUpperCase()}</span>
            <span style={{
              fontFamily: V6.display, fontSize: 17, fontWeight: 700,
              letterSpacing: '-0.02em',
            }}>{d.date}</span>
            {isToday && !isSel && (
              <span style={{
                position: 'absolute', bottom: 4,
                width: 4, height: 4, borderRadius: 999,
                background: V6.ink,
              }}/>
            )}
          </button>
        );
      })}
    </div>
  );
}

// ─── Weight (chart + history) ──────────────────────────────
function WeightScreen({ data, onOpenAI }) {
  const w = data.weight;
  const [range, setRange] = React.useState('3M');
  return (
    <div style={{ padding: '14px 0 130px', background: V6.bg2 }}>
      <div style={{ padding: '0 16px' }}>
        <V6Card padded={false} raised style={{ padding: 0, borderRadius: V6.r.xl, overflow: 'hidden' }}>
          <div style={{ padding: '18px 18px 6px' }}>
            <div style={{
              fontFamily: V6.sans, fontSize: 11, fontWeight: 700, color: V6.ink3,
              letterSpacing: '0.06em', textTransform: 'uppercase',
            }}>Current</div>
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 6, marginTop: 4 }}>
              <V6Num value={w.current} size={48}/>
              <span style={{ fontFamily: V6.sans, fontSize: 14, color: V6.ink3, fontWeight: 600 }}>lbs</span>
            </div>
            <div style={{
              fontFamily: V6.sans, fontSize: 13, color: V6.ink2, marginTop: 4,
            }}>
              <span style={{ color: w.weeklyChange < 0 ? V6.bad : V6.good, fontWeight: 700 }}>
                {w.weeklyChange > 0 ? '+' : ''}{w.weeklyChange} lbs/wk
              </span>
              <span style={{ color: V6.ink3 }}> · trend {w.trendWeight} · 3M avg {w.average3M}</span>
            </div>
          </div>
          <V6Spark series={w.series} color={V6.ringMove} height={140} range={w.range}/>
          <div style={{
            display: 'flex', justifyContent: 'space-around',
            padding: '8px 12px 14px',
          }}>
            {['1W','1M','3M','6M','1Y'].map(r => (
              <button key={r} onClick={() => setRange(r)} style={{
                background: range === r ? V6.ink : 'transparent', color: range === r ? V6.bg : V6.ink2,
                border: 'none', cursor: 'pointer', borderRadius: 999, padding: '6px 14px',
                fontFamily: V6.sans, fontSize: 12, fontWeight: 700, letterSpacing: '-0.005em',
              }}>{r}</button>
            ))}
          </div>
        </V6Card>
      </div>

      <div style={{ padding: '20px 16px 0' }}>
        <V6SectionHead title="History"/>
        <V6Card padded={false}>
          {w.history.map((h, i) => (
            <div key={i} style={{
              padding: '12px 16px', display: 'flex', alignItems: 'center', gap: 10,
              borderTop: i === 0 ? 'none' : `0.5px solid ${V6.hairline2}`,
            }}>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{
                  fontFamily: V6.display, fontSize: 14, fontWeight: 700, color: V6.ink,
                  letterSpacing: '-0.012em',
                }}>{h.v} lbs</div>
                <div style={{
                  fontFamily: V6.sans, fontSize: 11.5, color: V6.ink3, marginTop: 2,
                }}>{h.d} · {h.src === 'health' ? 'Apple Health' : 'Manual'}</div>
              </div>
              <div style={{
                fontFamily: V6.sans, fontSize: 12.5, fontWeight: 700,
                color: h.ch < 0 ? V6.bad : V6.good,
                fontVariantNumeric: 'tabular-nums',
              }}>{h.ch > 0 ? '+' : ''}{h.ch}</div>
            </div>
          ))}
        </V6Card>
      </div>

      <div style={{ padding: '16px 16px 0' }}>
        <V6Pill tone="soft" size="lg" onClick={onOpenAI} style={{ width: '100%', justifyContent: 'center' }}>
          Ask why I'm trending down
        </V6Pill>
      </div>
    </div>
  );
}

// ─── Weight Goal ──────────────────────────────────────────
function WeightGoalScreen({ data }) {
  const g = data.goal;
  return (
    <div style={{ padding: '16px 16px 130px' }}>
      <V6Card raised style={{ padding: '20px', borderRadius: V6.r.xl }}>
        <div style={{
          fontFamily: V6.sans, fontSize: 11, fontWeight: 700, color: V6.ink3,
          letterSpacing: '0.06em', textTransform: 'uppercase',
        }}>Goal</div>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 6, marginTop: 6 }}>
          <V6Num value={g.target} size={42}/>
          <span style={{ fontFamily: V6.sans, fontSize: 14, color: V6.ink3 }}>lbs · {g.direction}</span>
        </div>
        <V6Progress pct={g.pctDone} color={V6.accent}/>
        <div style={{
          fontFamily: V6.sans, fontSize: 12.5, color: V6.ink2, marginTop: 8,
        }}>{g.pctDone}% complete · {g.toGo} lbs to go · {g.daysLeft} days left</div>
      </V6Card>
      <V6Card style={{ marginTop: 12 }}>
        <div style={{ fontFamily: V6.display, fontSize: 14, fontWeight: 700, color: V6.ink, letterSpacing: '-0.015em' }}>Started</div>
        <div style={{ fontFamily: V6.sans, fontSize: 13, color: V6.ink2, marginTop: 4 }}>{g.startDate} at {g.started} lbs</div>
      </V6Card>
    </div>
  );
}

// ─── Body Rhythm ──────────────────────────────────────────
function BodyRhythmScreen({ data }) {
  const r = data.bodyRhythm;
  return (
    <div style={{ padding: '14px 0 130px', background: V6.bg2 }}>
      <div style={{ padding: '0 16px' }}>
        <V6Card raised padded={false} style={{ padding: '18px', borderRadius: V6.r.xl }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 16 }}>
            <V6MiniRing size={84} stroke={11} value={r.recovery} target={100}
              color={V6.ringEx} bg={V6.ringExBg}/>
            <div style={{ flex: 1 }}>
              <div style={{
                fontFamily: V6.sans, fontSize: 11, fontWeight: 700, color: V6.ink3,
                letterSpacing: '0.06em', textTransform: 'uppercase',
              }}>Readiness</div>
              <V6Num value={r.recovery} size={36}/>
              <div style={{ fontFamily: V6.sans, fontSize: 12, color: V6.ink2, marginTop: 4 }}>14d avg {r.recoveryAvg}</div>
            </div>
          </div>
          <div style={{
            background: V6.accentSoft, color: V6.accent, padding: '10px 12px',
            borderRadius: V6.r.md, marginTop: 12,
            fontFamily: V6.sans, fontSize: 12.5, fontWeight: 600, lineHeight: 1.4,
          }}>{r.nudge}</div>
        </V6Card>
      </div>

      <div style={{ padding: '20px 16px 0' }}>
        <V6SectionHead title="Sleep"/>
        <V6Card padded={false} style={{ padding: '14px 16px' }}>
          <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between' }}>
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 6 }}>
              <V6Num value={r.sleep.slept} size={28}/>
              <span style={{ fontFamily: V6.sans, fontSize: 13, color: V6.ink3 }}>of {r.sleep.needed}h</span>
            </div>
            <V6Pill tone="soft" size="sm">Score {r.sleep.score}</V6Pill>
          </div>
          <div style={{ display: 'flex', height: 8, borderRadius: 4, overflow: 'hidden', marginTop: 12, background: V6.surface2 }}>
            {r.sleep.stages.map((s, i) => (
              <div key={i} style={{
                width: `${s.pct}%`,
                background: ['oklch(0.7 0.18 290)', V6.ringStand, V6.ringEx, V6.warn][i],
              }}/>
            ))}
          </div>
          <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 8, gap: 4 }}>
            {r.sleep.stages.map((s, i) => (
              <div key={i} style={{ textAlign: 'center', flex: 1 }}>
                <div style={{ fontFamily: V6.sans, fontSize: 10.5, color: V6.ink3, fontWeight: 600 }}>{s.k}</div>
                <div style={{ fontFamily: V6.display, fontSize: 13, fontWeight: 700, color: V6.ink, fontVariantNumeric: 'tabular-nums' }}>{s.v}h</div>
              </div>
            ))}
          </div>
          <div style={{ fontFamily: V6.sans, fontSize: 11.5, color: V6.ink3, marginTop: 10 }}>{r.sleep.bed}</div>
        </V6Card>
      </div>

      <div style={{ padding: '20px 16px 0' }}>
        <V6SectionHead title="Vitals"/>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2,1fr)', gap: 8 }}>
          <V6CompTile label="Resting HR" value={r.rhr} unit="bpm" delta={r.rhrChange} tone={V6.ringMove}/>
          <V6CompTile label="Respiratory" value={r.respiratory} unit="br/m" delta={r.respChange} tone={V6.ringStand}/>
        </div>
      </div>
    </div>
  );
}

// ─── Glucose ───────────────────────────────────────────────
function GlucoseScreen({ data }) {
  const g = data.glucose;
  return (
    <div style={{ padding: '14px 0 130px', background: V6.bg2 }}>
      <div style={{ padding: '0 16px' }}>
        <V6Card raised padded={false} style={{ padding: '18px', borderRadius: V6.r.xl }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
            <div>
              <div style={{
                fontFamily: V6.sans, fontSize: 11, fontWeight: 700, color: V6.ink3,
                letterSpacing: '0.06em', textTransform: 'uppercase',
              }}>Right now</div>
              <V6Num value={g.current} size={42}/>
              <span style={{ fontFamily: V6.sans, fontSize: 13, color: V6.ink3, marginLeft: 4 }}>mg/dL</span>
            </div>
            <V6Pill tone="soft" size="sm">{g.timeInRange}% in range</V6Pill>
          </div>
          <V6GlucoseSpark series={g.series} low={g.low} high={g.high}/>
          <div style={{
            display: 'grid', gridTemplateColumns: 'repeat(3,1fr)', gap: 8, marginTop: 10,
          }}>
            <V6KPI label="24h mean" value={g.mean24h} unit="mg/dL"/>
            <V6KPI label="7d mean" value={g.mean7d} unit="mg/dL"/>
            <V6KPI label="Range" value={`${g.low}–${g.high}`} unit=""/>
          </div>
        </V6Card>
      </div>

      <div style={{ padding: '20px 16px 0' }}>
        <V6SectionHead title="Notable spikes"/>
        <V6Card padded={false}>
          {g.spikes.map((s, i) => (
            <div key={i} style={{
              padding: '12px 16px', display: 'flex', alignItems: 'center', gap: 10,
              borderTop: i === 0 ? 'none' : `0.5px solid ${V6.hairline2}`,
            }}>
              <div style={{
                width: 32, height: 32, borderRadius: 10, background: V6.ringFatBg,
                display: 'flex', alignItems: 'center', justifyContent: 'center',
              }}>
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke={V6.ringFat} strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round">
                  <path d="M4 18l5-7 4 4 7-10"/><path d="M14 5h6v6"/>
                </svg>
              </div>
              <div style={{ flex: 1 }}>
                <div style={{ fontFamily: V6.display, fontSize: 13.5, fontWeight: 700, color: V6.ink, letterSpacing: '-0.012em' }}>{s.meal}</div>
                <div style={{ fontFamily: V6.sans, fontSize: 11.5, color: V6.ink3, marginTop: 2 }}>{s.time}</div>
              </div>
              <V6Num value={s.delta} size={15} color={V6.ringFat}/>
            </div>
          ))}
        </V6Card>
      </div>
    </div>
  );
}

// ─── Body Composition ──────────────────────────────────────
function BodyCompScreen({ data }) {
  const b = data.bodyComp;
  return (
    <div style={{ padding: '14px 0 130px', background: V6.bg2 }}>
      <div style={{ padding: '0 16px' }}>
        <V6Card raised padded={false} style={{ padding: '18px', borderRadius: V6.r.xl }}>
          <div style={{
            fontFamily: V6.sans, fontSize: 11, fontWeight: 700, color: V6.ink3,
            letterSpacing: '0.06em', textTransform: 'uppercase',
          }}>{b.vendor} · {b.date}</div>
          <div style={{
            display: 'grid', gridTemplateColumns: 'repeat(3,1fr)', gap: 8, marginTop: 12,
          }}>
            <V6CompTile label="Body fat" value={b.bodyFat} unit="%" delta={b.bodyFatChange} tone={V6.ringFat}/>
            <V6CompTile label="Lean mass" value={b.leanMass} unit="lb" delta={b.leanChange} tone={V6.ringEx}/>
            <V6CompTile label="Fat mass" value={b.fatMass} unit="lb" delta={b.fatChange} tone={V6.ringMove}/>
          </div>
        </V6Card>
      </div>

      <div style={{ padding: '20px 16px 0' }}>
        <V6SectionHead title="Regional"/>
        <V6Card padded={false}>
          {b.regions.map((r, i) => (
            <div key={i} style={{
              padding: '12px 16px', display: 'flex', alignItems: 'center', gap: 10,
              borderTop: i === 0 ? 'none' : `0.5px solid ${V6.hairline2}`,
            }}>
              <div style={{ width: 70, fontFamily: V6.display, fontSize: 13, fontWeight: 700, color: V6.ink, letterSpacing: '-0.012em' }}>{r.region}</div>
              <div style={{ flex: 1, height: 6, background: V6.surface2, borderRadius: 3, overflow: 'hidden' }}>
                <div style={{ width: `${r.pct * 3}%`, height: '100%', background: V6.ringFat }}/>
              </div>
              <div style={{ width: 70, textAlign: 'right' }}>
                <V6Num value={`${r.pct}%`} size={13}/>
                <div style={{ fontFamily: V6.sans, fontSize: 10.5, color: V6.ink3, marginTop: 1 }}>{r.fat}/{r.lean} lb</div>
              </div>
            </div>
          ))}
        </V6Card>
      </div>

      <div style={{ padding: '20px 16px 0' }}>
        <V6SectionHead title="Metabolic"/>
        <V6Card padded={false} style={{ padding: '14px 16px', display: 'grid', gridTemplateColumns: 'repeat(3,1fr)', gap: 12 }}>
          <V6KPI label="RMR" value={b.rmr} unit="kcal"/>
          <V6KPI label="A/G ratio" value={b.agRatio} unit=""/>
          <V6KPI label="Visceral" value={b.visceral} unit="lb"/>
        </V6Card>
      </div>
    </div>
  );
}

// ─── Biomarkers ────────────────────────────────────────────
function BiomarkersScreen({ data }) {
  const b = data.biomarkers;
  return (
    <div style={{ padding: '14px 16px 130px', background: V6.bg2 }}>
      {b.panels.map((p, i) => (
        <div key={i} style={{ marginBottom: 14 }}>
          <V6SectionHead title={p.name} aside={p.date}/>
          <V6Card padded={false}>
            {p.items.map((it, ii) => (
              <div key={ii} style={{
                padding: '12px 16px', display: 'flex', alignItems: 'center', gap: 10,
                borderTop: ii === 0 ? 'none' : `0.5px solid ${V6.hairline2}`,
              }}>
                <div style={{ flex: 1 }}>
                  <div style={{ fontFamily: V6.display, fontSize: 13.5, fontWeight: 700, color: V6.ink, letterSpacing: '-0.012em' }}>{it.k}</div>
                  <div style={{ fontFamily: V6.sans, fontSize: 11, color: V6.ink3, marginTop: 2 }}>{it.range}</div>
                </div>
                <div style={{ textAlign: 'right' }}>
                  <V6Num value={it.v} size={15}/>
                  <span style={{ fontFamily: V6.sans, fontSize: 10.5, color: V6.ink3, marginLeft: 3 }}>{it.unit}</span>
                </div>
                <div style={{
                  width: 8, height: 8, borderRadius: '50%',
                  background: it.state === 'aligned' ? V6.good : V6.warn,
                }}/>
              </div>
            ))}
          </V6Card>
        </div>
      ))}
    </div>
  );
}

// ─── Settings ──────────────────────────────────────────────
function SettingsScreen() {
  const groups = [
    { label: 'Profile', items: [
      { k: 'Personal info', v: 'Drift' },
      { k: 'Health connections', v: 'Apple Health · CGM' },
    ]},
    { label: 'Units', items: [
      { k: 'Weight', v: 'lbs' }, { k: 'Energy', v: 'kcal' }, { k: 'Glucose', v: 'mg/dL' },
    ]},
    { label: 'Notifications', items: [
      { k: 'Daily summary', v: '8:00 AM' },
      { k: 'Meal reminders', v: 'On' },
      { k: 'Coaching nudges', v: 'On' },
    ]},
    { label: 'Data', items: [
      { k: 'Export', v: 'CSV · JSON' }, { k: 'Privacy', v: 'On-device' },
    ]},
  ];
  return (
    <div style={{ padding: '14px 16px 130px', background: V6.bg2 }}>
      {groups.map((g, gi) => (
        <div key={gi} style={{ marginBottom: 14 }}>
          <div style={{
            fontFamily: V6.sans, fontSize: 11, fontWeight: 700, color: V6.ink3,
            letterSpacing: '0.08em', textTransform: 'uppercase', padding: '0 4px 8px',
          }}>{g.label}</div>
          <V6Card padded={false}>
            {g.items.map((it, ii) => (
              <div key={ii} style={{
                padding: '13px 16px', display: 'flex', alignItems: 'center',
                borderTop: ii === 0 ? 'none' : `0.5px solid ${V6.hairline2}`,
              }}>
                <div style={{ flex: 1, fontFamily: V6.sans, fontSize: 14, color: V6.ink, fontWeight: 500 }}>{it.k}</div>
                <div style={{ fontFamily: V6.sans, fontSize: 13, color: V6.ink3, marginRight: 6 }}>{it.v}</div>
                <V6Chev/>
              </div>
            ))}
          </V6Card>
        </div>
      ))}
    </div>
  );
}

// ─── Exercise (compact overview) ──────────────────────────
function ExerciseScreen({ data }) {
  const ex = data.exercise;
  const [historyOpen, setHistoryOpen] = React.useState(false);
  return (
    <div style={{ padding: '14px 16px 130px', background: V6.bg2 }}>
      <V6Card raised style={{ padding: '18px', borderRadius: V6.r.xl }}>
        <div style={{
          fontFamily: V6.sans, fontSize: 11, fontWeight: 700, color: V6.ink3,
          letterSpacing: '0.06em', textTransform: 'uppercase',
        }}>This week</div>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 6, marginTop: 4 }}>
          <V6Num value={ex.thisWeek} size={42}/>
          <span style={{ fontFamily: V6.sans, fontSize: 14, color: V6.ink3 }}>workouts</span>
        </div>
        <div style={{
          fontFamily: V6.sans, fontSize: 12.5, color: V6.ink2, marginTop: 6,
        }}>Streak {ex.weeksStreak} weeks · best {ex.bestStreak} · {ex.in12Wks} in last 12wk</div>
      </V6Card>

      <div style={{ marginTop: 16 }}>
        <V6SectionHead title="History" action={
          <V6Pill onClick={() => setHistoryOpen(true)} tone="ghost" size="sm">
            View all · {ex.historyCount}
          </V6Pill>
        }/>
        <V6Card padded={false}>
          {ex.appleWorkouts.slice(0, 4).map((w, i) => (
            <button key={i} onClick={() => setHistoryOpen(true)} style={{
              width: '100%', background: 'transparent', border: 'none', cursor: 'pointer',
              padding: '12px 16px', display: 'flex', alignItems: 'center', gap: 12,
              borderTop: i === 0 ? 'none' : `0.5px solid ${V6.hairline2}`,
              textAlign: 'left',
            }}>
              <div style={{
                width: 34, height: 34, borderRadius: '50%',
                background: V6.surface3,
                display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
              }}>
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke={V6.ink2}
                     strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
                  <path d="M6.5 6.5l11 11M4 8l2-2M16 20l2-2M2 12l2-2M20 14l2-2M8 4l-2 2M20 16l-2 2"/>
                </svg>
              </div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{
                  fontFamily: V6.display, fontSize: 13.5, fontWeight: 700, color: V6.ink,
                  letterSpacing: '-0.012em',
                  whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
                }}>{w.name}</div>
                <div style={{
                  fontFamily: V6.sans, fontSize: 11.5, color: V6.ink3, marginTop: 2,
                  fontVariantNumeric: 'tabular-nums',
                }}>{w.date} · {w.dur} · {w.cal} kcal</div>
              </div>
              <V6Chev/>
            </button>
          ))}
        </V6Card>
      </div>

      <div style={{ marginTop: 16 }}>
        <V6SectionHead title="Recovery"/>
        <V6Card padded={false}>
          {ex.recovery.map((r, i) => (
            <div key={i} style={{
              padding: '11px 16px', display: 'flex', alignItems: 'center', gap: 10,
              borderTop: i === 0 ? 'none' : `0.5px solid ${V6.hairline2}`,
            }}>
              <div style={{ flex: 1, fontFamily: V6.display, fontSize: 13.5, fontWeight: 600, color: V6.ink, letterSpacing: '-0.012em' }}>{r.group}</div>
              <div style={{ fontFamily: V6.sans, fontSize: 11.5, color: V6.ink3, marginRight: 10, fontVariantNumeric: 'tabular-nums' }}>{r.daysAgo === null ? '—' : `${r.daysAgo}d ago`} · {r.sets} sets</div>
              <V6Pill tone={r.state === 'ready' ? 'soft' : 'neutral'} size="sm">{r.state}</V6Pill>
            </div>
          ))}
        </V6Card>
      </div>

      <div style={{ marginTop: 16 }}>
        <V6SectionHead title="Templates"/>
        <V6Card padded={false}>
          {ex.templates.map((t, i) => (
            <div key={i} style={{
              padding: '12px 16px', display: 'flex', alignItems: 'center', gap: 10,
              borderTop: i === 0 ? 'none' : `0.5px solid ${V6.hairline2}`,
            }}>
              <span style={{ color: t.star ? V6.warn : V6.ink4, fontSize: 14 }}>★</span>
              <div style={{ flex: 1 }}>
                <div style={{ fontFamily: V6.display, fontSize: 13.5, fontWeight: 700, color: V6.ink, letterSpacing: '-0.012em' }}>{t.name}</div>
                <div style={{ fontFamily: V6.sans, fontSize: 11.5, color: V6.ink3, marginTop: 1 }}>{t.meta}</div>
              </div>
              <V6Chev/>
            </div>
          ))}
        </V6Card>
      </div>

      {/* Full history overlay */}
      {historyOpen && (
        <V6ExerciseHistorySheet workouts={ex.appleWorkouts} count={ex.historyCount}
          onClose={() => setHistoryOpen(false)}/>
      )}
    </div>
  );
}

// ─── Full exercise history overlay ────────────────────────
function V6ExerciseHistorySheet({ workouts, count, onClose }) {
  const extra = [
    { name: 'Pull Day',            date: 'Wed, Apr 22', dur: '52m', cal: 312 },
    { name: 'Push Day',            date: 'Mon, Apr 20', dur: '47m', cal: 288 },
    { name: 'Strength Training',   date: 'Sat, Apr 18', dur: '41m', cal: 240 },
    { name: 'Workout',             date: 'Thu, Apr 16', dur: '22m', cal: 116 },
    { name: 'Leg Day',             date: 'Tue, Apr 14', dur: '58m', cal: 342 },
    { name: 'Strength Training',   date: 'Sun, Apr 12', dur: '36m', cal: 198 },
    { name: 'Workout',             date: 'Fri, Apr 10', dur: '28m', cal: 142 },
  ];
  const all = [...workouts, ...extra];
  return (
    <div style={{
      position: 'absolute', inset: 0, zIndex: 65,
      display: 'flex', flexDirection: 'column',
      background: 'rgba(20,20,30,0.32)',
      animation: 'v6-fade .18s ease-out',
    }} onClick={onClose}>
      <div onClick={e => e.stopPropagation()} style={{
        marginTop: 'auto',
        background: V6.bg, borderTopLeftRadius: 28, borderTopRightRadius: 28,
        boxShadow: '0 -10px 40px rgba(0,0,0,0.18)',
        animation: 'v6-slide .26s cubic-bezier(.2,.7,.3,1)',
        height: '90%', display: 'flex', flexDirection: 'column',
      }}>
        <div style={{
          padding: '10px 20px 8px',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>
          <div style={{ width: 38, height: 4, background: V6.hairline, borderRadius: 4 }}/>
        </div>
        <div style={{
          padding: '4px 20px 14px',
          display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between', gap: 12,
        }}>
          <div style={{ minWidth: 0 }}>
            <div style={{
              fontFamily: V6.sans, fontSize: 11, fontWeight: 700, color: V6.ink3,
              letterSpacing: '0.08em', textTransform: 'uppercase',
            }}>Exercise history</div>
            <div style={{
              fontFamily: V6.display, fontSize: 22, fontWeight: 700, color: V6.ink,
              letterSpacing: '-0.025em', marginTop: 2,
            }}>{count} workouts</div>
          </div>
          <button onClick={onClose} style={{
            background: V6.surface3, border: 'none', cursor: 'pointer',
            fontFamily: V6.sans, fontSize: 12, fontWeight: 700, color: V6.ink2,
            padding: '6px 12px', borderRadius: 999,
          }}>Done</button>
        </div>

        {/* Filter row */}
        <div style={{
          padding: '0 16px 12px', display: 'flex', gap: 6, overflowX: 'auto',
        }}>
          {['All', 'Strength', 'Cardio', 'Mobility', 'Last 30d', 'This year'].map((f, i) => (
            <button key={f} style={{
              flex: '0 0 auto', padding: '7px 12px',
              background: i === 0 ? V6.ink : V6.surface,
              color: i === 0 ? V6.bg : V6.ink2, border: 'none', cursor: 'pointer',
              borderRadius: 999, fontFamily: V6.sans, fontSize: 12, fontWeight: 700,
              letterSpacing: '-0.005em',
              boxShadow: i === 0 ? 'none' : V6.shadow.soft,
              whiteSpace: 'nowrap',
            }}>{f}</button>
          ))}
        </div>

        {/* Scrollable list */}
        <div style={{ flex: 1, overflowY: 'auto', padding: '0 16px 24px' }}>
          {all.map((w, i) => (
            <div key={i} style={{
              padding: '14px 4px', display: 'flex', alignItems: 'center', gap: 12,
              borderBottom: `0.5px solid ${V6.hairline2}`,
            }}>
              <div style={{
                width: 38, height: 38, borderRadius: '50%',
                background: V6.surface3,
                display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
              }}>
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke={V6.ink2}
                     strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
                  <path d="M6.5 6.5l11 11M4 8l2-2M16 20l2-2M2 12l2-2M20 14l2-2M8 4l-2 2M20 16l-2 2"/>
                </svg>
              </div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{
                  fontFamily: V6.display, fontSize: 14, fontWeight: 700, color: V6.ink,
                  letterSpacing: '-0.012em',
                  whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
                }}>{w.name}</div>
                <div style={{
                  fontFamily: V6.sans, fontSize: 11.5, color: V6.ink3, marginTop: 2,
                  fontVariantNumeric: 'tabular-nums',
                }}>{w.date} · {w.dur}</div>
              </div>
              <div style={{
                fontFamily: V6.display, fontSize: 14, fontWeight: 700, color: V6.ink,
                letterSpacing: '-0.015em', fontVariantNumeric: 'tabular-nums',
              }}>{w.cal}<span style={{ color: V6.ink3, fontWeight: 500 }}> kcal</span></div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

// ─── Supplements + Photo Log (compact stubs) ──────────────
function SupplementsScreen({ data }) {
  return (
    <div style={{ padding: '14px 16px 130px', background: V6.bg2 }}>
      <V6Card style={{ padding: '20px', borderRadius: V6.r.xl }}>
        <div style={{
          fontFamily: V6.sans, fontSize: 11, fontWeight: 700, color: V6.ink3,
          letterSpacing: '0.06em', textTransform: 'uppercase',
        }}>Today</div>
        <V6Num value="0 / 0" size={32}/>
        <div style={{ fontFamily: V6.sans, fontSize: 12.5, color: V6.ink2, marginTop: 6 }}>No supplements tracked yet</div>
      </V6Card>
      <V6Card style={{ marginTop: 12 }}>
        <div style={{ fontFamily: V6.display, fontSize: 14, fontWeight: 700, color: V6.ink, letterSpacing: '-0.015em' }}>Add your first supplement</div>
        <div style={{ fontFamily: V6.sans, fontSize: 13, color: V6.ink2, marginTop: 4, lineHeight: 1.45 }}>Track timing, dose, and consistency. Drift will remind you and tie it back to outcomes.</div>
        <V6Pill tone="accent" size="md" style={{ marginTop: 10 }}>+ Add supplement</V6Pill>
      </V6Card>
    </div>
  );
}

function PhotoLogScreen() {
  const photos = Array.from({ length: 12 }, (_, i) => i);
  return (
    <div style={{ padding: '14px 16px 130px', background: V6.bg2 }}>
      <V6SectionHead title="Weekly photos" aside="12 entries"/>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3,1fr)', gap: 6 }}>
        {photos.map(i => (
          <div key={i} style={{
            aspectRatio: '3 / 4', borderRadius: V6.r.md,
            background: `oklch(${0.92 - i * 0.012} 0.005 250)`,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            fontFamily: V6.sans, fontSize: 10.5, fontWeight: 600, color: V6.ink3,
          }}>Wk {12 - i}</div>
        ))}
      </div>
      <V6Pill tone="accent" size="lg" style={{ marginTop: 18, width: '100%', justifyContent: 'center' }}>+ Add this week's photo</V6Pill>
    </div>
  );
}

Object.assign(window, {
  FoodScreen, WeightScreen, WeightGoalScreen, BodyRhythmScreen, GlucoseScreen,
  BodyCompScreen, BiomarkersScreen, SettingsScreen, ExerciseScreen,
  SupplementsScreen, PhotoLogScreen, V6DayStrip,
});
