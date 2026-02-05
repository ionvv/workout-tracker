import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '../stores/auth'

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    {
      path: '/',
      redirect: () => {
        const authStore = useAuthStore()
        return authStore.isAuthenticated ? '/programs' : '/login'
      }
    },
    {
      path: '/login',
      name: 'login',
      component: () => import('../views/Login.vue')
    },
    {
      path: '/programs',
      name: 'programs',
      component: () => import('../views/Programs.vue')
    },
    {
      path: '/builder',
      name: 'builder',
      component: () => import('../views/WorkoutBuilder.vue')
    },
    {
      path: '/workout/:programId/:dayId',
      name: 'workout',
      component: () => import('../views/ActiveWorkout.vue')
    },
    {
      path: '/history',
      name: 'history',
      component: () => import('../views/History.vue')
    },
    {
      path: '/analytics',
      name: 'analytics',
      component: () => import('../views/Analytics.vue')
    },
    {
      path: '/pair-device',
      name: 'pair-device',
      redirect: '/profile'
    },
    {
      path: '/profile',
      name: 'profile',
      component: () => import('../views/Profile.vue')
    }
  ]
})

// Navigation guard for auth
router.beforeEach(async (to, from, next) => {
  const authStore = useAuthStore()
  
  // Initialize auth if not done yet (first navigation)
  if (authStore.session === null && authStore.user === null) {
    await authStore.init()
  }
  
  // If going to login but already authenticated, redirect to programs
  if (to.path === '/login' && authStore.isAuthenticated) {
    next('/programs')
    return
  }
  
  // If going to a protected route but not authenticated, redirect to login
  const publicRoutes = ['/login']
  if (!publicRoutes.includes(to.path) && !authStore.isAuthenticated) {
    next('/login')
    return
  }
  
  next()
})

export default router
