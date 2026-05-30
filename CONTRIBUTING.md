# Contributing

Thanks for your interest in improving Echo Test.

## Getting started

1. Fork the repository and create a branch from `main`.
2. Make focused changes with clear commit messages.
3. Run the client script locally to confirm behavior:

```bash
python3 client/echo_client.py 127.0.0.1 7 --count 3
```

4. Open a pull request using the provided template.

## Development guidelines

- Keep changes scoped and avoid unrelated refactors.
- Update documentation when behavior or usage changes.
- Add or update tests when introducing logic changes.
- Prefer explicit errors over silent failures.

## Pull request checklist

- [ ] Code follows existing project style and structure
- [ ] Documentation is updated (README, examples, or scripts docs)
- [ ] Local verification is complete
- [ ] PR description explains what changed and why
