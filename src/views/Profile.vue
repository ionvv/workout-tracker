<template>
  <div class="min-h-screen bg-gray-50 p-4">
    <div class="max-w-2xl mx-auto space-y-6">
      <!-- Header -->
      <div class="flex items-center justify-between">
        <h1 class="text-2xl font-bold text-gray-900">Profile</h1>
        <router-link to="/programs" class="text-sm text-blue-600 hover:text-blue-700">
          ← Back to Programs
        </router-link>
      </div>

      <!-- User Info Card -->
      <div class="card">
        <h2 class="text-lg font-semibold mb-4">Account Information</h2>
        <div class="space-y-3">
          <div>
            <label class="text-sm text-gray-600">Email</label>
            <p class="text-gray-900 font-medium">{{ authStore.user?.email || 'Not logged in' }}</p>
          </div>
          <div>
            <label class="text-sm text-gray-600">User ID</label>
            <p class="text-xs text-gray-500 font-mono">{{ authStore.user?.id || 'N/A' }}</p>
          </div>
        </div>

        <!-- Sign Out Button -->
        <button
          v-if="authStore.user"
          @click="handleSignOut"
          class="mt-6 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition"
        >
          Sign Out
        </button>
      </div>

      <!-- Pair Apple Watch Card -->
      <div class="card">
        <div class="flex items-center gap-3 mb-4">
          <span class="text-2xl">⌚</span>
          <h2 class="text-lg font-semibold">Pair Apple Watch</h2>
        </div>

        <p class="text-sm text-gray-600 mb-4">
          Enter the 6-digit code displayed on your Apple Watch to link it to your account.
        </p>

        <!-- Pairing Code Input -->
        <form @submit.prevent="submitPairingCode" class="space-y-4">
          <div>
            <label for="code" class="block text-sm font-medium text-gray-700 mb-2">
              Pairing Code
            </label>
            <input
              id="code"
              v-model="pairingCode"
              type="text"
              maxlength="6"
              pattern="[0-9]{6}"
              placeholder="123456"
              required
              class="w-full px-4 py-3 text-center text-2xl font-mono tracking-widest border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              :disabled="loading"
            />
          </div>

          <!-- Error Message -->
          <div v-if="error" class="p-3 bg-red-50 border border-red-200 rounded-lg">
            <p class="text-sm text-red-600">{{ error }}</p>
          </div>

          <!-- Success Message -->
          <div v-if="success" class="p-3 bg-green-50 border border-green-200 rounded-lg">
            <p class="text-sm text-green-600">
              ✓ Watch paired successfully! Your watch should log in automatically.
            </p>
          </div>

          <!-- Submit Button -->
          <button
            type="submit"
            :disabled="loading || pairingCode.length !== 6"
            class="w-full py-3 px-4 bg-blue-600 text-white font-semibold rounded-lg hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed transition"
          >
            <span v-if="!loading">Pair Watch</span>
            <span v-else>Pairing...</span>
          </button>
        </form>

        <!-- Instructions -->
        <div class="mt-6 p-4 bg-blue-50 border border-blue-200 rounded-lg">
          <h3 class="text-sm font-semibold text-blue-900 mb-2">How to pair:</h3>
          <ol class="text-sm text-blue-800 space-y-1 list-decimal list-inside">
            <li>Open Workout Tracker on your Apple Watch</li>
            <li>A 6-digit code will appear on the screen</li>
            <li>Enter that code above within 3 minutes</li>
            <li>Your watch will automatically log in!</li>
          </ol>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'
import { authorizePairingCode } from '../api/devicePairing'

const router = useRouter()
const authStore = useAuthStore()

const pairingCode = ref('')
const loading = ref(false)
const error = ref(null)
const success = ref(false)

// Redirect to login if not authenticated
if (!authStore.user) {
  router.push('/login')
}

async function submitPairingCode() {
  if (pairingCode.value.length !== 6) {
    error.value = 'Please enter a valid 6-digit code'
    return
  }

  loading.value = true
  error.value = null
  success.value = false

  try {
    if (!authStore.user) {
      error.value = 'You must be logged in to pair a device'
      router.push('/login')
      return
    }

    await authorizePairingCode(pairingCode.value, authStore.user.id)
    
    success.value = true
    pairingCode.value = ''
    
  } catch (err) {
    console.error('Pairing error:', err)
    error.value = err.message || 'Invalid or expired code. Please try again.'
  } finally {
    loading.value = false
  }
}

async function handleSignOut() {
  try {
    await authStore.signOut()
    router.push('/login')
  } catch (err) {
    console.error('Sign out error:', err)
  }
}
</script>
