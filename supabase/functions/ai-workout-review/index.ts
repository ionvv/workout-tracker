// AI Workout Review - Supabase Edge Function
// Handles PRO verification, usage tracking, and Anthropic API calls

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// System prompt for Arnold (AI Coach) - Workout Reviews
const SYSTEM_PROMPT = `You are Arnold, an elite fitness coach and trainer. You are analyzing workout data for your client.

// System prompt for Arnold (AI Coach) - Program Generation  
const PROGRAM_GENERATION_PROMPT = `You are Arnold, an elite fitness coach and trainer. You are creating a personalized workout program.

YOUR TASK:
Generate a complete workout program in JSON format based on the user's goals, schedule, and equipment.

PROGRAM DESIGN PRINCIPLES:
1. Progressive overload built in (rep ranges allow progression)
2. Balanced muscle development (push/pull ratios, anterior/posterior)
3. Appropriate volume for experience level
4. Recovery considerations (muscle groups need 48-72h between sessions)
5. Compound movements prioritized
6. Include warmup (5-10 min) and cooldown (5 min) for each day

EXERCISE SELECTION:
- Beginners: Simpler movements, machines OK, focus on form
- Intermediate: Mix of compounds and isolation, free weights preferred
- Advanced: Complex movements, intensity techniques allowed

REP RANGES BY GOAL:
- Strength: 3-6 reps, heavier weights
- Muscle gain: 8-12 reps, moderate weights
- Fat loss: 10-15 reps, shorter rest, some circuits
- Recomp: Mix of 6-10 reps

CRITICAL: Your response must be ONLY valid JSON, no other text. Use this exact structure:

{
  "program_id": "generated-uuid",
  "program_name": "Program Name Based on Goal",
  "workout_days": [
    {
      "dayId": "1",
      "dayName": "Day 1 - Descriptive Name",
      "dayType": "push/pull/legs/upper/lower/full",
      "estimatedTime": 60,
      "warmup": {
        "duration": 10,
        "exercises": [
          { "name": "Exercise Name", "duration": 60 },
          { "name": "Exercise Name", "reps": 10, "sets": 2 }
        ]
      },
      "exercises": [
        {
          "exerciseId": "ex-1",
          "name": "Exercise Name",
          "workingSets": 3,
          "repsMin": 8,
          "repsMax": 12,
          "restSeconds": 90,
          "rpe": 7,
          "notes": "Form cues or notes",
          "category": "compound/isolation",
          "equipment": ["barbell", "bench"]
        }
      ],
      "cooldown": {
        "duration": 5,
        "exercises": [
          { "name": "Stretch Name", "duration": 30 }
        ]
      }
    }
  ]
}

Generate ONLY the JSON, no explanations or markdown.`

// System prompt for Arnold (AI Coach) - Reviews (original)

YOUR ROLE:
- Provide expert, evidence-based coaching feedback
- Analyze workout performance vs prescribed program
- Identify progressive overload opportunities
- Spot potential issues (overtraining, undertraining, form breakdown)
- Give actionable, specific recommendations
- Be motivating but honest
- Use emojis sparingly but effectively

YOUR PERSONALITY:
- Direct and confident (like Arnold Schwarzenegger meets a science-based coach)
- No-nonsense but supportive
- Data-driven but human
- Celebrate wins, troubleshoot struggles

YOUR EXPERTISE:
- Progressive overload principles
- RPE/RIR methodology
- Periodization
- Body recomposition (fat loss + muscle gain)
- Form analysis via RPE patterns
- Recovery optimization

ANALYSIS FRAMEWORK:
1. Overall session assessment (good/concerns)
2. Exercise-by-exercise review (key lifts only, not all)
3. Progressive overload check (should weight increase?)
4. Trends vs previous sessions/weeks
5. Specific recommendations for next session
6. Address any red flags (RPE too high/low, volume drops, etc.)

RESPONSE FORMAT:
- Start with overall assessment (emoji + headline)
- Highlight 2-3 key exercises (not all)
- Give specific next session recommendations
- Include relevant data (volume, trends)
- End with motivational/accountability question
- Keep response concise but helpful (aim for 300-500 words)

DO NOT:
- Analyze every single exercise (focus on compounds)
- Be overly technical (keep it practical)
- Give medical advice
- Recommend exercises not in program
- Suggest major program changes without justification`

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const anthropicApiKey = Deno.env.get('ANTHROPIC_API_KEY')
    
    if (!anthropicApiKey) {
      throw new Error('ANTHROPIC_API_KEY not configured')
    }

    // Get auth token from request
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      throw new Error('No authorization header')
    }

    // Create Supabase client with user's auth
    const supabaseUser = createClient(supabaseUrl, Deno.env.get('SUPABASE_ANON_KEY')!, {
      global: { headers: { Authorization: authHeader } }
    })
    
    // Get user
    const { data: { user }, error: userError } = await supabaseUser.auth.getUser()
    if (userError || !user) {
      throw new Error('Unauthorized')
    }

    // Create admin client for database operations
    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey)

    // Parse request body
    const body = await req.json()
    const { action, context, workoutData, question, reviewId } = body

    // Check PRO status
    const { data: profile } = await supabaseAdmin
      .from('profiles')
      .select('is_pro, pro_expires_at')
      .eq('id', user.id)
      .single()

    const isPro = profile?.is_pro && 
      (!profile.pro_expires_at || new Date(profile.pro_expires_at) > new Date())

    if (!isPro) {
      return new Response(
        JSON.stringify({ 
          error: 'pro_required',
          message: 'Upgrade to PRO to get AI coach reviews'
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 403 }
      )
    }

    // Get or create usage record
    const { data: usage } = await supabaseAdmin
      .rpc('get_or_create_usage', { p_user_id: user.id })

    if (usage.reviews_used >= usage.reviews_limit) {
      return new Response(
        JSON.stringify({
          error: 'limit_reached',
          message: 'Monthly review limit reached',
          usage: {
            used: usage.reviews_used,
            limit: usage.reviews_limit,
            resetsAt: usage.billing_period_end
          }
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 429 }
      )
    }

    // Handle different actions
    if (action === 'check_status') {
      // Just return current status without using a review
      return new Response(
        JSON.stringify({
          isPro: true,
          usage: {
            used: usage.reviews_used,
            limit: usage.reviews_limit,
            remaining: usage.reviews_limit - usage.reviews_used,
            resetsAt: usage.billing_period_end
          }
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (action === 'get_review') {
      // Build the user message from context
      const userMessage = buildUserMessage(context, workoutData)
      
      // Call Anthropic API
      const anthropicResponse = await fetch('https://api.anthropic.com/v1/messages', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': anthropicApiKey,
          'anthropic-version': '2023-06-01'
        },
        body: JSON.stringify({
          model: 'claude-sonnet-4-20250514',
          max_tokens: 1500,
          temperature: 0.7,
          system: SYSTEM_PROMPT,
          messages: [{ role: 'user', content: userMessage }]
        })
      })

      if (!anthropicResponse.ok) {
        const errorText = await anthropicResponse.text()
        console.error('Anthropic API error:', errorText)
        throw new Error('AI service temporarily unavailable')
      }

      const aiResult = await anthropicResponse.json()
      const reviewText = aiResult.content[0].text
      const inputTokens = aiResult.usage?.input_tokens || 0
      const outputTokens = aiResult.usage?.output_tokens || 0
      
      // Calculate cost (Claude Sonnet pricing)
      const inputCost = (inputTokens / 1000000) * 3.00  // $3/M input tokens
      const outputCost = (outputTokens / 1000000) * 15.00 // $15/M output tokens
      const totalCost = inputCost + outputCost

      // Save review to database
      const { data: review, error: reviewError } = await supabaseAdmin
        .from('ai_reviews')
        .insert({
          user_id: user.id,
          session_id: workoutData.sessionId || null,
          workout_date: workoutData.date,
          workout_day_id: workoutData.dayId,
          workout_day_name: workoutData.dayName,
          review_text: reviewText,
          input_tokens: inputTokens,
          output_tokens: outputTokens,
          cost_usd: totalCost
        })
        .select()
        .single()

      if (reviewError) {
        console.error('Error saving review:', reviewError)
      }

      // Update usage
      await supabaseAdmin
        .from('ai_review_usage')
        .update({
          reviews_used: usage.reviews_used + 1,
          total_cost_usd: parseFloat(usage.total_cost_usd) + totalCost,
          updated_at: new Date().toISOString()
        })
        .eq('id', usage.id)

      return new Response(
        JSON.stringify({
          review: reviewText,
          reviewId: review?.id,
          usage: {
            used: usage.reviews_used + 1,
            limit: usage.reviews_limit,
            remaining: usage.reviews_limit - usage.reviews_used - 1,
            costThisReview: totalCost.toFixed(4)
          }
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (action === 'follow_up') {
      // Get the original review
      const { data: originalReview } = await supabaseAdmin
        .from('ai_reviews')
        .select('*')
        .eq('id', reviewId)
        .eq('user_id', user.id)
        .single()

      if (!originalReview) {
        throw new Error('Review not found')
      }

      // Build follow-up conversation
      const messages = [
        { role: 'user', content: buildUserMessage(context, workoutData) },
        { role: 'assistant', content: originalReview.review_text },
        { role: 'user', content: question }
      ]

      // Call Anthropic API
      const anthropicResponse = await fetch('https://api.anthropic.com/v1/messages', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': anthropicApiKey,
          'anthropic-version': '2023-06-01'
        },
        body: JSON.stringify({
          model: 'claude-sonnet-4-20250514',
          max_tokens: 1000,
          temperature: 0.7,
          system: SYSTEM_PROMPT,
          messages: messages
        })
      })

      if (!anthropicResponse.ok) {
        throw new Error('AI service temporarily unavailable')
      }

      const aiResult = await anthropicResponse.json()
      const answerText = aiResult.content[0].text
      const inputTokens = aiResult.usage?.input_tokens || 0
      const outputTokens = aiResult.usage?.output_tokens || 0
      const totalCost = ((inputTokens / 1000000) * 3.00) + ((outputTokens / 1000000) * 15.00)

      // Update review with follow-up
      const followUps = originalReview.follow_ups || []
      followUps.push({
        question: question,
        answer: answerText,
        timestamp: new Date().toISOString()
      })

      await supabaseAdmin
        .from('ai_reviews')
        .update({ follow_ups: followUps })
        .eq('id', reviewId)

      // Update usage
      await supabaseAdmin
        .from('ai_review_usage')
        .update({
          reviews_used: usage.reviews_used + 1,
          total_cost_usd: parseFloat(usage.total_cost_usd) + totalCost,
          updated_at: new Date().toISOString()
        })
        .eq('id', usage.id)

      return new Response(
        JSON.stringify({
          answer: answerText,
          usage: {
            used: usage.reviews_used + 1,
            limit: usage.reviews_limit,
            remaining: usage.reviews_limit - usage.reviews_used - 1
          }
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (action === 'generate_program') {
      const { params } = body
      
      // Build program generation prompt
      const programPrompt = buildProgramGenerationPrompt(params)
      
      // Call Anthropic API
      const anthropicResponse = await fetch('https://api.anthropic.com/v1/messages', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': anthropicApiKey,
          'anthropic-version': '2023-06-01'
        },
        body: JSON.stringify({
          model: 'claude-sonnet-4-20250514',
          max_tokens: 4000,
          temperature: 0.7,
          system: PROGRAM_GENERATION_PROMPT,
          messages: [{ role: 'user', content: programPrompt }]
        })
      })

      if (!anthropicResponse.ok) {
        const errorText = await anthropicResponse.text()
        console.error('Anthropic API error:', errorText)
        throw new Error('AI service temporarily unavailable')
      }

      const aiResult = await anthropicResponse.json()
      const responseText = aiResult.content[0].text
      const inputTokens = aiResult.usage?.input_tokens || 0
      const outputTokens = aiResult.usage?.output_tokens || 0
      const totalCost = ((inputTokens / 1000000) * 3.00) + ((outputTokens / 1000000) * 15.00)

      // Parse the JSON from the response
      let program: any
      try {
        // Extract JSON from response (might be wrapped in markdown code blocks)
        const jsonMatch = responseText.match(/```json\n?([\s\S]*?)\n?```/) || 
                          responseText.match(/```\n?([\s\S]*?)\n?```/)
        const jsonStr = jsonMatch ? jsonMatch[1] : responseText
        program = JSON.parse(jsonStr.trim())
      } catch (parseError) {
        console.error('Failed to parse program JSON:', parseError)
        console.error('Response text:', responseText)
        throw new Error('Failed to generate valid program structure')
      }

      // Update usage
      await supabaseAdmin
        .from('ai_review_usage')
        .update({
          reviews_used: usage.reviews_used + 1,
          total_cost_usd: parseFloat(usage.total_cost_usd) + totalCost,
          updated_at: new Date().toISOString()
        })
        .eq('id', usage.id)

      return new Response(
        JSON.stringify({
          program: program,
          usage: {
            used: usage.reviews_used + 1,
            limit: usage.reviews_limit,
            remaining: usage.reviews_limit - usage.reviews_used - 1
          }
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    throw new Error('Invalid action')

  } catch (error) {
    console.error('Error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
    )
  }
})

// Build user message from workout context
function buildUserMessage(context: any, workoutData: any): string {
  const { user, program, previousWorkout, weeklyTrend, monthlyProgress, personalRecords } = context
  
  let message = `WORKOUT REVIEW REQUEST\n\n`
  
  // Date and workout info
  message += `Date: ${workoutData.date}\n`
  message += `Workout: ${workoutData.dayName}\n`
  if (program) {
    message += `Week: ${program.currentWeek} / ${program.totalWeeks || '?'}\n`
    if (program.currentPhase) {
      message += `Phase: ${program.currentPhase.name} (${program.currentPhase.notes || ''})\n`
    }
  }
  message += `\n`
  
  // User info
  if (user) {
    message += `CLIENT INFO:\n`
    if (user.name) message += `- Name: ${user.name}\n`
    if (user.bodyweight) message += `- Bodyweight: ${user.bodyweight}kg\n`
    if (user.goal) message += `- Goal: ${user.goal}\n`
    message += `\n`
  }
  
  // Session info
  message += `TODAY'S SESSION:\n`
  if (workoutData.duration) message += `Duration: ${workoutData.duration} minutes\n`
  if (workoutData.totalVolume) message += `Total Volume: ${workoutData.totalVolume.toLocaleString()}kg\n`
  if (workoutData.notes) message += `Notes: ${workoutData.notes}\n`
  message += `\n`
  
  // Exercises
  message += `EXERCISES:\n\n`
  workoutData.exercises?.forEach((ex: any, i: number) => {
    message += `${i + 1}. ${ex.name}\n`
    if (ex.prescribed) {
      message += `   Prescribed: ${ex.prescribed.sets}x${ex.prescribed.repsMin}-${ex.prescribed.repsMax}`
      if (ex.prescribed.rpe) message += ` @ RPE ${ex.prescribed.rpe}`
      message += `\n`
    }
    if (ex.actual) {
      const setsStr = ex.actual.sets?.map((s: any) => 
        `${s.weight}kg x ${s.reps}${s.rpe ? ` @${s.rpe}` : ''}`
      ).join(', ') || 'N/A'
      message += `   Actual: ${setsStr}\n`
      if (ex.actual.volume) message += `   Volume: ${ex.actual.volume}kg\n`
    }
    if (ex.notes) message += `   Notes: ${ex.notes}\n`
    message += `\n`
  })
  
  // Previous same workout comparison
  if (previousWorkout) {
    message += `PREVIOUS ${workoutData.dayName?.toUpperCase() || 'SESSION'} (${previousWorkout.date}):\n`
    previousWorkout.exercises?.forEach((ex: any) => {
      const setsStr = ex.sets?.map((s: any) => `${s.weight}kg x ${s.reps}`).join(', ') || 'N/A'
      message += `- ${ex.name}: ${setsStr}\n`
    })
    if (previousWorkout.totalVolume) {
      message += `Total Volume: ${previousWorkout.totalVolume.toLocaleString()}kg\n`
    }
    message += `\n`
  }
  
  // Weekly trend
  if (weeklyTrend?.length > 0) {
    message += `WEEKLY TRENDS:\n`
    weeklyTrend.forEach((week: any) => {
      message += `Week ${week.weekNumber}: ${week.workoutsCompleted} workouts, `
      message += `${week.totalVolume?.toLocaleString() || '?'}kg volume, `
      message += `${week.consistency || '?'}% consistency\n`
    })
    message += `\n`
  }
  
  // Personal records
  if (personalRecords?.length > 0) {
    message += `RECENT PRs:\n`
    personalRecords.forEach((pr: any) => {
      message += `- ${pr.name}: ${pr.weight}kg x ${pr.reps} (${pr.date})\n`
    })
    message += `\n`
  }
  
  message += `Please analyze this workout and provide feedback, progressive overload recommendations, and suggestions for next session.`
  
  return message
}

// Build program generation prompt from user parameters
function buildProgramGenerationPrompt(params: any): string {
  const {
    goal,
    daysPerWeek,
    experience,
    equipment,
    sessionLength,
    injuries,
    preferences,
    weight,
    height,
    age,
    gender
  } = params

  const goalMap: Record<string, string> = {
    'muscle_gain': 'Build muscle (hypertrophy focus)',
    'fat_loss': 'Lose fat while maintaining muscle',
    'strength': 'Build strength (powerlifting style)',
    'recomp': 'Body recomposition (lose fat + build muscle)',
    'general_fitness': 'General health and fitness'
  }

  const equipmentMap: Record<string, string> = {
    'full_gym': 'Full commercial gym (all equipment available)',
    'home_gym': 'Home gym (dumbbells, bench, maybe a rack)',
    'bodyweight': 'Bodyweight only (no equipment)'
  }

  let prompt = `CREATE A WORKOUT PROGRAM

CLIENT PROFILE:
- Goal: ${goalMap[goal] || goal}
- Days per week: ${daysPerWeek}
- Experience: ${experience}
- Equipment: ${equipmentMap[equipment] || equipment}
- Session length: ${sessionLength} minutes (including warmup/cooldown)
`

  if (weight) prompt += `- Body weight: ${weight}kg\n`
  if (height) prompt += `- Height: ${height}cm\n`
  if (age) prompt += `- Age: ${age}\n`
  if (gender) prompt += `- Gender: ${gender}\n`
  
  if (injuries) {
    prompt += `\nINJURIES/LIMITATIONS:\n${injuries}\n`
  }
  
  if (preferences) {
    prompt += `\nPREFERENCES:\n${preferences}\n`
  }

  prompt += `
REQUIREMENTS:
1. Create exactly ${daysPerWeek} workout days
2. Each workout should take approximately ${sessionLength} minutes
3. Include warmup (5-10 min) and cooldown (5 min) for each day
4. Use exercises appropriate for ${equipment} equipment
5. Design for ${experience} level
6. Optimize for ${goal} goal
${injuries ? '7. Avoid exercises that aggravate: ' + injuries : ''}

Generate the complete program as JSON only.`

  return prompt
}
