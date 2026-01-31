import { defineStore } from 'pinia'
import { db } from '../utils/db'

export const useProgramsStore = defineStore('programs', {
  state: () => ({
    programs: [],
    loading: false
  }),

  actions: {
    async loadPrograms() {
      this.loading = true
      try {
        this.programs = await db.programs.toArray()
      } catch (error) {
        console.error('Failed to load programs:', error)
      } finally {
        this.loading = false
      }
    },

    async addProgram(program) {
      const id = await db.programs.add({
        ...program,
        createdAt: new Date().toISOString()
      })
      await this.loadPrograms()
      return id
    },

    async updateProgram(programId, updates) {
      await db.programs.update(programId, updates)
      await this.loadPrograms()
    },

    async deleteProgram(programId) {
      await db.programs.delete(programId)
      await this.loadPrograms()
    },

    async importFromJSON(jsonData) {
      const program = JSON.parse(jsonData)
      return await this.addProgram(program)
    },

    async importFromMarkdown(markdown) {
      const program = this.parseMarkdown(markdown)
      return await this.addProgram(program)
    },

    parseMarkdown(markdown) {
      const lines = markdown.split('\n')
      let program = {
        programName: '',
        workoutDays: []
      }
      let currentDay = null

      for (const line of lines) {
        const trimmed = line.trim()

        // Program name (# Program Name: ...)
        if (trimmed.startsWith('# Program Name:')) {
          program.programName = trimmed.replace('# Program Name:', '').trim()
        }

        // Day name (## Day A - ...)
        else if (trimmed.startsWith('##')) {
          if (currentDay) program.workoutDays.push(currentDay)
          currentDay = {
            dayName: trimmed.replace('##', '').trim(),
            exercises: []
          }
        }

        // Exercise (- Exercise: 4×6-8 ...)
        else if (trimmed.startsWith('-') && currentDay) {
          const exercise = this.parseExerciseLine(trimmed)
          if (exercise) currentDay.exercises.push(exercise)
        }
      }

      if (currentDay) program.workoutDays.push(currentDay)
      return program
    },

    parseExerciseLine(line) {
      // Format: - ExerciseName: 4×6-8 (rest: 180s, notes: ..., demo: ...)
      const match = line.match(/^-\s+([^:]+):\s+(\d+)×([\d-]+)(.*)/)
      if (!match) return null

      const [, name, sets, reps, rest] = match

      // Extract rest time
      const restMatch = rest.match(/rest:\s*(\d+)s/)
      const restSeconds = restMatch ? parseInt(restMatch[1]) : 120

      // Extract notes
      const notesMatch = rest.match(/notes:\s*([^,)]+)/)
      const notes = notesMatch ? notesMatch[1].trim() : ''

      // Extract demo URL
      const demoMatch = rest.match(/demo:\s*(https?:\/\/[^\s),]+)/)
      const demoUrl = demoMatch ? demoMatch[1] : ''

      return {
        name: name.trim(),
        prescribedSets: parseInt(sets),
        prescribedReps: reps.trim(),
        restSeconds,
        notes,
        demoUrl,
        type: 'compound' // default
      }
    }
  }
})
