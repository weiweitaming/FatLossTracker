# FatLossTracker

[简体中文](README.md) · English

A native macOS fat-loss tracking app built through vibe coding. It brings daily food logging, macro tracking, weight trends, training-day planning, and AI-assisted nutrition analysis into one desktop app.

## Interface Preview

![FatLossTracker dashboard](docs/images/dashboard.png)

![AI-assisted food analysis](docs/images/food-analysis.png)

![Training-day and rest-day meal plans](docs/images/plan.png)

## Features

- Log breakfast, lunch, dinner, and snacks, then review daily nutrition intake and calorie trends
- Maintain a custom food database and use separate meal templates for training and rest days
- Enter nutrition manually or let AI parse a meal description using the custom food database as a reference
- Track weight and body-fat trends and generate fat-loss suggestions
- Generate and save home-cooking recipes
- Export the selected day's food log as CSV

## Customization

- Training-day and rest-day calorie and macro targets are currently configured through `DietPlan.default`; a graphical editor is not available yet
- The Settings screen supports services compatible with the OpenAI Chat Completions protocol, including a custom API Base URL and model name

## Privacy and Security

- The API key is stored in the local macOS Keychain and is never written to the source tree or Git repository
- Remote API Base URLs must use HTTPS; when an AI feature is used, the relevant food or weight data is sent to the service configured by the user
- Remove personal health data and credentials before sharing issues, screenshots, or logs

## Requirements and Usage

- macOS 14 or later
- Swift 6
- Xcode, or a compatible Swift toolchain and macOS SDK

Run in development:

```bash
swift run FatLossTracker
```

Build a local `.app` bundle:

```bash
./build-app.sh
```

The generated app is saved as `FatLossTracker.app` in the project root. It is a build artifact and is excluded from Git.

## Project Structure

- `Sources/Views/ContentView.swift`: primary application views
- `Sources/AppState.swift`: application state, business logic, and AI requests
- `Sources/PersistenceController.swift`: Core Data model and local persistence
- `Sources/KeychainAPIKeyStore.swift`: secure API-key storage in macOS Keychain

## Project Status

This is an early but usable release. HealthKit integration is not available yet. AI-generated nutrition values are estimates and are not a substitute for advice from a physician or registered dietitian.

## License

[MIT](LICENSE)
