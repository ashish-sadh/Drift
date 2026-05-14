// v6-log-sheet.jsx — One-tap food logging.
// Bottom sheet, four entry methods + recent quick-adds.

function V6LogSheet({ open, onClose, data, accent }) {
  const [mode, setMode] = React.useState('quick');     // quick · search · voice · snap
  const [query, setQuery] = React.useState('');
  const [recent, setRecent] = React.useState([
    { name: 'Avocado',                kcal: 240, p: 3,  meta: '1 medium · saved 4×' },
    { name: 'Whey protein scoop',     kcal: 120, p: 24, meta: '1 scoop · saved 12×' },
    { name: 'TJ Turkey Meatballs',    kcal: 240, p: 30, meta: '3 meatballs · saved 6×' },
    { name: 'Greek yogurt + berries', kcal: 180, p: 18, meta: 'Combo · saved 9×' },
    { name: 'Oatmeal (apple cinn.)',  kcal: 160, p: 4,  meta: '1 packet · saved 8×' },
    { name: 'Taco al pastor',         kcal: 270, p: 18, meta: '1 taco · saved 3×' },
  ]);
  const [added, setAdded] = React.useState([]);

  React.useEffect(() => {
    if (open) { setMode('quick'); setQuery(''); setAdded([]); }
  }, [open]);

  if (!open) return null;
  const totalKcal = added.reduce((s, i) => s + i.kcal, 0);
  const totalP = added.reduce((s, i) => s + i.p, 0);

  return (
    <div style={{
      position: 'absolute', inset: 0, zIndex: 50,
      display: 'flex', flexDirection: 'column', justifyContent: 'flex-end',
      background: 'rgba(20,20,30,0.32)',
      animation: 'v6-fade .18s ease-out',
    }} onClick={onClose}>
      <style>{`
        @keyframes v6-fade { from { opacity: 0; } to { opacity: 1; } }
        @keyframes v6-slide { from { transform: translateY(100%); } to { transform: translateY(0); } }
      `}</style>
      <div onClick={e => e.stopPropagation()} style={{
        background: V6.bg, borderTopLeftRadius: 28, borderTopRightRadius: 28,
        boxShadow: '0 -10px 40px rgba(0,0,0,0.18)',
        animation: 'v6-slide .26s cubic-bezier(.2,.7,.3,1)',
        maxHeight: '88%', display: 'flex', flexDirection: 'column',
      }}>
        {/* Handle + header */}
        <div style={{
          padding: '10px 20px 8px', display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        }}>
          <div style={{ width: 36 }}/>
          <div style={{ width: 38, height: 4, background: V6.hairline, borderRadius: 4 }}/>
          <button onClick={onClose} style={{
            background: V6.surface3, border: 'none', cursor: 'pointer',
            fontFamily: V6.sans, fontSize: 12, fontWeight: 700, color: V6.ink2,
            padding: '6px 12px', borderRadius: 999,
          }}>Done</button>
        </div>
        <div style={{ padding: '0 20px 12px' }}>
          <div style={{
            fontFamily: V6.display, fontSize: 22, fontWeight: 700, color: V6.ink,
            letterSpacing: '-0.025em',
          }}>Log a meal</div>
          <div style={{
            fontFamily: V6.sans, fontSize: 12.5, color: V6.ink3, marginTop: 2,
          }}>{added.length ? `${added.length} items · ${totalKcal} kcal · ${totalP}g protein` : 'Tap a recent item or use a method below'}</div>
        </div>

        {/* Mode segmented */}
        <div style={{ padding: '0 16px 12px' }}>
          <div style={{
            display: 'grid', gridTemplateColumns: 'repeat(4,1fr)',
            background: V6.surface2, borderRadius: 14, padding: 4, gap: 2,
          }}>
            {[
              { id: 'quick',  label: 'Recent',  icon: 'clock'  },
              { id: 'search', label: 'Search',  icon: 'search' },
              { id: 'voice',  label: 'Voice',   icon: 'mic'    },
              { id: 'snap',   label: 'Snap',    icon: 'camera' },
            ].map(m => (
              <button key={m.id} onClick={() => setMode(m.id)} style={{
                background: mode === m.id ? V6.surface : 'transparent',
                border: 'none', cursor: 'pointer', borderRadius: 10,
                padding: '8px 4px', display: 'flex', flexDirection: 'column',
                alignItems: 'center', gap: 3,
                boxShadow: mode === m.id ? V6.shadow.soft : 'none',
              }}>
                <V6QuickIcon kind={m.icon}/>
                <span style={{
                  fontFamily: V6.sans, fontSize: 11, fontWeight: 700,
                  color: mode === m.id ? V6.ink : V6.ink3,
                  letterSpacing: '-0.005em',
                }}>{m.label}</span>
              </button>
            ))}
          </div>
        </div>

        {/* Mode content */}
        <div style={{ flex: 1, overflowY: 'auto', padding: '0 16px 12px' }}>
          {mode === 'quick' && (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
              {recent.map((it, i) => {
                const isAdded = added.some(a => a.name === it.name);
                return (
                  <button key={i} onClick={() => {
                    if (isAdded) setAdded(a => a.filter(x => x.name !== it.name));
                    else setAdded(a => [...a, it]);
                  }} style={{
                    background: V6.surface, border: 'none', cursor: 'pointer',
                    borderRadius: 14, padding: '12px 14px',
                    display: 'flex', alignItems: 'center', gap: 12, textAlign: 'left',
                    boxShadow: V6.shadow.soft,
                  }}>
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <div style={{
                        fontFamily: V6.display, fontSize: 14, fontWeight: 700, color: V6.ink,
                        letterSpacing: '-0.012em',
                      }}>{it.name}</div>
                      <div style={{
                        fontFamily: V6.sans, fontSize: 11.5, color: V6.ink3, marginTop: 2,
                      }}>{it.meta}</div>
                    </div>
                    <div style={{ textAlign: 'right' }}>
                      <V6Num value={it.kcal} size={15}/>
                      <div style={{
                        fontFamily: V6.sans, fontSize: 10.5, color: V6.ink3, marginTop: 2,
                        fontVariantNumeric: 'tabular-nums',
                      }}>{it.p}g P</div>
                    </div>
                    <div style={{
                      width: 28, height: 28, borderRadius: '50%',
                      background: isAdded ? V6.accent : V6.surface3,
                      display: 'flex', alignItems: 'center', justifyContent: 'center',
                      flexShrink: 0, transition: 'background .15s',
                    }}>
                      <svg width="14" height="14" viewBox="0 0 24 24" fill="none"
                           stroke={isAdded ? V6.bg : V6.ink2} strokeWidth="3" strokeLinecap="round" strokeLinejoin="round">
                        {isAdded ? <path d="M4 12l5 5L20 6"/> : <path d="M12 5v14M5 12h14"/>}
                      </svg>
                    </div>
                  </button>
                );
              })}
            </div>
          )}

          {mode === 'search' && (
            <div>
              <div style={{
                background: V6.surface, borderRadius: 14, padding: '12px 14px',
                display: 'flex', alignItems: 'center', gap: 10, boxShadow: V6.shadow.soft,
              }}>
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke={V6.ink3}
                     strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round">
                  <circle cx="11" cy="11" r="7"/><path d="M20 20l-3.5-3.5"/>
                </svg>
                <input value={query} onChange={e => setQuery(e.target.value)}
                  placeholder="Search foods, brands, restaurants…" autoFocus
                  style={{
                    flex: 1, border: 'none', outline: 'none', background: 'transparent',
                    fontFamily: V6.sans, fontSize: 14, color: V6.ink,
                  }}/>
              </div>
              <div style={{
                fontFamily: V6.sans, fontSize: 12, color: V6.ink3, padding: '14px 4px 6px',
                fontWeight: 600,
              }}>{query ? 'Top match' : 'Suggested'}</div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
                {(query ? recent.filter(r => r.name.toLowerCase().includes(query.toLowerCase())) : recent.slice(0, 4)).map((it, i) => (
                  <div key={i} style={{
                    background: V6.surface, borderRadius: 14, padding: '12px 14px',
                    display: 'flex', alignItems: 'center', gap: 12,
                    boxShadow: V6.shadow.soft,
                  }}>
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <div style={{
                        fontFamily: V6.display, fontSize: 14, fontWeight: 700, color: V6.ink,
                      }}>{it.name}</div>
                      <div style={{
                        fontFamily: V6.sans, fontSize: 11.5, color: V6.ink3, marginTop: 2,
                      }}>{it.kcal} kcal · {it.p}g protein</div>
                    </div>
                    <V6Pill tone="soft" size="sm" onClick={() => setAdded(a => [...a, it])}>+ Add</V6Pill>
                  </div>
                ))}
              </div>
            </div>
          )}

          {mode === 'voice' && (
            <div style={{
              padding: '32px 20px', display: 'flex', flexDirection: 'column',
              alignItems: 'center', gap: 18,
            }}>
              <div style={{
                width: 110, height: 110, borderRadius: '50%',
                background: V6.accentSoft, position: 'relative',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
              }}>
                <div style={{
                  position: 'absolute', inset: -8, borderRadius: '50%',
                  background: V6.accentSoft, opacity: 0.5,
                  animation: 'v6-pulse 1.8s ease-out infinite',
                }}/>
                <style>{`@keyframes v6-pulse { 0% { transform: scale(1); opacity: .5; } 100% { transform: scale(1.5); opacity: 0; } }`}</style>
                <svg width="46" height="46" viewBox="0 0 24 24" fill="none" stroke={V6.accent}
                     strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                  <rect x="9" y="3" width="6" height="11" rx="3"/>
                  <path d="M6 11a6 6 0 0 0 12 0M12 17v4M8 21h8"/>
                </svg>
              </div>
              <div style={{ textAlign: 'center' }}>
                <div style={{
                  fontFamily: V6.display, fontSize: 17, fontWeight: 700, color: V6.ink,
                  letterSpacing: '-0.02em',
                }}>Listening…</div>
                <div style={{
                  fontFamily: V6.sans, fontSize: 13, color: V6.ink3, marginTop: 4,
                  maxWidth: 260, lineHeight: 1.4,
                }}>"Two eggs, toast with avocado, and a black coffee" — speak naturally.</div>
              </div>
            </div>
          )}

          {mode === 'snap' && (
            <div style={{ padding: '20px 8px' }}>
              <div style={{
                aspectRatio: '4 / 3', borderRadius: 18, background: V6.surface2,
                border: `1.5px dashed ${V6.hairline}`, position: 'relative',
                display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 8,
              }}>
                <svg width="36" height="36" viewBox="0 0 24 24" fill="none" stroke={V6.ink3}
                     strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
                  <path d="M3 8a2 2 0 0 1 2-2h2.5l1.5-2h6l1.5 2H19a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>
                  <circle cx="12" cy="13" r="4"/>
                </svg>
                <div style={{
                  fontFamily: V6.display, fontSize: 15, fontWeight: 600, color: V6.ink2,
                }}>Snap your plate</div>
                <div style={{
                  fontFamily: V6.sans, fontSize: 12, color: V6.ink3, maxWidth: 240,
                  textAlign: 'center', lineHeight: 1.4,
                }}>AI will detect each item and suggest portions. Confirm before logging.</div>
                <V6Pill tone="accent" size="md" style={{ marginTop: 6 }}>Open camera</V6Pill>
              </div>
            </div>
          )}
        </div>

        {/* Bottom bar */}
        {added.length > 0 && (
          <div style={{
            borderTop: `0.5px solid ${V6.hairline}`,
            padding: '12px 16px 18px', display: 'flex', alignItems: 'center', gap: 10,
            background: V6.bg,
          }}>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{
                fontFamily: V6.display, fontSize: 14, fontWeight: 700, color: V6.ink,
                letterSpacing: '-0.012em',
              }}>{added.length} {added.length === 1 ? 'item' : 'items'} · {totalKcal} kcal</div>
              <div style={{
                fontFamily: V6.sans, fontSize: 11.5, color: V6.ink3, marginTop: 2,
              }}>{totalP}g protein · adds to today</div>
            </div>
            <V6Pill tone="accent" size="lg" onClick={onClose}>Log to today</V6Pill>
          </div>
        )}
      </div>
    </div>
  );
}

Object.assign(window, { V6LogSheet });
