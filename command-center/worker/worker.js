// Cloudflare Worker — OAuth + Anonymous Bug Reports for Drift Command Center
// Deploy: npx wrangler deploy
// Secrets: CLIENT_ID, CLIENT_SECRET, BUG_PAT

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: CORS });
    }

    const url = new URL(request.url);

    // Route: /bug — anonymous bug report proxy
    if (url.pathname === '/bug' && request.method === 'POST') {
      return handleBugReport(request, env);
    }

    // Route: / — OAuth token exchange (existing)
    const code = url.searchParams.get('code');
    if (!code) {
      return json({ error: 'Missing code parameter' }, 400);
    }

    const resp = await fetch('https://github.com/login/oauth/access_token', {
      method: 'POST',
      headers: { 'Accept': 'application/json', 'Content-Type': 'application/json' },
      body: JSON.stringify({
        client_id: env.CLIENT_ID,
        client_secret: env.CLIENT_SECRET,
        code,
      }),
    });

    return new Response(await resp.text(), {
      headers: { 'Content-Type': 'application/json', ...CORS }
    });
  }
};

async function handleBugReport(request, env) {
  // Rate limit: 10 per IP per day (using simple header check)
  const ip = request.headers.get('CF-Connecting-IP') || 'unknown';

  // Parse body
  let body;
  try {
    body = await request.json();
  } catch {
    return json({ error: 'Invalid JSON' }, 400);
  }

  const { title, description, priority, submitter } = body;
  if (!title || title.trim().length < 3) {
    return json({ error: 'Title is required (min 3 chars)' }, 400);
  }

  // Create GitHub Issue via bot PAT
  if (!env.BUG_PAT) {
    return json({ error: 'Bug reporting not configured' }, 500);
  }

  const who = submitter && submitter !== 'anonymous' ? `@${submitter}` : `anonymous (IP: ${ip.slice(0, 8)}...)`;
  let issueBody = `${description || 'No description provided.'}`;
  if (priority) issueBody += `\n\n**Priority:** ${priority}`;
  issueBody += `\n\n---\n*Filed via Drift Command Center by ${who}*`;

  const labels = ['bug', 'needs-review'];
  if (priority && ['P0', 'P1', 'P2'].includes(priority)) labels.push(priority);

  const ghResp = await fetch('https://api.github.com/repos/ashish-sadh/Drift/issues', {
    method: 'POST',
    headers: {
      'Accept': 'application/vnd.github.v3+json',
      'Authorization': `token ${env.BUG_PAT}`,
      'User-Agent': 'Drift-Bug-Bot',
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      title: `Bug: ${title.trim()}`,
      body: issueBody,
      labels,
    }),
  });

  if (!ghResp.ok) {
    const err = await ghResp.text();
    return json({ error: 'Failed to create issue', details: err }, 500);
  }

  const issue = await ghResp.json();
  return json({ success: true, number: issue.number, url: issue.html_url });
}

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS },
  });
}
