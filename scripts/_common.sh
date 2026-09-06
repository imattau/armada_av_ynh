#!/bin/bash

# Shared constants and helpers for armada_av's YunoHost scripts.

# The upstream armada-av repo lives only on an ngit/GRASP relay (it is
# published over Nostr, not GitHub/GitLab) and exports no downloadable,
# sha256-pinnable release tarball - checked: relay.ngit.dev has no
# /archive/<ref>.tar.gz style endpoint, only git's smart HTTP protocol. So
# unlike the Bun/LiveKit sources (real tarballs, handled by
# resources.sources), this one is fetched with a plain `git clone` + pinned
# commit checkout below. The commit hash - a Merkle hash over the whole
# tree - plays the same integrity role a sha256 would for a tarball.
ARMADA_AV_REPO_URL="https://relay.ngit.dev/npub1scvyzz02ayma34hesz62pdrd5nhsmxp74hjq8msmfs9khh3r3drsnw68d8/armada-av.git"
ARMADA_AV_COMMIT="eeed860f51fcfe675d97e700e3037ae566479ae9"

broker_dir="$install_dir/broker"
bun_bin="$install_dir/bun/bun"
livekit_dir="$install_dir/livekit"
livekit_bin="$livekit_dir/livekit-server"
broker_env_path="$install_dir/broker.env"
livekit_conf_path="$livekit_dir/livekit.yaml"

# Clone the pinned armada-av commit into $broker_dir.
armada_av_fetch_broker_source() {
    ynh_safe_rm "$broker_dir"
    git clone --quiet "$ARMADA_AV_REPO_URL" "$broker_dir"
    git -C "$broker_dir" checkout --quiet "$ARMADA_AV_COMMIT"
    # Not needed at runtime and would otherwise sit inside $install_dir with
    # its own (unmanaged) permissions.
    ynh_safe_rm "$broker_dir/.git"
}

# Install the broker's production dependencies with the pinned Bun runtime.
armada_av_install_broker_deps() {
    pushd "$broker_dir" >/dev/null
    "$bun_bin" install --frozen-lockfile --production
    popd >/dev/null
}
