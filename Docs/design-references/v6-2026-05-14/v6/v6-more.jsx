// v6-more.jsx — More tab + global sub-screens.

function V6MoreTab({ data, onOpenSub }) {
  const ex = data.exercise;
  const groups = [
    {
      label: 'Activity',
      items: [
        { id: 'exercise',   label: 'Exercise',         hint: `${ex.thisWeek}/${ex.weeksStreak ? 4 : 4} workouts · ${ex.bestStreak}wk best`, icon: 'dumbbell' },
        { id: 'photolog',   label: 'Photo Log',        hint: '12 photos · weekly',           icon: 'camera' },
      ],
    },
    {
      label: 'Health',
      items: [
        { id: 'supp',       label: 'Supplements',      hint: `${data.supplements.takenToday}/${data.supplements.totalToday || '—'} today`, icon: 'pill' },
        { id: 'biomarkers', label: 'Biomarkers',       hint: 'Last lab · Feb 10',            icon: 'flask' },
      ],
    },
    {
      label: 'App',
      items: [
        { id: 'weight-goal', label: 'Weight Goal', hint: `${data.goal.target} lbs · ${data.goal.daysLeft}d`, icon: 'target' },
        { id: 'settings',    label: 'Settings',    hint: 'Units · sync · export',            icon: 'gear' },
      ],
    },
  ];
  return (
    <div style={{ padding: '0 0 130px', background: V6.bg2, minHeight: '100%' }}>
      {groups.map((g, gi) => (
        <div key={gi} style={{ padding: gi === 0 ? '4px 16px 0' : '20px 16px 0' }}>
          <div style={{
            fontFamily: V6.sans, fontSize: 11.5, fontWeight: 700, color: V6.ink3,
            letterSpacing: '0.08em', textTransform: 'uppercase', padding: '0 4px 8px',
          }}>{g.label}</div>
          <V6Card padded={false}>
            {g.items.map((it, ii) => (
              <button key={it.id} onClick={() => onOpenSub(it.id)} style={{
                width: '100%', background: 'transparent', border: 'none', cursor: 'pointer',
                padding: '14px 16px', display: 'flex', alignItems: 'center', gap: 12,
                borderTop: ii === 0 ? 'none' : `0.5px solid ${V6.hairline2}`, textAlign: 'left',
              }}>
                <V6MoreIcon kind={it.icon}/>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{
                    fontFamily: V6.display, fontSize: 14.5, fontWeight: 600, color: V6.ink,
                    letterSpacing: '-0.012em',
                  }}>{it.label}</div>
                  <div style={{
                    fontFamily: V6.sans, fontSize: 12, color: V6.ink3, marginTop: 2,
                  }}>{it.hint}</div>
                </div>
                <V6Chev/>
              </button>
            ))}
          </V6Card>
        </div>
      ))}

      {/* Footer */}
      <div style={{
        fontFamily: V6.sans, fontSize: 11, color: V6.ink4, textAlign: 'center',
        padding: '28px 0 0',
      }}>Drift · v6.0 · 2026</div>
    </div>
  );
}

function V6MoreIcon({ kind }) {
  const map = {
    dumbbell: { bg: V6.ringMoveBg, fg: V6.ringMove, path: (
      <g><path d="M6 9v6M3 11v2M18 9v6M21 11v2M6 12h12"/></g>
    )},
    camera: { bg: V6.ringStandBg, fg: V6.ringStand, path: (
      <g><path d="M3 8a2 2 0 0 1 2-2h2.5l1.5-2h6l1.5 2H19a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><circle cx="12" cy="13" r="3.5"/></g>
    )},
    pill: { bg: V6.ringExBg, fg: V6.ringEx, path: (
      <g><rect x="3" y="9" width="18" height="6" rx="3" transform="rotate(-30 12 12)"/><path d="M12 6l6 12"/></g>
    )},
    flask: { bg: V6.ringCarbsBg, fg: V6.ringCarbs, path: (
      <g><path d="M9 2v6L4 19a2 2 0 0 0 2 3h12a2 2 0 0 0 2-3L15 8V2M8 2h8M7 14h10"/></g>
    )},
    target: { bg: V6.ringFatBg, fg: V6.ringFat, path: (
      <g><circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="5"/><circle cx="12" cy="12" r="1.5" fill="currentColor"/></g>
    )},
    gear: { bg: V6.surface3, fg: V6.ink2, path: (
      <g><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 1 1-4 0v-.09a1.65 1.65 0 0 0-1.08-1.5 1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 1 1 0-4h.09a1.65 1.65 0 0 0 1.5-1.08 1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 1 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 1 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/></g>
    )},
  };
  const it = map[kind] || map.gear;
  return (
    <div style={{
      width: 34, height: 34, borderRadius: 10, background: it.bg, flexShrink: 0,
      display: 'flex', alignItems: 'center', justifyContent: 'center',
    }}>
      <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke={it.fg}
           strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">{it.path}</svg>
    </div>
  );
}

Object.assign(window, { V6MoreTab, V6MoreIcon });
