# Twitcher for Redot

[![Redot 26.2](https://img.shields.io/badge/Redot-26.2-EA4335?style=flat-square)](https://github.com/Redot-Engine/redot-engine/releases/tag/redot-26.2-stable)
[![Redot compatibility](https://github.com/dominicbytes/twitcher/actions/workflows/redot-compatibility.yml/badge.svg)](https://github.com/dominicbytes/twitcher/actions/workflows/redot-compatibility.yml)
[![License](https://img.shields.io/badge/License-MIT-blue.svg?style=flat-square)](LICENSE)

**Twitch integration for Redot 26.2 LTS.**

Twitcher for Redot connects Redot games, overlays, and applications to Twitch. It supports
EventSub, the Helix API, chat commands, OAuth flows, channel-point rewards, emotes, badges, and
Cheermotes.

This is an independent Redot project derived from
[kani_dev's original Twitcher](https://github.com/kanimaru/twitcher). It is maintained separately
and is not intended to merge back into the original project. Twitcher for Redot preserves the
original public API and `res://addons/twitcher` paths while maintaining and testing Redot support.

## Features

- EventSub listeners for follows, subscriptions, cheers, rewards, and other Twitch events
- Generated, typed wrappers for the Twitch Helix REST API
- OAuth Authorization Code, Client Credentials, and Device Code flows
- Twitch chat commands with permission checks and help generation
- Redot editor tools for authentication, scopes, EventSub configuration, and rewards
- Twitch emote, badge, and Cheermote loading as Redot `SpriteFrames`

## Requirements

- [Redot 26.2 LTS](https://github.com/Redot-Engine/redot-engine/releases/tag/redot-26.2-stable)
- A Twitch developer application for features that require authentication

## Installation

1. Download or clone this repository.
2. Copy `addons/twitcher` into your Redot project at exactly `res://addons/twitcher`.
3. In Redot, open **Project → Project Settings → Plugins** and enable **Twitcher for Redot**.
4. Open **Project → Tools → Twitcher → Setup** to configure your Twitch application and scopes.

## Documentation

The [upstream Twitcher documentation](https://twitcher.kani.dev/) describes the public API and
core workflows shared by this fork. Where its editor screenshots or engine-version guidance
differs, use Redot 26.2 and the setup path above.

## Animated emotes

Twitcher offers three image transformers:

- `TwitchImageTransformer`: static images; works without external tools
- `MagickImageTransformer`: GIF support through a separate
  [ImageMagick](https://imagemagick.org/) installation
- `NativeImageTransformer`: experimental GDScript GIF support based on
  [vbousquet/godot-gif-importer](https://github.com/vbousquet/godot-gif-importer)

## Development and validation

Run the Redot compatibility checks from the repository root:

```powershell
redot --headless --path . --import
redot --headless --path . --script res://tests/redot_compatibility.gd
```

The probe loads the editor plugin and setup scenes and instantiates the runtime `TwitchService`.
Live OAuth, Twitch API, and EventSub delivery require credentials and remain integration tests.

To enable the local secret-clearing pre-commit hook:

```bash
git config core.hooksPath .githooks
```

## Original project and license

Twitcher for Redot is derived from the original
[kanimaru/twitcher](https://github.com/kanimaru/twitcher), created by kani_dev. This repository is
an independent Redot continuation and does not replace or represent the original project. Both are
distributed under the [MIT License](LICENSE).

## Notes

I vibe coded this in GPT Sol 5.6. Use at your own risk.

## About Dominic Bytes

Greetings! I am Dominic Bytes, the synth walker. I hail from the distant future. Where brains occupy robot bodies, time travel is a trip to the corner store, and the neon glow of our attire is powered by the light of our souls. Join me on a 1.21 gigawatt powered journey of chill vibes with gaming, anime, movies, and more!

- [Website](https://dominicbytes.carrd.co/)
- [X](https://x.com/DominicBytes)
- [Twitch](https://www.twitch.tv/dominicbytes)
- [YouTube](http://www.youtube.com/@DominicBytes)
- [Kick](https://kick.com/dominicbytes)
