---
name: gpu-workload-placement-and-arbitration
category: DevOps & Tooling
description: Use when planning or deploying services that touch a GPU (ML inference, image/video generation, upscaling) and multiple such services must share one physical card. Covers deciding which services need direct GPU access, designing serialized arbitration so processes don't collide, and validating VRAM coexistence with no regressions.
status: active
version: 2026-07-05
---

# GPU Workload Placement and Arbitration

## When to use

- Before scaffolding or choosing a host for any compute-intensive service (ML inference, image generation, video transcoding/upscaling).
- When two or more GPU-using services will run on the same box and share a single card.
- When adding a new GPU workload to an already-running shared-GPU system, or containerizing a GPU workload.

## Method

1. **Classify each service before choosing a host.** Decide whether it computes on the GPU itself (needs local GPU access — e.g. ComfyUI/Stable Diffusion, `ollama.run()`) or merely reaches a GPU indirectly (proxies to a remote API over HTTP and can run on plain CPU). This classification must precede the scaffold and host decision — get it wrong and you provision the wrong hardware.

2. **Model GPU access as a first-class deployment requirement, not an afterthought**, whenever multiple services will compete for one card (e.g., Ollama inference + an upscaling service on a 12 GB RTX 3060). Design for serialized access: one process holds the GPU at a time; others unload their models before the next loads. Write this constraint into the feature spec, including an explicit "dedicated-GPU upgrade" trigger — the condition under which sharing no longer works (e.g., two workloads genuinely need VRAM in parallel).

3. **Track per-service VRAM budgets** so you can tell in advance whether a new workload fits. Example budget: Ollama ~6 GB, an upscaler ~7.5 GB, video models 12+ GB. Sum against total card VRAM before adding a workload.

4. **Enforce single-renderer discipline for services that can all see the GPU simultaneously** (e.g., ComfyUI + Forge): only one inference process runs at a time; no concurrent requests. Leave headroom for idle background tasks (e.g., Ollama holding 1.4 GB while ComfyUI peaks at 10.4 GB on a 12 GB card is safe). Use a `--lowvram` flag (or equivalent) as a fallback when headroom is tight, not as the primary strategy.

5. **For containerized GPU workloads**, negotiate runtime + capabilities explicitly rather than granting broad access: use the nvidia container runtime with the minimal capability set needed (`utility` for tooling, `compute` for inference) to avoid silent GPU-fallback-to-CPU failures. Verify GPU presence end-to-end after every deploy: host-level (`pct exec nvidia-smi` or equivalent), container-level (`docker exec <ctr> ps` checking the PROCESSOR column), and process-table level (`nvidia-smi`'s process list). When CPU/GPU split modes are needed, gate them behind environment toggles so switching is a pure config flip, never a structural refactor.

6. **Validate coexistence at three levels before calling a shared-GPU deployment done:**
   - **VRAM timeline** — sample `nvidia-smi` throughout the operation to confirm each workload's memory is allocated and released correctly (no OOM, nothing stuck).
   - **Combined peak** — sum both processes' VRAM at the highest simultaneous point and confirm it's under the card's total (e.g., 6.1 GB + 4.76 GB = 10.9 GB < 12 GB).
   - **No regression** — the co-resident workload must stay responsive throughout (e.g., still able to load a model mid-operation on the other service).
   Record wall time as GPU-speed evidence (e.g., 6 seconds for a scale=4 + face-enhance op vs. minutes on CPU) and keep the full VRAM timeline as the audit trail.

## Gotchas

- Skipping step 1 (compute-locally vs. proxy classification) leads to over-provisioning GPU hosts for services that never touch the GPU directly.
- A service that "can see" the GPU isn't the same as one that's safe to run concurrently — visibility and arbitration are separate concerns.
- Stale or frozen healthchecks can mask a wedged GPU process; always confirm with a live `nvidia-smi` process-table read, not just container health status.
- Don't rely on total-VRAM headroom alone — validate the timeline, not just the peak, since transient spikes during model load/unload are where OOMs happen.

## Diagram

[View diagram](diagram.html)
