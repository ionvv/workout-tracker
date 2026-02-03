import { defineStore } from 'pinia'

export const useExercisesStore = defineStore('exercises', {
  state: () => ({
    exercises: [],
    loading: false,
    loaded: false
  }),

  getters: {
    // Get exercise by exerciseDbId
    getExerciseById: (state) => (exerciseDbId) => {
      return state.exercises.find(ex => ex.id === exerciseDbId)
    },

    // Search exercises by name, muscle group, equipment, etc.
    searchExercises: (state) => (query, filters = {}) => {
      let results = state.exercises

      // Text search (name, description, muscle groups)
      if (query) {
        const lowerQuery = query.toLowerCase()
        results = results.filter(ex => {
          const nameMatch = ex.name?.toLowerCase().includes(lowerQuery)
          const descMatch = ex.description?.toLowerCase().includes(lowerQuery)
          const muscleMatch = ex.muscleGroups?.primary?.some(m => m.toLowerCase().includes(lowerQuery))
          return nameMatch || descMatch || muscleMatch
        })
      }

      // Filter by muscle group
      if (filters.muscleGroup) {
        results = results.filter(ex => 
          ex.muscleGroups?.primary?.includes(filters.muscleGroup) ||
          ex.muscleGroups?.secondary?.includes(filters.muscleGroup)
        )
      }

      // Filter by equipment
      if (filters.equipment) {
        results = results.filter(ex => 
          ex.equipment?.includes(filters.equipment)
        )
      }

      // Filter by difficulty
      if (filters.difficulty) {
        results = results.filter(ex => ex.difficulty === filters.difficulty)
      }

      // Filter by category
      if (filters.category) {
        results = results.filter(ex => ex.category === filters.category)
      }

      return results
    }
  },

  actions: {
    async loadExercises() {
      if (this.loaded || this.loading) return
      
      this.loading = true
      try {
        const response = await fetch('/exercises-database.json')
        if (!response.ok) {
          throw new Error('Failed to load exercise database')
        }
        
        const data = await response.json()
        this.exercises = data.exercises || []
        this.loaded = true
      } catch (error) {
        console.error('Failed to load exercises:', error)
        this.exercises = []
      } finally {
        this.loading = false
      }
    },

    // Enrich a program's exercises with data from the exercise database
    enrichProgramExercises(program) {
      if (!program?.workoutDays) return program

      const enrichedProgram = { ...program }
      enrichedProgram.workoutDays = program.workoutDays.map(day => {
        const enrichedDay = { ...day }
        enrichedDay.exercises = day.exercises?.map(exercise => {
          // Flatten media URLs if nested
          const flatGifUrl = exercise.gifUrl || exercise.media?.gifUrl
          const flatVideoUrl = exercise.videoUrl || exercise.media?.videoUrl
          const flatThumbnailUrl = exercise.thumbnailUrl || exercise.media?.thumbnailUrl
          
          // If exercise has exerciseDbId, merge with database info
          if (exercise.exerciseDbId) {
            const dbExercise = this.getExerciseById(exercise.exerciseDbId)
            if (dbExercise) {
              return {
                ...exercise,
                // Add database fields if not already present (flattened)
                gifUrl: flatGifUrl || dbExercise.media?.gifUrl,
                videoUrl: flatVideoUrl || dbExercise.media?.videoUrl,
                thumbnailUrl: flatThumbnailUrl || dbExercise.media?.thumbnailUrl,
                demoUrl: exercise.demoUrl || dbExercise.demoUrl,
                instructions: exercise.instructions || dbExercise.instructions,
                formCues: exercise.formCues || dbExercise.formCues,
                muscleGroupsDb: dbExercise.muscleGroups,
                equipmentDb: dbExercise.equipment,
                difficultyDb: dbExercise.difficulty
              }
            }
          }
          // If no exerciseDbId, still flatten media URLs
          return {
            ...exercise,
            gifUrl: flatGifUrl,
            videoUrl: flatVideoUrl,
            thumbnailUrl: flatThumbnailUrl
          }
        })
        return enrichedDay
      })

      return enrichedProgram
    }
  }
})
