# Armada AV, packaged for YunoHost

Blind LiveKit voice/video broker for Armada's Concord communities (CORD-07).

See [doc/DESCRIPTION.md](doc/DESCRIPTION.md) for what this installs and what
to check before installing it.

This package is not yet published to a YunoHost app catalog. Install it
directly from this repository:

```
sudo yunohost app install https://github.com/imattau/armada_av_ynh
```

(adjust the URL if this repo ends up hosted elsewhere, e.g. a `testing`
branch or a local path for development).

## 📦 Developer info

🛠️ Upstream `armada-av` repository (published over Nostr's git protocol, not
GitHub/GitLab): <https://gitworkshop.dev/chad@chadwick.site/relay.ngit.dev/armada-av>

Companion package: [armada_ynh](https://github.com/imattau/armada_ynh)
packages the Armada web client itself; this package is the optional
voice/video backend it can point at.

### 📚 App packaging documentation

Please see <https://doc.yunohost.org/dev/packaging/> for more information.
