// Posts a report to the Discord channel shared with one of the signed-in user's
// people (people.discord_channel_id), so both sides see the same message.
// Body: { person_id, text }. The channel ID is read through RLS, so a user can only
// post for people they own. The bot token stays server-side in the
// DISCORD_BOT_TOKEN secret.
import { createClient } from 'npm:@supabase/supabase-js@2';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } });

const DISCORD = 'https://discord.com/api/v10';
const MAX = 2000; // Discord message length limit

// Split on line breaks so long mass reports go out as several messages.
function chunks(text: string): string[] {
  const out: string[] = [];
  let cur = '';
  for (const line of text.split('\n')) {
    const next = cur ? `${cur}\n${line}` : line;
    if (next.length <= MAX) { cur = next; continue; }
    if (cur) out.push(cur);
    cur = line.slice(0, MAX);
  }
  if (cur) out.push(cur);
  return out;
}

async function discord(path: string, token: string, body: unknown) {
  const res = await fetch(DISCORD + path, {
    method: 'POST',
    headers: { Authorization: `Bot ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    const msg = data.code === 10003
      ? 'Discord channel not found. Check the Discord channel ID on this person.'
      : data.code === 50001 || data.code === 50013
        ? "The bot can't post in that channel. Make sure it's in the server and allowed to view and send messages there."
        : res.status === 401
          ? 'The Discord bot token is invalid. Update the DISCORD_BOT_TOKEN secret in Supabase.'
          : `Discord error ${res.status}: ${data.message ?? 'unknown'}`;
    throw new Error(msg);
  }
  return data;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

  try {
    const token = Deno.env.get('DISCORD_BOT_TOKEN');
    if (!token) return json({ error: 'DISCORD_BOT_TOKEN is not set in Supabase Edge Function secrets.' }, 500);

    const { person_id, text } = await req.json().catch(() => ({}));
    if (typeof person_id !== 'string' || typeof text !== 'string' || !text.trim()) {
      return json({ error: 'person_id and text are required' }, 400);
    }
    if (text.length > 20000) return json({ error: 'Report is too long' }, 400);

    // Query as the calling user so RLS limits this to their own people.
    const db = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!, {
      global: { headers: { Authorization: req.headers.get('Authorization') ?? '' } },
    });
    const { data: person, error } = await db.from('people').select('name, discord_channel_id').eq('id', person_id).maybeSingle();
    if (error) return json({ error: error.message }, 400);
    if (!person) return json({ error: 'Person not found' }, 404);
    if (!person.discord_channel_id) return json({ error: `No Discord channel ID saved for ${person.name}.` }, 400);

    for (const content of chunks(text)) {
      await discord(`/channels/${person.discord_channel_id}/messages`, token, { content, allowed_mentions: { parse: [] } });
    }
    return json({ ok: true });
  } catch (err) {
    return json({ error: err instanceof Error ? err.message : String(err) }, 502);
  }
});
