import { defineStore } from 'pinia'
import { db } from '../utils/db'

export const useSessionsStore = defineStore('sessions', {
  state: () => ({
    sessions: [],
    activeSession: null,
    loading: false
  }),

  getters: {
    isSessionActive: (state) => !!state.activeSession,
    
    sessionsByDate: (state) => {
      return state.sessions.reduce((acc, session) => {
        const date = new Date(session.startTime).toISOString().split('T')[0]
        if (!acc[date]) acc[date] = []
        acc[date].push(session)
        return acc
      }, {})
    },

    exerciseHistory: (state) => (exerciseName) => {
      return state.sessions
        .flatMap(session => 
          session.exercises
            .filter(ex => ex.exerciseName === exerciseName && !ex.skipped)
            .map(ex => ({
              date: session.startTime,
              sets: ex.sets
            }))
        )
        .sort((a, b) => new Date(a.date) - new Date(b.date))
    }
  },

  actions: {
    async loadSessions() {
      this.loading = true
      try {
        this.sessions = await db.sessions.toArray()
      } catch (error) {
        console.error('Failed to load sessions:', error)
      } finally {
        this.loading = false
      }
    },

    async startSession(program, day) {
      this.activeSession = {
        sessionId: crypto.randomUUID(),
        programId: program.programId,
        dayId: day.dayId,
        dayName: day.dayName,
        startTime: new Date().toISOString(),
        endTime: null,
        exercises: day.exercises.map(ex => ({
          exerciseId: ex.exerciseId,
          exerciseName: ex.name,
          prescribedSets: ex.prescribedSets,
          prescribedReps: ex.prescribedReps,
          sets: [],
          skipped: false
        })),
        notes: ''
      }
    },

    addSet(exerciseIndex, weight, reps, rpe = null) {
      if (!this.activeSession) return

      const exercise = this.activeSession.exercises[exerciseIndex]
      exercise.sets.push({
        setNumber: exercise.sets.length + 1,
        weight: parseFloat(weight),
        reps: parseInt(reps),
        timestamp: new Date().toISOString(),
        rpe
      })
    },

    skipExercise(exerciseIndex) {
      if (!this.activeSession) return
      this.activeSession.exercises[exerciseIndex].skipped = true
    },

    async endSession(notes = '') {
      if (!this.activeSession) return

      this.activeSession.endTime = new Date().toISOString()
      this.activeSession.notes = notes

      // Calculate total volume
      const totalVolume = this.activeSession.exercises.reduce((sum, ex) => {
        return sum + ex.sets.reduce((exSum, set) => {
          return exSum + (set.weight * set.reps)
        }, 0)
      }, 0)

      this.activeSession.totalVolume = totalVolume
      this.activeSession.totalSets = this.activeSession.exercises.reduce((sum, ex) => sum + ex.sets.length, 0)
      
      const start = new Date(this.activeSession.startTime)
      const end = new Date(this.activeSession.endTime)
      this.activeSession.duration = Math.round((end - start) / 1000 / 60) // minutes

      await db.sessions.add(this.activeSession)
      await this.loadSessions()

      this.activeSession = null
    },

    async deleteSession(sessionId) {
      await db.sessions.delete(sessionId)
      await this.loadSessions()
    },

    exportSessionJSON(session) {
      return JSON.stringify(session, null, 2)
    },

    exportSessionCSV(session) {
      let csv = 'Date,Exercise,Set,Weight(kg),Reps,RPE\n'
      const date = new Date(session.startTime).toISOString().split('T')[0]
      
      session.exercises.forEach(exercise => {
        exercise.sets.forEach(set => {
          csv += `${date},${exercise.exerciseName},${set.setNumber},${set.weight},${set.reps},${set.rpe || ''}\n`
        })
      })
      
      return csv
    },

    exportSessionMarkdown(session) {
      let md = `# Workout Session - ${session.dayName}\n\n`
      md += `**Date:** ${new Date(session.startTime).toISOString().split('T')[0]}\n`
      md += `**Duration:** ${session.duration} minutes\n\n`

      session.exercises.forEach(exercise => {
        if (exercise.skipped) return
        
        md += `## ${exercise.exerciseName}\n`
        exercise.sets.forEach(set => {
          md += `- Set ${set.setNumber}: ${set.weight}kg × ${set.reps} reps`
          if (set.rpe) md += ` (RPE: ${set.rpe})`
          md += '\n'
        })
        md += '\n'
      })

      if (session.notes) {
        md += `**Notes:** ${session.notes}\n`
      }

      return md
    }
  }
})
