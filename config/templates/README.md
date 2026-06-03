# config/templates/

One subdirectory per pipeline stage's prompt template per `docs/plugin-spec/06-pipelines.md`. Bootstrap with prompts derived from the spec; never copied from the Python plugin.

Read-only at runtime — operators do not edit these. Pipeline stages load the matching template via `config/pipelines.json:stages`.
