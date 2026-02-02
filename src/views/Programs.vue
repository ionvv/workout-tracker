<template>
  <div class="p-4">
    <!-- Header with sync status -->
    <div class="mb-4">
      <div class="flex items-center justify-between mb-2">
        <h1 class="text-2xl font-bold">Programs</h1>
        <router-link
          v-if="authStore.isAuthenticated"
          to="/profile"
          class="text-sm text-blue-600 hover:text-blue-700 flex items-center gap-1"
        >
          <span>Profile</span>
          <span>→</span>
        </router-link>
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

    <div class="flex gap-2 mb-6">
      <router-link to="/builder" class="btn-primary flex-1 text-center">
        🏗️ Build Workout
      </router-link>
      <button @click="showImportModal = true" class="btn-secondary flex-1">
        📄 Import
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
        <div class="flex items-start justify-between mb-2">
          <h3 class="font-semibold text-lg">{{ program.programName }}</h3>
          <span
            v-if="program.difficulty"
            class="text-xs px-2 py-1 rounded-full"
            :class="{
              'bg-green-100 text-green-700': program.difficulty === 'beginner',
              'bg-blue-100 text-blue-700': program.difficulty === 'intermediate',
              'bg-purple-100 text-purple-700': program.difficulty === 'advanced'
            }"
          >
            {{ program.difficulty }}
          </span>
        </div>
        
        <div class="flex items-center gap-4 text-sm text-gray-600">
          <span v-if="program.duration">📅 {{ program.duration }} weeks</span>
          <span v-if="program.weeklyFrequency">🔁 {{ program.weeklyFrequency }}x/week</span>
          <span v-if="program.workoutDays">💪 {{ program.workoutDays.length }} workouts</span>
        </div>
        
        <p v-if="program.description" class="text-sm text-gray-600 mt-2 line-clamp-2">
          {{ program.description }}
        </p>
        
        <div v-if="program.phases && program.phases.length > 0" class="mt-3 flex gap-1">
          <span
            v-for="phase in program.phases"
            :key="phase.phaseId"
            class="text-xs px-2 py-0.5 bg-gray-100 text-gray-600 rounded"
            :title="`${phase.phaseName}: Weeks ${phase.weeks.join(', ')}`"
          >
            {{ phase.phaseName }}
          </span>
        </div>
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
          <div>
            <h2 class="text-xl font-bold">{{ selectedProgram.programName }}</h2>
            <div v-if="selectedProgram.description" class="text-sm text-gray-600 mt-1">
              {{ selectedProgram.description }}
            </div>
          </div>
          <button @click="selectedProgram = null" class="text-gray-600 text-2xl">✕</button>
        </div>

        <!-- Program Metadata -->
        <div v-if="selectedProgram.duration || selectedProgram.difficulty || selectedProgram.goal" class="mb-4 p-3 bg-gray-50 rounded-lg space-y-2 text-sm">
          <div v-if="selectedProgram.duration" class="flex items-center gap-2">
            <span class="text-gray-500">Duration:</span>
            <span class="font-medium">{{ selectedProgram.duration }} weeks</span>
          </div>
          <div v-if="selectedProgram.weeklyFrequency" class="flex items-center gap-2">
            <span class="text-gray-500">Frequency:</span>
            <span class="font-medium">{{ selectedProgram.weeklyFrequency }}x per week</span>
          </div>
          <div v-if="selectedProgram.difficulty" class="flex items-center gap-2">
            <span class="text-gray-500">Level:</span>
            <span class="font-medium capitalize">{{ selectedProgram.difficulty }}</span>
          </div>
          <div v-if="selectedProgram.goal" class="flex items-center gap-2">
            <span class="text-gray-500">Goal:</span>
            <span class="font-medium capitalize">{{ selectedProgram.goal.replace(/-/g, ' ') }}</span>
          </div>
        </div>

        <!-- Phases -->
        <div v-if="selectedProgram.phases && selectedProgram.phases.length > 0" class="mb-4">
          <h3 class="text-sm font-semibold text-gray-700 mb-2">📈 Training Phases</h3>
          <div class="space-y-2">
            <div
              v-for="phase in selectedProgram.phases"
              :key="phase.phaseId"
              class="p-2 border border-gray-200 rounded-lg"
            >
              <div class="flex items-center justify-between">
                <span class="text-sm font-medium">{{ phase.phaseName }}</span>
                <span class="text-xs text-gray-500">Weeks {{ phase.weeks.join(', ') }}</span>
              </div>
              <p v-if="phase.notes" class="text-xs text-gray-600 mt-1">{{ phase.notes }}</p>
            </div>
          </div>
        </div>

        <h3 class="text-sm font-semibold text-gray-700 mb-3">💪 Workout Days</h3>
        <div class="space-y-3">
          <div
            v-for="day in selectedProgram.workoutDays"
            :key="day.dayId"
            class="border border-gray-200 rounded-lg overflow-hidden"
          >
            <!-- Day Header - Clickable to expand/collapse -->
            <div
              @click="toggleDay(day.dayId)"
              class="p-3 cursor-pointer hover:bg-gray-50 transition"
            >
              <div class="flex items-center justify-between">
                <div>
                  <h3 class="font-semibold">{{ day.dayName }}</h3>
                  <p class="text-sm text-gray-600">{{ day.exercises?.length || 0 }} exercises</p>
                </div>
                <span class="text-gray-400 transition-transform" :class="{ 'rotate-180': expandedDays.has(day.dayId) }">
                  ▼
                </span>
              </div>
            </div>

            <!-- Exercise List - Expanded -->
            <div v-if="expandedDays.has(day.dayId)" class="border-t border-gray-200 bg-gray-50">
              <div class="p-3 space-y-2">
                <div
                  v-for="(exercise, idx) in day.exercises"
                  :key="exercise.exerciseId"
                  class="bg-white rounded border border-gray-200 overflow-hidden"
                >
                  <!-- Exercise GIF (if available) -->
                  <div
                    v-if="exercise.gifUrl"
                    class="relative aspect-video bg-gray-100 overflow-hidden"
                  >
                    <img
                      :src="exercise.gifUrl"
                      :alt="exercise.name"
                      class="w-full h-full object-cover"
                      @error="handleImageError"
                    />
                    <!-- Exercise number badge -->
                    <div class="absolute top-2 left-2 bg-black bg-opacity-70 text-white text-xs font-semibold px-2 py-1 rounded">
                      {{ idx + 1 }}
                    </div>
                  </div>

                  <!-- Exercise Details -->
                  <div class="p-2">
                    <div class="flex items-start gap-2">
                      <span v-if="!exercise.gifUrl" class="text-xs font-semibold text-gray-400 mt-0.5">{{ idx + 1 }}</span>
                      <div class="flex-1">
                        <div class="flex items-center gap-2">
                          <span class="font-medium text-sm">{{ exercise.name }}</span>
                          <a
                            v-if="exercise.demoUrl"
                            :href="exercise.demoUrl"
                            target="_blank"
                            rel="noopener noreferrer"
                            class="text-blue-600 hover:text-blue-700"
                            title="View exercise details"
                          >
                            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"></path>
                            </svg>
                          </a>
                        </div>
                        <div class="text-xs text-gray-600 mt-0.5">
                          {{ exercise.prescribedSets }}×{{ exercise.prescribedReps }}
                          <span v-if="exercise.restSeconds" class="ml-2">• Rest: {{ formatRestTime(exercise.restSeconds) }}</span>
                        </div>
                        <div v-if="exercise.notes" class="text-xs text-gray-500 italic mt-1">
                          {{ exercise.notes }}
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>

              <!-- Start Workout Button -->
              <div class="p-3 pt-0">
                <button
                  @click.stop="startWorkout(day)"
                  class="btn-primary w-full"
                >
                  Start Workout
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Import Modal -->
    <div
      v-if="showImportModal"
      class="fixed inset-0 bg-black bg-opacity-50 flex items-end justify-center z-50"
      @click.self="closeImportModal"
    >
      <div class="bg-white rounded-t-2xl w-full max-w-lg p-6 max-h-[90vh] overflow-y-auto">
        <h2 class="text-xl font-bold mb-4">Import Program</h2>

        <!-- Error Message -->
        <div v-if="importError" class="mb-4 p-3 bg-red-50 border border-red-200 rounded-lg">
          <p class="text-sm text-red-600 font-semibold mb-1">Import Failed</p>
          <p class="text-sm text-red-600">{{ importError }}</p>
        </div>

        <!-- Pre-built Programs -->
        <div class="mb-6 p-4 bg-blue-50 border border-blue-200 rounded-lg">
          <h3 class="font-semibold text-sm mb-2">📦 Pre-built Programs</h3>
          <button
            @click="loadModifiedRomanianProgram"
            class="w-full p-3 bg-white border border-gray-200 rounded-lg text-left hover:border-primary hover:bg-primary/5 transition"
            :disabled="importLoading"
          >
            <div class="font-semibold text-sm">Modified Romanian 3-Day Recomp</div>
            <div class="text-xs text-gray-600 mt-1">12 weeks • 3 days/week • Intermediate</div>
            <div class="text-xs text-gray-500 mt-1">💪 Strength + Fat Loss • Full periodization</div>
          </button>
        </div>

        <div class="text-sm text-gray-500 mb-3 text-center">— or paste your own —</div>

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
          <button @click="closeImportModal" class="btn-secondary flex-1" :disabled="importLoading">
            Cancel
          </button>
          <button @click="handleImport" class="btn-primary flex-1" :disabled="importLoading || !importData">
            {{ importLoading ? 'Importing...' : 'Import' }}
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
const expandedDays = ref(new Set())
const importError = ref(null)
const importLoading = ref(false)

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
  expandedDays.value = new Set() // Reset expanded state
}

function toggleDay(dayId) {
  if (expandedDays.value.has(dayId)) {
    expandedDays.value.delete(dayId)
  } else {
    expandedDays.value.add(dayId)
  }
  // Trigger reactivity
  expandedDays.value = new Set(expandedDays.value)
}

function formatRestTime(seconds) {
  if (seconds < 60) return `${seconds}s`
  const minutes = Math.floor(seconds / 60)
  const remainingSeconds = seconds % 60
  if (remainingSeconds === 0) return `${minutes}m`
  return `${minutes}m ${remainingSeconds}s`
}

function handleImageError(event) {
  // Hide broken images gracefully
  event.target.style.display = 'none'
  // Show fallback if parent exists
  const parent = event.target.parentElement
  if (parent) {
    parent.classList.add('hidden')
  }
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

function closeImportModal() {
  showImportModal.value = false
  importData.value = ''
  importError.value = null
}

async function loadModifiedRomanianProgram() {
  importError.value = null
  importLoading.value = true
  
  try {
    const response = await fetch('/programs/modified-romanian-program.json')
    if (!response.ok) {
      throw new Error('Failed to load program file')
    }
    
    const programData = await response.json()
    const jsonString = JSON.stringify(programData, null, 2)
    await programsStore.importFromJSON(jsonString)
    
    // Success!
    closeImportModal()
  } catch (error) {
    console.error('Load program error:', error)
    importError.value = 'Failed to load Modified Romanian program. ' + error.message
  } finally {
    importLoading.value = false
  }
}

async function handleImport() {
  importError.value = null
  importLoading.value = true
  
  try {
    if (!importData.value.trim()) {
      throw new Error('Please enter program data to import')
    }

    if (importType.value === 'markdown') {
      await programsStore.importFromMarkdown(importData.value)
    } else {
      await programsStore.importFromJSON(importData.value)
    }
    
    // Success!
    closeImportModal()
  } catch (error) {
    console.error('Import error:', error)
    
    // Parse error message for user-friendly display
    let errorMsg = error.message
    
    if (errorMsg.includes('duplicate key') || errorMsg.includes('unique constraint')) {
      errorMsg = 'A program with this ID already exists. Please delete the existing program first or use a different program ID.'
    } else if (errorMsg.includes('JSON')) {
      errorMsg = 'Invalid JSON format. Please check your JSON syntax.'
    } else if (errorMsg.includes('markdown')) {
      errorMsg = 'Invalid markdown format. Please check the format.'
    }
    
    importError.value = errorMsg
  } finally {
    importLoading.value = false
  }
}
</script>
