# slackbuilds

Personal SlackBuilds, targeting the Slackware 15.0 branch.

## Packages

- **age/**: installs the official static `age`
  release tarball: `age`, `age-keygen`, `age-inspect` and the
  `age-plugin-*` helpers. No compiler/Go toolchain needed, x86_64 only.
- **sops/**: installs the official static `sops`
  binary. No compiler/Go toolchain needed, x86_64 only.

Each package directory holds the standard SBo file set:
`$PRGNAM.SlackBuild`, `$PRGNAM.info`, `slack-desc`, `README`.

https://slackbuilds.org/repository/15.0/development/age/

https://slackbuilds.org/repository/15.0/development/sops

## Usage

Requires GNU make and Docker. Every target except `help` and `clean` runs
inside a Slackware 15.0 container (`linux/amd64`, emulated on arm64
hosts) with the repo mounted on `/mnt`. Run `make help` for the full list.

| Target | What it does | Image |
|--------|--------------|-------|
| `download PKG=<name>` | fetches the `.info` downloads into `<name>/` and checks their MD5SUM | `aclemons/slackware:15.0` |
| `package PKG=<name>` | builds `dist/<name>.tar.gz` for submission, downloads excluded | `aclemons/slackware:15.0` |
| `try PKG=<name> [RUN="<cmd>"]` | builds, installs and runs the package (default `RUN`: `<name> --version`) in a throwaway container | `aclemons/slackware:15.0` |
| `build PKG=<name>` | runs the SlackBuild, writing the package to `dist/` | `aclemons/sbo-maintainer-tools` |
| `lint PKG=<name>` | `sbolint` on `dist/<name>.tar.gz`, `sbopkglint` on the built package | `aclemons/sbo-maintainer-tools` |
| `package_all`, `lint_all` | `package` / `lint` for every package | |
| `clean` | removes `dist/` and the downloaded files | host |

Notes:

- The slackware image has no CA certificates, so `download` mounts the
  host's bundle; set `CA_BUNDLE=<path>` if it isn't found.
- `build` and `lint` use the sbo-maintainer-tools image because the
  slackware one has no `strip`; `try` packages unstripped binaries, so
  it is a smoke test only.
- Downloads stay in the package directory, where the SlackBuild reads
  them; `make clean` removes them.
- Containers run as root: on Linux hosts, `dist/` and downloads end up
  root-owned.

## Submission Guidelines (slackbuilds.org)

Before submitting/updating a build on SBo:

- Run `sbolint` and `sbopkglint` (from `sbo-maintainer-tools`) on the
  script and the built package — catches rejection-causing issues
  before you submit (`make lint PKG=<name>`).
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
