ARG PYTHON_BASE=avizdock/ncp-python-base-312-alpine:latest
FROM ${PYTHON_BASE} AS builder

RUN pip install --no-cache-dir uv

WORKDIR /app

RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    uv sync --locked --no-install-project --no-dev

COPY . /app

RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked --no-dev


FROM ${PYTHON_BASE}
ENV PYTHONUNBUFFERED=1

RUN apk add --no-cache ca-certificates

COPY --from=builder --chown=app:app /app /app

WORKDIR /app

USER app

ENV PATH="/app/.venv/bin:$PATH"

EXPOSE 8000

CMD ["python", "-u", "server.py"]
