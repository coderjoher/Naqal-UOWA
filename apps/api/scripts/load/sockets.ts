/*
 * NF-08 socket half of the morning peak: every rider in the prepared data (6 000 at SCALE=3)
 * connects to /live, joins the run they ride, and listens to bus positions while k6 drives the
 * REST traffic. Reports connection failures and ping → student latency; exits 1 when more than
 * 0.5 % of sockets fail or p95 latency exceeds 3 s (NF-07).
 *
 *   npx ts-node scripts/load/sockets.ts /tmp/load.json http://localhost:3000 1800
 */
import { readFileSync } from 'node:fs';
import { io, Socket } from 'socket.io-client';

const [file, api = 'http://localhost:3000', seconds = '60'] = process.argv.slice(2);
const data = JSON.parse(readFileSync(file, 'utf8')) as { riders: { token: string; runId: string }[] };
const url = `${api.replace(/\/$/, '')}/live`;

async function main() {
  const sockets: Socket[] = [];
  let failed = 0;
  let dropped = 0;
  const latencies: number[] = [];
  const started = Date.now();
  // Connect in waves of 200, as students open the app over the morning.
  for (let i = 0; i < data.riders.length; i += 200) {
    await Promise.all(
      data.riders.slice(i, i + 200).map(
        (r) =>
          new Promise<void>((resolve) => {
            const s = io(url, { auth: { token: r.token }, transports: ['websocket'], reconnection: true, reconnectionDelay: 1000 });
            const timer = setTimeout(() => {
              failed++;
              resolve();
            }, 15_000);
            s.once('ready', async () => {
              clearTimeout(timer);
              const ack = await s.timeout(10_000).emitWithAck('join', { runId: r.runId }).catch(() => null);
              if (!ack?.ok) failed++;
              resolve();
            });
            s.on('bus', (m: { at: string }) => latencies.push(Date.now() - Date.parse(m.at)));
            s.on('disconnect', (reason) => reason !== 'io client disconnect' && dropped++);
            sockets.push(s);
          }),
      ),
    );
  }
  console.log(`connected ${sockets.length - failed}/${data.riders.length} sockets in ${((Date.now() - started) / 1000).toFixed(1)} s`);

  const until = started + Number(seconds) * 1000;
  while (Date.now() < until) {
    await new Promise((r) => setTimeout(r, 10_000));
    const live = sockets.filter((s) => s.connected).length;
    console.log(`${new Date().toISOString()} live ${live}, bus events ${latencies.length}, drops ${dropped}`);
  }
  sockets.forEach((s) => s.disconnect());

  latencies.sort((a, b) => a - b);
  const p95 = latencies.length ? latencies[Math.floor(latencies.length * 0.95)] : Infinity;
  const failRate = failed / data.riders.length;
  console.log(JSON.stringify({ sockets: data.riders.length, failed, failRate, dropped, events: latencies.length, p95Ms: p95 }));
  if (failRate > 0.005 || p95 > 3000) {
    console.error('FAILED: socket error rate above 0.5 % or p95 above 3 s');
    process.exit(1);
  }
  process.exit(0);
}

main();
