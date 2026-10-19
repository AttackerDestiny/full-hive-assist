# BSS project instructions

- Do not spawn or use subagents.
- After every completed script change, rebuild the standalone bundle, run the relevant validation/regression checks, and re-execute the tested update on the connected client using the existing safe deployment procedure. Preserve unresolved request flags and never retry an uncertain spend.
- The user explicitly authorized publishing every script update to the existing GitHub repository, `https://github.com/AttackerDestiny/full-hive-assist.git`. Commit the completed source, generated bundle, related tests and documentation, then push to the current intended branch on `origin`. Verify that the remote branch contains the commit before reporting success. Do not force-push or overwrite unrelated work.
- Keep the existing recurring monitor's instructions consistent with this publishing requirement. If GitHub is unavailable, preserve the local commit and report the failed push; do not report the update as published.
