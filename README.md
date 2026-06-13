# ssap

**Screenshot Snap, Annotate, Place** — lightweight macOS screenshot organizer.

Auto-sorts screenshots into `YYYY/MM` directories, tags via native macOS xattr, and prompts for annotation on capture.

## Features

- **Auto-organize** — new screenshots are sorted into `~/Screenshots/YYYY/MM/` by date
- **Tag prompt** — SwiftUI popup appears on capture for quick annotation
- **Native tags** — uses macOS extended attributes (`kMDItemUserTags`), searchable via Spotlight
- **Multi-tag** — one screenshot, many tags (e.g., `troubleshooting`, `incident-123`)
- **Delete on capture** — catch accidental screenshots immediately
- **Archive** — compress old years into tarballs
- **Daemon** — runs as a LaunchAgent, watches via FSEvents

## Install

### Homebrew

```bash
brew tap linkoffate/tap
brew install ssap
ssap install    # sets up LaunchAgent + screenshot location
```

### From source

```bash
git clone https://github.com/linkoffate/ssap.git
cd ssap
make install    # builds and copies to ~/.local/bin/
ssap install    # sets up LaunchAgent + screenshot location
```

Requires macOS 13+ and Swift 5.9+.

## Usage

```bash
ssap watch              # start watching (default command)
ssap prompt <file>      # manually open tag prompt for a file
ssap tag <file> <tags>  # tag from CLI
ssap rename <file> <name>  # rename a screenshot (tags kept; extension kept if omitted)
ssap search <tag>       # find screenshots by tag (Spotlight)
ssap archive <year>     # compress a year to tar.gz
ssap install            # install LaunchAgent + set screenshot location
ssap uninstall          # reverse everything
```

## How it works

```
Cmd+Shift+4 (screenshot)
      ↓
macOS saves to ~/Screenshots/
      ↓
ssap daemon detects new file (FSEvents)
      ↓
Moves to ~/Screenshots/YYYY/MM/
      ↓
Shows tag prompt (SwiftUI)
┌─────────────────────────────┐
│  [thumbnail]                │
│                             │
│  Tags: [troubleshooting]    │
│        [incident]           │
│        [+ custom...]        │
│                             │
│  [Delete]  [Skip]  [Save]   │
└─────────────────────────────┘
      ↓
Applies macOS xattr tags
```

## Configuration

Config lives at `~/.config/ssap/config.yaml`:

```yaml
watch_dir: ~/Screenshots
organize: true
prompt: true
delete_prompt: true

tag_presets:
  - troubleshooting
  - incident
  - reference
  - meeting
  - personal

archive:
  preserve_xattrs: true
```

See [`config.example.yaml`](config.example.yaml) for a full example.

## Directory structure

```
~/Screenshots/
├── 2024.tar.gz          # archived years
├── 2025.tar.gz
└── 2026/                # current year (live)
    ├── 01/
    ├── 02/
    └── ...
```

## Uninstall

```bash
ssap uninstall          # removes LaunchAgent, resets screenshot location
make uninstall          # removes binary
```

Config and screenshots are preserved.

## License

MIT
