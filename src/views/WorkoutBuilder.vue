<template>
  <div class="p-4 pb-20">
    <div class="mb-6">
      <h1 class="text-2xl font-bold mb-2">Workout Builder</h1>
      <p class="text-gray-600 text-sm">Build your custom workout from 600+ exercises</p>
    </div>

    <!-- Workout Name -->
    <div class="mb-4">
      <input
        v-model="workoutName"
        type="text"
        placeholder="Workout Name (e.g., Push Day A)"
        class="input w-full"
      />
    </div>

    <!-- Search & Filters -->
    <div class="mb-4 space-y-2">
      <input
        v-model="searchQuery"
        type="text"
        placeholder="Search exercises..."
        class="input w-full"
      />
      
      <div class="flex gap-2 overflow-x-auto pb-2">
        <select v-model="filterMuscle" class="input text-sm">
          <option value="">All Muscles</option>
          <option v-for="muscle in muscleGroups" :key="muscle" :value="muscle">
            {{ formatLabel(muscle) }}
          </option>
        </select>
        
        <select v-model="filterEquipment" class="input text-sm">
          <option value="">All Equipment</option>
          <option v-for="eq in equipmentTypes" :key="eq" :value="eq">
            {{ formatLabel(eq) }}
          </option>
        </select>
        
        <select v-model="filterDifficulty" class="input text-sm">
          <option value="">All Levels</option>
          <option value="beginner">Beginner</option>
          <option value="intermediate">Intermediate</option>
          <option value="advanced">Advanced</option>
        </select>
        
        <select v-model="filterCategory" class="input text-sm">
          <option value="">All Categories</option>
          <option value="strength">Strength</option>
          <option value="cardio">Cardio</option>
          <option value="core">Core</option>
          <option value="olympic">Olympic</option>
        </select>
      </div>
    </div>

    <!-- Selected Exercises Summary -->
    <div v-if="selectedExercises.length > 0" class="mb-4 p-3 bg-primary/10 border border-primary rounded-lg">
      <div class="flex items-center justify-between">
        <span class="text-sm font-medium text-primary">
          {{ selectedExercises.length }} exercise{{ selectedExercises.length !== 1 ? 's' : '' }} selected
        </span>
        <button @click="showSelectedView = !showSelectedView" class="text-sm text-primary underline">
          {{ showSelectedView ? 'Show Database' : 'Review & Configure' }}
        </button>
      </div>
    </div>

    <!-- Exercise Database View -->
    <div v-if="!showSelectedView">
      <div v-if="loading" class="text-center py-12">
        <p class="text-gray-600">Loading exercises...</p>
      </div>

      <div v-else-if="filteredExercises.length === 0" class="text-center py-12">
        <p class="text-gray-600">No exercises found</p>
        <button @click="clearFilters" class="text-sm text-primary underline mt-2">
          Clear filters
        </button>
      </div>

      <div v-else>
        <!-- Results count -->
        <div class="mb-3 text-sm text-gray-600">
          Showing {{ paginatedExercises.length }} of {{ filteredExercises.length }} exercises
        </div>

        <div class="space-y-3">
          <div
            v-for="exercise in paginatedExercises"
            :key="exercise.id"
            class="card"
          >
            <!-- Exercise Image -->
            <div v-if="exercise.media?.gifUrl" class="mb-3 relative aspect-video bg-gray-100 rounded overflow-hidden">
              <img
                :src="exercise.media.gifUrl"
                :alt="exercise.name"
                loading="lazy"
                class="w-full h-full object-cover"
                @error="handleImageError"
              />
            </div>

          <!-- Exercise Info -->
          <h3 class="font-semibold mb-1">{{ exercise.name }}</h3>
          <p class="text-xs text-gray-600 mb-2">{{ exercise.description }}</p>
          
          <div class="flex flex-wrap gap-1 mb-3">
            <span class="text-xs px-2 py-0.5 bg-blue-100 text-blue-700 rounded">
              {{ formatLabel(exercise.difficulty) }}
            </span>
            <span class="text-xs px-2 py-0.5 bg-purple-100 text-purple-700 rounded">
              {{ formatLabel(exercise.category) }}
            </span>
            <span
              v-for="muscle in exercise.muscleGroups.primary"
              :key="muscle"
              class="text-xs px-2 py-0.5 bg-green-100 text-green-700 rounded"
            >
              {{ formatLabel(muscle) }}
            </span>
          </div>

          <!-- Add Button -->
          <button
            v-if="!isSelected(exercise.id)"
            @click="addExercise(exercise)"
            class="btn-primary w-full text-sm"
          >
            + Add to Workout
          </button>
          <button
            v-else
            @click="removeExercise(exercise.id)"
            class="btn-secondary w-full text-sm"
          >
            ✓ Added
          </button>
        </div>
        </div>

        <!-- Load More Button -->
        <div v-if="hasMoreExercises" class="mt-4">
          <button
            @click="loadMore"
            class="btn-secondary w-full"
          >
            Load More ({{ filteredExercises.length - paginatedExercises.length }} remaining)
          </button>
        </div>
      </div>
    </div>

    <!-- Selected Exercises View -->
    <div v-else class="space-y-3">
      <div v-if="selectedExercises.length === 0" class="text-center py-12">
        <p class="text-gray-600">No exercises selected yet</p>
        <button @click="showSelectedView = false" class="btn-primary mt-4">
          Browse Exercises
        </button>
      </div>

      <div
        v-for="(selected, index) in selectedExercises"
        :key="selected.exercise.id"
        class="card"
      >
        <!-- Exercise Header -->
        <div class="flex items-start justify-between mb-3">
          <div class="flex-1">
            <div class="flex items-center gap-2 mb-1">
              <span class="text-xs font-semibold text-gray-400">{{ index + 1 }}</span>
              <h3 class="font-semibold">{{ selected.exercise.name }}</h3>
            </div>
            <p class="text-xs text-gray-600">{{ selected.exercise.description }}</p>
          </div>
          <button
            @click="removeExercise(selected.exercise.id)"
            class="text-red-600 text-sm"
          >
            ✕
          </button>
        </div>

        <!-- Configuration -->
        <div class="space-y-2">
          <div class="grid grid-cols-3 gap-2">
            <div>
              <label class="text-xs text-gray-600">Sets</label>
              <input
                v-model.number="selected.sets"
                type="number"
                min="1"
                max="10"
                class="input w-full text-sm"
              />
            </div>
            <div>
              <label class="text-xs text-gray-600">Reps</label>
              <input
                v-model="selected.reps"
                type="text"
                placeholder="8-12"
                class="input w-full text-sm"
              />
            </div>
            <div>
              <label class="text-xs text-gray-600">Rest (sec)</label>
              <input
                v-model.number="selected.rest"
                type="number"
                min="0"
                max="600"
                step="30"
                class="input w-full text-sm"
              />
            </div>
          </div>
          
          <div>
            <label class="text-xs text-gray-600">Notes (optional)</label>
            <input
              v-model="selected.notes"
              type="text"
              placeholder="Form cues, tips..."
              class="input w-full text-sm"
            />
          </div>
        </div>

        <!-- Move buttons -->
        <div class="flex gap-2 mt-3">
          <button
            v-if="index > 0"
            @click="moveExercise(index, -1)"
            class="btn-secondary text-xs flex-1"
          >
            ↑ Move Up
          </button>
          <button
            v-if="index < selectedExercises.length - 1"
            @click="moveExercise(index, 1)"
            class="btn-secondary text-xs flex-1"
          >
            ↓ Move Down
          </button>
        </div>
      </div>

      <!-- Save Workout Button -->
      <div class="sticky bottom-20 bg-gray-50 -mx-4 px-4 py-4 border-t">
        <button
          @click="saveWorkout"
          :disabled="!canSave"
          class="btn-primary w-full"
        >
          Save Workout
        </button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import { useProgramsStore } from '../stores/programs'

const router = useRouter()
const programsStore = useProgramsStore()

const loading = ref(true)
const exercises = ref([])
const searchQuery = ref('')
const filterMuscle = ref('')
const filterEquipment = ref('')
const filterDifficulty = ref('')
const filterCategory = ref('')
const showSelectedView = ref(false)
const workoutName = ref('')
const selectedExercises = ref([])
const pageSize = ref(20)
const currentPage = ref(1)

onMounted(async () => {
  try {
    const response = await fetch('/exercises-database.json')
    const data = await response.json()
    exercises.value = data.exercises
  } catch (error) {
    console.error('Failed to load exercises:', error)
  } finally {
    loading.value = false
  }
})

// Reset pagination when filters change
watch([searchQuery, filterMuscle, filterEquipment, filterDifficulty, filterCategory], () => {
  currentPage.value = 1
})

const muscleGroups = computed(() => {
  const muscles = new Set()
  exercises.value.forEach(ex => {
    ex.muscleGroups.primary.forEach(m => muscles.add(m))
    ex.muscleGroups.secondary.forEach(m => muscles.add(m))
  })
  return Array.from(muscles).sort()
})

const equipmentTypes = computed(() => {
  const equipment = new Set()
  exercises.value.forEach(ex => {
    ex.equipment.forEach(eq => equipment.add(eq))
  })
  return Array.from(equipment).sort()
})

const filteredExercises = computed(() => {
  let filtered = exercises.value

  // Search filter
  if (searchQuery.value) {
    const query = searchQuery.value.toLowerCase()
    filtered = filtered.filter(ex =>
      ex.name.toLowerCase().includes(query) ||
      ex.description.toLowerCase().includes(query)
    )
  }

  // Muscle filter
  if (filterMuscle.value) {
    filtered = filtered.filter(ex =>
      ex.muscleGroups.primary.includes(filterMuscle.value) ||
      ex.muscleGroups.secondary.includes(filterMuscle.value)
    )
  }

  // Equipment filter
  if (filterEquipment.value) {
    filtered = filtered.filter(ex =>
      ex.equipment.includes(filterEquipment.value)
    )
  }

  // Difficulty filter
  if (filterDifficulty.value) {
    filtered = filtered.filter(ex =>
      ex.difficulty === filterDifficulty.value
    )
  }

  // Category filter
  if (filterCategory.value) {
    filtered = filtered.filter(ex =>
      ex.category === filterCategory.value
    )
  }

  return filtered
})

const paginatedExercises = computed(() => {
  const end = currentPage.value * pageSize.value
  return filteredExercises.value.slice(0, end)
})

const hasMoreExercises = computed(() => {
  return paginatedExercises.value.length < filteredExercises.value.length
})

const canSave = computed(() => {
  return workoutName.value.trim() && selectedExercises.value.length > 0
})

function formatLabel(str) {
  return str
    .split(/[-_]/)
    .map(word => word.charAt(0).toUpperCase() + word.slice(1))
    .join(' ')
}

function handleImageError(event) {
  event.target.style.display = 'none'
  const parent = event.target.parentElement
  if (parent) {
    parent.classList.add('hidden')
  }
}

function clearFilters() {
  searchQuery.value = ''
  filterMuscle.value = ''
  filterEquipment.value = ''
  filterDifficulty.value = ''
  filterCategory.value = ''
  currentPage.value = 1
}

function loadMore() {
  currentPage.value++
}

function isSelected(exerciseId) {
  return selectedExercises.value.some(s => s.exercise.id === exerciseId)
}

function addExercise(exercise) {
  selectedExercises.value.push({
    exercise,
    sets: 3,
    reps: '8-12',
    rest: 120,
    notes: ''
  })
}

function removeExercise(exerciseId) {
  selectedExercises.value = selectedExercises.value.filter(
    s => s.exercise.id !== exerciseId
  )
}

function moveExercise(index, direction) {
  const newIndex = index + direction
  if (newIndex < 0 || newIndex >= selectedExercises.value.length) return
  
  const temp = selectedExercises.value[index]
  selectedExercises.value[index] = selectedExercises.value[newIndex]
  selectedExercises.value[newIndex] = temp
  
  // Force reactivity
  selectedExercises.value = [...selectedExercises.value]
}

async function saveWorkout() {
  if (!canSave.value) return

  const program = {
    programId: `program-${Date.now()}`,
    programName: workoutName.value,
    workoutDays: [
      {
        dayId: `day-1`,
        dayName: workoutName.value,
        exercises: selectedExercises.value.map((sel, idx) => ({
          exerciseId: `ex-${idx}-${sel.exercise.id}`,
          name: sel.exercise.name,
          prescribedSets: sel.sets,
          prescribedReps: sel.reps,
          restSeconds: sel.rest,
          notes: sel.notes || null,
          gifUrl: sel.exercise.media?.gifUrl || null,
          demoUrl: null,
          type: sel.exercise.category
        }))
      }
    ]
  }

  try {
    await programsStore.addProgram(program)
    router.push('/programs')
  } catch (error) {
    console.error('Failed to save workout:', error)
    alert('Failed to save workout: ' + error.message)
  }
}
</script>
