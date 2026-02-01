<template>
  <div class="min-h-screen bg-gray-50 flex items-center justify-center px-4">
    <div class="max-w-md w-full space-y-8">
      <div class="text-center">
        <h2 class="text-3xl font-bold text-gray-900">Pair Your Device</h2>
        <p class="mt-2 text-sm text-gray-600">
          Enter the 6-digit code displayed on your Apple Watch
        </p>
      </div>

      <!-- Pairing Code Input -->
      <div class="bg-white p-8 rounded-lg shadow-md">
        <form @submit.prevent="submitPairingCode" class="space-y-6">
          <!-- Code Input -->
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
              class="w-full px-4 py-3 text-center text-3xl font-mono tracking-widest border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
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
              ✓ Device paired successfully! Your watch should log in automatically.
            </p>
          </div>

          <!-- Submit Button -->
          <button
            type="submit"
            :disabled="loading || pairingCode.length !== 6"
            class="w-full py-3 px-4 bg-blue-600 text-white font-semibold rounded-lg hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed transition"
          >
            <span v-if="!loading">Pair Device</span>
            <span v-else>Pairing...</span>
          </button>
        </form>

        <!-- Back to Programs -->
        <div class="mt-6 text-center">
          <router-link
            to="/programs"
            class="text-sm text-blue-600 hover:text-blue-700"
          >
            ← Back to Programs
          </router-link>
        </div>
      </div>

      <!-- Instructions -->
      <div class="bg-blue-50 border border-blue-200 rounded-lg p-4">
        <h3 class="text-sm font-semibold text-blue-900 mb-2">How it works:</h3>
        <ol class="text-sm text-blue-800 space-y-1 list-decimal list-inside">
          <li>Open the Workout Tracker app on your Apple Watch</li>
          <li>A 6-digit code will appear on the screen</li>
          <li>Enter that code above within 3 minutes</li>
          <li>Your watch will automatically log in!</li>
        </ol>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { useAuthStore } from '../stores/auth'
import { authorizePairingCode } from '../api/devicePairing'

const authStore = useAuthStore()

const pairingCode = ref('')
const loading = ref(false)
const error = ref(null)
const success = ref(false)

async function submitPairingCode() {
  if (pairingCode.value.length !== 6) {
    error.value = 'Please enter a valid 6-digit code'
    return
  }

  loading.value = true
  error.value = null
  success.value = false

  try {
    // User must be logged in to pair a device
    if (!authStore.user) {
      error.value = 'You must be logged in to pair a device'
      return
    }

    await authorizePairingCode(pairingCode.value, authStore.user.id)
    
    success.value = true
    pairingCode.value = ''
    
    // Optional: redirect after 2 seconds
    setTimeout(() => {
      // Could navigate back or show success state
    }, 2000)
  } catch (err) {
    console.error('Pairing error:', err)
    error.value = err.message || 'Invalid or expired code. Please try again.'
  } finally {
    loading.value = false
  }
}
</script>
