<template>
  <div class="min-h-screen flex items-center justify-center p-4 bg-gray-50">
    <div class="w-full max-w-md">
      <!-- Logo/Title -->
      <div class="text-center mb-8">
        <h1 class="text-3xl font-bold text-gray-900 mb-2">🏋️ Workout Tracker</h1>
        <p class="text-gray-600">Sign in to sync across devices</p>
      </div>

      <!-- Auth Card -->
      <div class="card">
        <!-- Tabs -->
        <div class="flex mb-6 border-b">
          <button
            @click="mode = 'signin'"
            class="flex-1 pb-3 font-medium transition-colors"
            :class="mode === 'signin' ? 'text-primary border-b-2 border-primary' : 'text-gray-500'"
          >
            Sign In
          </button>
          <button
            @click="mode = 'signup'"
            class="flex-1 pb-3 font-medium transition-colors"
            :class="mode === 'signup' ? 'text-primary border-b-2 border-primary' : 'text-gray-500'"
          >
            Sign Up
          </button>
        </div>

        <!-- Error Message -->
        <div v-if="error" class="mb-4 p-3 bg-red-50 border border-red-200 rounded-lg text-sm text-red-600">
          {{ error }}
        </div>

        <!-- Success Message -->
        <div v-if="success" class="mb-4 p-3 bg-green-50 border border-green-200 rounded-lg text-sm text-green-600">
          {{ success }}
        </div>

        <!-- Form -->
        <form @submit.prevent="handleSubmit" class="space-y-4" autocomplete="on">
          <div>
            <label for="email" class="block text-sm font-medium mb-1">Email</label>
            <input
              id="email"
              v-model="email"
              type="email"
              name="email"
              autocomplete="email"
              required
              class="input w-full"
              placeholder="you@example.com"
              :disabled="loading"
            />
          </div>

          <div>
            <label for="password" class="block text-sm font-medium mb-1">Password</label>
            <input
              id="password"
              v-model="password"
              type="password"
              name="password"
              :autocomplete="mode === 'signin' ? 'current-password' : 'new-password'"
              required
              minlength="6"
              class="input w-full"
              placeholder="••••••••"
              :disabled="loading"
            />
          </div>

          <button
            type="submit"
            class="btn-primary w-full"
            :disabled="loading"
          >
            {{ loading ? 'Loading...' : mode === 'signin' ? 'Sign In' : 'Sign Up' }}
          </button>
        </form>

        <!-- Continue Offline -->
        <div class="mt-6 text-center">
          <button
            @click="continueOffline"
            class="text-sm text-gray-600 hover:text-gray-900 underline"
          >
            Continue without signing in (offline only)
          </button>
        </div>
      </div>

      <!-- Info -->
      <div class="mt-6 text-center text-sm text-gray-600">
        <p>🔒 Your data is private and encrypted</p>
        <p class="mt-1">Sync automatically across all your devices</p>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'

const router = useRouter()
const authStore = useAuthStore()

const mode = ref('signin')
const email = ref('')
const password = ref('')
const loading = ref(false)
const error = ref('')
const success = ref('')

async function handleSubmit() {
  error.value = ''
  success.value = ''
  loading.value = true

  try {
    if (mode.value === 'signup') {
      const { error: signUpError } = await authStore.signUp(email.value, password.value)
      
      if (signUpError) {
        error.value = signUpError
      } else {
        success.value = 'Account created! Check your email to verify, then sign in.'
        mode.value = 'signin'
        password.value = ''
      }
    } else {
      const { error: signInError } = await authStore.signIn(email.value, password.value)
      
      if (signInError) {
        error.value = signInError
      } else {
        router.push('/programs')
      }
    }
  } finally {
    loading.value = false
  }
}

function continueOffline() {
  router.push('/programs')
}
</script>
