-- AI Workout Review Feature Tables
-- Run this migration in Supabase SQL Editor

-- 1. Weekly/Monthly Summaries (for compressed context)
CREATE TABLE IF NOT EXISTS workout_summaries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    summary_type TEXT NOT NULL CHECK (summary_type IN ('weekly', 'monthly')),
    period_key TEXT NOT NULL, -- e.g., "2026-W07" or "2026-02"
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    data JSONB NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, summary_type, period_key)
);

-- Index for fast lookups
CREATE INDEX idx_summaries_user_type ON workout_summaries(user_id, summary_type);
CREATE INDEX idx_summaries_period ON workout_summaries(user_id, period_start DESC);

-- 2. AI Review Usage Tracking (PRO limits)
CREATE TABLE IF NOT EXISTS ai_review_usage (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    billing_period_start DATE NOT NULL,
    billing_period_end DATE NOT NULL,
    reviews_used INT DEFAULT 0,
    reviews_limit INT DEFAULT 175,
    total_cost_usd DECIMAL(10,4) DEFAULT 0,
    budget_usd DECIMAL(10,4) DEFAULT 3.50,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, billing_period_start)
);

-- Index for fast lookups
CREATE INDEX idx_usage_user ON ai_review_usage(user_id);
CREATE INDEX idx_usage_period ON ai_review_usage(user_id, billing_period_start DESC);

-- 3. AI Reviews (stored responses)
CREATE TABLE IF NOT EXISTS ai_reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    session_id UUID REFERENCES sessions(id) ON DELETE SET NULL,
    workout_date DATE NOT NULL,
    workout_day_id TEXT,
    workout_day_name TEXT,
    review_text TEXT NOT NULL,
    highlights JSONB, -- Array of key highlights
    recommendations JSONB, -- Array of recommendations
    concerns JSONB, -- Array of concerns
    input_tokens INT,
    output_tokens INT,
    cost_usd DECIMAL(10,6),
    follow_ups JSONB DEFAULT '[]', -- Array of follow-up Q&A
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for fast lookups
CREATE INDEX idx_reviews_user ON ai_reviews(user_id);
CREATE INDEX idx_reviews_date ON ai_reviews(user_id, workout_date DESC);
CREATE INDEX idx_reviews_session ON ai_reviews(session_id);

-- 4. User PRO status (simplified - can extend later)
-- For now, check profiles table or add is_pro column
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS is_pro BOOLEAN DEFAULT FALSE;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS pro_expires_at TIMESTAMPTZ;

-- RLS Policies
ALTER TABLE workout_summaries ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_review_usage ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_reviews ENABLE ROW LEVEL SECURITY;

-- Users can only see their own data
CREATE POLICY "Users can view own summaries" ON workout_summaries
    FOR SELECT USING (auth.uid() = user_id);
    
CREATE POLICY "Users can insert own summaries" ON workout_summaries
    FOR INSERT WITH CHECK (auth.uid() = user_id);
    
CREATE POLICY "Users can update own summaries" ON workout_summaries
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can view own usage" ON ai_review_usage
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can view own reviews" ON ai_reviews
    FOR SELECT USING (auth.uid() = user_id);

-- Service role can do everything (for Edge Functions)
CREATE POLICY "Service can manage summaries" ON workout_summaries
    FOR ALL USING (true) WITH CHECK (true);
    
CREATE POLICY "Service can manage usage" ON ai_review_usage
    FOR ALL USING (true) WITH CHECK (true);
    
CREATE POLICY "Service can manage reviews" ON ai_reviews
    FOR ALL USING (true) WITH CHECK (true);

-- Function to get or create current billing period
CREATE OR REPLACE FUNCTION get_or_create_usage(p_user_id UUID)
RETURNS ai_review_usage AS $$
DECLARE
    v_usage ai_review_usage;
    v_period_start DATE;
    v_period_end DATE;
BEGIN
    -- Calculate current billing period (1st of month to end of month)
    v_period_start := DATE_TRUNC('month', CURRENT_DATE)::DATE;
    v_period_end := (DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month - 1 day')::DATE;
    
    -- Try to get existing record
    SELECT * INTO v_usage
    FROM ai_review_usage
    WHERE user_id = p_user_id
      AND billing_period_start = v_period_start;
    
    -- Create if doesn't exist
    IF v_usage IS NULL THEN
        INSERT INTO ai_review_usage (
            user_id, billing_period_start, billing_period_end,
            reviews_used, reviews_limit, total_cost_usd, budget_usd
        ) VALUES (
            p_user_id, v_period_start, v_period_end,
            0, 175, 0, 3.50
        )
        RETURNING * INTO v_usage;
    END IF;
    
    RETURN v_usage;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
