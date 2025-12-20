#  AI Dream Interpretation Configuration Guide

## Overview
The DreamWeaver app now includes AI-powered dream interpretation that analyzes your sleep biosignals and generates personalized, poetic dream narratives with enhanced visualizations.

## Features

### 🤖 AI Service (`AIDreamService.swift`)
- **OpenAI GPT-4o-mini Integration**: Generate sophisticated dream interpretations
- **Anthropic Claude Integration**: Alternative AI provider option
- **Local Fallback**: Works without API key using built-in algorithms
- **Async Processing**: Non-blocking AI calls with loading indicators

### 🎨 Enhanced Visualization (`AIEnhancedVisualizationView.swift`)
- **Dynamic particle systems** driven by AI intensity metrics
- **Mood-based gradients** (ethereal, turbulent, intense, peaceful, calm)
- **Symbolic orbs** displaying dream symbolism with emoji icons
- **Narrative overlay** with poetic AI-generated dream stories
- **Theme tags** showing identified dream themes
- **Consciousness rings** for lucid dream detection
- **Intensity indicators** with 5-level visual scale

### 📊 Extended Data Model
New SleepData properties:
- `aiNarrative`: AI-generated dream story (2-3 sentences)
- `aiThemes`: Array of dream themes (e.g., "cosmos", "transformation")
- `aiSymbolism`: Symbolic elements (e.g., "stars", "water", "fire")
- `aiIntensity`: 0-1 scale of dream intensity
- `aiConsciousness`: 0-1 scale of lucidity/awareness
- `aiVisualPrompt`: Description used for visualization generation

## Setup Options

### Option 1: Use Local Interpretation (Default - No Setup Required)
The app works immediately with sophisticated local algorithms. No API key needed.

**How it works:**
- Analyzes heart rate variability, movement, REM%, deep sleep%
- Generates mood-appropriate narratives and visualizations
- Fast processing, no internet required
- Privacy-friendly (all processing on-device)

### Option 2: Enable OpenAI Integration
For more varied and creative dream interpretations.

**Setup:**
1. Get API key from https://platform.openai.com/api-keys
2. Open `AIDreamService.swift`
3. Find line ~280: `static let apiKey: String? = ProcessInfo.processInfo.environment["AI_API_KEY"]`
4. Change to: `static let apiKey: String? = "sk-your-key-here"`
5. Change line ~283: `static let defaultProvider: AIProvider = .local`
6. To: `static let defaultProvider: AIProvider = .openAI`

**Cost:** ~$0.001-0.002 per dream interpretation (GPT-4o-mini)

### Option 3: Enable Anthropic Claude Integration
For alternative AI interpretation style.

**Setup:**
1. Get API key from https://console.anthropic.com/
2. Follow same steps as OpenAI but use: `static let defaultProvider: AIProvider = .anthropic`

**Cost:** ~$0.003-0.005 per dream interpretation (Claude 3.5 Sonnet)

## Usage

### Tracking a Dream Session
1. Tap "Start Dream Mode" in the app
2. Let the timer run (use simulated data for testing, or real sleep for production)
3. Tap "Stop Tracking"
4. **AI processing begins automatically** (loading indicator appears)
5. View your dream in the main list

### Viewing AI Interpretation
1. Tap on any dream card
2. Dream Detail view shows:
   - ✨ **AI Dream Interpretation** section (if generated)
   - Poetic narrative describing your dream
   - Theme tags (clickable pills)
   - Intensity & Lucidity progress bars
3. Tap **"Play Dream Visualization"** to see full AI-enhanced animation

### AI-Enhanced Visualization Features
- **Background**: Mood-specific color gradients
- **Particles**: 60 dynamic particles with AI-controlled movement
- **Central Orb**: Rotating symbolic representation with emoji
- **Floating Themes**: Horizontal scrolling theme tags
- **Narrative Overlay**: Slides up after 2 seconds with full story
- **Consciousness Ring**: Appears for lucid dreams (>50% consciousness)

## Privacy & Data

### What Gets Sent to AI (if enabled):
- Sleep duration
- Average heart rate & HRV
- Movement percentage
- REM & deep sleep percentages
- Ambient noise level
- Current mood classification

### What Does NOT Get Sent:
- Your name or personal information
- Location data
- Photos or images
- Previous dream history
- Any other app data

### Local-Only Mode (Default):
- **Zero data leaves your device**
- All processing happens on-iPhone
- No internet connection required
- Full privacy guaranteed

## Troubleshooting

### "API key not configured" message
✅ **This is normal!** The app automatically falls back to local interpretation. Everything works perfectly without an API key.

### AI interpretation not showing
- Check if AI processing indicator appeared after stopping tracking
- Verify internet connection (if using OpenAI/Anthropic)
- Check API key is valid (if configured)
- Local fallback will be used automatically if AI fails

### Visualization not appearing
- Ensure you tapped "Play Dream Visualization" button
- Check that dream data was saved (appears in main list)
- Try force-closing and reopening the app

### Build errors
If you get compilation errors:
```bash
cd "/Users/SEV0A/Iphone/GJSPO/DreamWeaver/Dream Vewawer"
xcodebuild -project "Dream Vewawer.xcodeproj" -scheme "Dream Vewawer" -destination 'platform=iOS Simulator,name=iPhone 16e' clean build
```

## Technical Details

### AI Interpretation Algorithm
The AI analyzes biosignals to determine:
- **Peaceful dreams**: High HRV (>60) + low movement (<0.3) + high deep sleep
- **Chaotic dreams**: Low HRV (<40) + high movement (>0.6)
- **Intense dreams**: High REM (>25%) + moderate movement
- **Calm dreams**: Balanced metrics

### Prompt Engineering
The system sends structured prompts requesting:
- Narrative: 2-3 sentence poetic dream story
- Mood: Emotional tone classification
- Themes: 3-5 identified dream themes
- Visual Prompt: Description for particle animation
- Intensity: Numerical scale for dream vividness
- Consciousness: Numerical scale for lucidity
- Symbolism: 2-4 symbolic elements

### Particle System
- 60 particles with individual trajectories
- Movement speed controlled by AI intensity
- Opacity pulsing for high consciousness dreams
- Chaotic velocity for turbulent moods
- Edge wrapping for continuous flow

## Examples

### Sample AI Narrative (Peaceful Dream)
> "Vast cosmic expanses unfold in slow motion. Stars breathe in rhythm with your heartbeat, galaxies swirl in deep blue silence. You float through infinite space, weightless and serene."

**Themes:** cosmos, infinity, serenity, transcendence  
**Symbolism:** ⭐️ stars, 🌑 void, ☯️ unity  
**Intensity:** 30% | Lucidity: 20%

### Sample AI Narrative (Chaotic Dream)
> "Rapid scenes flash and morph. Colors clash and swirl violently. You run through shifting landscapes where walls become water and floors dissolve beneath urgent footsteps."

**Themes:** urgency, transformation, chaos, pursuit  
**Symbolism:** 🔥 fire, ⚡️ storm, 🌀 maze, 🦋 metamorphosis  
**Intensity:** 90% | Lucidity: 70%

## Future Enhancements
- Export dream narratives as PDFs
- Share visualizations as videos
- Dream journal with AI insights over time
- Trend analysis across multiple nights
- Custom AI prompts and personalities
- Voice narration of dream stories

## Support
For issues or questions about AI dream interpretation:
- Check this guide first
- Verify setup steps completed correctly
- Test with local mode (always works)
- Review console logs for API errors
