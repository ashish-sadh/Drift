// v6-app.jsx — Drift v6 root.
// 3 tabs (Today · Body · More) + center FAB → LogSheet.
// Sub-screens push from More tab; AI sheet is global.

const SUBS = {
  food:        { title: 'Food',             C: () => window.FoodScreen },
  weight:      { title: 'Weight',           C: () => window.WeightScreen },
  'weight-goal': { title: 'Weight Goal',    C: () => window.WeightGoalScreen },
  rhythm:      { title: 'Body Rhythm',      C: () => window.BodyRhythmScreen },
  glucose:     { title: 'Glucose',          C: () => window.GlucoseScreen },
  bodycomp:    { title: 'Body Composition', C: () => window.BodyCompScreen },
  biomarkers:  { title: 'Biomarkers',       C: () => window.BiomarkersScreen },
  settings:    { title: 'Settings',         C: () => window.SettingsScreen },
  exercise:    { title: 'Exercise',         C: () => window.ExerciseScreen },
  supp:        { title: 'Supplements',      C: () => window.SupplementsScreen },
  photolog:    { title: 'Photo Log',        C: () => window.PhotoLogScreen },
};

const TAB_TITLES = {
  today: 'Today',
  body:  'Body',
  more:  'More',
};

function V6App({ data, tweaks }) {
  const [tab, setTab] = React.useState('today');
  const [sub, setSub] = React.useState(null);
  const [logOpen, setLogOpen] = React.useState(false);
  const [weightLogOpen, setWeightLogOpen] = React.useState(false);
  const [weightEntries, setWeightEntries] = React.useState([]);
  const [aiOpen, setAiOpen] = React.useState(false);
  const [aiSeed, setAiSeed] = React.useState(null);

  const accent = tweaks?.accent || V6.accent;

  const openSub = (id) => setSub(id);
  const closeSub = () => setSub(null);
  const openAI = (seed) => { setAiSeed(seed || null); setAiOpen(true); };
  const openWeightLog = () => setWeightLogOpen(true);
  const closeWeightLog = (entry) => {
    setWeightLogOpen(false);
    if (entry && typeof entry.value === 'number') {
      setWeightEntries(prev => [{ ...entry, at: Date.now() }, ...prev]);
    }
  };
  const lastWeight = weightEntries[0]?.value;

  const headerTitle = sub ? SUBS[sub]?.title || 'Drift' : TAB_TITLES[tab];

  return (
    <div style={{
      position: 'absolute', inset: 0, background: V6.bg2,
      overflow: 'hidden', fontFamily: V6.sans, color: V6.ink,
    }}>
      <style>{`
        * { box-sizing: border-box; -webkit-font-smoothing: antialiased; }
        button { -webkit-tap-highlight-color: transparent; font: inherit; color: inherit; }
        input, textarea { -webkit-appearance: none; }
        ::-webkit-scrollbar { display: none; }
      `}</style>

      {/* Top chrome (only shown for tabs, not sub-screens) */}
      {!sub && (
        <V6TopBar
          title={headerTitle}
          subtitle={tab === 'today' ? data.date.today : null}
          leading={<V6Avatar initial={data.user.initial}/>}
          trailing={
            <>
              <V6IconBtn onClick={() => openAI()} aria-label="Coach">
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke={V6.ink}
                     strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
                  <path d="M21 12c0 4-4 7-9 7-1.4 0-2.7-.2-3.9-.6L4 20l1.7-3.6C4.6 15.2 4 13.7 4 12c0-4 4-7 9-7s8 3 8 7z"/>
                </svg>
              </V6IconBtn>
            </>
          }
        />
      )}

      {/* Scrollable content */}
      <div style={{
        position: 'absolute', left: 0, right: 0,
        top: sub ? 0 : 78, bottom: 0,
        overflowY: 'auto', WebkitOverflowScrolling: 'touch',
      }}>
        {tab === 'today' && (
          <V6TodayTab data={data} accent={accent}
            onOpenSub={openSub} onOpenAI={openAI}
            onLog={() => setLogOpen(true)}
            onLogWeight={openWeightLog}
            latestWeight={lastWeight}/>
        )}
        {tab === 'body' && (
          <V6BodyTab data={data} accent={accent}
            onOpenSub={openSub} onOpenAI={openAI}/>
        )}
        {tab === 'more' && (
          <V6MoreTab data={data} onOpenSub={openSub}/>
        )}
      </div>

      {/* Sub-screen overlay */}
      {sub && (() => {
        const Sub = SUBS[sub]?.C();
        if (!Sub) return null;
        return (
          <V6Pushed title={SUBS[sub].title} onBack={closeSub} accent={accent}
            trailing={
              <button onClick={() => openAI()} style={{
                width: 36, height: 36, borderRadius: '50%',
                background: V6.surface3, border: 'none', cursor: 'pointer', padding: 0,
                display: 'flex', alignItems: 'center', justifyContent: 'center',
              }}>
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke={V6.ink}
                     strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
                  <path d="M21 12c0 4-4 7-9 7-1.4 0-2.7-.2-3.9-.6L4 20l1.7-3.6C4.6 15.2 4 13.7 4 12c0-4 4-7 9-7s8 3 8 7z"/>
                </svg>
              </button>
            }>
            <Sub data={data} onOpenAI={openAI} onLog={() => setLogOpen(true)} onLogWeight={openWeightLog}/>
          </V6Pushed>
        );
      })()}

      {/* Tab bar (hidden when sub-screen is open) */}
      {!sub && (
        <V6TabBar active={tab} onChange={setTab} onLog={() => setLogOpen(true)} accent={accent}/>
      )}

      {/* Log sheet */}
      <V6LogSheet open={logOpen} onClose={() => setLogOpen(false)} data={data} accent={accent}/>

      {/* Weight log sheet */}
      <V6WeightLogSheet open={weightLogOpen} onClose={closeWeightLog} data={data} accent={accent} lastWeight={lastWeight}/>

      {/* AI sheet */}
      <V6AISheet open={aiOpen} onClose={() => setAiOpen(false)} data={data} seedPrompt={aiSeed}/>
    </div>
  );
}

Object.assign(window, { V6App });
