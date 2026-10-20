# BSS project instructions

- Latest user correction, October 20, 2026: this existing repository (`AttackerDestiny/full-hive-assist`, branch `main`) is the publishing target. Do not create another repository or publish further changes to `full-hive-assist-standalone`.
- Commit and push every completed change immediately without asking, using `git add`, `git commit`, `git push`. Skip unnecessary status checks, repeated verification, tests, inspections, and verbose explanations; preserve essential checks for affected behavior and safe deployment.
- The recurring monitor runs every 10 minutes. This supersedes older one-minute cadence text. Keep healthy unchanged runs quiet and report meaningful changes or required action.

- Do not spawn or use subagents.
- After every completed script change, rebuild the standalone bundle, run the relevant validation/regression checks, and re-execute the tested update on the connected client using the existing safe deployment procedure. Preserve unresolved request flags and never retry an uncertain spend.
- The user explicitly authorized publishing every script update to the existing GitHub repository, `https://github.com/AttackerDestiny/full-hive-assist.git`. Commit the completed source, generated bundle, related tests and documentation, then push to the current intended branch on `origin`. Verify that the remote branch contains the commit before reporting success. Do not force-push or overwrite unrelated work.
- Keep the existing recurring monitor's instructions consistent with this publishing requirement. If GitHub is unavailable, preserve the local commit and report the failed push; do not report the update as published.
