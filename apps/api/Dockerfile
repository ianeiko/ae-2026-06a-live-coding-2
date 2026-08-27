# Built by Cloud Build in issue #2 — nobody runs `docker build` locally.
FROM python:3.12-slim

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

WORKDIR /app

# Dependencies first: this layer is cached unless the lockfile changes.
COPY pyproject.toml uv.lock README.md ./
RUN uv sync --frozen --no-dev --no-install-project

COPY src ./src
RUN uv sync --frozen --no-dev

ENV PATH="/app/.venv/bin:$PATH" \
    PYTHONUNBUFFERED=1

# Cloud Run injects PORT; default matches local runs.
ENV PORT=8000
CMD ["sh", "-c", "uvicorn agent.app:app --host 0.0.0.0 --port ${PORT}"]
