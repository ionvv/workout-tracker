# Workout Tracker

Fast, minimal workout tracking PWA built with Vue 3.

## Features

✅ **Program Management**
- Import workouts from Markdown or JSON
- Store multiple programs locally

✅ **Session Tracking**
- Real-time set logging during workouts
- Skip exercises, add notes
- Auto-calculates volume and duration

✅ **Export**
- JSON, CSV, Markdown formats
- Own your data

✅ **Analytics**
- Exercise progress tracking
- Personal records
- 1RM estimates (Epley formula)

✅ **Offline-First**
- IndexedDB storage
- Works without internet
- PWA installable

## Tech Stack

- **Vue 3** (Composition API)
- **Vite** (build tool)
- **Pinia** (state management)
- **Dexie.js** (IndexedDB wrapper)
- **Tailwind CSS** (styling)
- **Chart.js** (analytics)
- **Vite PWA Plugin** (service worker)

## Setup

```bash
npm install
npm run dev
```

Build for production:
```bash
npm run build
```

## Import Example (Markdown)

```markdown
# Program Name: 3-Day Recomp

## Day A - Squat/Push/Pull
- Back Squat: 4×6-8 (rest: 180s, notes: Heavy controlled)
- Bench Press: 4×6-8 (rest: 180s)
- Pull-ups: 4×8-10 (rest: 120s)

## Day B - Hinge/Press/Row
- Deadlift: 4×5 (rest: 180s)
- Overhead Press: 4×8 (rest: 120s)
```

## Architecture

```
src/
├── components/       # Reusable Vue components
├── views/           # Page components
│   ├── Programs.vue
│   ├── ActiveWorkout.vue
│   ├── History.vue
│   └── Analytics.vue
├── stores/          # Pinia state management
│   ├── programs.js
│   └── sessions.js
├── utils/           # Utilities
│   └── db.js        # Dexie database
└── router/          # Vue Router config
```

## Data Model

See product brief for complete schemas.

**Program:**
- programId, programName, workoutDays[]

**WorkoutDay:**
- dayId, dayName, exercises[]

**Exercise:**
- exerciseId, name, prescribedSets, prescribedReps, notes, restSeconds, demoUrl, type

**Session:**
- sessionId, programId, dayId, startTime, endTime, exercises[], totalVolume, totalSets, duration

## Contributing

Built by Engineer for Ion. No social features, no bloat—just track your work.

## License

MIT
