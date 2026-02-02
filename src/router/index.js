import { createRouter, createWebHistory } from 'vue-router'

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    {
      path: '/',
      redirect: '/login'
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

export default router
