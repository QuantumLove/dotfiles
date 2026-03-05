# PLT-576: Datadog Observability Integration for Middleman

## TL;DR

> **Quick Summary**: Add comprehensive Datadog observability to the Middleman ECS Fargate service — APM tracing with latency breakdown, structured JSON logging with trace correlation, custom DogStatsD metrics, and a Pulumi-managed dashboard + monitors. This is the first service in the monorepo to use ddtrace, structlog, and Firelens.
>
> **Deliverables**:
> - Datadog Agent + Firelens (FluentBit) sidecars in ECS task definition
> - ddtrace APM with custom spans for upstream provider latency vs. middleware processing
> - structlog JSON logging with automatic ddtrace trace ID injection
> - DogStatsD custom metrics (request count, latency histograms, cache stats, provider health)
> - Pulumi-managed Datadog dashboard ("Middleman Operations")
> - Pulumi-managed Datadog monitors/alerts (error rate, latency, provider outage)
> - Sensitive data filtering (danger_name, request/response bodies, API keys NEVER sent to Datadog)
>
> **Estimated Effort**: Large
> **Parallel Execution**: YES — 4 waves + final verification
> **Critical Path**: Task 1 → Task 5/6 → Task 8/9/10 → F1-F4

---

## Context

### Original Request
Add Datadog observability to Middleman for metrics, tracing, and monitoring. User pain: cannot see where bottlenecks are, how the service behaves, or when to scale.

### Interview Summary
**Key Discussions**:
- **Log forwarding**: DD Agent + Firelens (2 sidecars) for instant trace-log correlation. Chose over HTTP POST (Hawk pattern) because Middleman needs APM and trace-log correlation for bottleneck hunting.
- **structlog**: Yes, replace stdlib logging with structlog JSON. First in repo — becomes the pattern.
- **ddtrace**: First in monorepo. Accepted the pioneering complexity.
- **Metrics scope**: Comprehensive — 4 operational questions framework (latency breakdown, behavior patterns, capacity signals, alerting).
- **Dashboard**: Pulumi code in infra/datadog/. 6-row layout covering golden signals through top-N analysis.
- **Test strategy**: Agent QA only — deploy to dev, verify in Datadog. No unit tests.

**Research Findings**:
- ECS task: Single container, 1024 CPU / 2048 MB, ARM64/Graviton, awslogs driver, single replica (S3 write conflicts)
- DD_API_KEY: Secrets Manager at `{env}/platform/datadog-api-key`
- DD_SITE: `us3.datadoghq.com`
- No existing ddtrace, structlog, Firelens, or Datadog Agent sidecar patterns in the repo
- Sentry active with `enable_tracing=True` at server.py:46-55
- Two request paths: unified (/completions via request.py:98) and passthrough (via passthrough.py:82)
- Hawk API uses fire-and-forget HTTP POST to Datadog (different pattern, not applicable)

### Metis Review
**Identified Gaps** (addressed):
- **Memory budget**: Task memory increased from 2048 → 3072 MB to accommodate sidecars (~300 MB overhead)
- **DD_VERSION**: Set to container image digest (matches existing image pinning strategy)
- **Sentry double-tracing**: Set `SENTRY_TRACES_SAMPLE_RATE=0` when ddtrace active (Sentry keeps error capture only)
- **structlog + ddtrace**: Custom processor needed for trace ID injection (`DD_LOGS_INJECTION` only works with stdlib logging)
- **SensitiveError in traces**: Added TraceFilter to scrub secret model error details from spans
- **Streaming response spans**: Only instrument initial `session.post()`, NOT the async generator body
- **FluentBit Host**: Must use `http-intake.logs.us3.datadoghq.com` (us3 site endpoint)
- **FluentBit health check**: Required for `dependsOn` ordering
- **Gunicorn access logs**: Disable (ddtrace captures request metrics already)
- **asyncio.create_task(cache.set)**: Don't span — detached from trace context
- **DD_TRACE_HEADER_TAGS**: MUST NOT set (would capture auth headers)
- **CloudWatch dual-write**: FluentBit sends to both Datadog AND CloudWatch as fallback
- **DD API key in dev**: Must verify secret exists before deploying

---

## Work Objectives

### Core Objective
Enable the team to answer 4 operational questions about Middleman: "Where is the time going?", "How is the service behaving?", "Do we need to scale?", and "What just broke?" — through Datadog APM traces, structured logs, custom metrics, dashboards, and alerts.

### Concrete Deliverables
- `infra/core/middleman.py` — Updated ECS task definition with DD Agent + Firelens sidecars, env vars, IAM
- `middleman/src/middleman/observability/` — New package: datadog config, structlog setup, metrics helper, sensitivity filter
- `middleman/src/middleman/server.py` — ddtrace initialization, structlog replacement
- `middleman/src/middleman/request.py` — Custom spans for upstream unified API calls
- `middleman/src/middleman/passthrough.py` — Custom spans for upstream passthrough calls
- `middleman/src/middleman/auth.py` — Custom span for JWT validation
- `middleman/src/middleman/cache.py` — Custom span for cache.get (not cache.set — detached context)
- `middleman/src/middleman/*.py` — All modules switched from stdlib logging to structlog
- `middleman/Dockerfile` — `ddtrace-run` prefix added to CMD
- `infra/datadog/middleman_dashboard.py` — Pulumi dashboard component
- `infra/datadog/middleman_monitors.py` — Pulumi monitor definitions

### Definition of Done
- [ ] ECS task runs with 3 healthy containers (middleman, datadog-agent, log_router)
- [ ] APM traces for /health and /completions appear in Datadog APM within 5 minutes
- [ ] Custom spans show upstream provider latency separate from middleware processing
- [ ] Structured JSON logs in Datadog Log Explorer with `dd.trace_id` correlation
- [ ] No `danger_name`, request/response content, or API keys in any trace/log/metric
- [ ] DogStatsD custom metrics visible in Datadog Metrics Explorer
- [ ] Dashboard loads with live data
- [ ] Monitors created and in OK state
- [ ] Sentry still captures errors (error capture preserved)
- [ ] ALB health check passes continuously

### Must Have
- APM traces with latency breakdown (middleware vs. upstream)
- Structured JSON logs correlated with traces (dd.trace_id)
- Sensitive data filtering (danger_name, bodies, keys, auth headers)
- DD Agent + Firelens sidecars in ECS
- Custom metrics for request count, latency histograms, cache stats
- Pulumi dashboard + monitors
- Sample rates: Dev 100%, Staging 100%/10%, Prod 10%/1%

### Must NOT Have (Guardrails)
- ❌ `danger_name` in ANY span tag, log field, or metric tag
- ❌ Request/response bodies in traces (`DD_TRACE_REQUEST_BODY_ENABLED=false`)
- ❌ `DD_TRACE_HEADER_TAGS` set (captures auth headers)
- ❌ Custom FastAPI middleware (use ddtrace's built-in ASGI integration)
- ❌ Spans on `asyncio.create_task(cache.set(...))` (detached context)
- ❌ Spans wrapping streaming response body/async generator (only initial session.post())
- ❌ Changes to deployment strategy, desired_count, or deregistration delay
- ❌ Changes to /health endpoint behavior
- ❌ Changes to error redaction logic (should_show_sensitive_error)
- ❌ Autoscaling (service is single-replica by design)
- ❌ OpenTelemetry (ddtrace only)
- ❌ Refactoring error handling or passthrough logic
- ❌ Monitors/dashboards for non-Middleman services
- ❌ Unit tests (Agent QA only)

---

## Verification Strategy

> **ZERO HUMAN INTERVENTION** — ALL verification is agent-executed. No exceptions.

### Test Decision
- **Infrastructure exists**: NO (first ddtrace/structlog in repo)
- **Automated tests**: None (Agent QA only)
- **Framework**: N/A

### QA Policy
Every task MUST include agent-executed QA scenarios. Evidence saved to `.sisyphus/evidence/task-{N}-{scenario-slug}.{ext}`.

- **Infrastructure (Pulumi)**: Use Bash — `pulumi preview`, `aws ecs describe-tasks`, `aws ecs describe-services`
- **Application (ddtrace/structlog)**: Use Bash — `curl` endpoints + Datadog API queries
- **Dashboard/Monitors**: Use Bash — Datadog API verification
- **Sensitive data**: Use Bash — `grep` through Datadog API trace/log responses for forbidden values

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Foundation + Infra — start immediately, 4 parallel):
├── Task 1: Add ddtrace + structlog + datadog dependencies [quick]
├── Task 2: Create observability package — sensitivity filter, trace filter, metric constants [deep]
├── Task 3: Add DD Agent + Firelens sidecars to ECS task definition [deep]
└── Task 4: Create Middleman Datadog dashboard in Pulumi [unspecified-high]

Wave 2 (Instrumentation Core — 3 parallel, depends on Wave 1):
├── Task 5: Configure structlog (JSON, ddtrace trace injection processor, data filter) (depends: 1, 2) [deep]
├── Task 6: Initialize ddtrace — Dockerfile ddtrace-run + server.py config + disable Sentry tracing (depends: 1, 2) [deep]
└── Task 7: Create DogStatsD metrics helper module (depends: 1, 2) [quick]

Wave 3 (Application Integration — 4 parallel, depends on Wave 2):
├── Task 8: Instrument request.py + passthrough.py — structlog + custom upstream spans (depends: 5, 6, 2) [deep]
├── Task 9: Instrument auth.py + cache.py — structlog + custom spans (depends: 5, 6, 2) [quick]
├── Task 10: Instrument server.py + apis.py — structlog + metrics emission (depends: 5, 6, 7) [unspecified-high]
└── Task 11: Instrument remaining modules — structlog only (depends: 5) [quick]

Wave 4 (Monitors — 1 task, depends on Wave 1):
└── Task 12: Create Middleman Datadog monitors/alerts in Pulumi (depends: 2 for metric names) [unspecified-high]

Wave FINAL (After ALL tasks — 4 parallel verification):
├── F1: Plan compliance audit [oracle]
├── F2: Code quality review [unspecified-high]
├── F3: Real QA — deploy to dev, verify in Datadog [unspecified-high]
└── F4: Scope fidelity check [deep]

Critical Path: Task 1 → Task 5/6 → Task 8/10 → F1-F4
Parallel Speedup: ~60% faster than sequential
Max Concurrent: 4 (Waves 1 & 3)
```

### Dependency Matrix

| Task | Depends On | Blocks | Wave |
|------|-----------|--------|------|
| 1 | — | 5, 6, 7 | 1 |
| 2 | — | 5, 6, 7, 8, 9, 12 | 1 |
| 3 | — | F1-F4 | 1 |
| 4 | — | F1-F4 | 1 |
| 5 | 1, 2 | 8, 9, 10, 11 | 2 |
| 6 | 1, 2 | 8, 9, 10 | 2 |
| 7 | 1, 2 | 10 | 2 |
| 8 | 5, 6, 2 | F1-F4 | 3 |
| 9 | 5, 6, 2 | F1-F4 | 3 |
| 10 | 5, 6, 7 | F1-F4 | 3 |
| 11 | 5 | F1-F4 | 3 |
| 12 | 2 | F1-F4 | 4 |
| F1-F4 | ALL | — | FINAL |

### Agent Dispatch Summary

- **Wave 1**: 4 tasks — T1 `quick`, T2 `deep`, T3 `deep`, T4 `unspecified-high`
- **Wave 2**: 3 tasks — T5 `deep`, T6 `deep`, T7 `quick`
- **Wave 3**: 4 tasks — T8 `deep`, T9 `quick`, T10 `unspecified-high`, T11 `quick`
- **Wave 4**: 1 task — T12 `unspecified-high`
- **FINAL**: 4 tasks — F1 `oracle`, F2 `unspecified-high`, F3 `unspecified-high`, F4 `deep`

---

## TODOs

- [ ] 1. Add ddtrace + structlog + datadog dependencies

  **What to do**:
  - Add `ddtrace>=2.0.0` to middleman/pyproject.toml dependencies
  - Add `structlog>=24.1.0` to middleman/pyproject.toml dependencies
  - Add `datadog>=0.49.0` to middleman/pyproject.toml dependencies (for DogStatsD client)
  - Run `uv lock` from repo root to update uv.lock
  - Verify no dependency conflicts with existing packages (sentry-sdk, aiohttp, fastapi)

  **Must NOT do**:
  - Do NOT add python-json-logger (structlog handles JSON natively)
  - Do NOT change Python version requirement (~=3.11.0)
  - Do NOT modify any other dependency

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Single file edit (pyproject.toml) + lock file update
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - `git-master`: Not needed for a simple dependency addition

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 2, 3, 4)
  - **Blocks**: Tasks 5, 6, 7
  - **Blocked By**: None

  **References**:

  **Pattern References**:
  - `middleman/pyproject.toml` — Current dependencies list. Add new deps in the `[project.dependencies]` section alongside existing `sentry-sdk[aiohttp,fastapi]>=2.19.2`

  **API/Type References**:
  - None

  **External References**:
  - PyPI: ddtrace — https://pypi.org/project/ddtrace/
  - PyPI: structlog — https://pypi.org/project/structlog/
  - PyPI: datadog — https://pypi.org/project/datadog/

  **WHY Each Reference Matters**:
  - `middleman/pyproject.toml` — This is the ONLY file to edit. Match the existing dependency format (package>=version).

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: Dependencies resolve without conflicts
    Tool: Bash
    Preconditions: Repo checked out, uv available
    Steps:
      1. Run `uv lock --check` from repo root
      2. Verify ddtrace, structlog, datadog appear in uv.lock
      3. Run `uv pip compile middleman/pyproject.toml --quiet` to verify resolution
    Expected Result: Lock resolves successfully, all 3 new packages present
    Failure Indicators: Resolution error, version conflict with sentry-sdk or aiohttp
    Evidence: .sisyphus/evidence/task-1-deps-resolve.txt

  Scenario: No unwanted dependency changes
    Tool: Bash
    Preconditions: uv.lock updated
    Steps:
      1. Run `git diff --stat uv.lock` to check scope of changes
      2. Verify only additions (no removals or version changes to existing deps)
    Expected Result: Only new packages added, existing packages unchanged
    Failure Indicators: Existing package versions changed unexpectedly
    Evidence: .sisyphus/evidence/task-1-lockfile-diff.txt
  ```

  **Commit**: YES
  - Message: `feat(middleman): add ddtrace, structlog, datadog dependencies`
  - Files: `middleman/pyproject.toml`, `uv.lock`
  - Pre-commit: `uv lock --check`

- [ ] 2. Create observability package — sensitivity filter, trace filter, metric constants

  **What to do**:
  - Create `middleman/src/middleman/observability/__init__.py` (empty or minimal exports)
  - Create `middleman/src/middleman/observability/constants.py`:
    - `DD_SERVICE = "middleman"`
    - `DD_SITE = "us3.datadoghq.com"`
    - Metric name constants: `METRIC_REQUEST_COUNT`, `METRIC_REQUEST_DURATION`, `METRIC_UPSTREAM_DURATION`, `METRIC_CACHE_HIT`, `METRIC_CACHE_MISS`, `METRIC_AUTH_DURATION`, `METRIC_ERROR_COUNT`, `METRIC_RATE_LIMITED`
    - Tag key constants: `TAG_PROVIDER`, `TAG_MODEL`, `TAG_ENDPOINT`, `TAG_STATUS_CODE`, `TAG_USER_ID`, `TAG_CACHE_RESULT`
    - Forbidden field names: `SENSITIVE_FIELDS = {"danger_name", "api_key", "authorization", ...}`
  - Create `middleman/src/middleman/observability/filters.py`:
    - `SensitiveDataTraceFilter` class (ddtrace `TraceFilter` subclass): Scrubs `danger_name` from span tags, replaces with `public_name`. Redacts error details on spans for secret model requests (catches `SensitiveError`). Removes any span tag in SENSITIVE_FIELDS.
    - `sensitive_data_log_processor(logger, method_name, event_dict)` — structlog processor that removes SENSITIVE_FIELDS from log events, replaces `danger_name` with `[REDACTED]`
    - `sanitize_model_tag(model_config) -> str` — Returns `public_name` if model exists, handles None
  - Write clear docstrings explaining WHY each filter exists (data sensitivity requirements)

  **Must NOT do**:
  - Do NOT import ddtrace or structlog at module level (they may not be installed yet in Wave 1 — use TYPE_CHECKING guard or lazy imports)
  - Do NOT implement the structlog JSON configuration here (that's Task 5)
  - Do NOT implement ddtrace initialization here (that's Task 6)
  - Do NOT implement DogStatsD client here (that's Task 7)

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: Requires understanding data sensitivity requirements, ddtrace TraceFilter API, and structlog processor API. Security-critical code.
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - `playwright`: No browser interaction needed

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 3, 4)
  - **Blocks**: Tasks 5, 6, 7, 8, 9, 12
  - **Blocked By**: None

  **References**:

  **Pattern References**:
  - `middleman/src/middleman/server.py:46-55` — Sentry initialization shows how observability is set up. The new observability package will be imported similarly.
  - `middleman/src/middleman/server.py:518-538` — `should_show_sensitive_error()` function shows the existing pattern for secret model error redaction. The TraceFilter must implement similar logic for span errors.
  - `middleman/src/middleman/models.py` — Model configuration with `danger_name`, `public_name`, `are_details_secret` fields. These are the fields the filter must handle.

  **API/Type References**:
  - `middleman/src/middleman/models.py:ModelInfo` — Has `danger_name: str`, `public_name: str`, `are_details_secret: bool` fields
  - ddtrace `TraceFilter` API — `process_trace(trace: List[Span]) -> Optional[List[Span]]`

  **External References**:
  - ddtrace TraceFilter: https://ddtrace.readthedocs.io/en/stable/advanced_usage.html#trace-filtering
  - structlog processors: https://www.structlog.org/en/stable/processors.html

  **WHY Each Reference Matters**:
  - `server.py:320-340` (`should_show_sensitive_error`) — The TraceFilter MUST implement the same logic: if a model has `are_details_secret=True`, scrub error details from the span. This is the authoritative pattern for secret model handling.
  - `models.py:MiddlemanModel` — The filter needs to know the shape of model config to extract `public_name` vs `danger_name`.

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: Sensitivity filter module imports correctly
    Tool: Bash
    Preconditions: Dependencies installed (may need to install ddtrace first)
    Steps:
      1. Run `python -c "from middleman.observability.constants import SENSITIVE_FIELDS, METRIC_REQUEST_COUNT; print('OK')"` from middleman/src/
      2. Run `python -c "from middleman.observability.filters import SensitiveDataTraceFilter; print('OK')"` from middleman/src/
    Expected Result: Both imports succeed, print "OK"
    Failure Indicators: ImportError, ModuleNotFoundError
    Evidence: .sisyphus/evidence/task-2-import-check.txt

  Scenario: SENSITIVE_FIELDS contains all required fields
    Tool: Bash
    Preconditions: Module created
    Steps:
      1. Run `python -c "from middleman.observability.constants import SENSITIVE_FIELDS; assert 'danger_name' in SENSITIVE_FIELDS; assert 'api_key' in SENSITIVE_FIELDS; assert 'authorization' in SENSITIVE_FIELDS; print('All sensitive fields present')"` from middleman/src/
    Expected Result: Assertion passes
    Failure Indicators: AssertionError
    Evidence: .sisyphus/evidence/task-2-sensitive-fields.txt
  ```

  **Commit**: YES
  - Message: `feat(middleman): add observability config module with sensitivity filtering`
  - Files: `middleman/src/middleman/observability/__init__.py`, `middleman/src/middleman/observability/constants.py`, `middleman/src/middleman/observability/filters.py`

- [ ] 3. Add Datadog Agent + Firelens sidecars to ECS task definition

  **What to do**:
  - In `infra/core/middleman.py`, add **Datadog Agent sidecar** container to `container_definitions`:
    - Name: `datadog-agent`
    - Image: `public.ecr.aws/datadog/agent:7` (multi-arch, includes ARM64)
    - Essential: `false` (app should survive agent crash)
    - Memory reservation: 256 MB
    - CPU: 128
    - Port mappings: 8126/tcp (APM traces), 8125/udp (DogStatsD)
    - Environment: `DD_APM_ENABLED=true`, `DD_DOGSTATSD_NON_LOCAL_TRAFFIC=true`, `DD_APM_NON_LOCAL_TRAFFIC=true`, `DD_SITE=us3.datadoghq.com`, `DD_ENV=<stack_env>`, `DD_ECS_FARGATE=true`, `DD_PROCESS_AGENT_ENABLED=false`, `ECS_FARGATE=true`
    - Secrets: `DD_API_KEY` from `{env}/platform/datadog-api-key` Secrets Manager ARN
    - Log configuration: `awslogs` driver (NOT awsfirelens — would be circular) with `{env}/middleman` log group, stream prefix `datadog-agent`
    - Health check: `CMD ["agent", "health"]` (interval 30s, timeout 5s, retries 3, start_period 15s)
  - Add **Firelens (FluentBit) log router** container:
    - Name: `log_router`
    - Image: `amazon/aws-for-fluent-bit:stable` (multi-arch, AWS maintained)
    - Essential: `true` (losing logs is critical)
    - Memory reservation: 50 MB
    - CPU: 64
    - FirelensConfiguration: `{"type": "fluentbit", "options": {"enable-ecs-log-metadata": "true", "config-file-type": "file", "config-file-value": "/fluent-bit/configs/minimize-log-loss.conf"}}`
    - Log configuration: `awslogs` driver with `{env}/middleman` log group, stream prefix `log_router`
    - Health check: `CMD ["curl", "-f", "http://127.0.0.1:2020/api/v1/health"]` (interval 30s, timeout 5s, retries 3, start_period 15s)
  - **Switch middleman container** log configuration from `awslogs` to `awsfirelens`:
    - logDriver: `awsfirelens`
    - Options: `Name=datadog`, `Host=http-intake.logs.us3.datadoghq.com`, `TLS=on`, `dd_service=middleman`, `dd_source=python`, `dd_tags=env:<env>`, `provider=ecs`, `retry_limit=5`
    - ALSO add a secondary FluentBit output for CloudWatch (dual-write for fallback):
      - `Name=cloudwatch_logs`, `region=us-west-2`, `log_group_name={env}/middleman`, `log_stream_prefix=ecs/middleman/`, `auto_create_group=false`
    - Secrets in logConfiguration: `apikey` → DD_API_KEY from Secrets Manager
  - Add `dependsOn` to middleman container: `[{"containerName": "log_router", "condition": "HEALTHY"}, {"containerName": "datadog-agent", "condition": "HEALTHY"}]`
  - Add **DD environment variables** to middleman container:
    - `DD_AGENT_HOST=localhost`
    - `DD_TRACE_AGENT_PORT=8126`
    - `DD_DOGSTATSD_PORT=8125`
    - `DD_ENV=<stack_env>`
    - `DD_SERVICE=middleman`
    - `DD_VERSION=<image_digest_short>` (first 12 chars of image digest)
    - `DD_SITE=us3.datadoghq.com`
    - `DD_TRACE_SAMPLE_RATE` — set per environment (dev: 1.0, staging: 1.0, prod: 0.1)
    - `DD_TRACE_REQUEST_BODY_ENABLED=false`
    - `DD_TRACE_RESPONSE_BODY_ENABLED=false`
    - `DD_LOGS_INJECTION=true`
    - `SENTRY_TRACES_SAMPLE_RATE=0` — disable Sentry tracing (ddtrace handles it now)
  - **Increase task memory** from 2048 to 3072 MB to accommodate sidecars
  - Update middleman container memory to soft limit 2560 MB (leaving ~512 MB for sidecars)
  - **Update IAM task execution role** to allow:
    - `secretsmanager:GetSecretValue` for `{env}/platform/datadog-api-key` (add to existing policy)
    - `logs:CreateLogStream`, `logs:PutLogEvents` (already present, but verify for sidecar log groups)
  - **Validate** that `{env}/platform/datadog-api-key` secret exists (add a Pulumi `aws.secretsmanager.get_secret_version_output` lookup, or document as a prerequisite)

  **Must NOT do**:
  - Do NOT change desired_count (stays at 1)
  - Do NOT change deployment strategy or deregistration delay (1800s)
  - Do NOT change the health check on the middleman container
  - Do NOT modify security groups (egress is already 0.0.0.0/0)
  - Do NOT add DD_TRACE_HEADER_TAGS

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: Complex Pulumi/ECS changes touching task definition, container definitions, IAM roles, secrets, and log configuration. Requires understanding Fargate sidecar patterns and Firelens configuration.
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 2, 4)
  - **Blocks**: F1-F4
  - **Blocked By**: None

  **References**:

  **Pattern References**:
  - `infra/core/middleman.py:429-497` — Current container_definitions array (single middleman container). Add the 2 sidecar containers to this array.
  - `infra/core/middleman.py:482-490` — Current awslogs log configuration on middleman container. Replace with awsfirelens.
  - `infra/core/middleman.py:403-427` — Current environment variables and secrets injection pattern. Follow this pattern for DD_* env vars.
  - `infra/core/middleman.py:293-345` — Task execution role with existing secretsmanager:GetSecretValue policy. Extend this policy to include the DD API key secret ARN.
  - `infra/core/middleman.py:454-455` — `"cpu": task_cpu, "memory": task_memory` — Need to change memory allocation to leave room for sidecars.
  - `infra/core/datadog_integration.py:309-311` — Pattern for referencing DD API key from Secrets Manager (`aws.secretsmanager.get_secret_version_output`).
  - `infra/core/datadog_integration.py:241-511` — DatadogSynthetics ECS service shows how DD Agent containers are configured in Pulumi (different pattern — full DD Agent service, not sidecar — but useful for env var and secret patterns).

  **API/Type References**:
  - `infra/core/middleman.py:MiddlemanConfig` dataclass — Has `task_cpu`, `task_memory`, `cloudwatch_logs_retention_days` fields. May need to add `task_memory` default change or make memory configurable.

  **External References**:
  - AWS Firelens guide: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/using_firelens.html
  - Datadog ECS Fargate guide: https://docs.datadoghq.com/integrations/ecs_fargate/
  - FluentBit Datadog output: https://docs.fluentbit.io/manual/pipeline/outputs/datadog

  **WHY Each Reference Matters**:
  - `middleman.py:429-497` — This is the exact section to modify. The executor must understand the current container_definitions structure to add sidecars correctly.
  - `middleman.py:293-345` — The IAM policy MUST be extended for the DD API key. Missing this = ECS fails to start the agent container.
  - `datadog_integration.py:309-311` — Shows the established pattern for looking up the DD API key secret. Don't invent a new pattern.

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: Pulumi preview shows 3 containers in task definition
    Tool: Bash
    Preconditions: Pulumi stack selected, AWS credentials configured
    Steps:
      1. Run `pulumi preview --diff` in infra/ directory
      2. Check the task definition diff shows container_definitions with 3 containers
      3. Verify container names: "middleman", "datadog-agent", "log_router"
      4. Verify middleman logDriver changed from "awslogs" to "awsfirelens"
      5. Verify task memory increased to 3072
    Expected Result: Preview shows all expected changes without errors
    Failure Indicators: Pulumi error, missing containers, wrong log driver
    Evidence: .sisyphus/evidence/task-3-pulumi-preview.txt

  Scenario: DD API key secret reference is valid
    Tool: Bash
    Preconditions: AWS credentials for target environment
    Steps:
      1. Check the Pulumi code references the correct secret ARN pattern
      2. Verify the task execution role policy includes the DD API key secret ARN
    Expected Result: Secret ARN pattern matches `{env}/platform/datadog-api-key`
    Failure Indicators: Wrong secret name, missing IAM permission
    Evidence: .sisyphus/evidence/task-3-secret-ref.txt

  Scenario: Sidecar health checks are configured
    Tool: Bash
    Preconditions: Pulumi code written
    Steps:
      1. Read the container definitions in the code
      2. Verify datadog-agent has healthCheck with `["CMD", "agent", "health"]`
      3. Verify log_router has healthCheck with `["CMD", "curl", "-f", "http://127.0.0.1:2020/api/v1/health"]`
      4. Verify middleman has dependsOn for both sidecars with condition HEALTHY
    Expected Result: All health checks present, dependsOn ordering correct
    Failure Indicators: Missing health check, wrong condition
    Evidence: .sisyphus/evidence/task-3-health-checks.txt
  ```

  **Commit**: YES
  - Message: `feat(infra): add Datadog Agent + Firelens sidecars to Middleman ECS task`
  - Files: `infra/core/middleman.py`

- [ ] 4. Create Middleman Datadog dashboard in Pulumi

  **What to do**:
  - Create `infra/datadog/middleman_dashboard.py` as a new Pulumi ComponentResource
  - Follow the existing pattern in `infra/datadog/dashboards.py` — use `pulumi_datadog.DashboardJson` with a JSON builder function
  - Dashboard title: "Middleman Operations"
  - Dashboard layout (6 rows, 2 panels each):
    - **Row 1 — Golden Signals**: Request Rate (RPS) by provider (timeseries) | Error Rate (%) by provider (timeseries)
    - **Row 2 — Latency**: P50/P95/P99 latency timeseries | Upstream vs Middleware latency breakdown (stacked bar/area)
    - **Row 3 — Provider Health**: Per-provider error rate heatmap | Rate limiting (429s) by provider (timeseries)
    - **Row 4 — Capacity**: CPU + Memory utilization from ECS (timeseries) | Active connections / Worker utilization (timeseries)
    - **Row 5 — Cache**: Cache hit rate over time (timeseries) | Cache size (gauge/timeseries)
    - **Row 6 — Top N**: Slowest models P95 (top list) | Highest error models (top list)
  - Use metric names from `middleman/src/middleman/observability/constants.py` (but hardcode the string values in dashboard JSON — Pulumi dashboard is infra, not app code)
  - Metric queries should filter by `service:middleman` and `env:$env`
  - Include APM trace metrics (trace.fastapi.request.duration, trace.fastapi.request.hits) alongside custom DogStatsD metrics
  - Register the component in `infra/datadog/__init__.py` (follow existing pattern for DatadogDashboards)
  - Only create dashboard for stg/prd stacks (not dev) — follow existing `config.create_datadog_aws_integration` guard

  **Must NOT do**:
  - Do NOT create dashboards for Hawk or other services
  - Do NOT use hardcoded Datadog dashboard IDs
  - Do NOT create the dashboard manually in Datadog UI

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Requires understanding Pulumi Datadog provider, DashboardJson format, and metric query syntax. Not trivial but not deeply algorithmic.
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 2, 3)
  - **Blocks**: F1-F4
  - **Blocked By**: None

  **References**:

  **Pattern References**:
  - `infra/datadog/dashboards.py` — Existing dashboard component using `DashboardJson`. Follow this pattern EXACTLY for the Middleman dashboard. Look at how JSON is structured, how env tags are parameterized, how the component is registered.
  - `infra/datadog/__init__.py` — Shows how dashboard components are registered and instantiated. Add the Middleman dashboard component here.

  **External References**:
  - Datadog Dashboard JSON schema: https://docs.datadoghq.com/api/latest/dashboards/
  - Pulumi Datadog DashboardJson: https://www.pulumi.com/registry/packages/datadog/api-docs/dashboardjson/

  **WHY Each Reference Matters**:
  - `dashboards.py` — The AUTHORITATIVE pattern for how dashboards are built in this repo. Don't invent a new pattern. Copy the structure and adapt for Middleman metrics.

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: Dashboard Pulumi resource creates without errors
    Tool: Bash
    Preconditions: Pulumi stack selected
    Steps:
      1. Run `pulumi preview --diff` targeting the datadog stack
      2. Verify a new DashboardJson resource appears for "Middleman Operations"
      3. Verify the dashboard JSON contains all 6 row groups
    Expected Result: Preview succeeds, dashboard resource present
    Failure Indicators: Pulumi error, JSON syntax error, missing widgets
    Evidence: .sisyphus/evidence/task-4-dashboard-preview.txt

  Scenario: Dashboard JSON references correct metrics
    Tool: Bash
    Preconditions: Dashboard code written
    Steps:
      1. Read the dashboard JSON builder function
      2. Verify it references `service:middleman` in queries
      3. Verify it includes trace.fastapi.request.duration and custom metric names
      4. Verify no `danger_name` appears anywhere in the dashboard definition
    Expected Result: Correct metric names, service filter present
    Failure Indicators: Wrong metric names, missing service filter
    Evidence: .sisyphus/evidence/task-4-dashboard-metrics.txt
  ```

  **Commit**: YES
  - Message: `feat(infra): add Middleman Datadog dashboard`
  - Files: `infra/datadog/middleman_dashboard.py`, `infra/datadog/__init__.py`

- [ ] 5. Configure structlog with JSON output and ddtrace trace injection

  **What to do**:
  - Create `middleman/src/middleman/observability/logging.py`:
    - `configure_structlog()` function that sets up structlog globally
    - Processor chain:
      1. `structlog.stdlib.add_log_level` — adds log level
      2. `structlog.processors.TimeStamper(fmt="iso")` — ISO timestamps
      3. `add_datadog_trace_context` — **CUSTOM processor** that reads ddtrace context and adds `dd.trace_id`, `dd.span_id`, `dd.service`, `dd.env`, `dd.version` to each log event (DD_LOGS_INJECTION only works with stdlib, NOT structlog — this is critical)
      4. `sensitive_data_log_processor` — imported from `observability.filters` (Task 2)
      5. `structlog.processors.JSONRenderer()` — final JSON output
    - Wrapper class: `structlog.make_filtering_bound_logger(logging.INFO)`
    - `get_logger(name: str)` convenience function that returns a structlog bound logger
  - The `add_datadog_trace_context` processor must:
    - Import `ddtrace` and call `ddtrace.tracer.current_span()` to get active span
    - If span exists, add `dd.trace_id`, `dd.span_id` (as strings, not ints) to event_dict
    - If no span (e.g., during startup), add empty/None values
    - Always add `dd.service`, `dd.env`, `dd.version` from environment variables
  - Configure stdlib logging to route through structlog (for third-party libraries that use stdlib logging):
    - `structlog.stdlib.ProcessorFormatter` wrapping the same processor chain
    - `logging.basicConfig` with the ProcessorFormatter as handler

  **Must NOT do**:
  - Do NOT use `ddtrace.contrib.logging` (it patches stdlib logging, not structlog)
  - Do NOT set DD_LOGS_INJECTION=true in this task (that's an env var for stdlib, not needed with custom processor)
  - Do NOT change any existing module's logging calls (that's Tasks 8-11)

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: Requires understanding structlog processor chains, ddtrace internal APIs (tracer.current_span()), and how to bridge structlog with stdlib logging for third-party libs. The custom trace context processor is non-trivial.
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 6, 7)
  - **Blocks**: Tasks 8, 9, 10, 11
  - **Blocked By**: Tasks 1, 2

  **References**:

  **Pattern References**:
  - `middleman/src/middleman/observability/filters.py` (from Task 2) — The `sensitive_data_log_processor` to include in the processor chain
  - `middleman/src/middleman/observability/constants.py` (from Task 2) — `DD_SERVICE` and other constants

  **External References**:
  - structlog configuration: https://www.structlog.org/en/stable/configuration.html
  - structlog + stdlib integration: https://www.structlog.org/en/stable/standard-library.html
  - ddtrace manual trace context: https://docs.datadoghq.com/tracing/other_telemetry/connect_logs_and_traces/python/

  **WHY Each Reference Matters**:
  - `filters.py` — The log processor from Task 2 must be wired into the structlog chain here. If it's not included, sensitive data will leak into logs.
  - ddtrace manual trace context docs — Explains how to extract `dd.trace_id` and `dd.span_id` from the current ddtrace span. This is the ONLY way to correlate structlog logs with traces (DD_LOGS_INJECTION doesn't work with structlog).

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: structlog outputs JSON with all required fields
    Tool: Bash
    Preconditions: Tasks 1, 2 complete
    Steps:
      1. Run `python -c "from middleman.observability.logging import configure_structlog, get_logger; configure_structlog(); log = get_logger('test'); log.info('hello', key='value')"` from middleman/src/
      2. Capture stdout
      3. Parse as JSON
      4. Verify fields: event, level, timestamp, key
    Expected Result: Valid JSON output with all fields
    Failure Indicators: Non-JSON output, missing fields
    Evidence: .sisyphus/evidence/task-5-json-output.txt

  Scenario: Log output includes dd.* trace context fields
    Tool: Bash
    Preconditions: ddtrace installed
    Steps:
      1. Run a Python script that: initializes ddtrace, creates a span, calls structlog logger inside the span
      2. Capture stdout
      3. Parse JSON and verify dd.trace_id, dd.span_id, dd.service fields exist
    Expected Result: dd.trace_id and dd.span_id are non-empty strings
    Failure Indicators: Missing dd.* fields, fields are None/empty
    Evidence: .sisyphus/evidence/task-5-trace-context.txt
  ```

  **Commit**: YES
  - Message: `feat(middleman): configure structlog with JSON output and trace injection`
  - Files: `middleman/src/middleman/observability/logging.py`

- [ ] 6. Initialize ddtrace — Dockerfile ddtrace-run + server.py config + disable Sentry tracing

  **What to do**:
  - **Dockerfile change**: Modify the CMD to prefix with `ddtrace-run`:
    - Current: `CMD ["gunicorn", "middleman.server:app", "--worker-class", "uvicorn.workers.UvicornWorker", "--preload", "--bind", "0.0.0.0:3500", ...]`
    - New: `CMD ["ddtrace-run", "gunicorn", "middleman.server:app", "--worker-class", "uvicorn.workers.UvicornWorker", "--preload", "--bind", "0.0.0.0:3500", ...]`
    - Keep `docker-entrypoint.sh` as ENTRYPOINT (it does GCP credential setup then `exec "$@"`)
  - **Disable gunicorn access logs** (ddtrace captures request metrics already):
    - Change `--access-logfile -` to `--access-logfile ""` (empty = disabled)
    - Keep `--error-logfile -` (errors still go to stderr)
  - **server.py changes** — After the existing Sentry init block (lines 46-55):
    - Import and call `configure_structlog()` from `observability.logging`
    - Import `SensitiveDataTraceFilter` from `observability.filters`
    - Register the TraceFilter: `tracer.configure(settings={"FILTERS": [SensitiveDataTraceFilter()]})`
    - Note: `ddtrace-run` handles the actual initialization of ddtrace. The server.py code only adds the custom filter and configures structlog.
  - **Environment variable configuration** (these are set in the ECS task definition from Task 3, but document the expected values):
    - `DD_TRACE_SAMPLE_RATE`: Controls trace sampling (set per env in Task 3)
    - `DD_PROFILING_ENABLED`: `false` for dev, `true` with low rate for staging/prod
    - `DD_TRACE_REQUEST_BODY_ENABLED=false`
    - `DD_TRACE_RESPONSE_BODY_ENABLED=false`
    - `SENTRY_TRACES_SAMPLE_RATE=0` (disables Sentry's tracing — ddtrace handles it)
  - **Verify Sentry coexistence**: After changes, Sentry should still capture errors (SENTRY_DSN still set, sentry_sdk.init still called) but NOT create traces (SENTRY_TRACES_SAMPLE_RATE=0 overrides enable_tracing=True)

  **Must NOT do**:
  - Do NOT remove Sentry SDK or sentry_sdk.init() — Sentry stays for error capture
  - Do NOT remove `--preload` from gunicorn (needed for model pre-loading)
  - Do NOT change docker-entrypoint.sh (GCP credential setup must remain)
  - Do NOT add custom FastAPI middleware for tracing (ddtrace auto-instruments FastAPI)
  - Do NOT set DD_TRACE_HEADER_TAGS

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: Requires understanding ddtrace-run lifecycle, gunicorn worker forking with --preload, Sentry coexistence, and TraceFilter registration. Mistakes here break the service.
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 5, 7)
  - **Blocks**: Tasks 8, 9, 10
  - **Blocked By**: Tasks 1, 2

  **References**:

  **Pattern References**:
  - `middleman/src/middleman/server.py:46-55` — Sentry initialization block. The ddtrace configuration must be placed AFTER this block (ddtrace-run already patches before import, so order within server.py matters less — but keep it clean).
  - `middleman/src/middleman/server.py:52` — `SENTRY_TRACES_SAMPLE_RATE` env var usage. This is where the env var override from Task 3 takes effect to disable Sentry tracing.
  - `middleman/Dockerfile` — Current CMD format. Modify to prepend `ddtrace-run`.
  - `middleman/docker-entrypoint.sh` — Uses `exec "$@"` at the end. This means ddtrace-run will be the process that `exec` replaces to, which is correct.

  **API/Type References**:
  - ddtrace `tracer.configure()` — Used to register the SensitiveDataTraceFilter

  **External References**:
  - ddtrace-run: https://ddtrace.readthedocs.io/en/stable/integrations.html#ddtrace-run
  - ddtrace + gunicorn: https://ddtrace.readthedocs.io/en/stable/advanced_usage.html#gunicorn

  **WHY Each Reference Matters**:
  - `server.py:46-55` — MUST understand the Sentry init to ensure ddtrace config doesn't break it
  - `Dockerfile` — The CMD line is the single most important change. Getting it wrong = service doesn't start.
  - `docker-entrypoint.sh` — Must verify `exec "$@"` pattern is compatible with ddtrace-run prefix.

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: Dockerfile CMD includes ddtrace-run
    Tool: Bash
    Preconditions: Dockerfile modified
    Steps:
      1. Read middleman/Dockerfile
      2. Verify CMD starts with "ddtrace-run"
      3. Verify gunicorn arguments are preserved
      4. Verify --access-logfile is empty string or removed
      5. Verify ENTRYPOINT is still docker-entrypoint.sh
    Expected Result: CMD = ["ddtrace-run", "gunicorn", ...], ENTRYPOINT unchanged
    Failure Indicators: Missing ddtrace-run, entrypoint changed
    Evidence: .sisyphus/evidence/task-6-dockerfile.txt

  Scenario: server.py registers TraceFilter without import errors
    Tool: Bash
    Preconditions: Tasks 1, 2 complete
    Steps:
      1. Run `python -c "import middleman.server"` from middleman/src/
      2. Verify no ImportError
    Expected Result: Module imports successfully
    Failure Indicators: ImportError for observability modules
    Evidence: .sisyphus/evidence/task-6-server-import.txt
  ```

  **Commit**: YES
  - Message: `feat(middleman): initialize ddtrace APM with sample rates and sensitivity filter`
  - Files: `middleman/Dockerfile`, `middleman/src/middleman/server.py`

- [ ] 7. Create DogStatsD metrics helper module

  **What to do**:
  - Create `middleman/src/middleman/observability/metrics.py`:
    - Initialize DogStatsD client: `from datadog import initialize, statsd; initialize(statsd_host="localhost", statsd_port=8125)`
    - Helper functions that wrap `statsd` calls with standard tags:
      - `record_request(provider: str, model: str, status_code: int, user_id: str | None, endpoint: str)` — increments `middleman.request.count` with appropriate tags
      - `record_request_duration(duration_ms: float, provider: str, model: str, endpoint: str)` — histogram `middleman.request.duration`
      - `record_upstream_duration(duration_ms: float, provider: str, model: str)` — histogram `middleman.upstream.duration`
      - `record_auth_duration(duration_ms: float)` — histogram `middleman.auth.duration`
      - `record_cache_result(hit: bool, provider: str, model: str)` — increment `middleman.cache.hit` or `middleman.cache.miss`
      - `record_error(provider: str, model: str, error_type: str, status_code: int)` — increment `middleman.error.count`
      - `record_rate_limited(provider: str, model: str)` — increment `middleman.rate_limited.count`
    - ALL metric names and tag keys imported from `observability.constants`
    - ALL model tags use `public_name` (never `danger_name`) — use `sanitize_model_tag()` from `observability.filters`
    - Tags are formatted as `key:value` strings (DogStatsD format)

  **Must NOT do**:
  - Do NOT use `datadog.api` (that's the HTTP API, not DogStatsD)
  - Do NOT call `statsd` directly from application code — always use the helper functions (they enforce tag sanitization)
  - Do NOT include `danger_name` in any tag value

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Straightforward wrapper module. The complexity is in the design (already specified), not the implementation.
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 5, 6)
  - **Blocks**: Task 10
  - **Blocked By**: Tasks 1, 2

  **References**:

  **Pattern References**:
  - `middleman/src/middleman/observability/constants.py` (from Task 2) — Metric name constants and tag key constants to import
  - `middleman/src/middleman/observability/filters.py` (from Task 2) — `sanitize_model_tag()` function to sanitize model names in tags

  **External References**:
  - DogStatsD Python client: https://docs.datadoghq.com/developers/dogstatsd/?tab=python

  **WHY Each Reference Matters**:
  - `constants.py` — Metric names MUST match the dashboard queries (Task 4). Using constants ensures consistency.
  - `filters.py` — Every metric tag with a model name MUST go through `sanitize_model_tag()` to prevent `danger_name` leaks.

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: Metrics module imports and functions callable
    Tool: Bash
    Preconditions: Tasks 1, 2 complete
    Steps:
      1. Run `python -c "from middleman.observability.metrics import record_request, record_request_duration, record_upstream_duration, record_cache_result; print('All metrics functions available')"` from middleman/src/
    Expected Result: Import succeeds, prints confirmation
    Failure Indicators: ImportError, NameError
    Evidence: .sisyphus/evidence/task-7-metrics-import.txt

  Scenario: Metric tags never contain danger_name
    Tool: Bash
    Preconditions: Module code written
    Steps:
      1. Read middleman/src/middleman/observability/metrics.py
      2. Search for any direct use of `danger_name` in tag formatting
      3. Verify all model tags go through `sanitize_model_tag()`
    Expected Result: Zero direct danger_name references in tag values
    Failure Indicators: danger_name used directly in tags
    Evidence: .sisyphus/evidence/task-7-no-danger-name.txt
  ```

  **Commit**: YES
  - Message: `feat(middleman): add DogStatsD metrics helper module`
  - Files: `middleman/src/middleman/observability/metrics.py`

- [ ] 8. Instrument request.py + passthrough.py — structlog + custom upstream spans

  **What to do**:
  - **request.py** changes:
    - Replace `import logging; logger = logging.getLogger(__name__)` with `from middleman.observability.logging import get_logger; logger = get_logger(__name__)`
    - In `_single_post()` (line 98 area): Wrap the `session.post()` call with a custom ddtrace span:
      ```python
      from ddtrace import tracer
      with tracer.trace("upstream.request", service="middleman", resource=url) as span:
          span.set_tag("provider", provider_name)  # passed as parameter
          span.set_tag("model", public_name)  # MUST be public_name, never danger_name
          span.set_tag("http.method", "POST")
          response = await session.post(url, json=body, headers=headers, timeout=timeout)
          span.set_tag("http.status_code", response.status)
      ```
    - Add `provider_name` and `public_name` parameters to `_single_post()` and `do_post_request()` signatures so the span can be tagged. These values come from the caller (lab_apis/base.py or passthrough handlers).
    - Update all callers of `do_post_request()` to pass provider/model info
  - **passthrough.py** changes:
    - Replace stdlib logging with structlog (same pattern)
    - In `make_post_request()` (line 82 area): Wrap `session.post()` with a custom span:
      ```python
      with tracer.trace("upstream.passthrough", service="middleman", resource=url) as span:
          span.set_tag("provider", provider_name)
          span.set_tag("model", public_name)  # from model_config
          response = await session.post(url, json=body, headers=headers)
          span.set_tag("http.status_code", response.status)
      ```
    - **CRITICAL**: Only instrument the initial `session.post()` call. Do NOT try to wrap the `StreamingResponse` body or async generator. The span captures time-to-first-byte (TTFB) from the provider, which is the meaningful latency metric.
    - In `_handle_anthropic_request()` (line 113+): Ensure the model tag uses `public_name`, NOT `danger_name`. The passthrough handler has access to the model config — use `model_config.public_name`.
    - Apply the same pattern to `handle_gemini_*()` and `handle_openai_*()` functions.
    - Log key events with structlog: request start (provider, model, endpoint), request complete (status, duration), errors

  **Must NOT do**:
  - Do NOT wrap StreamingResponse body in a span (async generator, span would close prematurely)
  - Do NOT tag spans with `danger_name` — always use `public_name`
  - Do NOT change the function signatures in ways that break existing callers (add new params with defaults)
  - Do NOT refactor error handling logic
  - Do NOT modify the response body or headers
  - Do NOT add middleware — use inline span creation

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: Requires understanding async Python, aiohttp session.post patterns, ddtrace span lifecycle, and the critical distinction between danger_name and public_name. Must NOT break streaming responses.
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 9, 10, 11)
  - **Blocks**: F1-F4
  - **Blocked By**: Tasks 5, 6, 2

  **References**:

  **Pattern References**:
  - `middleman/src/middleman/request.py:79-126` — `do_post_request()` and `_single_post()`. The span wraps line 98 (`session.post()`). This is the unified path for all lab API calls.
  - `middleman/src/middleman/passthrough.py:72-95` — `make_post_request()`. The span wraps line 82 (`session.post()`). This is the passthrough path.
  - `middleman/src/middleman/passthrough.py:113-180` — `_handle_anthropic_request()`. Shows how model_config is available (line 125-135 area). Use `model_config.public_name` for span tags.
  - `middleman/src/middleman/passthrough.py:200-280` — `handle_openai_*` functions. Same pattern as Anthropic.
  - `middleman/src/middleman/lab_apis/base.py:33-71` — `get_model_outputs()` calls `do_post_request()`. This is where provider/model info needs to be passed through.
  - `middleman/src/middleman/models.py` — `MiddlemanModel` with `public_name` and `danger_name` fields.

  **WHY Each Reference Matters**:
  - `request.py:98` — This is the SINGLE MOST IMPORTANT line to instrument. It's where ALL unified API calls hit the upstream provider. Missing this = no latency breakdown.
  - `passthrough.py:82` — Second most important. All passthrough API calls go through here.
  - `passthrough.py:113-180` — Shows how to access `model_config.public_name` in the context of a passthrough handler. The executor MUST use public_name, not danger_name.

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: Custom spans use public_name, never danger_name
    Tool: Bash
    Preconditions: Code modified
    Steps:
      1. Search for `danger_name` in request.py and passthrough.py
      2. Verify zero occurrences of `danger_name` in span.set_tag() calls
      3. Verify all model tags use `public_name` or `sanitize_model_tag()`
    Expected Result: Zero danger_name references in span tags
    Failure Indicators: danger_name found in span tag code
    Evidence: .sisyphus/evidence/task-8-no-danger-name.txt

  Scenario: No span wraps streaming response body
    Tool: Bash
    Preconditions: Code modified
    Steps:
      1. Search for `tracer.trace` in passthrough.py
      2. Verify spans only wrap `session.post()` calls, NOT StreamingResponse generators
      3. Verify no span context is passed into `iter_any()` or similar async generators
    Expected Result: Spans are scoped to session.post() only
    Failure Indicators: Span wrapping async generator, span in StreamingResponse
    Evidence: .sisyphus/evidence/task-8-no-streaming-span.txt

  Scenario: structlog replaces stdlib logging
    Tool: Bash
    Preconditions: Code modified
    Steps:
      1. Search for `import logging` and `logging.getLogger` in request.py and passthrough.py
      2. Verify they are replaced with structlog imports
    Expected Result: Zero stdlib logging imports remain
    Failure Indicators: stdlib logging still used
    Evidence: .sisyphus/evidence/task-8-structlog-migration.txt
  ```

  **Commit**: YES
  - Message: `feat(middleman): add custom spans for upstream API calls in request and passthrough`
  - Files: `middleman/src/middleman/request.py`, `middleman/src/middleman/passthrough.py`

- [ ] 9. Instrument auth.py + cache.py — structlog + custom spans

  **What to do**:
  - **auth.py** changes:
    - Replace stdlib logging with structlog
    - Wrap `get_user_info()` (line 83-136) with a custom span:
      ```python
      with tracer.trace("auth.validate_token", service="middleman") as span:
          # existing JWT validation logic
          span.set_tag("auth.issuer", issuer)
          span.set_tag("auth.user_id", user_id)  # after successful validation
      ```
    - Do NOT put the JWT token value or any credential in span tags
    - Log: auth success (user_id, issuer), auth failure (reason, issuer)
  - **cache.py** changes:
    - Replace stdlib logging with structlog
    - Wrap `cache.get()` (line ~28) with a custom span:
      ```python
      with tracer.trace("cache.lookup", service="middleman") as span:
          result = self._cache.get(key, default=MISSING)
          span.set_tag("cache.hit", result is not MISSING)
      ```
    - Do NOT span `cache.set()` when called via `asyncio.create_task()` — it's detached from the trace context and would create orphan spans. Only span `cache.set()` if called synchronously.
    - Log: cache hit/miss (key hash, not full key — key may contain sensitive data)

  **Must NOT do**:
  - Do NOT put JWT tokens, API keys, or credentials in span tags or logs
  - Do NOT span `asyncio.create_task(cache.set(...))` (detached context — orphan spans)
  - Do NOT change auth validation logic
  - Do NOT change cache eviction or size behavior

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Smaller scope (2 files), straightforward span additions. Auth and cache are simpler than the upstream call instrumentation.
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 8, 10, 11)
  - **Blocks**: F1-F4
  - **Blocked By**: Tasks 5, 6, 2

  **References**:

  **Pattern References**:
  - `middleman/src/middleman/auth.py:83-136` — `get_user_info()` function. The span wraps the entire function body.
  - `middleman/src/middleman/cache.py:26-35` — `get()` and `set()` methods. Only span `get()`. For `set()`, check if it's called directly or via `asyncio.create_task`.
  - `middleman/src/middleman/server.py:257` — `asyncio.create_task(cache.set(...))` — This is the fire-and-forget pattern. Do NOT try to span this.

  **WHY Each Reference Matters**:
  - `auth.py:83-136` — The auth span helps answer "how much time does JWT validation add?" Important for latency breakdown.
  - `server.py:257` — Shows the detached cache.set() call. The executor MUST NOT try to span this.

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: Auth span does not leak credentials
    Tool: Bash
    Preconditions: Code modified
    Steps:
      1. Search for span.set_tag in auth.py
      2. Verify no tag contains "token", "jwt", "key", "secret", "authorization"
      3. Verify only safe tags: user_id, issuer
    Expected Result: Zero credential values in span tags
    Failure Indicators: Token or key values in tags
    Evidence: .sisyphus/evidence/task-9-auth-no-creds.txt

  Scenario: cache.set via create_task is NOT spanned
    Tool: Bash
    Preconditions: Code modified
    Steps:
      1. Read cache.py
      2. Verify tracer.trace only wraps cache.get, not cache.set
      3. Verify server.py asyncio.create_task(cache.set(...)) is unchanged
    Expected Result: No span on cache.set
    Failure Indicators: Span wrapping cache.set
    Evidence: .sisyphus/evidence/task-9-no-cache-set-span.txt
  ```

  **Commit**: YES
  - Message: `feat(middleman): add custom spans for auth and cache operations`
  - Files: `middleman/src/middleman/auth.py`, `middleman/src/middleman/cache.py`

- [ ] 10. Instrument server.py + apis.py — structlog + metrics emission

  **What to do**:
  - **server.py** changes:
    - Replace stdlib logging with structlog (all `logger.*` calls)
    - Call `configure_structlog()` early in module initialization (before app creation)
    - Add DogStatsD metrics emission at key points:
      - After successful completions: `record_request(provider, public_name, status_code, user_id, endpoint)`
      - After completions: `record_request_duration(total_ms, provider, public_name, endpoint)`
      - After errors: `record_error(provider, public_name, error_type, status_code)`
    - In passthrough route handlers: `record_request()` and `record_request_duration()` around the handler
    - Import metrics functions from `observability.metrics`
    - Log route entry/exit with structlog (provider, model, user_id, request_id, duration)
  - **apis.py** changes:
    - Replace stdlib logging with structlog
    - Add timing measurements around `get_completions_internal()`:
      - Start timer at function entry
      - Record total duration and upstream duration at function exit
      - Call `record_upstream_duration()` after the provider call returns
    - Log: completion request details (provider, model count, cache hit), completion results (token counts, duration)

  **Must NOT do**:
  - Do NOT log request or response bodies (prompts, completions)
  - Do NOT use `danger_name` in any metric tag — use `public_name` via `sanitize_model_tag()`
  - Do NOT change error handling logic or response format
  - Do NOT change the /health endpoint

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Touches the main server and API orchestration files. Needs to integrate structlog, ddtrace, and DogStatsD metrics without breaking routing or error handling.
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 8, 9, 11)
  - **Blocks**: F1-F4
  - **Blocked By**: Tasks 5, 6, 7

  **References**:

  **Pattern References**:
  - `middleman/src/middleman/server.py:131-510` — All route handlers. Each needs structlog + metrics.
  - `middleman/src/middleman/server.py:232-257` — `get_completions_internal()` wrapper with cache check and token counting. Good place for timing and metrics.
  - `middleman/src/middleman/apis.py:506-578` — `get_completions_internal()` with provider dispatch. Add timing here for upstream vs total duration.
  - `middleman/src/middleman/observability/metrics.py` (from Task 7) — Import `record_request`, `record_request_duration`, `record_upstream_duration`, `record_error`

  **WHY Each Reference Matters**:
  - `server.py:131-510` — These are ALL the routes. Each route handler needs metrics emission at entry/exit.
  - `apis.py:506-578` — This is where "middleman processing time" vs "upstream time" can be measured. The timer around `cls.get_model_outputs()` gives upstream duration.

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: All logging uses structlog in server.py
    Tool: Bash
    Preconditions: Code modified
    Steps:
      1. Search server.py for `import logging` and `logging.getLogger`
      2. Verify replaced with structlog imports
      3. Verify `configure_structlog()` is called before app creation
    Expected Result: Zero stdlib logging, structlog configured
    Failure Indicators: stdlib logging remains
    Evidence: .sisyphus/evidence/task-10-structlog-server.txt

  Scenario: Metrics use public_name only
    Tool: Bash
    Preconditions: Code modified
    Steps:
      1. Search server.py and apis.py for `record_request`, `record_error`, etc.
      2. Verify model parameter always comes from public_name or sanitize_model_tag()
      3. Verify no danger_name in any metrics call
    Expected Result: All metrics use sanitized model names
    Failure Indicators: danger_name used in metrics calls
    Evidence: .sisyphus/evidence/task-10-metrics-safety.txt
  ```

  **Commit**: YES
  - Message: `feat(middleman): instrument server and apis with structlog and DogStatsD metrics`
  - Files: `middleman/src/middleman/server.py`, `middleman/src/middleman/apis.py`

- [ ] 11. Instrument remaining modules — structlog only

  **What to do**:
  - Replace stdlib logging with structlog in ALL remaining modules that use `logging.getLogger`:
    - `middleman/src/middleman/lab_apis/open_ai.py`
    - `middleman/src/middleman/lab_apis/anthropic_api.py`
    - `middleman/src/middleman/lab_apis/google_gemini.py`
    - `middleman/src/middleman/lab_apis/base.py`
    - `middleman/src/middleman/models.py`
    - Any other files with `import logging` / `logging.getLogger`
  - For each file:
    - Replace `import logging; logger = logging.getLogger(__name__)` with `from middleman.observability.logging import get_logger; logger = get_logger(__name__)`
    - Verify all `logger.*` calls still work (structlog's bound logger has the same method names: info, warning, error, debug, exception)
    - If any log call uses stdlib-specific features (like `extra={}` or `exc_info=True`), adapt to structlog equivalent

  **Must NOT do**:
  - Do NOT add custom spans in these modules (spans are only for the 4 critical points in Tasks 8-9)
  - Do NOT add DogStatsD metrics in these modules (metrics are added in Task 10)
  - Do NOT change any business logic
  - Do NOT log sensitive data (model internals, API keys)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Mechanical replacement across multiple files. Same pattern repeated. No business logic changes.
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 8, 9, 10)
  - **Blocks**: F1-F4
  - **Blocked By**: Task 5

  **References**:

  **Pattern References**:
  - `middleman/src/middleman/observability/logging.py` (from Task 5) — `get_logger()` function to use
  - Any module already converted in Tasks 8-10 (request.py, passthrough.py, auth.py, cache.py, server.py, apis.py) — Follow the same import pattern

  **WHY Each Reference Matters**:
  - `logging.py:get_logger()` — This is the ONLY function to use for creating loggers. It ensures consistent configuration.

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: Zero stdlib logging remains in middleman/src/
    Tool: Bash
    Preconditions: All modules converted
    Steps:
      1. Run `grep -r "import logging" middleman/src/middleman/ --include="*.py" | grep -v observability | grep -v __pycache__`
      2. Run `grep -r "logging.getLogger" middleman/src/middleman/ --include="*.py" | grep -v observability | grep -v __pycache__`
    Expected Result: Zero matches (all converted to structlog)
    Failure Indicators: Any remaining stdlib logging imports
    Evidence: .sisyphus/evidence/task-11-no-stdlib-logging.txt

  Scenario: All modules import from observability.logging
    Tool: Bash
    Preconditions: All modules converted
    Steps:
      1. Run `grep -r "from middleman.observability.logging import" middleman/src/middleman/ --include="*.py" | grep -v __pycache__`
      2. Count matches — should be >= 10 (all modules that previously used logging)
    Expected Result: All logging modules use observability.logging
    Failure Indicators: Fewer imports than expected
    Evidence: .sisyphus/evidence/task-11-structlog-imports.txt
  ```

  **Commit**: YES
  - Message: `feat(middleman): switch remaining modules to structlog`
  - Files: `middleman/src/middleman/lab_apis/*.py`, `middleman/src/middleman/models.py`, and other files with stdlib logging

- [ ] 12. Create Middleman Datadog monitors/alerts in Pulumi

  **What to do**:
  - Create `infra/datadog/middleman_monitors.py` as a new Pulumi ComponentResource
  - Follow the existing pattern in `infra/datadog/monitors.py` — use `pulumi_datadog.Monitor`
  - Define monitors:
    - **Error Rate Spike**: Alert when middleman error rate (5xx responses / total requests) exceeds 5% over 5 minutes. Tags: `service:middleman`.
    - **P95 Latency Threshold**: Alert when P95 request latency exceeds 30s (configurable) over 5 minutes. Note: 30s is generous because of reasoning models (o1/o3). A separate monitor for non-reasoning models at 10s may be useful.
    - **Provider Outage**: Alert when a single provider's error rate exceeds 50% over 5 minutes (indicates provider-side issue, not middleman). Group by provider tag.
    - **Service Down**: Alert when zero requests received for 10 minutes (service health).
    - **High Memory Usage**: Alert when container memory exceeds 80% of limit (early warning for OOM).
  - Each monitor should have:
    - Name: `[Middleman] {description}`
    - Message: Include `@slack-{channel}` or `@pagerduty-{service}` notification (use a variable/config for notification target)
    - Tags: `service:middleman`, `team:platform`, `env:${env}`
    - Priority: P2 for most, P1 for service down
  - Register component in `infra/datadog/__init__.py`
  - Only create monitors for stg/prd stacks (not dev) — follow existing pattern

  **Must NOT do**:
  - Do NOT create monitors for Hawk or other services
  - Do NOT use `danger_name` in any monitor query
  - Do NOT hardcode notification targets (use config)

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Requires understanding Datadog monitor query syntax, alert conditions, and the existing Pulumi monitor pattern.
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (can run alongside Wave 3)
  - **Parallel Group**: Wave 4
  - **Blocks**: F1-F4
  - **Blocked By**: Task 2 (for metric name constants)

  **References**:

  **Pattern References**:
  - `infra/datadog/monitors.py` — Existing monitor definitions using `pulumi_datadog.Monitor`. Follow this pattern EXACTLY.
  - `infra/datadog/__init__.py` — Registration of monitor components.

  **External References**:
  - Datadog Monitor API: https://docs.datadoghq.com/api/latest/monitors/
  - Pulumi Datadog Monitor: https://www.pulumi.com/registry/packages/datadog/api-docs/monitor/

  **WHY Each Reference Matters**:
  - `monitors.py` — The AUTHORITATIVE pattern for monitor definitions in this repo. Don't invent a new pattern.

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: Monitor Pulumi resources create without errors
    Tool: Bash
    Preconditions: Pulumi stack selected
    Steps:
      1. Run `pulumi preview --diff` targeting the datadog stack
      2. Verify new Monitor resources appear for: error rate, latency, provider outage, service down, memory
      3. Verify each monitor has name, message, query, type fields
    Expected Result: Preview succeeds, 5 monitor resources present
    Failure Indicators: Pulumi error, missing monitors, invalid query syntax
    Evidence: .sisyphus/evidence/task-12-monitors-preview.txt

  Scenario: Monitor queries use correct metric names and service filter
    Tool: Bash
    Preconditions: Monitor code written
    Steps:
      1. Read monitor queries
      2. Verify all reference `service:middleman`
      3. Verify no `danger_name` in any query
      4. Verify metric names match constants from Task 2
    Expected Result: Correct queries, no sensitive data
    Failure Indicators: Wrong metric names, missing service filter
    Evidence: .sisyphus/evidence/task-12-monitor-queries.txt
  ```

  **Commit**: YES
  - Message: `feat(infra): add Middleman Datadog monitors and alerts`
  - Files: `infra/datadog/middleman_monitors.py`, `infra/datadog/__init__.py`

---

## Final Verification Wave (MANDATORY — after ALL implementation tasks)

> 4 review agents run in PARALLEL. ALL must APPROVE. Rejection → fix → re-run.

- [ ] F1. **Plan Compliance Audit** — `oracle`
  Read the plan end-to-end. For each "Must Have": verify implementation exists (read file, curl endpoint, run command). For each "Must NOT Have": search codebase for forbidden patterns (`danger_name` in span tags, `DD_TRACE_HEADER_TAGS`, etc.) — reject with file:line if found. Check evidence files exist in .sisyphus/evidence/. Compare deliverables against plan.
  Output: `Must Have [N/N] | Must NOT Have [N/N] | Tasks [N/N] | VERDICT: APPROVE/REJECT`

- [ ] F2. **Code Quality Review** — `unspecified-high`
  Run linter + type checker on middleman/. Review all changed files for: `as any`/`# type: ignore`, empty except blocks, print() in prod, commented-out code, unused imports. Check AI slop: excessive comments, over-abstraction, generic variable names. Verify ddtrace initialization order (before Sentry). Verify structlog processors are correctly chained. Verify no `danger_name` leaks in any instrumentation code.
  Output: `Lint [PASS/FAIL] | Types [PASS/FAIL] | Files [N clean/N issues] | VERDICT`

- [ ] F3. **Real QA** — `unspecified-high`
  Requires deployment to a dev environment. Execute EVERY QA scenario from EVERY task. Verify: (1) ECS task healthy with 3 containers, (2) APM traces in Datadog, (3) structured logs with trace IDs, (4) custom metrics in Metrics Explorer, (5) dashboard loads with data, (6) monitors in OK state, (7) Sentry still captures errors, (8) NO danger_name/body/key in any Datadog data. Save evidence to `.sisyphus/evidence/final-qa/`.
  Output: `Scenarios [N/N pass] | Integration [N/N] | Sensitivity [PASS/FAIL] | VERDICT`

- [ ] F4. **Scope Fidelity Check** — `deep`
  For each task: read "What to do", read actual diff (git log/diff). Verify 1:1 — everything in spec was built, nothing beyond spec was built. Check "Must NOT" compliance. Detect cross-task file contamination. Flag unaccounted changes. Verify no autoscaling, no OTel, no extra middleware, no streaming body spans, no cache.set spans.
  Output: `Tasks [N/N compliant] | Contamination [CLEAN/N issues] | Unaccounted [CLEAN/N files] | VERDICT`

---

## Commit Strategy

- **Wave 1**: `feat(middleman): add ddtrace, structlog, datadog dependencies` — pyproject.toml
- **Wave 1**: `feat(middleman): add observability config module with sensitivity filtering` — middleman/src/middleman/observability/
- **Wave 1**: `feat(infra): add Datadog Agent + Firelens sidecars to Middleman ECS task` — infra/core/middleman.py
- **Wave 1**: `feat(infra): add Middleman Datadog dashboard` — infra/datadog/
- **Wave 2**: `feat(middleman): configure structlog with JSON output and trace injection` — middleman/src/middleman/observability/
- **Wave 2**: `feat(middleman): initialize ddtrace APM with sample rates` — Dockerfile, server.py
- **Wave 2**: `feat(middleman): add DogStatsD metrics helper` — middleman/src/middleman/observability/
- **Wave 3**: `feat(middleman): add custom spans for upstream API calls` — request.py, passthrough.py
- **Wave 3**: `feat(middleman): add custom spans for auth and cache` — auth.py, cache.py
- **Wave 3**: `feat(middleman): instrument server and apis with structlog and metrics` — server.py, apis.py
- **Wave 3**: `feat(middleman): switch remaining modules to structlog` — lab_apis/, models.py, etc.
- **Wave 4**: `feat(infra): add Middleman Datadog monitors and alerts` — infra/datadog/

---

## Success Criteria

### Verification Commands
```bash
# ECS task healthy with 3 containers
aws ecs describe-tasks --cluster $CLUSTER --tasks $TASK_ARN \
  --query 'tasks[0].containers[*].[name,lastStatus]' --output table
# Expected: middleman RUNNING, datadog-agent RUNNING, log_router RUNNING

# Health check passes
curl -sf https://middleman-ecs.$DOMAIN/health
# Expected: 200 OK

# APM traces exist (Datadog API)
curl -s "https://api.us3.datadoghq.com/api/v2/spans/events/search" \
  -H "DD-API-KEY: $DD_API_KEY" -H "DD-APPLICATION-KEY: $DD_APP_KEY" \
  -d '{"filter":{"query":"service:middleman","from":"now-1h","to":"now"}}'
# Expected: spans returned with service:middleman

# Structured logs with trace correlation
# In Datadog Log Explorer: service:middleman → verify dd.trace_id field present

# Sentry still works
curl -X POST https://middleman-ecs.$DOMAIN/throw_error
# Expected: 500 error captured in Sentry (verify via Sentry API)

# No sensitive data
# Search Datadog traces for danger_name → Expected: 0 results
```

### Final Checklist
- [ ] All "Must Have" present
- [ ] All "Must NOT Have" absent
- [ ] ECS task stable for 30+ minutes with no restarts
- [ ] APM traces show latency breakdown (middleware vs upstream)
- [ ] Logs correlated with traces via dd.trace_id
- [ ] Custom metrics in Datadog Metrics Explorer
- [ ] Dashboard loads with data
- [ ] Monitors in OK state
- [ ] Sentry error capture preserved
