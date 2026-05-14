// v6-ai.jsx — Global AI sheet (Drift Coach).
// Slide-up sheet from the bottom, modal-ish, with quick prompts + chat.

function V6AISheet({ open, onClose, data, seedPrompt }) {
  const MODELS = [
    { id: 'drift',  label: 'Drift Coach',   sub: 'Tuned on your data',    badge: 'Included' },
    { id: 'byok',   label: 'Your model',    sub: 'Bring your own key',    badge: 'BYOK' },
  ];
  const [model, setModel] = React.useState('drift');
  const [modelMenuOpen, setModelMenuOpen] = React.useState(false);
  const activeModel = MODELS.find(m => m.id === model);
  const [messages, setMessages] = React.useState([]);
  const [input, setInput] = React.useState('');
  const [loading, setLoading] = React.useState(false);
  const scrollRef = React.useRef(null);

  React.useEffect(() => {
    if (open) {
      setMessages([{
        role: 'assistant',
        text: `Hi Drift. You're at ${data.weight.current} lbs, ${data.food.target - data.food.consumed} kcal under for today. What can I help with?`,
      }]);
      setInput('');
      if (seedPrompt) setTimeout(() => send(seedPrompt), 250);
    }
  }, [open]);

  React.useEffect(() => {
    if (scrollRef.current) scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
  }, [messages, loading]);

  const send = async (textOverride) => {
    const t = (textOverride ?? input).trim();
    if (!t) return;
    setInput('');
    setMessages(m => [...m, { role: 'user', text: t }]);
    setLoading(true);
    try {
      const ctx = `User context: weight ${data.weight.current} lbs trending ${data.weight.weeklyChange}/wk toward gain goal of ${data.goal.target} lbs. Today ate ${data.food.consumed}/${data.food.target} kcal. Protein ${data.food.macros.protein.eaten}/${data.food.macros.protein.target}g. Fiber ${data.food.macros.fiber.eaten}/${data.food.macros.fiber.target}g. Sleep last night ${data.bodyRhythm.sleep.slept}h. Recovery ${data.bodyRhythm.recovery}. Be concise, conversational, max 4 sentences.`;
      const reply = await window.claude.complete({
        messages: [
          { role: 'user', content: ctx + '\n\nQuestion: ' + t },
        ],
      });
      setMessages(m => [...m, { role: 'assistant', text: reply }]);
    } catch (e) {
      setMessages(m => [...m, { role: 'assistant', text: 'Sorry, I lost the connection. Try again?' }]);
    } finally {
      setLoading(false);
    }
  };

  if (!open) return null;

  const quick = [
    'Suggest a high-protein snack',
    'Why am I not gaining?',
    "What's good for tonight's dinner?",
    'Review my sleep this week',
  ];

  return (
    <div style={{
      position: 'absolute', inset: 0, zIndex: 60,
      display: 'flex', flexDirection: 'column', justifyContent: 'flex-end',
      background: 'rgba(20,20,30,0.36)',
      animation: 'v6-fade .18s ease-out',
    }} onClick={onClose}>
      <div onClick={e => e.stopPropagation()} style={{
        background: V6.bg, borderTopLeftRadius: 28, borderTopRightRadius: 28,
        boxShadow: '0 -10px 40px rgba(0,0,0,0.2)',
        animation: 'v6-slide .26s cubic-bezier(.2,.7,.3,1)',
        height: '88%', display: 'flex', flexDirection: 'column',
        position: 'relative',
      }}>
        {/* Header */}
        <div style={{
          padding: '10px 20px 12px', display: 'flex', alignItems: 'center', gap: 10,
          borderBottom: `0.5px solid ${V6.hairline}`,
        }}>
          <div style={{
            width: 32, height: 32, borderRadius: '50%', background: V6.accentSoft,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke={V6.accent}
                 strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
              <path d="M12 2v3M12 19v3M4 12H1M23 12h-3M5.6 5.6l2.1 2.1M16.3 16.3l2.1 2.1M5.6 18.4l2.1-2.1M16.3 7.7l2.1-2.1"/>
              <circle cx="12" cy="12" r="3.5"/>
            </svg>
          </div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontFamily: V6.display, fontSize: 15, fontWeight: 700, color: V6.ink, letterSpacing: '-0.018em' }}>Drift Coach</div>
            <button onClick={() => setModelMenuOpen(o => !o)} style={{
              marginTop: 2,
              background: 'transparent', border: 'none', cursor: 'pointer', padding: 0,
              display: 'inline-flex', alignItems: 'center', gap: 4,
              fontFamily: V6.sans, fontSize: 11, color: V6.ink3, fontWeight: 600,
            }}>
              <span style={{
                width: 6, height: 6, borderRadius: '50%',
                background: model === 'drift' ? V6.accent : V6.good,
              }}/>
              <span style={{ color: V6.ink2 }}>{activeModel.label}</span>
              <span style={{ color: V6.ink4 }}>· {activeModel.badge}</span>
              <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke={V6.ink3}
                   strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round"
                   style={{ marginLeft: 2, transform: modelMenuOpen ? 'rotate(180deg)' : 'none', transition: 'transform .15s' }}>
                <path d="M6 9l6 6 6-6"/>
              </svg>
            </button>
          </div>
          <button onClick={onClose} style={{
            background: V6.surface3, border: 'none', cursor: 'pointer',
            fontFamily: V6.sans, fontSize: 12, fontWeight: 700, color: V6.ink2,
            padding: '6px 12px', borderRadius: 999,
          }}>Done</button>
        </div>

        {/* Model picker dropdown */}
        {modelMenuOpen && (
          <div style={{
            position: 'absolute', top: 62, left: 16, right: 16, zIndex: 2,
            background: V6.bg, borderRadius: V6.r.lg,
            border: `0.5px solid ${V6.hairline}`,
            boxShadow: '0 12px 36px rgba(0,0,0,0.12)',
            padding: 6, display: 'flex', flexDirection: 'column', gap: 2,
          }}>
            {MODELS.map(m => {
              const sel = m.id === model;
              return (
                <button key={m.id} onClick={() => { setModel(m.id); setModelMenuOpen(false); }} style={{
                  background: sel ? V6.surface2 : 'transparent', border: 'none', cursor: 'pointer',
                  borderRadius: V6.r.md, padding: '12px 12px',
                  display: 'flex', alignItems: 'center', gap: 12, textAlign: 'left',
                }}>
                  <div style={{
                    width: 32, height: 32, borderRadius: '50%',
                    background: m.id === 'drift' ? V6.accentSoft : V6.surface3,
                    display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
                  }}>
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none"
                         stroke={m.id === 'drift' ? V6.accent : V6.ink2}
                         strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
                      {m.id === 'drift' ? (
                        <React.Fragment>
                          <path d="M12 2v3M12 19v3M4 12H1M23 12h-3M5.6 5.6l2.1 2.1M16.3 16.3l2.1 2.1M5.6 18.4l2.1-2.1M16.3 7.7l2.1-2.1"/>
                          <circle cx="12" cy="12" r="3.5"/>
                        </React.Fragment>
                      ) : (
                        <React.Fragment>
                          <path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"/>
                          <path d="M3.3 7l8.7 5 8.7-5M12 22V12"/>
                        </React.Fragment>
                      )}
                    </svg>
                  </div>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{
                      fontFamily: V6.sans, fontSize: 13.5, fontWeight: 700, color: V6.ink,
                      letterSpacing: '-0.005em',
                    }}>{m.label}</div>
                    <div style={{
                      fontFamily: V6.sans, fontSize: 11.5, color: V6.ink3, marginTop: 1,
                    }}>{m.sub}</div>
                  </div>
                  <div style={{
                    fontFamily: V6.sans, fontSize: 10, fontWeight: 700, color: V6.ink3,
                    background: V6.surface3, padding: '3px 7px', borderRadius: 999,
                    letterSpacing: '0.04em', textTransform: 'uppercase',
                  }}>{m.badge}</div>
                  <div style={{
                    width: 18, height: 18, borderRadius: '50%',
                    border: `1.5px solid ${sel ? V6.ink : V6.hairline}`,
                    background: sel ? V6.ink : 'transparent',
                    display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
                  }}>
                    {sel && (
                      <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke={V6.bg}
                           strokeWidth="3.5" strokeLinecap="round" strokeLinejoin="round">
                        <path d="M4 12l5 5L20 6"/>
                      </svg>
                    )}
                  </div>
                </button>
              );
            })}
            {model === 'byok' && (
              <div style={{
                margin: '4px 6px 2px',
                padding: '10px 12px',
                background: V6.surface2, borderRadius: V6.r.md,
                display: 'flex', alignItems: 'center', gap: 10,
              }}>
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke={V6.ink2}
                     strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
                  <circle cx="7" cy="15" r="4"/><path d="M10 12l8-8m-3 3l2 2"/>
                </svg>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{
                    fontFamily: V6.sans, fontSize: 11.5, color: V6.ink2, fontWeight: 600,
                  }}>OpenAI · sk-••••••••••4a8c</div>
                  <div style={{
                    fontFamily: V6.sans, fontSize: 10.5, color: V6.ink3, marginTop: 1,
                  }}>Manage keys in Settings</div>
                </div>
              </div>
            )}
          </div>
        )}

        {/* Messages */}
        <div ref={scrollRef} style={{ flex: 1, overflowY: 'auto', padding: '18px 16px' }}>
          {messages.map((m, i) => (
            <div key={i} style={{
              display: 'flex', justifyContent: m.role === 'user' ? 'flex-end' : 'flex-start',
              marginBottom: 10,
            }}>
              <div style={{
                maxWidth: '80%',
                background: m.role === 'user' ? V6.ink : V6.surface,
                color: m.role === 'user' ? V6.bg : V6.ink,
                padding: '10px 14px',
                borderRadius: 18,
                borderTopRightRadius: m.role === 'user' ? 6 : 18,
                borderTopLeftRadius: m.role === 'user' ? 18 : 6,
                fontFamily: V6.sans, fontSize: 13.5, lineHeight: 1.45,
                boxShadow: m.role === 'user' ? 'none' : V6.shadow.soft,
              }}>{m.text}</div>
            </div>
          ))}
          {loading && (
            <div style={{ display: 'flex', justifyContent: 'flex-start' }}>
              <div style={{
                background: V6.surface, padding: '12px 16px', borderRadius: 18, borderTopLeftRadius: 6,
                boxShadow: V6.shadow.soft, display: 'flex', gap: 4,
              }}>
                {[0,1,2].map(i => (
                  <span key={i} style={{
                    width: 6, height: 6, borderRadius: '50%', background: V6.ink3,
                    animation: `v6-dot 1.4s ${i * 0.2}s infinite`,
                  }}/>
                ))}
                <style>{`@keyframes v6-dot { 0%,60%,100% { opacity: .3; transform: translateY(0); } 30% { opacity: 1; transform: translateY(-3px); } }`}</style>
              </div>
            </div>
          )}
        </div>

        {/* Quick prompts */}
        {messages.length <= 1 && !loading && (
          <div style={{ padding: '0 16px 12px', display: 'flex', gap: 6, overflowX: 'auto', flexWrap: 'nowrap' }}>
            {quick.map(q => (
              <button key={q} onClick={() => send(q)} style={{
                background: V6.surface, border: `0.5px solid ${V6.hairline}`, cursor: 'pointer',
                borderRadius: 999, padding: '8px 14px', whiteSpace: 'nowrap',
                fontFamily: V6.sans, fontSize: 12.5, fontWeight: 600, color: V6.ink2,
                boxShadow: V6.shadow.soft, flexShrink: 0,
              }}>{q}</button>
            ))}
          </div>
        )}

        {/* Composer */}
        <div style={{
          padding: '10px 16px 18px', display: 'flex', gap: 8, alignItems: 'center',
          borderTop: `0.5px solid ${V6.hairline}`,
        }}>
          <div style={{
            flex: 1, background: V6.surface, borderRadius: 999, padding: '10px 16px',
            display: 'flex', alignItems: 'center', gap: 8, boxShadow: V6.shadow.soft,
          }}>
            <input value={input} onChange={e => setInput(e.target.value)}
              onKeyDown={e => { if (e.key === 'Enter') send(); }}
              placeholder="Ask Drift…"
              style={{
                flex: 1, border: 'none', outline: 'none', background: 'transparent',
                fontFamily: V6.sans, fontSize: 14, color: V6.ink,
              }}/>
          </div>
          <button onClick={() => send()} disabled={!input.trim() || loading} style={{
            width: 44, height: 44, borderRadius: '50%',
            background: input.trim() ? V6.ink : V6.surface3, border: 'none', cursor: 'pointer',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            opacity: input.trim() ? 1 : 0.6,
          }}>
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none"
                 stroke={input.trim() ? V6.bg : V6.ink3} strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round">
              <path d="M5 12h14M13 6l6 6-6 6"/>
            </svg>
          </button>
        </div>
      </div>
    </div>
  );
}

Object.assign(window, { V6AISheet });
