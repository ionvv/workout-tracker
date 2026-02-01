import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://fpatywrdrltaeftjjyjj.supabase.co'
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZwYXR5d3Jkcmx0YWVmdGpqeWpqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk5MTEzODQsImV4cCI6MjA4NTQ4NzM4NH0.ZrKpJ0Yrti3yUxmfzsN7XjJupf1zAeG_Ad9Iq7eJn-o'

export const supabase = createClient(supabaseUrl, supabaseAnonKey)
