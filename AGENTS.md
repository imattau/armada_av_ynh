# AGENTS.md

Notes for an AI (or human) picking up this package again. This is
tribal knowledge that bit us while building and testing it - none of it
is derivable just by reading the scripts, so don't rediscover it the hard
way.

## What this actually is

Two systemd services, no Docker: `armada_av-broker` (Bun/TypeScript,
CORD-07's blind token broker) and `armada_av-livekit` (a LiveKit SFU
binary). YunoHost's own Nginx/certs replace upstream's bundled Caddy.
`scripts/_common.sh` centralizes the paths and the pinned-source fetch
logic both scripts share.

## Version pinning is coupled across three things

`manifest.toml`'s Bun and LiveKit pins, and `scripts/_common.sh`'s
`ARMADA_AV_COMMIT`, aren't independent. The armada client's own
`AGENTS.md` warns that `livekit-client` (npm) and the LiveKit **server**
image must be bumped together - protocol skew makes clients full-reconnect
every ~16s otherwise. So: when bumping `ARMADA_AV_COMMIT`, check what
`livekit-client` version that commit's `package.json` depends on, and bump
`resources.sources.livekit` to a matching/newer LiveKit release - not just
"whatever's latest." The Bun pin should track armada-av's own Dockerfile
(`oven/bun:1.X-slim`), not the newest Bun release.

## armada-av has no tarball release - it's a git clone, not a source resource

`relay.ngit.dev` (an ngit/GRASP host, not GitHub/GitLab) serves git's smart
HTTP protocol but no `/archive/<ref>.tar.gz` endpoint - checked, confirmed
404. So unlike Bun/LiveKit (real sha256-pinned tarballs via
`resources.sources`), armada-av is fetched with a plain `git clone` +
pinned commit checkout in `armada_av_fetch_broker_source()`. The commit
hash is the integrity check here, playing the sha256's role. If you ever
need the clone URL again: `https://relay.ngit.dev/<npub>/armada-av.git`
(note the required `.git` suffix - without it the GRASP server 404s).
The npub is derived from `chad@chadwick.site`'s NIP-05; don't recompute it
from scratch, it's already in `_common.sh`.

## `ynh_config_add` does a blind text substitution - even inside comments

`_ynh_replace_vars` (helpers.v2.1.d/templating) regex-matches every
`__FOO__`-shaped token in a template file and dies with `ynh_die` if `$foo`
isn't a defined bash variable - it does not know or care whether the token
is inside a comment. This app has no `install.path` question (it's
domain-root-only, see below), so `$path` is never set. **Never write the
literal string `__PATH__` anywhere in `conf/*`, including prose comments**
- it will abort every install. Learned this the hard way in `nginx.conf`.

## `ynh_config_remove_systemd` takes a positional arg, not `--service=`

Every other systemd/nginx helper here (`ynh_config_add_systemd`,
`ynh_systemctl`) uses named `--service=` getopts args. The remove
counterpart doesn't: `ynh_config_remove_systemd "$app-broker"`, not
`ynh_config_remove_systemd --service="$app-broker"` (the latter silently
does nothing useful - it's `local service="${1:-$app}"`, so a `--service=`
flag just gets ignored and it falls back to `$app`, which isn't even a real
unit name here). Verified against current YunoHost `dev` HEAD, not just an
older checkout - re-verify with a real `git diff` against upstream if this
file is ever touched again, don't assume the signature is stable forever.

## Both services must be registered with `yunohost service add`

This is easy to forget - `ynh_config_add_systemd` + `ynh_systemctl` are
enough to make the services actually run, but not enough to make them
*visible* to `yunohost service status`, the webadmin Services page, or
diagnosis. Caught this live: `service_status` came back "Unknown service"
on a real test install until `yunohost service add` was added to install/
upgrade/restore (and `yunohost service remove` to remove). The LiveKit
registration also passes `--needs_exposed_ports "$port_rtc_tcp"
"$port_rtc_udp"` so diagnosis can check those are actually reachable -
worth keeping since this app's whole voice-quality story depends on the
UDP one being open.

## The domain must stay a bare origin - don't add an `install.path` question

CORD-07 (§2) signs grants over `PUBLIC_ORIGIN`, which must be a scheme+host
with no path (`config.ts`'s `canonicalOrigin` refuses anything else, and
`_validate_webpath_requirement` in YunoHost core will refuse to co-locate
this app with anything else on the same domain anyway). That's why there's
no `install.path` in `manifest.toml` and no `__PATH__` handling in
`nginx.conf` - this mirrors `quantumrelay_ynh`'s pattern, not an oversight.
Don't "fix" this by adding a path option.

## Cross-file secret consistency is the riskiest thing here - and it's tested

`livekit_api_key`/`livekit_api_secret` are generated once at install
(`ynh_string_random`), stored as app settings, and then templated into
*two* independently-rendered files: `conf/broker.env` (as
`LIVEKIT_API_KEY`/`LIVEKIT_API_SECRET`, what the broker sends) and
`conf/livekit.yaml` (as the `keys:` map, what LiveKit accepts). If a future
edit regenerates one without the other, or changes how either is
serialized, the broker's authenticated LiveKit health-check calls start
failing with 401s - visible in `armada_av-broker`'s journal, not in either
service's own "am I up" status. This was actually verified live during
packaging (the broker's periodic `RoomService.ListRooms` health probe
returning real `200`s, including across a full backup/restore cycle) -
don't remove that check from any future test pass just because both
services report "running."

## Testing this needs a dedicated domain, not the default one

`package_run_tests` (the bundled install→backup→remove→restore→remove
tool) always installs on the environment's default/starred domain, which
is normally already occupied by other apps on a real box (breaks this
app's domain-of-its-own requirement above). Use the individual
`package_install_test(..., args="domain=<free-subdomain>&...")` /
`package_backup_test` / `package_restore_test` / `package_remove_test`
tools instead, and expect to `domain_add` a throwaway subdomain first
(remember to `domain_remove` it after - that one needs owner co-signature,
a different identity from whoever's driving the test).

## Don't trust "install succeeded" - check what actually happened

`package_inspect`'s `requirements.install` check can say "already
installed" even when `apps_list` shows it isn't (seen live, source
unclear - possibly stale). And a clean `app_install` return only proves
the scripts didn't throw, not that the app works. The real verification
that caught both bugs above was hitting the live endpoints after install:
`GET /.well-known/concord/av` → `204`, `GET .../<64-hex-zeros>` → `401`
`{"error":"missing Authorization header"}`, `GET /` → `200 armada-av`,
`GET /rtc` → LiveKit's own `404` (proves it's routed there, not caught by
the nginx catch-all) - plus tailing `armada_av-livekit`'s journal for the
`UDP receive buffer is too small` warning after any host-level sysctl
change, since that's a kernel-level effect this package can't and
shouldn't set itself (see the commit history / conversation that produced
this file for the exact `net.core.rmem_max`/`wmem_max` tuning - it's a
host-wide setting, not something `scripts/install` should touch).
