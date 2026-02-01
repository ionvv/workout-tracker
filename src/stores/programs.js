import { defineStore } from 'pinia'
import { db } from '../utils/db'
import { supabase } from '../utils/supabase'
import { useAuthStore } from './auth'

export const useProgramsStore = defineStore('programs', {
  state: () => ({
    programs: [],
    loading: false,
    syncing: false
  }),

  actions: {
    async loadPrograms() {
      this.loading = true
      try {
        // Load from IndexedDB first (offline-first)
        this.programs = await db.programs.toArray()
        
        // Then sync from Supabase if authenticated
        const authStore = useAuthStore()
        if (authStore.isAuthenticated) {
          await this.syncFromCloud()
        }
      } catch (error) {
        console.error('Failed to load programs:', error)
      } finally {
        this.loading = false
      }
    },

    async syncFromCloud() {
      if (this.syncing) return
      
      this.syncing = true
      try {
        const { data, error } = await supabase
          .from('programs')
          .select('*')
          .order('created_at', { ascending: false })
        
        if (error) throw error
        
        if (data && data.length > 0) {
          // Clear local DB and replace with cloud data
          await db.programs.clear()
          
          for (const program of data) {
            await db.programs.add({
              programId: program.program_id,
              programName: program.program_name,
              workoutDays: program.workout_days,
              createdAt: program.created_at
            })
          }
          
          this.programs = await db.programs.toArray()
        }
      } catch (error) {
        console.error('Sync from cloud failed:', error)
      } finally {
        this.syncing = false
      }
    },

    async syncToCloud(program) {
      const authStore = useAuthStore()
      if (!authStore.isAuthenticated) return
      
      try {
        const { error } = await supabase
          .from('programs')
          .upsert({
            user_id: authStore.user.id,
            program_id: program.programId,
            program_name: program.programName,
            workout_days: program.workoutDays,
            created_at: program.createdAt
          })
        
        if (error) throw error
      } catch (error) {
        console.error('Sync to cloud failed:', error)
      }
    },

    async addProgram(program) {
      const programData = {
        ...program,
        createdAt: new Date().toISOString()
      }
      
      const id = await db.programs.add(programData)
      await this.syncToCloud(programData)
      await this.loadPrograms()
      return id
    },

    async updateProgram(programId, updates) {
      await db.programs.update(programId, updates)
      const program = await db.programs.get(programId)
      await this.syncToCloud(program)
      await this.loadPrograms()
    },

    async deleteProgram(programId) {
      const program = await db.programs.get(programId)
      await db.programs.delete(programId)
      
      const authStore = useAuthStore()
      if (authStore.isAuthenticated && program) {
        await supabase
          .from('programs')
          .delete()
          .eq('user_id', authStore.user.id)
          .eq('program_id', program.programId)
      }
      
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
