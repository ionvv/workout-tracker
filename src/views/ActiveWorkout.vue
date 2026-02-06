<template>
  <div class="p-4">
    <div v-if="!session" class="text-center py-12">
      <p class="text-gray-600">Loading workout...</p>
    </div>

    <div v-else>
      <!-- Header -->
      <div class="mb-6">
        <h1 class="text-2xl font-bold">{{ session.dayName }}</h1>
        <div class="flex items-center justify-between">
          <p class="text-sm text-gray-600">
            Started: {{ formatTime(session.startTime) }}
          </p>
          <p class="text-sm font-semibold text-primary">
            {{ workoutDuration }}
          </p>
        </div>
      </div>

      <!-- Warm-up Section -->
      <div v-if="currentDay?.warmup && currentDay.warmup.exercises?.length > 0" class="mb-6">
        <div class="flex items-center gap-2 mb-3">
          <h2 class="text-lg font-semibold">🔥 Warm-up</h2>
          <span class="text-sm text-gray-500">({{ currentDay.warmup.duration || 5 }} min)</span>
        </div>
        <div class="card p-4 bg-orange-50 border-orange-200">
          <ul class="space-y-2 text-sm">
            <li v-for="(ex, idx) in currentDay.warmup.exercises" :key="idx" class="flex items-start gap-2">
              <span class="text-gray-400">{{  idx + 1 }}.</span>
              <div class="flex-1">
                <span class="font-medium">{{ ex.name }}</span>
                <span v-if="ex.duration" class="text-gray-600 ml-2">({{ ex.duration }}s)</span>
                <span v-if="ex.reps" class="text-gray-600 ml-2">({{ ex.reps }} reps)</span>
                <span v-if="ex.sets" class="text-gray-600 ml-2">× {{ ex.sets }}</span>
              </div>
            </li>
          </ul>
        </div>
      </div>

      <!-- Main Exercises -->
      <div class="space-y-4">
        <div
          v-for="(exercise, index) in session.exercises"
          :key="exercise.exerciseId"
          class="card overflow-hidden p-0"
        >
          <!-- Exercise GIF -->
          <div
            v-if="getExerciseData(index)?.gifUrl"
            class="relative aspect-video bg-gray-100 overflow-hidden"
          >
            <img
              :src="getExerciseData(index).gifUrl"
              :alt="exercise.exerciseName"
              class="w-full h-full object-cover"
              @error="handleImageError"
            />
            <div class="absolute top-2 left-2 bg-black bg-opacity-70 text-white text-sm font-semibold px-3 py-1 rounded">
              Exercise {{ index + 1 }} of {{ session.exercises.length }}
            </div>
            <span v-if="exercise.sets.length > 0" class="absolute top-2 right-2 bg-green-500 text-white text-2xl rounded-full w-8 h-8 flex items-center justify-center">
              ✓
            </span>
          </div>

          <!-- Exercise Content -->
          <div class="p-4">
            <!-- Exercise Header -->
            <div class="flex items-start justify-between mb-3">
              <div class="flex-1">
                <div class="flex items-center gap-2">
                  <span class="text-lg font-semibold">
                    <span v-if="!getExerciseData(index)?.gifUrl">{{ index + 1 }}. </span>{{ exercise.exerciseName }}
                  </span>
                  <a
                    v-if="getExerciseData(index)?.demoUrl"
                    :href="getExerciseData(index).demoUrl"
                    target="_blank"
                    rel="noopener noreferrer"
                    class="text-blue-600 hover:text-blue-700"
                    title="View exercise details"
                  >
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"></path>
                    </svg>
                  </a>
                  <span v-if="exercise.sets.length > 0 && !getExerciseData(index)?.gifUrl" class="text-success">✓</span>
                </div>
                <p class="text-sm text-gray-600">
                  {{ exercise.prescribedSets }}×{{ exercise.prescribedReps }}
                  <span v-if="getExerciseData(index)?.restSeconds">
                    · {{ getExerciseData(index).restSeconds }}s rest
                  </span>
                  <span v-if="getExerciseData(index)?.tempo" class="ml-2">
                    · Tempo: {{ getExerciseData(index).tempo }}
                  </span>
                </p>
                
                <!-- Form Cues (collapsible) -->
                <div v-if="getExerciseData(index)?.formCues && getExerciseData(index).formCues.length > 0" class="mt-2">
                  <button
                    @click="toggleFormCues(index)"
                    class="text-xs text-blue-600 hover:text-blue-700 flex items-center gap-1"
                  >
                    <span>{{ showFormCues.has(index) ? '▼' : '▶' }}</span>
                    <span>Form Cues</span>
                  </button>
                  <ul v-if="showFormCues.has(index)" class="mt-2 text-xs text-gray-600 space-y-1 pl-4">
                    <li v-for="(cue, idx) in getExerciseData(index).formCues" :key="idx" class="flex items-start gap-2">
                      <span>•</span>
                      <span>{{ cue }}</span>
                    </li>
                  </ul>
                </div>
              </div>
              
              <div v-if="exercise.sets.length === 0 && !exercise.skipped" class="flex gap-2">
                <button
                  v-if="hasSubstitutions(index)"
                  @click="openSubstitutionModal(index)"
                  class="text-sm text-blue-600 hover:text-blue-700 flex items-center gap-1"
                >
                  🔄 Substitute
                </button>
                <button
                  @click="skipExercise(index)"
                  class="text-sm text-gray-500 hover:text-gray-700"
                >
                  Skip
                </button>
              </div>
            </div>

          <!-- Rest Timer -->
          <div
            v-if="restTimer.exerciseIndex === index && restTimer.secondsLeft > 0"
            class="mb-3 p-3 bg-primary/10 border border-primary rounded-lg text-center"
          >
            <p class="text-sm font-medium text-primary">Rest Timer</p>
            <p class="text-3xl font-bold text-primary">{{ formatRestTime(restTimer.secondsLeft) }}</p>
          </div>

          <!-- Logged Sets -->
          <div v-if="exercise.sets.length > 0" class="space-y-1 mb-3">
            <div
              v-for="set in exercise.sets"
              :key="set.setNumber"
              class="text-sm text-gray-700"
            >
              Set {{ set.setNumber }}: {{ set.weight }}kg × {{ set.reps }} reps
              <span v-if="set.rpe" class="text-gray-500">(RPE: {{ set.rpe }})</span>
            </div>
          </div>

          <!-- Skipped Badge -->
          <div v-if="exercise.skipped" class="text-sm text-gray-500 italic">
            Skipped
          </div>

          <!-- Add Set Button -->
          <button
            v-if="!exercise.skipped"
            @click="openSetModal(index)"
            class="btn-primary w-full"
          >
            + Add Set
          </button>
          </div>
        </div>
      </div>

      <!-- Cool-down Section -->
      <div v-if="currentDay?.cooldown && currentDay.cooldown.exercises?.length > 0" class="mt-6">
        <div class="flex items-center gap-2 mb-3">
          <h2 class="text-lg font-semibold">🧘 Cool-down</h2>
          <span class="text-sm text-gray-500">({{ currentDay.cooldown.duration || 5 }} min)</span>
        </div>
        <div class="card p-4 bg-blue-50 border-blue-200">
          <ul class="space-y-2 text-sm">
            <li v-for="(ex, idx) in currentDay.cooldown.exercises" :key="idx" class="flex items-start gap-2">
              <span class="text-gray-400">{{ idx + 1 }}.</span>
              <div class="flex-1">
                <span class="font-medium">{{ ex.name }}</span>
                <span v-if="ex.duration" class="text-gray-600 ml-2">({{ ex.duration }}s)</span>
                <span v-if="ex.reps" class="text-gray-600 ml-2">({{ ex.reps }} reps)</span>
                <span v-if="ex.sets" class="text-gray-600 ml-2">× {{ ex.sets }}</span>
              </div>
            </li>
          </ul>
        </div>
      </div>

      <!-- End Workout Button -->
      <div class="mt-6 sticky bottom-20 bg-gray-50 -mx-4 px-4 py-4 border-t">
        <button @click="showEndModal = true" class="btn-secondary w-full">
          End Workout
        </button>
      </div>
    </div>

    <!-- Set Logging Modal -->
    <div
      v-if="setModalOpen"
      class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50"
      @click.self="setModalOpen = false"
    >
      <div class="bg-white rounded-2xl w-11/12 max-w-sm p-6">
        <h3 class="text-lg font-bold mb-4">
          Log Set - {{ session.exercises[currentExerciseIndex]?.exerciseName }}
        </h3>

        <!-- Same as Last Set Button -->
        <button
          v-if="lastSetData"
          @click="useLastSet"
          class="btn-secondary w-full mb-4 text-sm"
        >
          📋 Same as Last Set ({{ lastSetData.weight }}kg × {{ lastSetData.reps }} reps)
        </button>

        <div class="space-y-4">
          <div>
            <label class="block text-sm font-medium mb-2">Weight (kg)</label>
            <div class="flex items-center gap-2 w-full">
              <button
                type="button"
                @click="decrementWeight"
                class="w-12 h-12 flex-shrink-0 flex items-center justify-center text-2xl font-bold bg-white text-red-600 border-2 border-red-600 rounded-lg active:bg-red-100"
              >
                −
              </button>
              <input
                v-model="setWeight"
                type="number"
                step="0.5"
                class="input flex-1 min-w-0 text-2xl text-center font-semibold py-2"
                inputmode="decimal"
              />
              <button
                type="button"
                @click="incrementWeight"
                class="w-12 h-12 flex-shrink-0 flex items-center justify-center text-2xl font-bold bg-white text-red-600 border-2 border-red-600 rounded-lg active:bg-red-100"
              >
                +
              </button>
            </div>
          </div>

          <div>
            <label class="block text-sm font-medium mb-2">Reps</label>
            <div class="flex items-center gap-2 w-full">
              <button
                type="button"
                @click="decrementReps"
                class="w-12 h-12 flex-shrink-0 flex items-center justify-center text-2xl font-bold bg-white text-red-600 border-2 border-red-600 rounded-lg active:bg-red-100"
              >
                −
              </button>
              <input
                v-model="setReps"
                type="number"
                class="input flex-1 min-w-0 text-2xl text-center font-semibold py-2"
                inputmode="numeric"
              />
              <button
                type="button"
                @click="incrementReps"
                class="w-12 h-12 flex-shrink-0 flex items-center justify-center text-2xl font-bold bg-white text-red-600 border-2 border-red-600 rounded-lg active:bg-red-100"
              >
                +
              </button>
            </div>
          </div>

          <div>
            <label class="block text-sm font-medium mb-2">RPE (optional)</label>
            <input
              v-model="setRPE"
              type="number"
              min="1"
              max="10"
              class="input w-full text-lg text-center"
              inputmode="numeric"
              placeholder="1-10"
            />
          </div>
        </div>

        <div class="flex gap-2 mt-6">
          <button @click="setModalOpen = false" class="btn-secondary flex-1">
            Cancel
          </button>
          <button @click="saveSet" class="btn-primary flex-1">
            Save Set
          </button>
        </div>
      </div>
    </div>

    <!-- End Workout Modal -->
    <div
      v-if="showEndModal"
      class="fixed inset-0 bg-black bg-opacity-50 flex items-end justify-center z-50"
      @click.self="showEndModal = false"
    >
      <div class="bg-white rounded-t-2xl w-full max-w-lg p-6">
        <h2 class="text-xl font-bold mb-4">End Workout</h2>

        <textarea
          v-model="sessionNotes"
          class="input w-full h-24 resize-none"
          placeholder="Notes (optional)"
        ></textarea>

        <div class="flex gap-2 mt-4">
          <button @click="showEndModal = false" class="btn-secondary flex-1">
            Cancel
          </button>
          <button @click="endWorkout" class="btn-primary flex-1">
            Finish
          </button>
        </div>
      </div>
    </div>

    <!-- Substitution Modal -->
    <div
      v-if="substitutionModalOpen"
      class="fixed inset-0 bg-black bg-opacity-50 flex items-end justify-center z-50"
      @click.self="closeSubstitutionModal"
    >
      <div class="bg-white rounded-t-2xl w-full max-w-lg p-6 max-h-[80vh] overflow-y-auto">
        <h2 class="text-xl font-bold mb-2">Substitute Exercise</h2>
        <p class="text-sm text-gray-600 mb-4">
          Can't do {{ session?.exercises[substitutionExerciseIndex]?.name }}? Choose an alternative:
        </p>

        <div class="space-y-3 mb-4">
          <div
            v-for="(sub, idx) in substitutionOptions"
            :key="idx"
            class="border border-gray-200 rounded-lg p-4 hover:border-blue-500 hover:bg-blue-50 transition-colors cursor-pointer"
            @click="performSubstitution(sub)"
          >
            <h3 class="font-semibold text-gray-900">{{ sub.exerciseId }}</h3>
            <p class="text-sm text-gray-600 mt-1">
              <span class="font-medium">Reason:</span> {{ sub.reason }}
            </p>
            <p v-if="sub.notes" class="text-sm text-gray-600 mt-1">
              <span class="font-medium">Note:</span> {{ sub.notes }}
            </p>
          </div>
        </div>

        <button @click="closeSubstitutionModal" class="btn-secondary w-full">
          Keep Original Exercise
        </button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted, computed } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useSessionsStore } from '../stores/sessions'
import { useProgramsStore } from '../stores/programs'
import { useExercisesStore } from '../stores/exercises'
import { storeToRefs } from 'pinia'

const router = useRouter()
const route = useRoute()
const sessionsStore = useSessionsStore()
const programsStore = useProgramsStore()

const { activeSession: session } = storeToRefs(sessionsStore)
const setModalOpen = ref(false)
const currentExerciseIndex = ref(0)
const setWeight = ref('')
const setReps = ref('')
const setRPE = ref('')
const showEndModal = ref(false)
const sessionNotes = ref('')
const currentProgram = ref(null)
const currentDay = ref(null)
const showFormCues = ref(new Set())

// Substitution modal
const substitutionModalOpen = ref(false)
const substitutionExerciseIndex = ref(null)
const substitutionOptions = ref([])

// Rest timer - uses timestamps to survive phone lock
const restTimer = ref({
  exerciseIndex: null,
  startTime: null,
  duration: 0,
  secondsLeft: 0,
  interval: null
})

// Workout duration - uses timestamps to survive phone lock
const workoutStartTime = ref(null)
const workoutElapsed = ref(0)
const workoutDurationInterval = ref(null)

// Computed properties
const workoutDuration = computed(() => {
  const minutes = Math.floor(workoutElapsed.value / 60)
  const seconds = workoutElapsed.value % 60
  return `${minutes}:${seconds.toString().padStart(2, '0')}`
})

const lastSetData = computed(() => {
  if (!session.value) return null
  const exercise = session.value.exercises[currentExerciseIndex.value]
  const lastSet = exercise?.sets.slice(-1)[0]
  return lastSet || null
})

onMounted(async () => {
  await programsStore.loadPrograms()
  
  const program = programsStore.programs.find(
    p => p.programId === route.params.programId
  )
  const day = program?.workoutDays.find(
    d => d.dayId === route.params.dayId
  )

  if (program && day) {
    currentProgram.value = program
    currentDay.value = day
    sessionsStore.startSession(program, day)
    
    // Start workout duration timer using timestamps
    workoutStartTime.value = Date.now()
    workoutDurationInterval.value = setInterval(() => {
      workoutElapsed.value = Math.floor((Date.now() - workoutStartTime.value) / 1000)
    }, 1000)
  } else {
    router.push('/programs')
  }
})

// Update timers immediately when page becomes visible (phone unlocked)
function handleVisibilityChange() {
  if (document.visibilityState === 'visible') {
    // Update workout elapsed time
    if (workoutStartTime.value) {
      workoutElapsed.value = Math.floor((Date.now() - workoutStartTime.value) / 1000)
    }
    // Update rest timer
    if (restTimer.value.startTime && restTimer.value.secondsLeft > 0) {
      const elapsed = Math.floor((Date.now() - restTimer.value.startTime) / 1000)
      restTimer.value.secondsLeft = Math.max(0, restTimer.value.duration - elapsed)
    }
  }
}

onMounted(() => {
  document.addEventListener('visibilitychange', handleVisibilityChange)
})

onUnmounted(() => {
  // Clear intervals
  if (workoutDurationInterval.value) {
    clearInterval(workoutDurationInterval.value)
  }
  if (restTimer.value.interval) {
    clearInterval(restTimer.value.interval)
  }
  document.removeEventListener('visibilitychange', handleVisibilityChange)
})

function formatTime(isoString) {
  const date = new Date(isoString)
  return date.toLocaleTimeString('en-US', { 
    hour: '2-digit', 
    minute: '2-digit' 
  })
}

function formatRestTime(seconds) {
  const mins = Math.floor(seconds / 60)
  const secs = seconds % 60
  if (mins > 0) {
    return `${mins}:${secs.toString().padStart(2, '0')}`
  }
  return `${secs}s`
}

function handleImageError(event) {
  // Hide broken images gracefully
  event.target.style.display = 'none'
  const parent = event.target.parentElement
  if (parent) {
    parent.classList.add('hidden')
  }
}

function toggleFormCues(index) {
  if (showFormCues.value.has(index)) {
    showFormCues.value.delete(index)
  } else {
    showFormCues.value.add(index)
  }
  // Trigger reactivity
  showFormCues.value = new Set(showFormCues.value)
}

function getExerciseData(index) {
  if (!currentProgram.value || !session.value) return null
  
  const day = currentProgram.value.workoutDays.find(
    d => d.dayId === session.value.dayId
  )
  return day?.exercises[index] || null
}

function startRestTimer(exerciseIndex) {
  // Clear existing timer
  if (restTimer.value.interval) {
    clearInterval(restTimer.value.interval)
  }
  
  // Get rest time from exercise data
  const exerciseData = getExerciseData(exerciseIndex)
  const restSeconds = exerciseData?.restSeconds || 90
  
  // Store start time and duration for timestamp-based calculation
  restTimer.value.exerciseIndex = exerciseIndex
  restTimer.value.startTime = Date.now()
  restTimer.value.duration = restSeconds
  restTimer.value.secondsLeft = restSeconds
  
  restTimer.value.interval = setInterval(() => {
    // Calculate remaining time based on timestamps (survives phone lock)
    const elapsed = Math.floor((Date.now() - restTimer.value.startTime) / 1000)
    restTimer.value.secondsLeft = Math.max(0, restTimer.value.duration - elapsed)
    
    if (restTimer.value.secondsLeft <= 0) {
      clearInterval(restTimer.value.interval)
      // Optional: play sound or vibrate
      if ('vibrate' in navigator) {
        navigator.vibrate([200, 100, 200])
      }
    }
  }, 1000)
}

function useLastSet() {
  if (lastSetData.value) {
    setWeight.value = lastSetData.value.weight
    setReps.value = lastSetData.value.reps
    setRPE.value = lastSetData.value.rpe || ''
  }
}

function openSetModal(index) {
  currentExerciseIndex.value = index
  const lastSet = session.value.exercises[index].sets.slice(-1)[0]
  setWeight.value = lastSet?.weight || ''
  setReps.value = lastSet?.reps || ''
  setRPE.value = ''
  setModalOpen.value = true
}

function saveSet() {
  sessionsStore.addSet(
    currentExerciseIndex.value,
    setWeight.value,
    setReps.value,
    setRPE.value || null
  )
  setModalOpen.value = false
  
  // Start rest timer
  startRestTimer(currentExerciseIndex.value)
}

function skipExercise(index) {
  sessionsStore.skipExercise(index)
}

async function endWorkout() {
  await sessionsStore.endSession(sessionNotes.value)
  router.push('/history')
}

function incrementWeight() {
  const current = parseFloat(setWeight.value) || 0
  setWeight.value = (current + 2.5).toFixed(1)
}

function decrementWeight() {
  const current = parseFloat(setWeight.value) || 0
  if (current > 0) {
    setWeight.value = Math.max(0, current - 2.5).toFixed(1)
  }
}

function incrementReps() {
  const current = parseInt(setReps.value) || 0
  setReps.value = current + 1
}

function decrementReps() {
  const current = parseInt(setReps.value) || 0
  if (current > 0) {
    setReps.value = Math.max(0, current - 1)
  }
}

// Substitution functions
function hasSubstitutions(index) {
  const exerciseData = getExerciseData(index)
  return exerciseData?.substitutions && exerciseData.substitutions.length > 0
}

function openSubstitutionModal(index) {
  const exerciseData = getExerciseData(index)
  if (!exerciseData?.substitutions || exerciseData.substitutions.length === 0) {
    alert('No substitutions available for this exercise')
    return
  }
  
  substitutionExerciseIndex.value = index
  substitutionOptions.value = exerciseData.substitutions
  substitutionModalOpen.value = true
}

function performSubstitution(substitution) {
  if (!session.value || substitutionExerciseIndex.value === null) return
  
  const index = substitutionExerciseIndex.value
  const exercisesStore = useExercisesStore()
  
  // Get substitute exercise from database
  let substituteExercise = null
  if (substitution.exerciseDbId) {
    substituteExercise = exercisesStore.getExerciseById(substitution.exerciseDbId)
  }
  
  // Create new exercise object (keep program prescription, add substitute details)
  const originalExercise = session.value.exercises[index]
  const newExercise = {
    ...originalExercise,
    // Mark as substitution
    isSubstitution: true,
    originalExerciseId: originalExercise.exerciseId,
    originalName: originalExercise.name,
    // Update with substitute details
    exerciseId: substitution.exerciseId,
    name: substituteExercise?.name || substitution.exerciseId,
    gifUrl: substituteExercise?.media?.gifUrl || substituteExercise?.gifUrl,
    demoUrl: substituteExercise?.demoUrl,
    instructions: substituteExercise?.instructions,
    formCues: substituteExercise?.formCues,
    substitutionReason: substitution.reason,
    substitutionNotes: substitution.notes
  }
  
  // Update session
  sessionsStore.substituteExercise(index, newExercise)
  
  // Close modal
  substitutionModalOpen.value = false
  substitutionExerciseIndex.value = null
  substitutionOptions.value = []
}

function closeSubstitutionModal() {
  substitutionModalOpen.value = false
  substitutionExerciseIndex.value = null
  substitutionOptions.value = []
}
</script>
