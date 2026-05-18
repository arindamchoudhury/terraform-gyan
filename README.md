# Terraform — Reading Notes

A [Zensical](https://zensical.org/) static site built from personal study notes on Terraform and OpenTofu.

## Run with Docker (recommended)

```bash
docker compose up
# open http://localhost:8000
```

`zensical.toml` and `docs/` are bind-mounted, so edits live-reload.

## Run locally with Python

```bash
python -m venv .venv
. .venv/Scripts/Activate.ps1   # macOS/Linux: source .venv/bin/activate
pip install zensical livereload
python serve.py
```

## Adding a new chapter's notes

1. Edit `docs/books/hafner/chapters/<NN>-<slug>.md`.
2. Nav is already wired in `zensical.toml`.
3. Flip the row to ✅ in `docs/books/hafner/index.md`.
4. Update `docs/topics/index.md` backlog with any topics the chapter touches.
5. Add new terms to `docs/reference/glossary.md` (with source attribution).
6. Add useful links to `docs/reference/resources.md`.
