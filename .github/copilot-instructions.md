# Copilot instructions for this repository

## Project context

- This repo contains a Python TCP latency client in `client/` and server setup
  scripts in `server/`.
- Favor minimal, practical changes over architectural rewrites.

## Implementation expectations

- Preserve CLI behavior and output format unless explicitly requested.
- Keep timing/math logic precise and avoid hidden defaults.
- Do not swallow exceptions; surface actionable errors clearly.
- Update `README.md` when user-facing behavior changes.

## Style and conventions

- Follow existing Python style in `client/echo_client.py`.
- Keep shell scripts POSIX-friendly unless the file already requires Bash-only
  features.
- Avoid introducing new dependencies unless necessary.

## Validation guidance

- For client changes, run a short local invocation (finite `--count`) to verify
  output and exit behavior.
- For server script changes, keep operations explicit and idempotent where
  possible.
