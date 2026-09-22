---
name: Tamkeen Learning Adventure
colors:
  surface: '#f9f9ff'
  surface-dim: '#cbdbf9'
  surface-bright: '#f9f9ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f0f3ff'
  surface-container: '#e7eeff'
  surface-container-high: '#dee9ff'
  surface-container-highest: '#d5e3ff'
  on-surface: '#0b1c32'
  on-surface-variant: '#3c4947'
  inverse-surface: '#213148'
  inverse-on-surface: '#ebf1ff'
  outline: '#6c7a77'
  outline-variant: '#bbcac6'
  surface-tint: '#006a62'
  primary: '#006a62'
  on-primary: '#ffffff'
  primary-container: '#2ec4b6'
  on-primary-container: '#004c46'
  inverse-primary: '#4fdbcc'
  secondary: '#ae2f34'
  on-secondary: '#ffffff'
  secondary-container: '#ff6b6b'
  on-secondary-container: '#6d0010'
  tertiary: '#785a00'
  on-tertiary: '#ffffff'
  tertiary-container: '#d5aa43'
  on-tertiary-container: '#564000'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#70f8e8'
  primary-fixed-dim: '#4fdbcc'
  on-primary-fixed: '#00201d'
  on-primary-fixed-variant: '#005049'
  secondary-fixed: '#ffdad8'
  secondary-fixed-dim: '#ffb3b0'
  on-secondary-fixed: '#410006'
  on-secondary-fixed-variant: '#8c1520'
  tertiary-fixed: '#ffdf9b'
  tertiary-fixed-dim: '#edc157'
  on-tertiary-fixed: '#251a00'
  on-tertiary-fixed-variant: '#5b4300'
  background: '#f9f9ff'
  on-background: '#0b1c32'
  surface-variant: '#d5e3ff'
typography:
  display-lg:
    fontFamily: Lexend
    fontSize: 40px
    fontWeight: '800'
    lineHeight: 52px
    letterSpacing: 0.02em
  display-lg-mobile:
    fontFamily: Lexend
    fontSize: 30px
    fontWeight: '800'
    lineHeight: 40px
    letterSpacing: 0.02em
  headline-lg:
    fontFamily: Lexend
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 42px
    letterSpacing: 0.02em
  headline-lg-mobile:
    fontFamily: Lexend
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 34px
    letterSpacing: 0.02em
  headline-md:
    fontFamily: Lexend
    fontSize: 22px
    fontWeight: '700'
    lineHeight: 32px
    letterSpacing: 0.015em
  headline-sm:
    fontFamily: Lexend
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 28px
    letterSpacing: 0.01em
  body-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 18px
    fontWeight: '500'
    lineHeight: 30px
    letterSpacing: 0.025em
  body-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 16px
    fontWeight: '500'
    lineHeight: 26px
    letterSpacing: 0.02em
  body-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '500'
    lineHeight: 22px
    letterSpacing: 0.02em
  label-lg:
    fontFamily: Lexend
    fontSize: 16px
    fontWeight: '700'
    lineHeight: 24px
    letterSpacing: 0.03em
  label-md:
    fontFamily: Lexend
    fontSize: 14px
    fontWeight: '700'
    lineHeight: 20px
    letterSpacing: 0.03em
  label-sm:
    fontFamily: Lexend
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 18px
    letterSpacing: 0.02em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1rem
  gutter-tablet: 1.5rem
  gutter-desktop: 2rem
  margin: 1rem
  margin-tablet: 2rem
  margin-desktop: 3rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2.5rem
---

## Brand & Style

This design system embodies an encouraging, calm, and tactile 2.5D gamified aesthetic created specifically for children and young teens with neurodivergent needs (such as Dyslexia and Dyscalculia). The design balances the playful delight of a narrative game with the soothing, non-overstimulating clarity of a wellness interface.

The design movement combines **Tactile / Skeuomorphic Micro-Depth** with **Modern Cognitive Minimalism**:
- **Tactile Physicality (2.5D Juicy UI):** Interactive elements feature physical volume, bottom extrusion edges, and responsive press animations that compress downwards into their base, providing instant physical confirmation without visual noise.
- **Calm Cognitive Atmosphere:** Avoids frantic flashing, aggressive timer stress, or punitive error screens. Visual feedback relies on warm encouragement, steady pacing, and gentle multi-sensory reinforcement.
- **Bilingual Neuro-Accessibility:** Balanced baseline harmony between Arabic and Latin scripts, structured visual chunking, and wide letter/word breathing room to alleviate visual crowding and tracking strain.

## Colors

The palette balances focus-enhancing coolness, playful warmth, and high-legibility grounding:

- **Primary Teal (#2EC4B6):** The core grounding tone. Calming, focus-inducing, and stable. Used for primary progress paths, positive affirmative states, and focused interactive zones.
- **Warm Coral (#FF6B6B):** An energetic accent reserved for prominent calls to action, adventure checkpoints, and dynamic interaction targets. Warm rather than alarmist.
- **Sunny Yellow (#FFD166):** Represents celebration, stars, collectible gems, quest milestones, and soft highlighted states.
- **Magic Periwinkle (#6C5CE7):** Accent for special challenges, discovery tools, audio-read aloud controls, and creative mastery spaces.
- **Deep Slate / Navy (#1D2D44):** The essential high-contrast text and border color, delivering AAA contrast against cream/mint backdrops without the harsh glare of pure black (#000000).
- **Background Surfaces:** Off-white cream `#FDFCF7` and pale mint `#F0F7F4` reduce glare and prevent visual distortion common in Scotopic Sensitivity Syndrome / Meares-Irlen symptoms.
- **Gentle Feedback Rules:** Never use saturated warning red for mistakes. Incorrect or incomplete attempts trigger a warm amber glow (`#F59E0B`) accompanied by supportive mascot prompts rather than harsh negative indicators.

## Typography

Typography is calibrated to mitigate character inversion, crowding, and visual fatigue:

- **Typeface Roles:**
  - `Lexend` anchors all titles, milestones, numeric counters, and button labels. Its widened character forms and scientifically tested inter-letter spacing directly aid reading fluency and numerical parsing.
  - `Plus Jakarta Sans` handles long-form reading, interactive dialogues, and educational explanations with open apertures, distinct ascenders/descenders, and clear distinctions between `I`, `l`, and `1`.
- **Dyslexia & Dyscalculia Considerations:**
  - Standard body text uses heightened line heights (1.6x minimum) and an open letter-spacing baseline (`0.02em` to `0.03em`).
  - Numbers in mathematical modules maintain monospaced tabular figures with enlarged decimal points and distinct operational symbols to prevent positional confusion.
  - Arabic script pairings (such as Readex Pro) mirror the exact baseline x-height and stroke weight of the Latin tokens, ensuring parity during RTL/LTR toggles.

## Layout & Spacing

The layout is built upon a fluid grid with generous safe-zones designed for touch targets:

- **Form Factors & Breakpoints:**
  - **Mobile (<640px):** 4-column fluid layout with generous vertical rhythm. Interactive elements maintain an absolute minimum touch zone of 56px by 56px to support developing fine motor skills.
  - **Tablet (640px - 1024px):** 8-column layout. The adventure map can sprawl horizontally or in an undulating vertical path with a persistent side companion dock.
  - **Desktop / Large Tablet Landscape (>1024px):** 12-column layout max-width capped at 1120px to prevent visual tracking exhaustion across overly wide scan lines.
- **Rhythm & Chunking:**
  - Content sections are grouped into clearly distinct, self-contained visual "islands."
  - Vertical spacing uses predictable multipliers of `1rem` (`space-md`), preventing sensory overload by guaranteeing clear separation between interactive exercise zones and instructional headers.

## Elevation & Depth

This system avoids realistic photographic shadows or blurry ambient diffusions that soften component edges. Instead, it relies on crisp **2.5D physical extrusions and directional offsets**:

- **Physical Extrusion Edge:** Buttons, quest tokens, and active cards have a solid bottom border (3px to 5px thick) rendered in a darkened tint of the element's base color (e.g., `#2EC4B6` has an extrusion edge of `#228F85`).
- **Interactive State Compression:** On `:hover` or touch start, the physical element translates down on the Y-axis by 2px, reducing the visible base extrusion. On `:active`, it translates down the full 4px, giving tactile physical feedback before release.
- **Soft Ambient Under-Glow:** A crisp, low-blur drop shadow (`0 8px 16px rgba(29, 45, 68, 0.08)`) hovers underneath floating badges and modal cards to elevate them above the background canvas without creating visual noise or blurring boundaries.
- **High-Contrast Separation Lines:** White surfaces are framed with a soft 1.5px structural border (`rgba(29, 45, 68, 0.08)`) to maintain distinct visual containment for users with low contrast sensitivity.

## Shapes

The shape system is friendly, organic, and cushioned:

- **Geometry:** Corners follow a friendly `rounded-xl` (1.5rem / 24px) for interactive tiles and structural containers, with primary buttons using full pill boundaries (`9999px`) or `rounded-lg` (1rem / 16px).
- **Cognitive Purpose:** Sharp corners create subconscious visual tension and can lead to fixation. Generous, consistent radii keep the visual field soft, approachable, and safe to explore.
- **Badges & Dialogue Nodes:** Circular nodes, cloud-like speech bubbles with rounded tails, and soft star medallions reinforce the organic, gamified feel.

## Components

### 1. Tactile 2.5D Buttons
- **Structure:** Pill or 16px rounded rectangular buttons featuring a solid base height of 52px to 64px.
- **Styling:** Top surface filled with primary teal (`#2EC4B6`) or warm coral (`#FF6B6B`), supported by a darkened 4px bottom extrusion ledge.
- **Interaction:** Presses physically move the button surface down along the Y-axis by 4px, playing a soft click sound and subtle haptic tap.

### 2. Winding Quest Adventure Nodes
- **Structure:** Circular pathway nodes (64px mobile, 80px tablet) connected by a dashed stone or vine path.
- **States:**
  - *Completed:* Filled with Sunny Yellow (`#FFD166`), featuring a 3D star crest.
  - *Active / Current:* Bouncing subtle pulse, Primary Teal fill, rimmed with a glowing outer halo.
  - *Locked:* Soft stone grey-blue with gentle lock iconography, clear without feeling punitive.

### 3. Interactive Karaoke Reading Blocks
- **Structure:** Text card where words are displayed in enlarged `body-lg` / `headline-sm` with wide tracking.
- **Behavior:** As audio narration plays, individual words illuminate with a soft, high-contrast highlighting chip (pale warm yellow `#FEF3C7` background with a subtle border) accompanied by a bounding guide underline. Clicking any word replays its phoneme breakdown.

### 4. Dyscalculia Math Keypad & Doodle Canvas
- **Keypad:** Chunky, high-contrast isolated number blocks (minimum 60px target) separated by wide gaps (`space-md`). Keycaps use distinct colors for numbers versus operational symbols (`+`, `-`, `×`, `÷`) to prevent conceptual conflation.
- **Scratchpad Canvas:** An integrated pastel mint side-drawer enabling kids to hand-draw dots, tally lines, or grouping circles with automatic number grouping guides.

### 5. Mascot Dialogue & Speech Bubbles
- **Structure:** Card surface in pure white with a 2px deep-slate outline (`#1D2D44` at 15% opacity), accompanied by an anchored rounded pointer pointing directly to the character avatar.
- **Audio Assist:** Includes a prominent periwinkle floating "Listen" speaker button that reads aloud the mascot text at variable speeds (0.75x, 1x).

### 6. Star Badges & Progress Meters
- **Meter:** Rounded track with a soft cream trough and a thick, candy-stripe animated fill bar capped with a rounded edge.
- **Badge:** Concentric star or gem medallions rendered with golden bevels, avoided flat outlines in favor of tactile layered disks.

### 7. Caregiver & Educator Analytics Cards
- **Styling:** Calm, structured container with clean dividers, pastel indicator tags, and simplified bar progress charts that focus on positive growth trends, completed sessions, and areas needing support rather than negative scores or red flags.