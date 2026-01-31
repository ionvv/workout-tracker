<template>
  <div class="p-4">
    <h1 class="text-2xl font-bold mb-6">Analytics</h1>

    <div v-if="sessions.length === 0" class="text-center py-12 text-gray-500">
      <p>No data yet</p>
      <p class="text-sm mt-2">Complete some workouts to see progress!</p>
    </div>

    <div v-else class="space-y-6">
      <!-- Summary Cards -->
      <div class="grid grid-cols-2 gap-3">
        <div class="card">
          <p class="text-sm text-gray-600">Total Workouts</p>
          <p class="text-2xl font-bold">{{ sessions.length }}</p>
        </div>

        <div class="card">
          <p class="text-sm text-gray-600">Total Volume</p>
          <p class="text-2xl font-bold">{{ totalVolume }}kg</p>
        </div>

        <div class="card">
          <p class="text-sm text-gray-600">Total Sets</p>
          <p class="text-2xl font-bold">{{ totalSets }}</p>
        </div>

        <div class="card">
          <p class="text-sm text-gray-600">Avg Duration</p>
          <p class="text-2xl font-bold">{{ avgDuration }}min</p>
        </div>
      </div>

      <!-- Exercise Selection -->
      <div class="card">
        <label class="block text-sm font-medium mb-2">Select Exercise</label>
        <select v-model="selectedExercise" class="input w-full">
          <option value="">-- Select --</option>
          <option v-for="name in uniqueExercises" :key="name" :value="name">
            {{ name }}
          </option>
        </select>
      </div>

      <!-- Exercise Progress -->
      <div v-if="selectedExercise" class="card">
        <h3 class="font-semibold mb-4">{{ selectedExercise }} Progress</h3>

        <div class="space-y-2">
          <div v-for="(entry, index) in exerciseProgress" :key="index" class="border-b pb-2">
            <p class="text-sm font-semibold">{{ formatDate(entry.date) }}</p>
            <div class="text-xs text-gray-600 space-y-1">
              <div v-for="(set, i) in entry.sets" :key="i">
                Set {{ i + 1 }}: {{ set.weight }}kg × {{ set.reps }} reps
                <span v-if="set.rpe" class="text-gray-500">(RPE: {{ set.rpe }})</span>
              </div>
            </div>
            <p class="text-xs text-gray-500 mt-1">
              Max: {{ maxWeight(entry.sets) }}kg × {{ maxReps(entry.sets) }} reps
              · Est 1RM: {{ estimate1RM(entry.sets) }}kg
            </p>
          </div>
        </div>
      </div>

      <!-- Personal Records -->
      <div v-if="selectedExercise" class="card">
        <h3 class="font-semibold mb-2">Personal Records</h3>
        <div class="space-y-1 text-sm">
          <p><span class="font-medium">Heaviest Weight:</span> {{ pr.maxWeight }}kg</p>
          <p><span class="font-medium">Most Reps:</span> {{ pr.maxReps }} reps</p>
          <p><span class="font-medium">Best Est. 1RM:</span> {{ pr.best1RM }}kg</p>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, computed } from 'vue'
import { useSessionsStore } from '../stores/sessions'
import { storeToRefs } from 'pinia'

const sessionsStore = useSessionsStore()
const { sessions } = storeToRefs(sessionsStore)
const selectedExercise = ref('')

onMounted(() => {
  sessionsStore.loadSessions()
})

const totalVolume = computed(() => {
  return sessions.value.reduce((sum, s) => sum + (s.totalVolume || 0), 0)
})

const totalSets = computed(() => {
  return sessions.value.reduce((sum, s) => sum + (s.totalSets || 0), 0)
})

const avgDuration = computed(() => {
  if (sessions.value.length === 0) return 0
  const total = sessions.value.reduce((sum, s) => sum + (s.duration || 0), 0)
  return Math.round(total / sessions.value.length)
})

const uniqueExercises = computed(() => {
  const names = new Set()
  sessions.value.forEach(session => {
    session.exercises?.forEach(ex => {
      if (!ex.skipped && ex.sets?.length > 0) {
        names.add(ex.exerciseName)
      }
    })
  })
  return Array.from(names).sort()
})

const exerciseProgress = computed(() => {
  if (!selectedExercise.value) return []
  return sessionsStore.exerciseHistory(selectedExercise.value)
})

const pr = computed(() => {
  if (!selectedExercise.value || exerciseProgress.value.length === 0) {
    return { maxWeight: 0, maxReps: 0, best1RM: 0 }
  }

  let maxWeight = 0
  let maxReps = 0
  let best1RM = 0

  exerciseProgress.value.forEach(entry => {
    entry.sets.forEach(set => {
      if (set.weight > maxWeight) maxWeight = set.weight
      if (set.reps > maxReps) maxReps = set.reps
      const est1RM = set.weight * (1 + set.reps / 30) // Epley formula
      if (est1RM > best1RM) best1RM = est1RM
    })
  })

  return {
    maxWeight: Math.round(maxWeight),
    maxReps,
    best1RM: Math.round(best1RM)
  }
})

function formatDate(isoString) {
  const date = new Date(isoString)
  return date.toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric'
  })
}

function maxWeight(sets) {
  return Math.max(...sets.map(s => s.weight))
}

function maxReps(sets) {
  return Math.max(...sets.map(s => s.reps))
}

function estimate1RM(sets) {
  const best = sets.reduce((max, set) => {
    const est = set.weight * (1 + set.reps / 30)
    return est > max ? est : max
  }, 0)
  return Math.round(best)
}
</script>
