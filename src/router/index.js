import { createRouter, createWebHistory } from 'vue-router'

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    {
      path: '/',
      redirect: '/programs'
    },
    {
      path: '/programs',
      name: 'programs',
      component: () => import('../views/Programs.vue')
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
    }
  ]
})

export default router
