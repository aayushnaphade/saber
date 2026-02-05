# SynapseAI Visual Integrity Registry

This file serves as a source of truth for "Premium" UI components and animations. AI Agents MUST respect the boundaries defined here to avoid regressions in high-fidelity design work.

## Protected Premium Components

### 1. Live Queue Card (App Dashboard)
- **Path**: `lib/pages/home/dashboard/widgets/live_queue_card.dart`
- **Visual Style**: Apple-style Mesh Gradient with fluid liquid mixing.
- **Rules**:
    - **DO NOT** replace the `MeshGradient` with standard gradients.
    - **DO NOT** change the 60s animation duration without adjusting frequency multipliers.
    - **DO NOT** flatten the glass overlay.
    - **CONTEXT**: This is distinct from the "Reception Portal" queue card. Modifications to one should NOT accidentally affect the other.

### 2. AI Thinking Orb (Report Generation)
- **Path**: `lib/pages/editor/editor.dart` (specifically `_ReportGenerationDialog`) and `lib/components/animations/mesh_orb.dart`.
- **Visual Style**: Pulsing Mesh Orb with full-screen particle absorption.
- **Rules**:
    - **DO NOT** revert to the old circular waveform.
    - **DO NOT** change the `brandColors` (Navy, Sky, Emerald) as they define the AI's identity.
    - **DO NOT** remove the pulsing box shadows or the immersive radial background.


### 3. Login Page (Saber App)
- **Paths**: `lib/pages/user/supabase_login.dart` and `lib/components/misc/flowing_gradient_background.dart`.
- **Visual Style**: Liquid Flowing Mesh Gradient with a minimalist white card.
- **Rules**:
    - **DO NOT** replace `FlowingGradientBackground` with static glassmorphism or `EtherealBackground`.
    - **DO NOT** restore "Sign Up" functionality; it has been intentionally removed.
    - **DO NOT** modify the 60s animation loop duration; this is tuned for a slow liquid mixing effect.
    - **PRESERVE** the logo layout: Single internal-card logo in Portrait, 300px scale sidebar logo in Landscape.
    - **BRANDING**: Always use the official `assets/images/logo.png`.

## Design Tokens (Primary Brand)
- **Navy**: `#0A4D8B`
- **Sky**: `#50B9E8`
- **Emerald**: `#10B981`
- **Deep Teal**: `#0D9488`

## Workflow for Modifications
Before modifying any file listed in this registry:
1. Search the codebase for other instances of similar components (e.g., search for "QueueCard").
2. Verify if the requested change is intended for the "Tablet App" (Saber) or the "Web Portal" (Synapse).
3. If in doubt, ask the user to specify the target platform explicitly.
