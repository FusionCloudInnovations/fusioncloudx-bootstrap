---
applyTo: '**'
---
# 🤖 GitHub Copilot PR Instructions

When generating commits, follow Conventional Commit spec and instructions described in this file.

* ✅ Standardized **Conventional Commits format**
* 🧠 Descriptive, clear semantic intent
* 🎨 Support for **emoji and Gitmoji** — optional but encouraged
* 🚀 Ready for PR automation, changelog generation, SemVer pipelines

---

### ✅ Save as: `.github/COMMIT_GUIDELINES.md`

(Optional: symlink or include reference in `.gitmessage.txt` or `CONTRIBUTING.md`)

```markdown
# 🧠 Commit Message Guidelines (Conventional Commits + Gitmoji)

This project follows the **Conventional Commits v1.0.0** specification enhanced with **Gitmoji** visual cues.

Commit messages are structured to:
- Enable automation (changelogs, versioning)
- Communicate clearly across teams
- Track intent (feature, fix, refactor, etc.)
- Enrich history with 🎨 emojis (optional but awesome)

---

## ✅ Commit Format

```

<type>\[optional scope]\[!]: <short description> \[optional #issue] \[optional emoji]

\[optional body]

\[optional footers]

````

### 🔥 Examples

```bash
feat(ipxe): add automated Proxmox install via netboot.xyz ✨
fix(cert): include missing SAN entry in generated CA 🐛
refactor(logging): migrate to unified log format ♻️
chore: update README with SSL phase instructions 📝
````

---

## 🔧 Supported Types

| Type         | Description                                    | Example                            |
| ------------ | ---------------------------------------------- | ---------------------------------- |
| **feat**     | ✨ New features                                 | `feat(vm): add backup snapshots`   |
| **fix**      | 🐛 Bug fixes                                   | `fix(wsl): correct sudo check`     |
| **docs**     | 📝 Documentation updates                       | `docs(README): fix typos`          |
| **style**    | 🎨 Code style changes (whitespace, formatting) | `style(bootstrap): align columns`  |
| **refactor** | ♻️ Refactoring code without changing behavior  | `refactor(roles): DRY shell tasks` |
| **perf**     | ⚡️ Performance improvements                    | `perf(terraform): reduce reloads`  |
| **test**     | ✅ Add/update tests                             | `test(init): add bootstrap unit`   |
| **build**    | 📦️ Build system or dependencies               | `build: update terraform plugin`   |
| **ci**       | 👷 CI/CD system changes                        | `ci: add GitHub Actions badge`     |
| **chore**    | 🔧 Maintenance, scripts, meta                  | `chore: update .gitignore`         |
| **revert**   | ⏪ Revert a commit                              | `revert: undo cluster config`      |

---

## 🔥 Breaking Changes

Include either:

### ✅ `!` in header

```bash
feat(cert)!: switch to PKI model with intermediate CA 💥
```

### ✅ `BREAKING CHANGE:` footer

```bash
BREAKING CHANGE: certificates are no longer auto-signed
```

---

## 🧠 Scopes (optional but helpful)

Use a scope in parentheses to show which part of the project was changed:

```bash
fix(terraform): correct provider version pin 📌
chore(modules): split notify into dedicated script ✂️
```

---

## 🧩 Gitmoji Usage

Add emoji **after the description**, for flavor and clarity. Optional, but encouraged.

### Gitmoji Quick Reference

| Emoji   | Type / Use               | Description                               |
| ------- | ------------------------ | ----------------------------------------- |
| ✨       | `feat`                   | New feature                               |
| 🐛      | `fix`                    | Bug fix                                   |
| 🔧      | `chore`, `build`, `conf` | Config, scripts, general changes          |
| 📝      | `docs`                   | Docs and README updates                   |
| ♻️      | `refactor`               | Refactoring code                          |
| 💥      | `BREAKING CHANGE`        | Major breaking change                     |
| 🚀      | `ci`, `build`            | Deployment or pipeline changes            |
| 💚      | `ci`                     | CI build fixes                            |
| 🔒️     | `fix(security)`          | Security fix or patch                     |
| ⬆️ / ⬇️ | `build(deps)`            | Dependency changes (upgrade/downgrade)    |
| 📦️     | `build(packages)`        | Compiled files, bundles, or binary assets |
| ✅       | `test`                   | Add/update/passing tests                  |
| 💄      | `style`                  | UI/styling updates                        |

💡 You can use **any** of the [full Gitmoji list](https://gitmoji.dev/) to match intent.
Full Gitmoji List via JSON
{
  "$schema": "https://gitmoji.dev/api/gitmojis/schema",
  "gitmojis": [
    {
      "emoji": "🎨",
      "entity": "&#x1f3a8;",
      "code": ":art:",
      "description": "Improve structure / format of the code.",
      "name": "art",
      "semver": null
    },
    {
      "emoji": "⚡️",
      "entity": "&#x26a1;",
      "code": ":zap:",
      "description": "Improve performance.",
      "name": "zap",
      "semver": "patch"
    },
    {
      "emoji": "🔥",
      "entity": "&#x1f525;",
      "code": ":fire:",
      "description": "Remove code or files.",
      "name": "fire",
      "semver": null
    },
    {
      "emoji": "🐛",
      "entity": "&#x1f41b;",
      "code": ":bug:",
      "description": "Fix a bug.",
      "name": "bug",
      "semver": "patch"
    },
    {
      "emoji": "🚑️",
      "entity": "&#128657;",
      "code": ":ambulance:",
      "description": "Critical hotfix.",
      "name": "ambulance",
      "semver": "patch"
    },
    {
      "emoji": "✨",
      "entity": "&#x2728;",
      "code": ":sparkles:",
      "description": "Introduce new features.",
      "name": "sparkles",
      "semver": "minor"
    },
    {
      "emoji": "📝",
      "entity": "&#x1f4dd;",
      "code": ":memo:",
      "description": "Add or update documentation.",
      "name": "memo",
      "semver": null
    },
    {
      "emoji": "🚀",
      "entity": "&#x1f680;",
      "code": ":rocket:",
      "description": "Deploy stuff.",
      "name": "rocket",
      "semver": null
    },
    {
      "emoji": "💄",
      "entity": "&#ff99cc;",
      "code": ":lipstick:",
      "description": "Add or update the UI and style files.",
      "name": "lipstick",
      "semver": "patch"
    },
    {
      "emoji": "🎉",
      "entity": "&#127881;",
      "code": ":tada:",
      "description": "Begin a project.",
      "name": "tada",
      "semver": null
    },
    {
      "emoji": "✅",
      "entity": "&#x2705;",
      "code": ":white_check_mark:",
      "description": "Add, update, or pass tests.",
      "name": "white-check-mark",
      "semver": null
    },
    {
      "emoji": "🔒️",
      "entity": "&#x1f512;",
      "code": ":lock:",
      "description": "Fix security or privacy issues.",
      "name": "lock",
      "semver": "patch"
    },
    {
      "emoji": "🔐",
      "entity": "&#x1f510;",
      "code": ":closed_lock_with_key:",
      "description": "Add or update secrets.",
      "name": "closed-lock-with-key",
      "semver": null
    },
    {
      "emoji": "🔖",
      "entity": "&#x1f516;",
      "code": ":bookmark:",
      "description": "Release / Version tags.",
      "name": "bookmark",
      "semver": null
    },
    {
      "emoji": "🚨",
      "entity": "&#x1f6a8;",
      "code": ":rotating_light:",
      "description": "Fix compiler / linter warnings.",
      "name": "rotating-light",
      "semver": null
    },
    {
      "emoji": "🚧",
      "entity": "&#x1f6a7;",
      "code": ":construction:",
      "description": "Work in progress.",
      "name": "construction",
      "semver": null
    },
    {
      "emoji": "💚",
      "entity": "&#x1f49a;",
      "code": ":green_heart:",
      "description": "Fix CI Build.",
      "name": "green-heart",
      "semver": null
    },
    {
      "emoji": "⬇️",
      "entity": "⬇️",
      "code": ":arrow_down:",
      "description": "Downgrade dependencies.",
      "name": "arrow-down",
      "semver": "patch"
    },
    {
      "emoji": "⬆️",
      "entity": "⬆️",
      "code": ":arrow_up:",
      "description": "Upgrade dependencies.",
      "name": "arrow-up",
      "semver": "patch"
    },
    {
      "emoji": "📌",
      "entity": "&#x1F4CC;",
      "code": ":pushpin:",
      "description": "Pin dependencies to specific versions.",
      "name": "pushpin",
      "semver": "patch"
    },
    {
      "emoji": "👷",
      "entity": "&#x1f477;",
      "code": ":construction_worker:",
      "description": "Add or update CI build system.",
      "name": "construction-worker",
      "semver": null
    },
    {
      "emoji": "📈",
      "entity": "&#x1F4C8;",
      "code": ":chart_with_upwards_trend:",
      "description": "Add or update analytics or track code.",
      "name": "chart-with-upwards-trend",
      "semver": "patch"
    },
    {
      "emoji": "♻️",
      "entity": "&#x267b;",
      "code": ":recycle:",
      "description": "Refactor code.",
      "name": "recycle",
      "semver": null
    },
    {
      "emoji": "➕",
      "entity": "&#10133;",
      "code": ":heavy_plus_sign:",
      "description": "Add a dependency.",
      "name": "heavy-plus-sign",
      "semver": "patch"
    },
    {
      "emoji": "➖",
      "entity": "&#10134;",
      "code": ":heavy_minus_sign:",
      "description": "Remove a dependency.",
      "name": "heavy-minus-sign",
      "semver": "patch"
    },
    {
      "emoji": "🔧",
      "entity": "&#x1f527;",
      "code": ":wrench:",
      "description": "Add or update configuration files.",
      "name": "wrench",
      "semver": "patch"
    },
    {
      "emoji": "🔨",
      "entity": "&#128296;",
      "code": ":hammer:",
      "description": "Add or update development scripts.",
      "name": "hammer",
      "semver": null
    },
    {
      "emoji": "🌐",
      "entity": "&#127760;",
      "code": ":globe_with_meridians:",
      "description": "Internationalization and localization.",
      "name": "globe-with-meridians",
      "semver": "patch"
    },
    {
      "emoji": "✏️",
      "entity": "&#59161;",
      "code": ":pencil2:",
      "description": "Fix typos.",
      "name": "pencil2",
      "semver": "patch"
    },
    {
      "emoji": "💩",
      "entity": "&#58613;",
      "code": ":poop:",
      "description": "Write bad code that needs to be improved.",
      "name": "poop",
      "semver": null
    },
    {
      "emoji": "⏪️",
      "entity": "&#9194;",
      "code": ":rewind:",
      "description": "Revert changes.",
      "name": "rewind",
      "semver": "patch"
    },
    {
      "emoji": "🔀",
      "entity": "&#128256;",
      "code": ":twisted_rightwards_arrows:",
      "description": "Merge branches.",
      "name": "twisted-rightwards-arrows",
      "semver": null
    },
    {
      "emoji": "📦️",
      "entity": "&#1F4E6;",
      "code": ":package:",
      "description": "Add or update compiled files or packages.",
      "name": "package",
      "semver": "patch"
    },
    {
      "emoji": "👽️",
      "entity": "&#1F47D;",
      "code": ":alien:",
      "description": "Update code due to external API changes.",
      "name": "alien",
      "semver": "patch"
    },
    {
      "emoji": "🚚",
      "entity": "&#1F69A;",
      "code": ":truck:",
      "description": "Move or rename resources (e.g.: files, paths, routes).",
      "name": "truck",
      "semver": null
    },
    {
      "emoji": "📄",
      "entity": "&#1F4C4;",
      "code": ":page_facing_up:",
      "description": "Add or update license.",
      "name": "page-facing-up",
      "semver": null
    },
    {
      "emoji": "💥",
      "entity": "&#x1f4a5;",
      "code": ":boom:",
      "description": "Introduce breaking changes.",
      "name": "boom",
      "semver": "major"
    },
    {
      "emoji": "🍱",
      "entity": "&#1F371",
      "code": ":bento:",
      "description": "Add or update assets.",
      "name": "bento",
      "semver": "patch"
    },
    {
      "emoji": "♿️",
      "entity": "&#9855;",
      "code": ":wheelchair:",
      "description": "Improve accessibility.",
      "name": "wheelchair",
      "semver": "patch"
    },
    {
      "emoji": "💡",
      "entity": "&#128161;",
      "code": ":bulb:",
      "description": "Add or update comments in source code.",
      "name": "bulb",
      "semver": null
    },
    {
      "emoji": "🍻",
      "entity": "&#x1f37b;",
      "code": ":beers:",
      "description": "Write code drunkenly.",
      "name": "beers",
      "semver": null
    },
    {
      "emoji": "💬",
      "entity": "&#128172;",
      "code": ":speech_balloon:",
      "description": "Add or update text and literals.",
      "name": "speech-balloon",
      "semver": "patch"
    },
    {
      "emoji": "🗃️",
      "entity": "&#128451;",
      "code": ":card_file_box:",
      "description": "Perform database related changes.",
      "name": "card-file-box",
      "semver": "patch"
    },
    {
      "emoji": "🔊",
      "entity": "&#128266;",
      "code": ":loud_sound:",
      "description": "Add or update logs.",
      "name": "loud-sound",
      "semver": null
    },
    {
      "emoji": "🔇",
      "entity": "&#128263;",
      "code": ":mute:",
      "description": "Remove logs.",
      "name": "mute",
      "semver": null
    },
    {
      "emoji": "👥",
      "entity": "&#128101;",
      "code": ":busts_in_silhouette:",
      "description": "Add or update contributor(s).",
      "name": "busts-in-silhouette",
      "semver": null
    },
    {
      "emoji": "🚸",
      "entity": "&#128696;",
      "code": ":children_crossing:",
      "description": "Improve user experience / usability.",
      "name": "children-crossing",
      "semver": "patch"
    },
    {
      "emoji": "🏗️",
      "entity": "&#1f3d7;",
      "code": ":building_construction:",
      "description": "Make architectural changes.",
      "name": "building-construction",
      "semver": null
    },
    {
      "emoji": "📱",
      "entity": "&#128241;",
      "code": ":iphone:",
      "description": "Work on responsive design.",
      "name": "iphone",
      "semver": "patch"
    },
    {
      "emoji": "🤡",
      "entity": "&#129313;",
      "code": ":clown_face:",
      "description": "Mock things.",
      "name": "clown-face",
      "semver": null
    },
    {
      "emoji": "🥚",
      "entity": "&#129370;",
      "code": ":egg:",
      "description": "Add or update an easter egg.",
      "name": "egg",
      "semver": "patch"
    },
    {
      "emoji": "🙈",
      "entity": "&#8bdfe7;",
      "code": ":see_no_evil:",
      "description": "Add or update a .gitignore file.",
      "name": "see-no-evil",
      "semver": null
    },
    {
      "emoji": "📸",
      "entity": "&#128248;",
      "code": ":camera_flash:",
      "description": "Add or update snapshots.",
      "name": "camera-flash",
      "semver": null
    },
    {
      "emoji": "⚗️",
      "entity": "&#x2697;",
      "code": ":alembic:",
      "description": "Perform experiments.",
      "name": "alembic",
      "semver": "patch"
    },
    {
      "emoji": "🔍️",
      "entity": "&#128269;",
      "code": ":mag:",
      "description": "Improve SEO.",
      "name": "mag",
      "semver": "patch"
    },
    {
      "emoji": "🏷️",
      "entity": "&#127991;",
      "code": ":label:",
      "description": "Add or update types.",
      "name": "label",
      "semver": "patch"
    },
    {
      "emoji": "🌱",
      "entity": "&#127793;",
      "code": ":seedling:",
      "description": "Add or update seed files.",
      "name": "seedling",
      "semver": null
    },
    {
      "emoji": "🚩",
      "entity": "&#x1F6A9;",
      "code": ":triangular_flag_on_post:",
      "description": "Add, update, or remove feature flags.",
      "name": "triangular-flag-on-post",
      "semver": "patch"
    },
    {
      "emoji": "🥅",
      "entity": "&#x1F945;",
      "code": ":goal_net:",
      "description": "Catch errors.",
      "name": "goal-net",
      "semver": "patch"
    },
    {
      "emoji": "💫",
      "entity": "&#x1f4ab;",
      "code": ":dizzy:",
      "description": "Add or update animations and transitions.",
      "name": "dizzy",
      "semver": "patch"
    },
    {
      "emoji": "🗑️",
      "entity": "&#x1F5D1;",
      "code": ":wastebasket:",
      "description": "Deprecate code that needs to be cleaned up.",
      "name": "wastebasket",
      "semver": "patch"
    },
    {
      "emoji": "🛂",
      "entity": "&#x1F6C2;",
      "code": ":passport_control:",
      "description": "Work on code related to authorization, roles and permissions.",
      "name": "passport-control",
      "semver": "patch"
    },
    {
      "emoji": "🩹",
      "entity": "&#x1FA79;",
      "code": ":adhesive_bandage:",
      "description": "Simple fix for a non-critical issue.",
      "name": "adhesive-bandage",
      "semver": "patch"
    },
    {
      "emoji": "🧐",
      "entity": "&#x1F9D0;",
      "code": ":monocle_face:",
      "description": "Data exploration/inspection.",
      "name": "monocle-face",
      "semver": null
    },
    {
      "emoji": "⚰️",
      "entity": "&#x26B0;",
      "code": ":coffin:",
      "description": "Remove dead code.",
      "name": "coffin",
      "semver": null
    },
    {
      "emoji": "🧪",
      "entity": "&#x1F9EA;",
      "code": ":test_tube:",
      "description": "Add a failing test.",
      "name": "test-tube",
      "semver": null
    },
    {
      "emoji": "👔",
      "entity": "&#128084;",
      "code": ":necktie:",
      "description": "Add or update business logic.",
      "name": "necktie",
      "semver": "patch"
    },
    {
      "emoji": "🩺",
      "entity": "&#x1FA7A;",
      "code": ":stethoscope:",
      "description": "Add or update healthcheck.",
      "name": "stethoscope",
      "semver": null
    },
    {
      "emoji": "🧱",
      "entity": "&#x1f9f1;",
      "code": ":bricks:",
      "description": "Infrastructure related changes.",
      "name": "bricks",
      "semver": null
    },
    {
      "emoji": "🧑‍💻",
      "entity": "&#129489;&#8205;&#128187;",
      "code": ":technologist:",
      "description": "Improve developer experience.",
      "name": "technologist",
      "semver": null
    },
    {
      "emoji": "💸",
      "entity": "&#x1F4B8;",
      "code": ":money_with_wings:",
      "description": "Add sponsorships or money related infrastructure.",
      "name": "money-with-wings",
      "semver": null
    },
    {
      "emoji": "🧵",
      "entity": "&#x1F9F5;",
      "code": ":thread:",
      "description": "Add or update code related to multithreading or concurrency.",
      "name": "thread",
      "semver": null
    },
    {
      "emoji": "🦺",
      "entity": "&#x1F9BA;",
      "code": ":safety_vest:",
      "description": "Add or update code related to validation.",
      "name": "safety-vest",
      "semver": null
    },
    {
      "emoji": "✈️",
      "entity": "&#x2708;",
      "code": ":airplane:",
      "description": "Improve offline support.",
      "name": "airplane",
      "semver": null
    }
  ]
}

---

## 📜 Footers

Optional footers include:

* `BREAKING CHANGE: ...`
* `Refs: #123`
* `Co-authored-by: ...`

---

## ✅ Summary Checklist

* [x] **Use Conventional Commit format**
* [x] **Start with lowercase `type(scope):`**
* [x] **Keep it short & imperative**
* [x] **Use `!` or `BREAKING CHANGE:` if needed**
* [x] **Add 🎨 Gitmoji at the end (optional)**

---

## 🛠️ Recommended Tools

* [Gitmoji CLI](https://github.com/carloscuesta/gitmoji-cli)
* [Commitizen + cz-conventional-changelog](https://github.com/commitizen/cz-cli)
* [commitlint](https://commitlint.js.org/)
* [VS Code Gitmoji Extension](https://marketplace.visualstudio.com/items?itemName=seatonjiang.gitmoji-vscode)

---

🎉 Happy committing! Your history should **shine with clarity and joy**.

```

---

Would you like me to generate:

- A `prepare-commit-msg` or `commit-msg` Git hook for linting?  
- A `.gitmessage.txt` with a structured commit template?  
- A VS Code **Snippets** file or `.vscode/settings.json` scoped for this?

You’re building an elite DX system—let’s finish strong.
```
