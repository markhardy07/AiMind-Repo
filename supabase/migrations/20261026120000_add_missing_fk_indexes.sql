-- Add covering indexes for unindexed foreign keys flagged by the Supabase
-- Performance Advisor. Forward-only and idempotent.
CREATE INDEX IF NOT EXISTS idx_mentor_requests_course_id ON public.mentor_requests (course_id);
CREATE INDEX IF NOT EXISTS idx_mentor_requests_module_id ON public.mentor_requests (module_id);
CREATE INDEX IF NOT EXISTS idx_scholarship_redemptions_user_id ON public.scholarship_redemptions (user_id);
CREATE INDEX IF NOT EXISTS idx_scholarship_seats_created_by ON public.scholarship_seats (created_by);
CREATE INDEX IF NOT EXISTS idx_social_link_clicks_post_id ON public.social_link_clicks (post_id);
CREATE INDEX IF NOT EXISTS idx_social_posts_created_by ON public.social_posts (created_by);
CREATE INDEX IF NOT EXISTS idx_social_posts_short_link_id ON public.social_posts (short_link_id);
CREATE INDEX IF NOT EXISTS idx_social_short_links_created_by ON public.social_short_links (created_by);
