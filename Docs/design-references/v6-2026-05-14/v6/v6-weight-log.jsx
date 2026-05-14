// v6-weight-log.jsx — Body weight logging bottom sheet.
// Big numeric value + steppers, time-of-day chip, optional note, save.

function V6WeightLogSheet({ open, onClose, data, accent, lastWeight }) {
  const baseline = lastWeight ?? data?.weight?.current ?? 150;
  const [value, setValue] = React.useState(baseline);
  const [when, setWhen] = React.useState('morning');
  const [note, setNote] = React.useState('');
  const [saved, setSaved] = React.useState(false);

  React.useEffect(() => {
    if (open) {
      setValue(baseline);
      setWhen('morning');
      setNote('');
      setSaved(false);
    }
  }, [open]);

  if (!open) return null;

  const round = (v) => Math.round(v * 10) / 10;
  const bump = (delta) => setValue(v => round(Math.max(0, v + delta)));
  const delta = round(value - baseline);
  const deltaStr = delta === 0 ? 'No change' : `${delta > 0 ? '+' : ''}${delta.toFixed(1)} lbs vs last`;
  const deltaColor = delta === 0 ? V6.ink3 : (delta < 0 ? V6.bad : V6.good);

  const save = () => {
    setSaved(true);
    setTimeout(() => { onClose && onClose({ value, when, note }); }, 650);
  };

  const intStr = Math.floor(value).toString();
  const decStr = (Math.round((value - Math.floor(value)) * 10)).toString();

  return (
    <div style={{
      position: 'absolute', inset: 0, zIndex: 55,
      display: 'flex', flexDirection: 'column', justifyContent: 'flex-end',
      background: 'rgba(20,20,30,0.32)',
      animation: 'v6-fade .18s ease-out',
    }} onClick={() => onClose && onClose(null)}>
      <div onClick={e => e.stopPropagation()} style={{
        background: V6.bg, borderTopLeftRadius: 28, borderTopRightRadius: 28,
        boxShadow: '0 -10px 40px rgba(0,0,0,0.18)',
        animation: 'v6-slide .26s cubic-bezier(.2,.7,.3,1)',
        display: 'flex', flexDirection: 'column',
      }}>
        {/* Handle + header */}
        <div style={{
          padding: '10px 20px 6px', display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        }}>
          <button onClick={() => onClose && onClose(null)} style={{
            background: 'transparent', border: 'none', cursor: 'pointer',
            fontFamily: V6.sans, fontSize: 13, fontWeight: 600, color: V6.ink3,
            padding: '6px 4px',
          }}>Cancel</button>
          <div style={{ width: 38, height: 4, background: V6.hairline, borderRadius: 4 }}/>
          <div style={{ width: 56 }}/>
        </div>
        <div style={{ padding: '4px 20px 0' }}>
          <div style={{
            fontFamily: V6.sans, fontSize: 11, fontWeight: 700, color: V6.ink3,
            letterSpacing: '0.08em', textTransform: 'uppercase',
          }}>Log weight</div>
          <div style={{
            fontFamily: V6.display, fontSize: 22, fontWeight: 700, color: V6.ink,
            letterSpacing: '-0.025em', marginTop: 2,
          }}>{data?.date?.today || 'Today'}</div>
        </div>

        {/* Big value */}
        <div style={{
          padding: '20px 20px 6px',
          display: 'flex', alignItems: 'baseline', justifyContent: 'center', gap: 4,
        }}>
          <span style={{
            fontFamily: V6.display, fontSize: 88, fontWeight: 700,
            color: V6.ink, letterSpacing: '-0.04em', lineHeight: 0.9,
            fontVariantNumeric: 'tabular-nums',
          }}>{intStr}</span>
          <span style={{
            fontFamily: V6.display, fontSize: 44, fontWeight: 600,
            color: V6.ink3, letterSpacing: '-0.03em',
            fontVariantNumeric: 'tabular-nums',
          }}>.{decStr}</span>
          <span style={{
            fontFamily: V6.sans, fontSize: 16, fontWeight: 600, color: V6.ink3,
            marginLeft: 6,
          }}>lbs</span>
        </div>
        <div style={{
          textAlign: 'center',
          fontFamily: V6.sans, fontSize: 12.5, fontWeight: 600,
          color: deltaColor, marginBottom: 4,
          fontVariantNumeric: 'tabular-nums',
        }}>{deltaStr}</div>

        {/* Steppers */}
        <div style={{
          padding: '14px 16px 0',
          display: 'grid', gridTemplateColumns: 'repeat(4,1fr)', gap: 8,
        }}>
          {[-1, -0.1, +0.1, +1].map(d => (
            <button key={d} onClick={() => bump(d)} style={{
              background: V6.surface, border: `0.5px solid ${V6.hairline}`,
              cursor: 'pointer', borderRadius: V6.r.md, padding: '14px 0',
              fontFamily: V6.display, fontSize: 16, fontWeight: 700, color: V6.ink,
              letterSpacing: '-0.015em', boxShadow: V6.shadow.soft,
              fontVariantNumeric: 'tabular-nums',
            }}>{d > 0 ? '+' : ''}{d}</button>
          ))}
        </div>

        {/* Time-of-day */}
        <div style={{ padding: '18px 20px 0' }}>
          <div style={{
            fontFamily: V6.sans, fontSize: 11, fontWeight: 700, color: V6.ink3,
            letterSpacing: '0.06em', textTransform: 'uppercase', marginBottom: 8,
          }}>When</div>
          <div style={{ display: 'flex', gap: 6 }}>
            {[
              { id: 'morning', label: 'Morning' },
              { id: 'midday',  label: 'Midday'  },
              { id: 'evening', label: 'Evening' },
            ].map(o => {
              const sel = when === o.id;
              return (
                <button key={o.id} onClick={() => setWhen(o.id)} style={{
                  flex: 1, padding: '10px 0',
                  background: sel ? V6.ink : V6.surface,
                  color: sel ? V6.bg : V6.ink, border: 'none', cursor: 'pointer',
                  borderRadius: 999, fontFamily: V6.sans, fontSize: 13, fontWeight: 700,
                  letterSpacing: '-0.005em',
                  boxShadow: sel ? 'none' : V6.shadow.soft,
                }}>{o.label}</button>
              );
            })}
          </div>
        </div>

        {/* Note */}
        <div style={{ padding: '14px 20px 0' }}>
          <input
            value={note}
            onChange={e => setNote(e.target.value)}
            placeholder="Add a note (optional)"
            style={{
              width: '100%', background: V6.surface,
              border: `0.5px solid ${V6.hairline}`, borderRadius: V6.r.md,
              padding: '12px 14px',
              fontFamily: V6.sans, fontSize: 13.5, color: V6.ink,
              outline: 'none',
            }}
          />
        </div>

        {/* Save */}
        <div style={{ padding: '18px 20px 24px' }}>
          <button onClick={save} disabled={saved} style={{
            width: '100%', padding: '15px 0',
            background: saved ? V6.good : V6.ink, color: V6.bg, border: 'none',
            cursor: saved ? 'default' : 'pointer', borderRadius: V6.r.lg,
            fontFamily: V6.sans, fontSize: 15, fontWeight: 700, letterSpacing: '-0.01em',
            display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
          }}>
            {saved ? (
              <>
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke={V6.bg}
                     strokeWidth="3" strokeLinecap="round" strokeLinejoin="round">
                  <path d="M4 12l5 5L20 6"/>
                </svg>
                Saved
              </>
            ) : 'Save weight'}
          </button>
        </div>
      </div>
    </div>
  );
}

Object.assign(window, { V6WeightLogSheet });
