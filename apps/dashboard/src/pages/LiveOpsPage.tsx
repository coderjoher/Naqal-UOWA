import { clsx } from "clsx";
import {
  Bus,
  CircleCheck,
  Hourglass,
  MapPin,
  Radio,
  Users,
  WifiOff,
} from "lucide-react";
import { AnimatePresence, motion } from "motion/react";
import { lazy, Suspense, useMemo, useState } from "react";
import { useI18n } from "../lib/i18n";
import { agoParts, useLiveFeed, useNow } from "../lib/live";
import {
  useCurrentUniversity,
  useDispatch,
  useLiveRuns,
  type LiveRun,
  type RunStatus,
} from "../lib/queries";
import {
  Badge,
  Card,
  EmptyState,
  Kpi,
  KpiGrid,
  PageHeader,
  SkeletonRows,
} from "../ui";
import type { MapMarker } from "../ui/MapView";
import { itemVariants, listVariants } from "../ui/motion";

// MapLibre needs browser APIs; load it lazily like the Points page.
const MapView = lazy(() =>
  import("../ui/MapView").then((m) => ({ default: m.MapView })),
);

const baghdadDate = () =>
  new Date(Date.now() + 3 * 3600_000).toISOString().slice(0, 10);
const STATUS_TONE: Record<
  RunStatus,
  "neutral" | "primary" | "success" | "warning" | "danger"
> = {
  planned: "neutral",
  started: "primary",
  at_stop: "warning",
  done: "success",
  cancelled: "danger",
};
const ORDER: RunStatus[] = [
  "at_stop",
  "started",
  "planned",
  "done",
  "cancelled",
];

/** TO-07: every bus on one map, run status and the waitlist, updating live. */
export function LiveOpsPage() {
  const { t } = useI18n();
  const date = baghdadDate();
  const runs = useLiveRuns(date);
  const uni = useCurrentUniversity();
  const board = useDispatch(date);
  const initial = useMemo(
    () => Object.fromEntries((runs.data ?? []).map((r) => [r.runId, r.bus])),
    [runs.data],
  );
  const { buses, connected } = useLiveFeed(initial, ["live-runs", date]);
  const [selected, setSelected] = useState<string | null>(null);
  const now = useNow(1000);

  const list = useMemo(
    () =>
      [...(runs.data ?? [])].sort(
        (a, b) =>
          ORDER.indexOf(a.status) - ORDER.indexOf(b.status) ||
          a.wave.time.localeCompare(b.wave.time),
      ),
    [runs.data],
  );
  const active = list.filter(
    (r) => r.status === "started" || r.status === "at_stop",
  );
  const waitlist = (board.data ?? []).flatMap((w) =>
    w.waitlist
      .filter((x) => x.status === "waitlisted")
      .map((x) => ({ ...x, wave: w.time })),
  );
  const sel = list.find((r) => r.runId === selected) ?? null;

  const markers = useMemo<MapMarker[]>(() => {
    const out: MapMarker[] = [];
    if (uni.data)
      out.push({
        id: "campus",
        lat: uni.data.campusLat,
        lng: uni.data.campusLng,
        label: t("live.campus"),
        kind: "campus",
      });
    if (sel)
      for (const s of sel.stops)
        out.push({
          id: `stop-${s.seq}`,
          lat: s.lat,
          lng: s.lng,
          label: `${s.seq}. ${s.name}`,
          kind: s.served ? "stop-done" : "stop",
        });
    for (const r of list) {
      const p = buses[r.runId];
      if (!p || (r.status !== "started" && r.status !== "at_stop")) continue;
      out.push({
        id: r.runId,
        lat: p.lat,
        lng: p.lng,
        label: `${r.driverName} · ${r.plate ?? ""}`,
        kind: r.femaleOnly ? "bus-female" : "bus",
      });
    }
    return out;
  }, [uni.data, sel, list, buses, t]);

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title={t("live.title")}
        description={t("live.desc")}
        actions={
          <span
            className={clsx(
              "inline-flex h-10 items-center gap-2 rounded-pill px-4 text-label",
              connected
                ? "bg-success-soft text-success"
                : "bg-warning-soft text-warning",
            )}
            role="status"
          >
            {connected ? (
              <Radio size={16} className="animate-pulse" aria-hidden />
            ) : (
              <WifiOff size={16} aria-hidden />
            )}
            {t(connected ? "live.connected" : "live.reconnecting")}
          </span>
        }
      />

      <KpiGrid>
        <Kpi tone="brand" icon={Bus} label={t("live.onRoad")} value={active.length} loading={runs.isPending} sub={t("overview.runsToday", { n: list.filter((r) => r.status !== "cancelled").length })} />
        <Kpi icon={MapPin} label={t("live.atStop")} value={list.filter((r) => r.status === "at_stop").length} loading={runs.isPending} />
        <Kpi icon={CircleCheck} label={t("live.done")} value={list.filter((r) => r.status === "done").length} loading={runs.isPending} />
        <Kpi
          icon={Hourglass}
          label={t("live.waitlist")}
          value={waitlist.length}
          loading={board.isPending}
          sub={waitlist.length ? t("overview.wave.waiting", { n: waitlist.length }) : t("overview.nobodyWaiting")}
          subTone={waitlist.length ? "warning" : "success"}
        />
      </KpiGrid>

      <div className="grid gap-4 xl:grid-cols-[minmax(0,1fr)_380px]">
        <Card className="overflow-hidden p-0">
          {uni.data ? (
            <Suspense
              fallback={
                <div className="h-[420px] animate-pulse bg-surface-muted md:h-[600px]" />
              }
            >
              <MapView
                className="h-[420px] md:h-[600px]"
                label={t("live.map")}
                center={{ lat: uni.data.campusLat, lng: uni.data.campusLng }}
                markers={markers}
                selectedId={selected}
                onSelect={(id: string) =>
                  id.startsWith("stop-") || id === "campus"
                    ? null
                    : setSelected(id)
                }
              />
            </Suspense>
          ) : (
            <div className="h-[420px] animate-pulse bg-surface-muted md:h-[600px]" />
          )}
        </Card>

        <div className="flex flex-col gap-4">
          <Card title={t("live.runs")} description={t("live.runsHint")}>
            {runs.isLoading ? (
              <SkeletonRows rows={4} />
            ) : list.length === 0 ? (
              <EmptyState
                icon={Bus}
                title={t("live.noRuns")}
                message={t("live.noRunsHint")}
              />
            ) : (
              <motion.ul
                className="-mx-2 flex max-h-[420px] flex-col gap-1 overflow-y-auto"
                variants={listVariants}
                initial="hidden"
                animate="show"
              >
                {list.map((r) => (
                  <motion.li key={r.runId} variants={itemVariants} layout>
                    <RunRow
                      run={r}
                      selected={r.runId === selected}
                      lastAt={buses[r.runId]?.at ?? null}
                      now={now}
                      onSelect={() =>
                        setSelected(r.runId === selected ? null : r.runId)
                      }
                    />
                  </motion.li>
                ))}
              </motion.ul>
            )}
          </Card>

          <Card title={t("live.waitlist")}>
            {waitlist.length === 0 ? (
              <p className="text-caption text-text-muted">
                {t("live.waitlistEmpty")}
              </p>
            ) : (
              <ul className="flex flex-col gap-2">
                <AnimatePresence initial={false}>
                  {waitlist.map((w) => (
                    <motion.li
                      key={w.id}
                      layout
                      initial={{ opacity: 0, y: 6 }}
                      animate={{ opacity: 1, y: 0 }}
                      exit={{ opacity: 0 }}
                      className="flex min-h-12 items-center justify-between gap-3 rounded-md bg-surface-muted px-4 py-2"
                    >
                      <span className="min-w-0">
                        <span className="block truncate text-label">
                          {w.name}
                        </span>
                        <span className="text-caption text-text-muted">
                          {w.point}
                        </span>
                      </span>
                      <span className="text-caption text-warning" dir="ltr">
                        {w.wave}
                      </span>
                    </motion.li>
                  ))}
                </AnimatePresence>
              </ul>
            )}
          </Card>
        </div>
      </div>
    </div>
  );
}

function RunRow({
  run,
  selected,
  lastAt,
  now,
  onSelect,
}: {
  run: LiveRun;
  selected: boolean;
  lastAt: string | null;
  now: number;
  onSelect: () => void;
}) {
  const { t } = useI18n();
  const served = run.stops.filter((s) => s.served).length;
  const ago = lastAt
    ? Math.max(0, Math.round((now - Date.parse(lastAt)) / 1000))
    : null;
  const moving = run.status === "started" || run.status === "at_stop";
  const updated = ago != null ? agoParts(ago) : null;
  return (
    <button
      type="button"
      onClick={onSelect}
      aria-pressed={selected}
      data-testid="live-run"
      className={clsx(
        "w-full rounded-md px-3 py-3.5 text-start transition-colors",
        selected ? "bg-primary-soft" : "hover:bg-surface-muted",
      )}
    >
      <span className="flex items-center justify-between gap-2">
        <span className="min-w-0 truncate text-label">{run.driverName}</span>
        <Badge tone={STATUS_TONE[run.status]}>
          {t(`live.status.${run.status}`)}
        </Badge>
      </span>
      <span className="mt-1 flex flex-wrap items-center gap-x-3 gap-y-1 text-caption text-text-muted">
        <span>
          {t(
            run.wave.type === "morning"
              ? "dispatch.morning"
              : "dispatch.return",
          )}{" "}
          <span dir="ltr">{run.wave.time}</span>
        </span>
        <span className="inline-flex items-center gap-1">
          <MapPin size={12} aria-hidden /> {served}/{run.stops.length}
        </span>
        <span className="inline-flex items-center gap-1">
          <Users size={12} aria-hidden /> {run.boarded}/{run.booked}
        </span>
        {run.femaleOnly ? (
          <span className="text-female-only">{t("dispatch.femaleOnly")}</span>
        ) : null}
        {moving && ago != null && updated ? (
          <span className={clsx(ago > 30 && "text-warning")}>
            {t(updated.key, { n: updated.n })}
          </span>
        ) : null}
      </span>
      <span
        className="mt-2 block h-1.5 overflow-hidden rounded-pill bg-surface-muted"
        aria-hidden
      >
        <motion.span
          className="block h-full rounded-pill bg-primary"
          initial={false}
          animate={{
            width: `${run.stops.length ? (served / run.stops.length) * 100 : 0}%`,
          }}
        />
      </span>
    </button>
  );
}
