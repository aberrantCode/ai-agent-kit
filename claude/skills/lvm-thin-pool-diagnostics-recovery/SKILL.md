---
name: lvm-thin-pool-diagnostics-recovery
description: Use when a host or guest (VM/container) using LVM thin-provisioned storage shows ENOSPC, read-only remounts, or stalled writes despite the filesystem reporting free space — covers layered diagnosis and safe recovery of the thin pool and any affected filesystems.
status: active
version: 2026-07-05
---

# LVM Thin-Pool Diagnostics & Recovery

## When to use

- A container or VM reports free filesystem space (`df`) but writes fail with ENOSPC or the filesystem has gone read-only.
- Host-side symptoms suggest an LVM thin pool is out of data space (`out-of-data-space error IO` mode).
- Streaming/write operations to thin-backed storage stall unpredictably under load, even when the pool isn't reported as full.

## Method

**1. Diagnose in layers — never trust filesystem-level free space alone.**
- Container/guest level: `df` can show "free" space that is meaningless if the *backing* thin pool can't allocate new blocks. Every write will fail with ENOSPC regardless of what `df` reports.
- Host level: run `lvs` to see true thin-pool utilization, and `dmesg` to check for `out-of-data-space error IO` mode — this is the pool refusing all new allocations fleet-wide, threatening every thin-backed guest, not just the one you're debugging.
- Filesystem level: check whether the filesystem has its own stuck flag — ext4's `errors=remount-ro` behavior can leave it in `emergency_ro` even after the underlying pool issue is fixed.

**2. Recover the pool first, then the filesystem, then reclaim space.**
- Extend the pool live, no downtime: `lvextend -L+<sizeG> pve/data`. The pool exits error-IO mode once resumed.
- Any filesystem that already remounted read-only stays stuck even after the pool recovers — check with `mount | grep rw`; if it still shows `ro`, a bare `mount -o remount,rw` will be rejected because the ext4 superblock error flag persists.
- To clear the superblock error flag: stop the guest, run `e2fsck` on the volume, then restart it.
- Reclaim the freed blocks from the guest side: run `fstrim` **from the host** against the guest (e.g. `pct fstrim <ctid>` for Proxmox containers) — an unprivileged `fstrim` run inside the guest itself will fail; the privileged host-side call succeeds. The reclaimed headroom is what allows a clean reinstall of any packages that were corrupted mid-write during the original failure.

**3. Diagnose write stalls separately from full-pool ENOSPC.**
Thin-pool writes can silently stall under *metadata* pressure (not just data-space pressure) at predictable thresholds, blocking streaming operations without an outright error. To confirm: use `iostat` to check I/Os-in-progress, sample `/proc/diskstats` over time, and correlate against live-mirror/replication activity. If confirmed, recover by draining the near-full pool onto a healthy one using **idempotent offline moves** — never online moves while under pressure — and force-stop the guest/service before moving, to prevent new writes from cascading into the source pool mid-drain.

## Gotchas

- Don't stop at "container shows free space" — that's the classic false signal; always check `lvs`/`dmesg` on the host before ruling out the pool.
- A plain `remount,rw` after fixing the pool will not clear an `emergency_ro` ext4 volume — you need `e2fsck` first.
- Don't run `fstrim` unprivileged from inside the guest expecting it to reclaim space — it silently fails or no-ops; it must run privileged from the host.
- Pool exhaustion is fleet-wide: recovering one guest's symptom doesn't mean the pool is safe — verify `lvs` shows healthy headroom before considering the incident closed.
- When stalls (not hard failures) are the symptom, don't assume the pool is "fine" just because it isn't reporting 100% full — metadata pressure can stall writes below that threshold; always drain offline, never online, once confirmed.
