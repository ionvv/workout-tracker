<template>
  <div class="min-h-screen flex flex-col">
    <!-- Main Content -->
    <main class="flex-1 pb-20">
      <router-view />
    </main>

    <!-- Bottom Navigation -->
    <nav class="fixed bottom-0 left-0 right-0 bg-white border-t border-gray-200 safe-area-inset-bottom">
      <div class="flex justify-around items-center h-16">
        <router-link
          to="/programs"
          class="flex flex-col items-center justify-center flex-1 h-full transition-colors"
          :class="$route.path === '/programs' ? 'text-primary' : 'text-gray-600'"
        >
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
          </svg>
          <span class="text-xs mt-1">Programs</span>
        </router-link>

        <router-link
          to="/history"
          class="flex flex-col items-center justify-center flex-1 h-full transition-colors"
          :class="$route.path === '/history' ? 'text-primary' : 'text-gray-600'"
        >
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          <span class="text-xs mt-1">History</span>
        </router-link>

        <router-link
          to="/analytics"
          class="flex flex-col items-center justify-center flex-1 h-full transition-colors"
          :class="$route.path === '/analytics' ? 'text-primary' : 'text-gray-600'"
        >
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
          </svg>
          <span class="text-xs mt-1">Analytics</span>
        </router-link>
      </div>
    </nav>
  </div>
</template>

<script setup>
// No additional logic needed here
</script>
