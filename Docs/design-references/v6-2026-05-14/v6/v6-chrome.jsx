// v6-chrome.jsx — Drift v6 chrome. Floating glass tab bar, top bar, FAB.

function V6TopBar({ title, subtitle, leading, trailing, large = true }) {
  return (
    <div style={{
      padding: large ? '8px 20px 4px' : '12px 16px',
      display: 'flex', alignItems: large ? 'flex-end' : 'center',
      justifyContent: 'space-between', gap: 12,
    }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, minWidth: 0, flex: 1 }}>
        {leading}
        <div style={{ minWidth: 0 }}>
          {subtitle && (
            <div style={{
              fontFamily: V6.sans, fontSize: 12, fontWeight: 500, color: V6.ink3,
              letterSpacing: '-0.005em', marginBottom: 2,
            }}>{subtitle}</div>
          )}
          <div style={{
            fontFamily: V6.display, fontSize: large ? 30 : 17,
            fontWeight: 700, color: V6.ink, letterSpacing: '-0.028em',
            lineHeight: 1, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
          }}>{title}</div>
        </div>
      </div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexShrink: 0 }}>
        {trailing}
      </div>
    </div>
  );
}

function V6Avatar({ initial = 'D', size = 36 }) {
  return (
    <div style={{
      width: size, height: size, borderRadius: '50%',
      background: V6.surface3, border: `0.5px solid ${V6.hairline}`,
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      fontFamily: V6.display, fontSize: size * 0.42, fontWeight: 700,
      color: V6.ink, letterSpacing: '-0.02em',
    }}>{initial}</div>
  );
}

function V6IconBtn({ onClick, children, tone = 'neutral', size = 36 }) {
  const bg = tone === 'accent' ? V6.ink : V6.surface;
  const fg = tone === 'accent' ? V6.bg : V6.ink;
  return (
    <button onClick={onClick} style={{
      width: size, height: size, borderRadius: '50%',
      background: bg, color: fg, border: `0.5px solid ${V6.hairline}`,
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      cursor: 'pointer', padding: 0,
      boxShadow: V6.shadow.soft,
    }}>{children}</button>
  );
}

// ─── Bottom tab bar: 3 tabs + center FAB ───────────────────
function V6TabBar({ active, onChange, onLog, accent }) {
  const tabs = [
    { id: 'today', label: 'Today', icon: 'today' },
    { id: 'body',  label: 'Body',  icon: 'body' },
    { id: 'more',  label: 'More',  icon: 'more' },
  ];
  return (
    <div style={{
      position: 'absolute', left: 16, right: 16, bottom: 16,
      display: 'flex', alignItems: 'center', gap: 10,
      zIndex: 30,
    }}>
      {/* Tab capsule */}
      <div style={{
        flex: 1,
        background: 'rgba(255,255,255,0.78)',
        backdropFilter: 'saturate(180%) blur(24px)',
        WebkitBackdropFilter: 'saturate(180%) blur(24px)',
        border: `0.5px solid ${V6.hairline}`,
        boxShadow: V6.shadow.pop,
        borderRadius: V6.r.pill,
        display: 'flex', justifyContent: 'space-around', alignItems: 'center',
        padding: '8px 6px',
        height: 60,
      }}>
        {tabs.map(t => {
          const isActive = active === t.id;
          return (
            <button key={t.id} onClick={() => onChange(t.id)} style={{
              flex: 1, background: 'transparent', border: 'none', padding: '6px 4px',
              cursor: 'pointer',
              display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 3,
            }}>
              <V6TabIcon kind={t.icon} active={isActive} accent={accent}/>
              <span style={{
                fontFamily: V6.sans, fontSize: 10, fontWeight: 700,
                color: isActive ? V6.ink : V6.ink3,
                letterSpacing: '-0.005em',
              }}>{t.label}</span>
            </button>
          );
        })}
      </div>
      {/* FAB */}
      <button onClick={onLog} style={{
        width: 60, height: 60, borderRadius: '50%', flexShrink: 0,
        background: V6.ink, border: 'none', cursor: 'pointer',
        boxShadow: `${V6.shadow.pop}, inset 0 1px 0 rgba(255,255,255,0.12)`,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
      }}>
        <svg width="22" height="22" viewBox="0 0 24 24" fill="none"
             stroke={V6.bg} strokeWidth="2.4" strokeLinecap="round">
          <path d="M12 5v14M5 12h14"/>
        </svg>
      </button>
    </div>
  );
}

function V6TabIcon({ kind, active, accent }) {
  const c = active ? V6.ink : V6.ink3;
  const sw = 2;
  switch (kind) {
    case 'today': return (
      <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round">
        <circle cx="12" cy="12" r="8"/>
        <circle cx="12" cy="12" r="4.5"/>
        <circle cx="12" cy="12" r="1.4" fill={c}/>
      </svg>
    );
    case 'body': return (
      <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round">
        <circle cx="12" cy="5.5" r="2.2"/>
        <path d="M12 8v6M8 11l4-1 4 1M9 20l3-6 3 6"/>
      </svg>
    );
    case 'more': return (
      <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round">
        <line x1="4" y1="7"  x2="20" y2="7"/>
        <line x1="4" y1="12" x2="20" y2="12"/>
        <line x1="4" y1="17" x2="20" y2="17"/>
      </svg>
    );
  }
}

// ─── Pushed/modal screen container ─────────────────────────
function V6Pushed({ title, onBack, trailing, children, accent }) {
  return (
    <div style={{
      position: 'absolute', inset: 0, background: V6.bg2,
      display: 'flex', flexDirection: 'column',
      animation: 'v6-push .26s cubic-bezier(.2,.7,.3,1)', zIndex: 20,
    }}>
      <style>{`@keyframes v6-push { from { transform: translateX(100%); } to { transform: translateX(0); } }`}</style>
      <div style={{
        padding: '8px 12px 8px', display: 'flex', alignItems: 'center', gap: 6,
        background: 'rgba(255,255,255,0.85)',
        backdropFilter: 'blur(20px)', WebkitBackdropFilter: 'blur(20px)',
        borderBottom: `0.5px solid ${V6.hairline}`,
        position: 'sticky', top: 0, zIndex: 1,
      }}>
        <button onClick={onBack} style={{
          width: 36, height: 36, borderRadius: '50%', background: V6.surface3,
          border: 'none', cursor: 'pointer', display: 'flex',
          alignItems: 'center', justifyContent: 'center', padding: 0,
        }}>
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none"
               stroke={accent || V6.ink} strokeWidth="2.6" strokeLinecap="round" strokeLinejoin="round">
            <path d="M15 6l-6 6 6 6"/>
          </svg>
        </button>
        <span style={{
          flex: 1, textAlign: 'center', fontFamily: V6.display, fontSize: 16, fontWeight: 700,
          color: V6.ink, letterSpacing: '-0.02em',
        }}>{title}</span>
        <div style={{ width: 36, display: 'flex', justifyContent: 'flex-end' }}>{trailing}</div>
      </div>
      <div style={{ flex: 1, overflowY: 'auto' }}>{children}</div>
    </div>
  );
}

Object.assign(window, {
  V6TopBar, V6Avatar, V6IconBtn, V6TabBar, V6TabIcon, V6Pushed,
});
