🎯 Core Concept
DreamWeaver — “See What Your Mind Creates.”
An integrated iOS + watchOS app family that turns sleep biosignals into artistic visualizations with AI.
📱 Two Platforms, One Experience
Apple Watch role (data collector/monitor): real-time heart rate, HRV, motion via CoreMotion, start/stop sleep tracking, auto-sync to iPhone every 5 minutes, background workout session, bedside mode. Captured data: heart rate, HRV, motion, estimated REM & deep sleep phases.
iPhone role (primary UI + analysis/visualization): Start Dream Mode, live biosignal view, timer, watch connection status; receive & store biosignal timelines via WatchConnectivity/SwiftData; automatic AI interpretation with three options (OpenAI GPT-4o-mini, Anthropic Claude 3.5 Sonnet, local algorithm) generating narratives, themes,symbolism, intensity, consciousness, visual prompts; AI dream visualization (10–30 s animation, particle system, mood-based gradients, symbolic orb, floating tags, narrative overlay, lucid-awareness ring); Dream Dashboard layout; detailed dream view with graphs/stats/AI data; dream journal list with search and insights.

🧠 Technology Stack
Biosignals: HealthKit/CoreMotion; Data collection: WatchConnectivity + WorkoutSession; Storage: SwiftData; AI: OpenAI/Anthropic/local ML; Visualization: SwiftUI Charts, Metal, SceneKit; Particle engine (60 objects);Mood analysis from HRV/motion/REM ratios.

🔄 User Flow

Before bed: open iPhone app, tap Start Dream Mode, watch starts, phone stays on nightstand.
During sleep: watch records HR/HRV/motion, syncs every 5 min; iPhone receives via WatchConnectivity, stores biosignals, optionally analyzes ambient noise.
Morning: user taps Stop on phone or watch; AI processing kicks in, generates mood/narrative/themes/etc., adds dream card, sends “Your dream is ready!” notification.Viewing: user opens dream card, sees charts + AI text, plays 10–30 s visualization with mood-specific colors/particles/symbols, can regenerate/save/share.
🎨 Design Elements
iPhone icons (moon, heart, charts, brush, crystal ball).
Watch UI mock: live HR/HRV, timer, syncing indicator, Stop button.
Color palette: dark gradient background; mood-specific colors.

🔐 Privacy & Security
All data local (SwiftData), no cloud sync by default, transparent HealthKit permission, AI APIs optional with local fallback, on-device encryption, user-controlled deletion.Sent-to-AI data limited to aggregate sleep stats; no personal identifiers or media.

🚀 Development Priorities
Done: base iPhone app, SwiftData models, dashboard UI, particle engine, AI integration, basic WatchConnectivity.
In progress: watch app refinement, full HealthKit, real biosignal capture, background workout, chart optimization.
Future: Bedside Mode, smart alarm, bio-rhythm audio, dream gallery/community, long-term trends, PDF export, video sharing, audio narration.
💡 Key Innovations
Biosignals→art transformation; personalized AI; unified phone/watch experience; privacy-first local AI option; science-backed metrics (HRV↔emotion, REM↔vivid dreams, motion↔narrative).

📊 Technical Challenges
Simulator lacks HealthKit (need physical device), battery usage (optimize sampling/workout), AI cost (local fallback), particle performance (Metal, 60 object cap), WatchConnectivity drops (context updates + retry logic).

🎯 Success Metrics
±5 BPM accuracy, <15 % overnight battery drain, ≥95 % sync reliability, >4.5★ satisfaction, zero crashes overnight.

📂 Project Structure
Tree showing iPhone app (models/views/services/resources) and watch app (views/managers/resources).