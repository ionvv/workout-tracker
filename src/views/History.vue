<template>
  <div class="p-4">
    <h1 class="text-2xl font-bold mb-6">History</h1>

    <div v-if="sessions.length > 0" class="space-y-3">
      <div
        v-for="session in sortedSessions"
        :key="session.sessionId"
        class="card cursor-pointer hover:shadow-md transition-shadow"
        @click="selectedSession = session"
      >
        <div class="flex items-start justify-between">
          <div class="flex-1">
            <h3 class="font-semibold">{{ session.dayName }}</h3>
            <p class="text-sm text-gray-600 mt-1">
              {{ formatDate(session.startTime) }}
            </p>
            <p class="text-sm text-gray-600">
              {{ session.totalSets }} sets · {{ session.duration }} min · {{ session.totalVolume }}kg total
            </p>
          </div>
        </div>
      </div>
    </div>

    <div v-else class="text-center py-12 text-gray-500">
      <p>No workouts logged yet</p>
      <p class="text-sm mt-2">Start your first workout!</p>
    </div>

    <!-- Session Detail Modal -->
    <div
      v-if="selectedSession"
      class="fixed inset-0 bg-black bg-opacity-50 flex items-end justify-center z-50"
      @click.self="selectedSession = null"
    >
      <div class="bg-white rounded-t-2xl w-full max-w-lg p-6 max-h-[80vh] overflow-y-auto">
        <div class="flex items-center justify-between mb-4">
          <h2 class="text-xl font-bold">{{ selectedSession.dayName }}</h2>
          <button @click="selectedSession = null" class="text-gray-600">✕</button>
        </div>

        <div class="text-sm text-gray-600 mb-4">
          <p>{{ formatDate(selectedSession.startTime) }}</p>
          <p>Duration: {{ selectedSession.duration }} minutes</p>
          <p>Total Volume: {{ selectedSession.totalVolume }}kg</p>
        </div>

        <div class="space-y-4 mb-6">
          <div
            v-for="exercise in selectedSession.exercises"
            :key="exercise.exerciseId"
            v-show="!exercise.skipped"
          >
            <h3 class="font-semibold mb-2">{{ exercise.exerciseName }}</h3>
            <div class="space-y-1 text-sm">
              <div v-for="set in exercise.sets" :key="set.setNumber">
                Set {{ set.setNumber }}: {{ set.weight }}kg × {{ set.reps }} reps
                <span v-if="set.rpe" class="text-gray-500">(RPE: {{ set.rpe }})</span>
              </div>
            </div>
          </div>
        </div>

        <div v-if="selectedSession.notes" class="mb-6 p-3 bg-gray-50 rounded-lg">
          <p class="text-sm font-semibold mb-1">Notes:</p>
          <p class="text-sm text-gray-700">{{ selectedSession.notes }}</p>
        </div>

        <div class="space-y-2">
          <button @click="exportJSON" class="btn-secondary w-full">Export JSON</button>
          <button @click="exportCSV" class="btn-secondary w-full">Export CSV</button>
          <button @click="exportMarkdown" class="btn-secondary w-full">Export Markdown</button>
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
const selectedSession = ref(null)

const sortedSessions = computed(() => {
  return [...sessions.value].sort((a, b) => 
    new Date(b.startTime) - new Date(a.startTime)
  )
})

onMounted(() => {
  sessionsStore.loadSessions()
})

function formatDate(isoString) {
  const date = new Date(isoString)
  return date.toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  })
}

function downloadFile(content, filename, type) {
  const blob = new Blob([content], { type })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = filename
  a.click()
  URL.revokeObjectURL(url)
}

function exportJSON() {
  const json = sessionsStore.exportSessionJSON(selectedSession.value)
  const date = new Date(selectedSession.value.startTime).toISOString().split('T')[0]
  downloadFile(json, `workout-${date}.json`, 'application/json')
}

function exportCSV() {
  const csv = sessionsStore.exportSessionCSV(selectedSession.value)
  const date = new Date(selectedSession.value.startTime).toISOString().split('T')[0]
  downloadFile(csv, `workout-${date}.csv`, 'text/csv')
}

function exportMarkdown() {
  const md = sessionsStore.exportSessionMarkdown(selectedSession.value)
  const date = new Date(selectedSession.value.startTime).toISOString().split('T')[0]
  downloadFile(md, `workout-${date}.md`, 'text/markdown')
}
</script>
