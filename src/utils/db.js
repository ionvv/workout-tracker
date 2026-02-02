import Dexie from 'dexie'

export const db = new Dexie('WorkoutTrackerDB')

// Version 1: Original schema
db.version(1).stores({
  programs: '++id, programId, programName, createdAt',
  sessions: '++id, sessionId, programId, dayId, startTime, endTime'
})

// Version 2: Add schema support for v2.0 program format
// New fields: duration, weeklyFrequency, difficulty, goal, phases
// progressCheckins: weekly check-ins (weight, waist, photos)
// exerciseHistory: track weights/reps per exercise over time
db.version(2).stores({
  programs: '++id, programId, programName, programType, difficulty, goal, createdAt',
  sessions: '++id, sessionId, programId, dayId, weekNumber, startTime, endTime',
  progressCheckins: '++id, programId, weekNumber, date, bodyWeight, waistMeasurement',
  exerciseHistory: '++id, programId, exerciseId, sessionId, date, weight, reps, rpe'
})

export default db
