<template>
  <div class="p-4">
    <!-- Header with sync status -->
    <div class="mb-4">
      <div class="flex items-center justify-between mb-2">
        <h1 class="text-2xl font-bold">Programs</h1>
        <button
          v-if="authStore.isAuthenticated"
          @click="authStore.signOut"
          class="text-sm text-gray-600 hover:text-gray-900"
        >
          Sign Out
        </button>
      </div>
      
      <div v-if="authStore.isAuthenticated" class="flex items-center gap-2 text-sm text-gray-600">
        <span class="w-2 h-2 rounded-full bg-green-500"></span>
        <span>Synced to cloud · {{ authStore.user.email }}</span>
      </div>
      <div v-else class="flex items-center gap-2 text-sm text-gray-600">
        <span class="w-2 h-2 rounded-full bg-gray-400"></span>
        <span>Offline only · <router-link to="/login" class="text-primary underline">Sign in to sync</router-link></span>
      </div>
    </div>

    <div class="flex items-center justify-between mb-6">
      <div></div>
      <button @click="showImportModal = true" class="btn-primary">
        + New Program
      </button>
    </div>

    <!-- Programs List -->
    <div v-if="programs.length > 0" class="space-y-3">
      <div
        v-for="program in programs"
        :key="program.id"
        class="card hover:shadow-md transition-shadow cursor-pointer"
        @click="selectProgram(program)"
      >
        <h3 class="font-semibold text-lg">{{ program.programName }}</h3>
        <p class="text-sm text-gray-600 mt-1">
          {{ program.workoutDays?.length || 0 }} workout days
        </p>
      </div>
    </div>

    <div v-else class="text-center py-12 text-gray-500">
      <p>No programs yet</p>
      <p class="text-sm mt-2">Import one to get started</p>
    </div>

    <!-- Program Details Modal -->
    <div
      v-if="selectedProgram"
      class="fixed inset-0 bg-black bg-opacity-50 flex items-end justify-center z-50"
      @click.self="selectedProgram = null"
    >
      <div class="bg-white rounded-t-2xl w-full max-w-lg p-6 max-h-[80vh] overflow-y-auto">
        <div class="flex items-center justify-between mb-4">
          <h2 class="text-xl font-bold">{{ selectedProgram.programName }}</h2>
          <button @click="selectedProgram = null" class="text-gray-600">✕</button>
        </div>

        <div class="space-y-3">
          <div
            v-for="day in selectedProgram.workoutDays"
            :key="day.dayId"
            class="border border-gray-200 rounded-lg p-3"
          >
            <h3 class="font-semibold mb-2">{{ day.dayName }}</h3>
            <p class="text-sm text-gray-600 mb-3">{{ day.exercises?.length || 0 }} exercises</p>
            <button
              @click="startWorkout(day)"
              class="btn-primary w-full"
            >
              Start Workout
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Import Modal -->
    <div
      v-if="showImportModal"
      class="fixed inset-0 bg-black bg-opacity-50 flex items-end justify-center z-50"
      @click.self="showImportModal = false"
    >
      <div class="bg-white rounded-t-2xl w-full max-w-lg p-6">
        <h2 class="text-xl font-bold mb-4">Import Program</h2>

        <div class="space-y-3 mb-4">
          <button
            @click="importType = 'markdown'"
            class="w-full p-3 border rounded-lg text-left"
            :class="importType === 'markdown' ? 'border-primary bg-primary/5' : 'border-gray-200'"
          >
            <div class="font-semibold">Markdown</div>
            <div class="text-sm text-gray-600">Plain text format</div>
          </button>

          <button
            @click="importType = 'json'"
            class="w-full p-3 border rounded-lg text-left"
            :class="importType === 'json' ? 'border-primary bg-primary/5' : 'border-gray-200'"
          >
            <div class="font-semibold">JSON</div>
            <div class="text-sm text-gray-600">Full program structure</div>
          </button>
        </div>

        <textarea
          v-model="importData"
          class="input w-full h-40 resize-none font-mono text-sm"
          :placeholder="importType === 'markdown' ? markdownExample : jsonExample"
        ></textarea>

        <div class="flex gap-2 mt-4">
          <button @click="showImportModal = false" class="btn-secondary flex-1">
            Cancel
          </button>
          <button @click="handleImport" class="btn-primary flex-1">
            Import
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useProgramsStore } from '../stores/programs'
import { useAuthStore } from '../stores/auth'
import { storeToRefs } from 'pinia'

const router = useRouter()
const programsStore = useProgramsStore()
const authStore = useAuthStore()
const { programs } = storeToRefs(programsStore)

const selectedProgram = ref(null)
const showImportModal = ref(false)
const importType = ref('markdown')
const importData = ref('')

const markdownExample = `# Program Name: My Program

## Day A
- Squat: 4×6-8 (rest: 180s)`

const jsonExample = `{
  "programName": "My Program",
  "workoutDays": [...]
}`

onMounted(() => {
  programsStore.loadPrograms()
})

function selectProgram(program) {
  selectedProgram.value = program
}

function startWorkout(day) {
  router.push({
    name: 'workout',
    params: {
      programId: selectedProgram.value.programId,
      dayId: day.dayId
    }
  })
}

async function handleImport() {
  try {
    if (importType.value === 'markdown') {
      await programsStore.importFromMarkdown(importData.value)
    } else {
      await programsStore.importFromJSON(importData.value)
    }
    showImportModal.value = false
    importData.value = ''
  } catch (error) {
    alert('Import failed: ' + error.message)
  }
}
</script>
