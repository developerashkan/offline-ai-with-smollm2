# SmolLM2 Offline Chat - Flutter

A modern, high-performance offline chat application built with Flutter and the pure-Dart `smollm2` inference engine. This app runs a Large Language Model (LLM) entirely on your device with no internet connection required.

## ✨ Features

- **100% Offline**: Privacy-first AI. No data leaves your device.
- **Pure Dart Inference**: Powered by the `smollm2` engine (no native C++/Llama.cpp bindings required).
- **Gemini-Inspired UI**: Modern, sleek aesthetic with live animated gradients and Material 3 design.
- **Token Streaming**: Real-time response generation for a snappy user experience.
- **Dynamic Theming**: Full support for system Light and Dark modes.
- **Bundled Model**: Comes pre-configured with the SmolLM2-135M model for immediate use.

---

## 🏗️ Project Structure

```text
lib/
├── main.dart            # Main UI implementation (ChatScreen, Header, Input, Bubbles)
├── llm_service.dart     # Core AI logic (Model loading, streaming, output cleaning)
└── chat_message.dart    # Simple data model for conversation history
assets/
└── smollm2-q16.bin      # The optimized 16-bit quantized AI model
android/
└── build.gradle.kts     # Configured for Android 15/16 (compileSdk 36)
```

### 🧩 Key Components

1.  **`LLMService`**: The bridge between the UI and the AI engine.
    -   Handles the extraction of the `.bin` model from assets to device storage.
    -   Manages the `ChatSession` for conversation context.
    -   Filters out prompt tags using Regex to ensure clean AI responses.
2.  **`ChatScreen`**: A stateful widget managing the modern chat interface.
    -   Uses `flutter_easyloading` for "Thinking..." states.
    -   Implements a custom animated gradient background for a "premium vibe."
3.  **`smollm2` Model**: 
    -   Model: `SmolLM2-135M-Instruct`
    -   Quantization: `Q16` (Optimized for mobile CPU performance/memory balance).

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK installed.
- An Android device or emulator (Android 8.0+ recommended).

### Installation
1. Clone the repository.
2. Run `flutter pub get` to fetch dependencies.
3. Launch the app using `flutter run`.

---

## 🛠️ How I Built the Model Binary

The AI model file usually located in `assets/` was created using a specific conversion process to make it compatible with the pure-Dart engine.

> [!NOTE]
> Due to GitHub file size limits, the `.bin` file is excluded from this repository. You can generate it yourself using the steps below or download it manually if a link is provided.

1.  **Download**: Fetched `HuggingFaceTB/SmolLM2-135M-Instruct` using the `huggingface_downloader`.
2.  **Quantize**: Converted the Safetensors weights into the `smollm2-q16.bin` format using the `export_smollm2` CLI.
3.  **Optimize**: Used `Q16` (16-bit) to ensure the model fits within mobile RAM (approx 270MB) while maintaining high intelligence.

### 📥 Manual Setup of the Model
To get the app working after cloning:
1. Follow the "How I Built the Model Binary" steps above.
2. Place the resulting `smollm2-q16.bin` file into the `assets/` directory.

---

## 📦 Sharing on GitHub

To upload this project to your own GitHub:

1. Create a new repository on [GitHub](https://github.com/new).
2. Run the following commands in your project terminal:

```bash
git init
git add .
git commit -m "Initial commit: Offline AI Chat with SmolLM2"
git branch -M main
git remote add origin YOUR_GITHUB_REPO_URL
git push -u origin main
```

---

## 📄 License
MIT License - Feel free to use and modify for your own offline AI projects!
