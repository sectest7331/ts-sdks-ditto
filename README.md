# ts-sdks-ditto — ActionsTrail PoC mirror

**This is a research test repository, not a real package source.**

It mirrors the workflow chain in [MystenLabs/ts-sdks @ e81f0bf](https://github.com/MystenLabs/ts-sdks/tree/e81f0bf483c54e45d905224f5267ce5fa136c261/.github/workflows) for the purpose of empirically verifying the supply-chain RCE chain documented in `actionstrail/bounty-reports/mystenlabs-ts-sdks-supply-chain-rce.md`.

## Safety modifications vs. upstream

- Package scope renamed `@mysten/sui` → `@sectest7331-ditto/sui` to keep the real `@mysten/*` npm namespace fully untouched.
- `_release-package.yml` Publish step hardcoded to `--dry-run` regardless of `DRY_RUN` input.
- Removed the `environment: sui-typescript-aws-kms-test-env` deployment gate and AWS/GCP KMS env vars (gated false anyway, but cleaner without).
- `pnpm install` runs without `--frozen-lockfile` (no committed lockfile in this minimal ditto).
- Removed `pnpm audit` and `pnpm manypkg check` steps from Turborepo CI — orthogonal to the studied chain.

Attack chain identity vs. upstream is preserved end-to-end (`workflow_run.branches:[main]` filter, `workflow_run.head_sha` pass-through, ref forwarding to `_release-package.yml`, attacker-controlled `pnpm run build`, OIDC `id-token: write` on publish step).
