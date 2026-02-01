import { defineStore } from 'pinia'
import { supabase } from '../utils/supabase'

export const useAuthStore = defineStore('auth', {
  state: () => ({
    user: null,
    session: null,
    loading: false
  }),

  getters: {
    isAuthenticated: (state) => !!state.user
  },

  actions: {
    async init() {
      // Get initial session
      const { data: { session } } = await supabase.auth.getSession()
      this.session = session
      this.user = session?.user || null

      // Listen for auth changes
      supabase.auth.onAuthStateChange((_event, session) => {
        this.session = session
        this.user = session?.user || null
      })
    },

    async signUp(email, password) {
      this.loading = true
      try {
        const { data, error } = await supabase.auth.signUp({
          email,
          password
        })
        if (error) throw error
        return { data, error: null }
      } catch (error) {
        return { data: null, error: error.message }
      } finally {
        this.loading = false
      }
    },

    async signIn(email, password) {
      this.loading = true
      try {
        const { data, error } = await supabase.auth.signInWithPassword({
          email,
          password
        })
        if (error) throw error
        return { data, error: null }
      } catch (error) {
        return { data: null, error: error.message }
      } finally {
        this.loading = false
      }
    },

    async signOut() {
      this.loading = true
      try {
        const { error } = await supabase.auth.signOut()
        if (error) throw error
        this.user = null
        this.session = null
      } catch (error) {
        console.error('Sign out error:', error)
      } finally {
        this.loading = false
      }
    }
  }
})
