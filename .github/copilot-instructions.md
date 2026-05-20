This project is a modern World of Warcraft addon for retail WoW.

Key facts for the agent:
- The project uses Lua and WoW addon conventions.
- Target WoW version is 12.0.5 and newer.
- When editing UI XML, resolve schema references against the `Retail Source Code` workspace folder.
- The UI schema file is expected under the `Retail Source Code` folder, e.g. `UI.xsd` in that workspace root.
- Use the Ace3 frameworks and libraries from the `Ace3 Source Code` workspace folder when appropriate, especially for event handling, configuration, and addon integration.
- Prefer WoW addon-specific patterns and XML usage, not generic web or desktop UI conventions.
- Ensure generated code and XML remain readable and maintainable for human authors, with clear naming and structure.
- When changing or refactoring code that is already working, plan the changes carefully to preserve existing behavior and avoid unnecessary breakage.

