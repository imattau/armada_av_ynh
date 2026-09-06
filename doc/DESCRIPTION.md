# Armada AV for YunoHost

Armada AV is the self-hostable voice/video backend for [Armada](https://armada.buzz/)'s
serverless, end-to-end encrypted "Concord" communities. It implements
CORD-07 §2: a *blind* token broker plus a LiveKit SFU. Clients prove they
hold a Channel's key, get a short-lived LiveKit token, and encrypt media
under keys only members can derive - the broker and SFU forward ciphertext
and learn nothing else (no roster, no membership check, no Nostr relay
connection, no database).

This package installs both pieces on one box: the broker (a small Bun/
TypeScript HTTP service) and one LiveKit node, fronted by YunoHost's own
Nginx and certificates instead of upstream's bundled Caddy.

Point an Armada client at `https://<this domain>` (Settings → Voice) to use
it.

## Before installing

- This app answers unauthenticated requests by design (CORD-07 requires
  it) - it cannot be placed behind YunoHost's SSO portal.
- It needs its own domain (or subdomain): `PUBLIC_ORIGIN` must be a bare
  origin with no path, so this app cannot share a domain at a sub-path with
  another app.
- Two ports are opened directly on the firewall for media and are **not**
  proxied by Nginx: TCP and UDP (defaults 7881/7882). Voice quality depends
  on the UDP one reaching this host; the TCP one is only an ICE fallback for
  networks that block UDP.
- Anyone can call this broker's two endpoints and get handed an SFU seat
  (that is what "blind" means) - abuse is bounded by the rate limit and
  token lifetime chosen at install, and by LiveKit's own per-room
  participant cap, not by an allow-list.

## Upstream

The broker and its LiveKit fleet guidance are maintained in `armada-av`,
which - unlike the Armada client itself - is not on GitHub/GitLab. It's
published over Nostr's git protocol (ngit), browsable at
<https://gitworkshop.dev/chad@chadwick.site/relay.ngit.dev/armada-av> and
clonable from `https://relay.ngit.dev/npub1scvyzz02ayma34hesz62pdrd5nhsmxp74hjq8msmfs9khh3r3drsnw68d8/armada-av.git`.
