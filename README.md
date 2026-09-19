# slackbuilds

Personal SlackBuilds, targeting the Slackware 15.0 branch.

## Packages

- **sops/** *(work in progress)* — installs the official static `sops`
  binary. No compiler/Go toolchain needed, x86_64 only.

Each package directory holds the standard SBo file set:
`$PRGNAM.SlackBuild`, `$PRGNAM.info`, `slack-desc`, `README`.

## Submission Guidelines (slackbuilds.org)

Before submitting/updating a build on SBo:

- Run `sbolint` and `sbopkglint` (from `sbo-maintainer-tools`) on the
  script and the built package — catches rejection-causing issues
  before you submit.
- Build and test on a full Slackware install of the target branch,
  latest patches applied.
- Check the repo, pending and ready queues for duplicates first.
- Submit as a tar archive via the `/submit/` form containing only
  `$PRGNAM.SlackBuild`, `.info`, `slack-desc`, `README` (+ patches if
  any) — **no source code**.
- For updates to an existing package, contact the current maintainer
  via the `.info` file first; if unresponsive, escalate to the
  mailing list. Unmaintained builds can be adopted.

Source: https://slackbuilds.org/guidelines/ and https://slackbuilds.org/faq/
