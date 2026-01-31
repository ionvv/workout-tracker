import Dexie from 'dexie'

export const db = new Dexie('WorkoutTrackerDB')

db.version(1).stores({
  programs: '++id, programId, programName, createdAt',
  sessions: '++id, sessionId, programId, dayId, startTime, endTime'
})

export default db
