<template>
  <div class="p-4">
    <div v-if="!session" class="text-center py-12">
      <p class="text-gray-600">Loading workout...</p>
    </div>

    <div v-else>
      <!-- Header -->
      <div class="mb-6">
        <h1 class="text-2xl font-bold">{{ session.dayName }}</h1>
        <p class="text-sm text-gray-600">
          Started: {{ formatTime(session.startTime) }}
        </p>
      </div>

      <!-- Exercises -->
      <div class="space-y-4">
        <div
          v-for="(exercise, index) in session.exercises"
          :key="exercise.exerciseId"
          class="card"
        >
          <!-- Exercise Header -->
          <div class="flex items-start justify-between mb-3">
            <div class="flex-1">
              <div class="flex items-center gap-2">
                <span class="text-lg font-semibold">{{ index + 1 }}. {{ exercise.exerciseName }}</span>
                <span v-if="exercise.sets.length > 0" class="text-success">✓</span>
              </div>
              <p class="text-sm text-gray-600">
                {{ exercise.prescribedSets }}×{{ exercise.prescribedReps }}
              </p>
            </div>
            
            <button
              v-if="exercise.sets.length === 0 && !exercise.skipped"
              @click="skipExercise(index)"
              class="text-sm text-gray-500 hover:text-gray-700"
            >
              Skip
            </button>
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
  </div>
</template>

<script setup>
import { ref, onMounted, computed } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useSessionsStore } from '../stores/sessions'
import { useProgramsStore } from '../stores/programs'
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

onMounted(async () => {
  await programsStore.loadPrograms()
  
  const program = programsStore.programs.find(
    p => p.programId === route.params.programId
  )
  const day = program?.workoutDays.find(
    d => d.dayId === route.params.dayId
  )

  if (program && day) {
    sessionsStore.startSession(program, day)
  } else {
    router.push('/programs')
  }
})

function formatTime(isoString) {
  const date = new Date(isoString)
  return date.toLocaleTimeString('en-US', { 
    hour: '2-digit', 
    minute: '2-digit' 
  })
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
</script>
