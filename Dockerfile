ARG PYTHON_BASE=avizdock/ncp-python-base-312-alpine:latest
# Runtime stage: plain upstream python:3.12-alpine -- the same Alpine release and
# CPython the shared base is built FROM, but without its build toolchain, so the
# image does not carry ~450 MB of gcc/binutils/git layers underneath. Override
# with a lean shared runtime base once deploy-ones provides one.
ARG PYTHON_RUNTIME_BASE=python:3.12-alpine
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


FROM ${PYTHON_RUNTIME_BASE}
ENV PYTHONUNBUFFERED=1

# Build toolchain, packaging tools: if PYTHON_RUNTIME_BASE is the shared alpine base it
# carries build-base/git/curl/*-dev, and every base carries pip/setuptools/wheel
# for building; none are needed at runtime (the server runs from /app/.venv), and
# they are the bulk of the image's HIGH findings (binutils, pip's vendored
# msgpack/setuptools).
RUN pkgs="$(apk info -e build-base libffi-dev openssl-dev git curl || true)" \
    && if [ -n "$pkgs" ]; then apk del --no-cache $pkgs; fi \
    && apk upgrade --no-cache \
    && apk add --no-cache ca-certificates \
    && (python -m pip uninstall -y setuptools wheel pip || true) \
    && (id app >/dev/null 2>&1 || (addgroup -g 10001 app && adduser -D -u 10001 -G app app))

COPY --from=builder --chown=app:app /app /app

WORKDIR /app

USER app

ENV PATH="/app/.venv/bin:$PATH"

EXPOSE 8000

CMD ["python", "-u", "server.py"]
